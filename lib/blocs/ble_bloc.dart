import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:sensebox_bike/ble/ble_characteristic_ref.dart';
import 'package:sensebox_bike/ble/ble_characteristic_streams.dart';
import 'package:sensebox_bike/ble/ble_connection_session.dart';
import 'package:sensebox_bike/ble/ble_constants.dart';
import 'package:sensebox_bike/ble/ble_device.dart';
import 'package:sensebox_bike/ble/ble_platform.dart';
import 'package:sensebox_bike/ble/ble_scanner.dart';
import 'package:sensebox_bike/blocs/settings_bloc.dart';
import 'package:sensebox_bike/services/custom_exceptions.dart';
import 'package:sensebox_bike/services/error_service.dart';
import 'package:sensebox_bike/services/permission_service.dart';
import 'package:sensebox_bike/utils/device_vibration.dart';

enum BleConnectionPhase {
  idle,
  connecting,
  connected,
  reconnecting,
}

class BleBloc with ChangeNotifier {
  BleBloc(
    this.settingsBloc, {
    bool initializePlatformBle = true,
    BlePlatform? platform,
    Duration adapterOffDebounce = bleAdapterOffDebounce,
    this.connectTimeLimit = bleConnectTimeLimit,
    this.reconnectTimeLimit = bleReconnectTimeLimit,
  })  : _platform = platform ?? BlePlatform(),
        _adapterOffDebounce = adapterOffDebounce {
    _scanner = BleScanner(
      platform: _platform,
      isScanningNotifier: isScanningNotifier,
    );
    _connectionSession = BleConnectionSession(platform: _platform);
    characteristicStreams = BleCharacteristicStreams(platform: _platform);

    if (initializePlatformBle) {
      _refreshBluetoothEnabledStatus();
      _adapterStatusSubscription =
          _platform.statusStream.listen(_onAdapterStatusChanged);
    }
  }

  final SettingsBloc settingsBloc;
  final BlePlatform _platform;
  final Duration _adapterOffDebounce;
  final Duration connectTimeLimit;
  final Duration reconnectTimeLimit;

  final ValueNotifier<bool> isBluetoothEnabledNotifier = ValueNotifier(false);
  final ValueNotifier<bool> isScanningNotifier = ValueNotifier(false);
  final ValueNotifier<bool> isConnectingNotifier = ValueNotifier(false);
  final ValueNotifier<bool> isReconnectingNotifier = ValueNotifier(false);
  final ValueNotifier<BleDevice?> selectedDeviceNotifier = ValueNotifier(null);
  final ValueNotifier<List<BleCharacteristicRef>> availableCharacteristics =
      ValueNotifier([]);
  final ValueNotifier<bool> connectionErrorNotifier = ValueNotifier(false);

  late final BleScanner _scanner;
  late final BleConnectionSession _connectionSession;
  late final BleCharacteristicStreams characteristicStreams;

  StreamSubscription<BleAdapterState>? _adapterStatusSubscription;
  StreamSubscription<BleLinkState>? _linkSubscription;

  List<BleDevice> get devicesList => _scanner.devicesList;
  Stream<List<BleDevice>> get devicesListStream => _scanner.devicesListStream;

  BleDevice? get selectedDevice => selectedDeviceNotifier.value;
  set selectedDevice(BleDevice? device) => selectedDeviceNotifier.value = device;

  BleConnectionPhase _phase = BleConnectionPhase.idle;
  bool _userInitiatedDisconnect = false;
  bool _autoConnectInProgress = false;

  bool get isConnected => _phase == BleConnectionPhase.connected;

  void _setPhase(BleConnectionPhase phase) {
    if (_phase != phase) {
      ErrorService.logEvent('ble', 'phase ${phase.name}',
          data: {'from': _phase.name});
    }
    _phase = phase;
    isConnectingNotifier.value = phase == BleConnectionPhase.connecting;
    isReconnectingNotifier.value = phase == BleConnectionPhase.reconnecting;
    notifyListeners();
  }

