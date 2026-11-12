import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:sensebox_bike/ble/ble_characteristic_streams.dart';
import 'package:sensebox_bike/ble/ble_constants.dart';
import 'package:sensebox_bike/ble/ble_device.dart';
import 'package:sensebox_bike/ble/ble_platform.dart';
import 'package:sensebox_bike/ble/ble_scanner.dart';
import 'package:sensebox_bike/ble/ble_uuids.dart';
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
    BlePlatform? platform,
    this.connectTimeLimit = bleConnectTimeLimit,
    this.reconnectTimeLimit = bleReconnectTimeLimit,
  }) : _platform = platform ?? BlePlatform() {
    _scanner = BleScanner(_platform);
    characteristicStreams = BleCharacteristicStreams(platform: _platform);
    _adapterStatusSubscription =
        _platform.statusStream.listen(_onAdapterStatusChanged);
    _linkSubscription = _platform.linkStates.listen(_onLinkStateChanged);
  }

  final SettingsBloc settingsBloc;
  final BlePlatform _platform;
  final Duration connectTimeLimit;
  final Duration reconnectTimeLimit;

  final ValueNotifier<bool> isBluetoothEnabledNotifier = ValueNotifier(false);
  final ValueNotifier<BleConnectionPhase> phaseNotifier =
      ValueNotifier(BleConnectionPhase.idle);
  final ValueNotifier<BleDevice?> selectedDeviceNotifier = ValueNotifier(null);
  final ValueNotifier<List<BleUuid>> availableCharacteristics =
      ValueNotifier(const []);
  final ValueNotifier<bool> connectionErrorNotifier = ValueNotifier(false);

  late final BleScanner _scanner;
  late final BleCharacteristicStreams characteristicStreams;
  late final StreamSubscription<BleAdapterState> _adapterStatusSubscription;
  late final StreamSubscription<BleLinkState> _linkSubscription;

  bool _userInitiatedDisconnect = false;
  bool _autoConnectInProgress = false;

  BleConnectionPhase get phase => phaseNotifier.value;
  bool get isConnected => phase == BleConnectionPhase.connected;

  BleDevice? get selectedDevice => selectedDeviceNotifier.value;
  set selectedDevice(BleDevice? device) => selectedDeviceNotifier.value = device;

  void _setPhase(BleConnectionPhase next) {
    if (phase != next) {
      ErrorService.logEvent('ble', 'phase ${next.name}',
          data: {'from': phase.name});
    }
    phaseNotifier.value = next;
    notifyListeners();
  }

  void _onAdapterStatusChanged(BleAdapterState status) {
    updateBluetoothStatus(status == BleAdapterState.ready);
    if (status == BleAdapterState.ready && phase == BleConnectionPhase.idle) {
      unawaited(autoConnectToRememberedDevice());
    }
  }

  void updateBluetoothStatus(bool isEnabled) {
    if (isBluetoothEnabledNotifier.value != isEnabled) {
      isBluetoothEnabledNotifier.value = isEnabled;
      notifyListeners();
    }
  }

  void _onLinkStateChanged(BleLinkState state) {
    final device = selectedDevice;
    if (state != BleLinkState.disconnected ||
        phase != BleConnectionPhase.connected ||
        device == null) {
      return;
    }
    if (settingsBloc.vibrateOnDisconnect) {
      ErrorService.logEvent('ble', 'vibrate on unexpected disconnect',
          data: {'device': device.id});
      unawaited(_pulseDisconnectVibration());
    }
    unawaited(_reconnect(device));
  }

  Future<void> _pulseDisconnectVibration() async {
    await vibrateDisconnectFeedback();
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    if (_userInitiatedDisconnect || _platform.isConnected) {
      return;
    }
    ErrorService.logEvent('ble', 'vibrate retry after disconnect');
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

  Stream<List<BleDevice>> scanForDevices() => _scanner.scanForDevices();

  Future<void> disconnectDevice() => _disconnect(failed: false);

  Future<void> _disconnect({required bool failed}) async {
    if (!failed) {
      _userInitiatedDisconnect = true;
      unawaited(_scanner.stopScanning());
    }
    _setPhase(BleConnectionPhase.connecting);
    try {
      availableCharacteristics.value = const [];
      await _releaseLink(settle: blePostDisconnectSettleDelay);
      connectionErrorNotifier.value = failed;
    } finally {
      selectedDevice = null;
      _setPhase(BleConnectionPhase.idle);
    }
  }

  Future<void> _releaseLink({required Duration settle}) async {
    await characteristicStreams.clear();
    try {
      await _platform.disconnect();
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
    if (phase != BleConnectionPhase.idle) {
      return;
    }
    _userInitiatedDisconnect = false;
    connectionErrorNotifier.value = false;
    _setPhase(BleConnectionPhase.connecting);
    try {
      await _connectWithRetries(
        device,
        timeLimit: connectTimeLimit,
        shouldStop: () => _userInitiatedDisconnect,
      );
      selectedDevice = device;
      _setPhase(BleConnectionPhase.connected);
    } catch (error, stackTrace) {
      if (!_userInitiatedDisconnect) {
        await _failConnection(
          BleConnectionFailurePhase.initialConnect,
          error,
          stackTrace,
        );
      }
    } finally {
      if (phase != BleConnectionPhase.connected) {
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
      } catch (error) {
        ErrorService.logEvent('ble', 'connect attempt failed',
            data: {'device': device.id, 'error': error.toString()});
        if (shouldStop()) {
          break;
        }
        if (elapsed.elapsed >= timeLimit) {
          rethrow;
        }
      }
      await _releaseLink(settle: bleSessionRetryDelay);
    }
    await _releaseLink(settle: Duration.zero);
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
  Future<void> _establishSession(BleDevice device) async {
    if (!_platform.isConnected) {
      final advertised = await _scanner.waitForAdvertisingDevice(device);
      if (advertised == null) {
        throw StateError('BLE device not advertising');
      }
      await _platform.connect(advertised.id);
    }
    availableCharacteristics.value = await characteristicStreams.establish();
  }

  Future<void> _reconnect(BleDevice device) async {
    if (phase != BleConnectionPhase.connected || selectedDevice != device) {
      return;
    }
    bool stopped() => _userInitiatedDisconnect || selectedDevice != device;

    availableCharacteristics.value = const [];
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
          BleConnectionFailurePhase.reconnection,
          error,
          stackTrace,
        );
      }
    }
  }

  Future<void> _failConnection(
    BleConnectionFailurePhase failurePhase,
    Object cause,
    StackTrace stackTrace,
  ) async {
    await ErrorService.reportToSentry(
      BleConnectionFailed(failurePhase, cause),
      stackTrace,
    );
    await _disconnect(failed: true);
  }

  void resetConnectionError() {
    connectionErrorNotifier.value = false;
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
        phase != BleConnectionPhase.idle) {
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
          phase != BleConnectionPhase.idle) {
        return;
      }
      await connectToDevice(found);
    } catch (_) {
      // Auto-connect is best-effort; never surface an error for it.
    } finally {
      _autoConnectInProgress = false;
    }
  }

  Future<void> requestEnableBluetooth() =>
      PermissionService.ensureBluetoothPermissionsGranted();

  @override
  void dispose() {
    _adapterStatusSubscription.cancel();
    _linkSubscription.cancel();
    _scanner.dispose();
    unawaited(characteristicStreams.clear());
    characteristicStreams.dispose();
    unawaited(_platform.dispose());
    selectedDeviceNotifier.dispose();
    isBluetoothEnabledNotifier.dispose();
    phaseNotifier.dispose();
    availableCharacteristics.dispose();
    connectionErrorNotifier.dispose();
    super.dispose();
  }
}