  Future<void> _refreshBluetoothEnabledStatus() async {
    updateBluetoothStatus(await _platform.isAdapterEnabled());
  }

  void _onAdapterStatusChanged(BleAdapterState status) {
    updateBluetoothStatus(isBluetoothAdapterEnabled(status));
    if (status == BleAdapterState.poweredOff) {
      unawaited(_onBluetoothPoweredOff());
    } else if (status == BleAdapterState.ready) {
      unawaited(_onBluetoothPoweredOn());
    }
  }

  Future<void> _onBluetoothPoweredOff() async {
    bool linkStillExpected() =>
        !_userInitiatedDisconnect &&
        selectedDevice != null &&
        _phase == BleConnectionPhase.connected;
    if (!linkStillExpected()) {
      return;
    }

    // Debounce: Android power-save/Doze can emit a transient `poweredOff` status
    // while the radio and the GATT link are still alive. Wait briefly and
    // re-check before tearing down a link that may have survived the blip.
    if (_adapterOffDebounce > Duration.zero) {
      await Future<void>.delayed(_adapterOffDebounce);
    }
    final device = selectedDevice;
    if (!linkStillExpected() || _platform.isConnected(device!.id)) {
      return;
    }

    try {
      await _platform.disconnect(device.id);
    } catch (_) {}
    unawaited(_reconnect(device));
  }

  Future<void> _onBluetoothPoweredOn() async {
    if (_userInitiatedDisconnect || selectedDevice == null) {
      unawaited(autoConnectToRememberedDevice());
      return;
    }
    final device = selectedDevice!;
    if (!_platform.isConnected(device.id)) {
      unawaited(_reconnect(device));
    }
  }

  void _invalidatePublishedCharacteristics() {
    if (availableCharacteristics.value.isNotEmpty) {
      availableCharacteristics.value = [];
    }
  }

  Future<void> _pulseDisconnectVibration(String deviceId) async {
    await vibrateDisconnectFeedback();
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    if (_userInitiatedDisconnect || _platform.isConnected(deviceId)) {
      return;
    }
    ErrorService.logEvent('ble', 'vibrate retry after disconnect',
        data: {'device': deviceId});
    await vibrateDisconnectFeedback();
  }

  Future<void> _waitForBluetoothReady() async {
    bool canContinue() =>
        isBluetoothEnabledNotifier.value || _userInitiatedDisconnect;
    if (canContinue()) {
      return;
    }
    final ready = Completer<void>();
    void onChange() {
      if (canContinue() && !ready.isCompleted) {
        ready.complete();
      }
    }

    addListener(onChange);
    try {
      await ready.future;
    } finally {
      removeListener(onChange);
    }
  }

  void updateBluetoothStatus(bool isEnabled) {
    if (isBluetoothEnabledNotifier.value != isEnabled) {
      isBluetoothEnabledNotifier.value = isEnabled;
      notifyListeners();
    }
  }

  Future<void> startScanning() async => _scanner.startScanning();

  Future<void> stopScanning() => _scanner.stopScanning();

  Future<void> scanForNewDevices() async {
    await disconnectDevice();
    await startScanning();
  }

  Future<void> disconnectDevice() => _disconnect(selectedDevice, failed: false);

  Future<void> _disconnect(BleDevice? device, {required bool failed}) async {
    if (!failed) {
      _userInitiatedDisconnect = true;
      unawaited(_scanner.stopScanning());
    }
    _setPhase(BleConnectionPhase.connecting);
    try {
      _invalidatePublishedCharacteristics();
      if (device != null) {
        await _releaseLink(device, settle: blePostDisconnectSettleDelay);
      }
      connectionErrorNotifier.value = failed;
      if (!failed) {
        _scanner.clearDiscoveredDevices();
      }
    } finally {
      unawaited(_linkSubscription?.cancel());
      _linkSubscription = null;
      selectedDevice = null;
      _setPhase(BleConnectionPhase.idle);
    }
  }

  Future<void> _releaseLink(BleDevice device, {required Duration settle}) async {
    await characteristicStreams.clear();
    try {
      await _platform.disconnect(device.id);
    } catch (_) {}
    await Future<void>.delayed(settle);
  }

  Future<void> connectToName(String name) async {
    final found = await _scanner.waitForAdvertisingDevice(
      BleDevice(id: '', name: name),
    );
    if (found != null) {
      await connectToDevice(found);
    }
  }

  Future<void> connectToDevice(BleDevice device) async {
    if (_phase == BleConnectionPhase.connecting ||
        _phase == BleConnectionPhase.reconnecting) {
      return;
    }

    _userInitiatedDisconnect = false;

    try {
      resetConnectionError();
      _setPhase(BleConnectionPhase.connecting);
      await _connectWithRetries(
        device,
        timeLimit: connectTimeLimit,
        shouldStop: () => _userInitiatedDisconnect,
      );
      selectedDevice = device;
      _setPhase(BleConnectionPhase.connected);
      _watchLink(device);
    } catch (error, stackTrace) {
      if (!_userInitiatedDisconnect) {
        await _failConnection(
          device,
          BleConnectionFailurePhase.initialConnect,
          error,
          stackTrace,
        );
      }
    } finally {
      if (_phase != BleConnectionPhase.connected) {
        _setPhase(BleConnectionPhase.idle);
      }
    }
  }

  Future<void> _connectWithRetries(
    BleDevice device, {
    required Duration timeLimit,
    required bool Function() shouldStop,
  }) async {
    final elapsed = Stopwatch()..start();
    while (true) {
      await _waitForBluetoothReady();
      if (shouldStop()) {
        break;
      }
      try {
        await _establishSession(device);
        if (!shouldStop()) {
          return;
        }
        break;
      } catch (_) {
        if (shouldStop()) {
          break;
        }
        if (elapsed.elapsed >= timeLimit) {
          rethrow;
        }
      }
      await _releaseLink(device, settle: bleSessionRetryDelay);
    }
    await _releaseLink(device, settle: Duration.zero);
    throw StateError('BLE connection attempts stopped');
  }

  // Always scan before connecting, even when the device id is known.
  // On Android, flutter_reactive_ble caches the native connection per device
  // and only drops it when the connect subscription is cancelled while still
  // active. After a link loss that stream ends on its own, so a direct
  // reconnect reuses the dead connection: notifications get enabled but never
  // deliver data. The scan gives the plugin time to clear that state.
  // The scan is filtered by every service UUID this box has advertised so far:
  // iOS returns nothing for unfiltered scans in the background, and Android
  // pauses them while the screen is off. A box advertises a different UUID
  // while it is still booting, so after a filtered scan misses, the next scan
  // for that box is unfiltered and picks up the new UUID.
  Future<void> _connectLink(BleDevice device) async {
    final advertised = await _scanner.waitForAdvertisingDevice(device);
    if (advertised == null) {
      throw StateError('BLE device not advertising');
    }
    await _platform.connect(advertised.id);
  }

  Future<void> _establishSession(BleDevice device) async {
    if (!_platform.isConnected(device.id)) {
      await _connectLink(device);
    }
    final result = await _connectionSession.establish(
      device,
      streams: characteristicStreams,
    );
    ErrorService.logEvent('ble', 'session probe', data: {
      'device': device.id,
      'success': result.success,
    });
    if (!result.success) {
      throw TimeoutException(
        'Connected, but no sensor data received',
        bleConnectionSessionProbeTimeout,
      );
    }
    availableCharacteristics.value = result.characteristics;
  }

  void _watchLink(BleDevice device) {
    unawaited(_linkSubscription?.cancel());
    _linkSubscription = _platform.connectionState(device.id).listen((state) {
      if (state != BleLinkState.disconnected ||
          _phase != BleConnectionPhase.connected ||
          _userInitiatedDisconnect) {
        return;
      }
      if (settingsBloc.vibrateOnDisconnect) {
        ErrorService.logEvent('ble', 'vibrate on unexpected disconnect',
            data: {'device': device.id});
        unawaited(_pulseDisconnectVibration(device.id));
      }
      unawaited(_reconnect(device));
    });
  }

  Future<void> _reconnect(BleDevice device) async {
    if (_phase != BleConnectionPhase.connected || selectedDevice != device) {
      return;
    }
    bool stopped() => _userInitiatedDisconnect || selectedDevice != device;

    _invalidatePublishedCharacteristics();
    _setPhase(BleConnectionPhase.reconnecting);
    try {
      await _connectWithRetries(
        device,
        timeLimit: reconnectTimeLimit,
        shouldStop: stopped,
      );
      _setPhase(BleConnectionPhase.connected);
    } catch (error, stackTrace) {
      if (!stopped()) {
        await _failConnection(
          device,
          BleConnectionFailurePhase.reconnection,
          error,
          stackTrace,
        );
      }
    }
  }

  Future<void> _failConnection(
    BleDevice device,
    BleConnectionFailurePhase failurePhase,
    Object? cause,
    StackTrace? stackTrace,
  ) async {
    await ErrorService.reportToSentry(
      BleConnectionFailed(failurePhase, cause),
      stackTrace ?? StackTrace.current,
    );
    await _disconnect(device, failed: true);
  }

  void resetConnectionError() {
    connectionErrorNotifier.value = false;
  }

  @visibleForTesting
  void debugSetConnectionPhase(BleConnectionPhase phase) => _setPhase(phase);

  @visibleForTesting
  void debugWatchLink(BleDevice device) => _watchLink(device);

  @visibleForTesting
  Future<void> debugOnBluetoothPoweredOff() => _onBluetoothPoweredOff();

  @visibleForTesting
  Future<void> debugOnBluetoothPoweredOn() => _onBluetoothPoweredOn();

  @override
  void dispose() {
    _adapterStatusSubscription?.cancel();
    _linkSubscription?.cancel();
    _scanner.dispose();
    unawaited(characteristicStreams.clear());
    characteristicStreams.dispose();
    unawaited(_platform.dispose());
    selectedDeviceNotifier.dispose();
    isBluetoothEnabledNotifier.dispose();
    isScanningNotifier.dispose();
    isConnectingNotifier.dispose();
    isReconnectingNotifier.dispose();
    availableCharacteristics.dispose();
    connectionErrorNotifier.dispose();
    super.dispose();
  }

  /// Best-effort, silent connect to the device remembered via
  /// [SettingsBloc.rememberDevice]. Does a short bounded scan for the
  /// device's advertisement; if it isn't found (box off / out of range) this
  /// gives up quietly without reporting an error — that's the expected case,
  /// not a failure. Safe to call repeatedly (e.g. on every adapter power-on).
  Future<void> autoConnectToRememberedDevice({
    Duration scanTimeout = bleAutoConnectScanTimeout,
  }) async {
    final id = settingsBloc.rememberedDeviceId;
    if (id == null || id.isEmpty) {
      return;
    }
    if (_autoConnectInProgress ||
        _userInitiatedDisconnect ||
        !isBluetoothEnabledNotifier.value ||
        _phase != BleConnectionPhase.idle) {
      return;
    }

    _autoConnectInProgress = true;
    try {
      final target =
          BleDevice(id: id, name: settingsBloc.rememberedDeviceName ?? '');
      final found = await _scanner.waitForAdvertisingDevice(
        target,
        timeout: scanTimeout,
      );
      if (found == null ||
          _userInitiatedDisconnect ||
          _phase != BleConnectionPhase.idle) {
        return;
      }
      await connectToDevice(found);
    } catch (_) {
      // Auto-connect is best-effort; never surface an error for it.
    } finally {
      _autoConnectInProgress = false;
    }
  }

  Future<void> requestEnableBluetooth() async {
    await PermissionService.ensureBluetoothPermissionsGranted();
    await _refreshBluetoothEnabledStatus();
  }
}
