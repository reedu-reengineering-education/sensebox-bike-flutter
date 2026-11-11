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

enum BleDisconnectReason {
  userRequested,
  connectionFailed,
  retryRelease,
}

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
    _platform.onLinkStateChanged = _handlePlatformLinkStateChange;

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
  final ValueNotifier<int> characteristicStreamsVersion = ValueNotifier(0);
  final ValueNotifier<bool> connectionErrorNotifier = ValueNotifier(false);

  late final BleScanner _scanner;
  late final BleConnectionSession _connectionSession;
  late final BleCharacteristicStreams characteristicStreams;

  StreamSubscription<BleAdapterState>? _adapterStatusSubscription;
  StreamSubscription<BleLinkState>? _linkSubscription;

  List<BleDevice> get devicesList => _scanner.devicesList;
  Stream<List<BleDevice>> get devicesListStream => _scanner.devicesListStream;

  BleDevice? selectedDevice;
  BleDevice? _linkWatchDevice;
  BleConnectionPhase _phase = BleConnectionPhase.idle;
  bool _userInitiatedDisconnect = false;
  bool _appInitiatedTeardown = false;
  bool _linkLostDueToAdapterPowerOff = false;
  String? _vibratedForDisconnectDeviceId;
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
    if (_userInitiatedDisconnect || selectedDevice == null) {
      return;
    }
    if (_phase != BleConnectionPhase.connected &&
        _phase != BleConnectionPhase.reconnecting) {
      return;
    }

    // Debounce: Android power-save/Doze can emit a transient `poweredOff` status
    // while the radio and the GATT link are still alive. Wait briefly and
    // re-check before tearing down a link that may have survived the blip.
    if (_adapterOffDebounce > Duration.zero) {
      await Future<void>.delayed(_adapterOffDebounce);
    }

    if (_userInitiatedDisconnect || selectedDevice == null) {
      return;
    }
    if (_phase != BleConnectionPhase.connected &&
        _phase != BleConnectionPhase.reconnecting) {
      return;
    }
    // If the link is still up after the debounce, it was a spurious blip; keep it.
    if (_platform.isConnected(selectedDevice!.id)) {
      return;
    }

    _linkLostDueToAdapterPowerOff = true;
    final deviceId = selectedDevice!.id;

    try {
      await _platform.disconnect(deviceId);
    } catch (_) {}

    _maybeVibrateOnUnexpectedDisconnect(deviceId);
    unawaited(_reconnect(selectedDevice!));
  }

  Future<void> _onBluetoothPoweredOn() async {
    if (_userInitiatedDisconnect || selectedDevice == null) {
      unawaited(autoConnectToRememberedDevice());
      return;
    }
    if (_phase == BleConnectionPhase.connecting ||
        _phase == BleConnectionPhase.reconnecting) {
      return;
    }
    final device = selectedDevice!;
    if (_platform.isConnected(device.id) && !_linkLostDueToAdapterPowerOff) {
      return;
    }
    _linkLostDueToAdapterPowerOff = false;
    unawaited(_reconnect(device));
  }

  void _invalidatePublishedCharacteristics() {
    if (availableCharacteristics.value.isEmpty) {
      return;
    }
    availableCharacteristics.value = [];
    characteristicStreamsVersion.value++;
  }

  void _handlePlatformLinkStateChange(
    String deviceId,
    BleLinkState? previous,
    BleLinkState next,
  ) {
    if (next == BleLinkState.connected) {
      if (_vibratedForDisconnectDeviceId == deviceId) {
        _vibratedForDisconnectDeviceId = null;
      }
      return;
    }
    if (previous != BleLinkState.connected) {
      return;
    }
    _maybeVibrateOnUnexpectedDisconnect(deviceId);
  }

  void _maybeVibrateOnUnexpectedDisconnect(String deviceId) {
    if (!settingsBloc.vibrateOnDisconnect) {
      return;
    }
    if (_userInitiatedDisconnect || _appInitiatedTeardown) {
      return;
    }
    final device = selectedDevice ?? _linkWatchDevice;
    if (device == null || device.id != deviceId) {
      return;
    }
    if (_vibratedForDisconnectDeviceId == deviceId) {
      return;
    }
    _vibratedForDisconnectDeviceId = deviceId;
    ErrorService.logEvent('ble', 'vibrate on unexpected disconnect',
        data: {'device': deviceId});
    unawaited(_pulseDisconnectVibration(deviceId));
  }

  Future<void> _pulseDisconnectVibration(String deviceId) async {
    await vibrateDisconnectFeedback();

    await Future<void>.delayed(const Duration(milliseconds: 1200));
    if (_vibratedForDisconnectDeviceId != deviceId) {
      return;
    }
    if (_userInitiatedDisconnect || _appInitiatedTeardown) {
      return;
    }
    if (_platform.isConnected(deviceId)) {
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

  Future<void> startScanning() => _scanner.startScanning();

  Future<void> stopScanning() => _scanner.stopScanning();

  Future<void> scanForNewDevices() async {
    await disconnectDevice(reason: BleDisconnectReason.userRequested);
    await startScanning();
  }

  Future<void> disconnectDevice({
    BleDevice? device,
    BleDisconnectReason reason = BleDisconnectReason.userRequested,
  }) async {
    final target = device ?? selectedDevice;
    final characteristics =
        List<BleCharacteristicRef>.from(availableCharacteristics.value);

    final keepSession = reason == BleDisconnectReason.retryRelease;

    if (reason == BleDisconnectReason.userRequested) {
      _prepareUserRequestedDisconnect();
    }

    if (!keepSession) {
      _setPhase(BleConnectionPhase.connecting);
    }

    try {
      _invalidatePublishedCharacteristics();

      await _teardownForDisconnect(
        target,
        characteristics: characteristics,
        keepSession: keepSession,
      );

      if (keepSession) {
        notifyListeners();
        return;
      }

      await _applyDisconnectOutcome(reason);

      if (reason != BleDisconnectReason.userRequested) {
        _userInitiatedDisconnect = false;
      }
    } finally {
      if (!keepSession) {
        _finalizeFullDisconnect();
      }
    }
  }

  void _prepareUserRequestedDisconnect() {
    _markUserInitiatedDisconnect();
    _clearUnexpectedDisconnectIndicators();
    unawaited(_scanner.stopScanning());
  }

  void _markUserInitiatedDisconnect() {
    _userInitiatedDisconnect = true;
  }

  void _clearUnexpectedDisconnectIndicators() {
    _linkLostDueToAdapterPowerOff = false;
    _vibratedForDisconnectDeviceId = null;
  }

  Future<void> _teardownForDisconnect(
    BleDevice? target, {
    required List<BleCharacteristicRef> characteristics,
    required bool keepSession,
  }) async {
    if (keepSession) {
      _appInitiatedTeardown = true;
    }
    try {
      await _teardownLink(
        target,
        characteristics: characteristics,
        settleAfterDisconnect: keepSession
            ? bleLinkOnlyDisconnectSettleDelay
            : blePostDisconnectSettleDelay,
      );
    } finally {
      if (keepSession) {
        _appInitiatedTeardown = false;
      }
    }
  }

  Future<void> _applyDisconnectOutcome(BleDisconnectReason reason) async {
    if (reason == BleDisconnectReason.connectionFailed) {
      connectionErrorNotifier.value = true;
      return;
    }

    connectionErrorNotifier.value = false;
    await _scanner.stopScanning();
    _scanner.clearDiscoveredDevices();
  }

  void _finalizeFullDisconnect() {
    unawaited(_linkSubscription?.cancel());
    _linkSubscription = null;
    selectedDevice = null;
    selectedDeviceNotifier.value = null;
    _linkWatchDevice = null;
    _setPhase(BleConnectionPhase.idle);
  }

  Future<void> connectToId(String name) async {
    resetConnectionError();
    final found = await _scanner.waitForAdvertisingDevice(
      BleDevice(id: '', name: name),
    );
    if (found != null) {
      await _connectResolvedDevice(found);
    }
  }

  Future<void> connectToDevice(BleDevice device) async {
    await _connectResolvedDevice(device);
  }

  Future<void> _connectResolvedDevice(BleDevice device) async {
    if (_phase == BleConnectionPhase.connecting ||
        _phase == BleConnectionPhase.reconnecting) {
      return;
    }

    _userInitiatedDisconnect = false;
    _linkWatchDevice = device;

    try {
      resetConnectionError();
      _setPhase(BleConnectionPhase.connecting);
      await _connectWithRetries(
        device,
        timeLimit: connectTimeLimit,
        shouldStop: () => _userInitiatedDisconnect,
      );
      selectedDevice = device;
      selectedDeviceNotifier.value = device;
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
        _linkWatchDevice = null;
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
      await disconnectDevice(
        device: device,
        reason: BleDisconnectReason.retryRelease,
      );
      await Future<void>.delayed(bleSessionRetryDelay);
    }
    await _connectionSession.release(device);
    throw StateError('BLE connection attempts stopped');
  }

  // Always scan before connecting, even when the device id is known.
  // On Android, flutter_reactive_ble caches the native connection per device
  // and only drops it when the connect subscription is cancelled while still
  // active. After a link loss that stream ends on its own, so a direct
  // reconnect reuses the dead connection: notifications get enabled but never
  // deliver data. The scan gives the plugin time to clear that state.
  // Trade-off: on iOS an unfiltered scan returns nothing in the background,
  // so background reconnects depend on the app being in the foreground.
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

    for (var probe = 0; probe < bleEstablishProbeAttemptsPerLink; probe++) {
      if (!_platform.isConnected(device.id)) {
        throw StateError('BLE link lost while waiting for sensor data');
      }

      final livenessTimeout = probe == 0
          ? bleConnectionSessionProbeTimeout
          : bleConnectionSessionExtendedProbeTimeout;

      final result = await _connectionSession.establish(
        device,
        streams: characteristicStreams,
        livenessTimeout: livenessTimeout,
      );
      ErrorService.logEvent('ble', 'session probe', data: {
        'device': device.id,
        'probe': probe,
        'success': result.success,
        'timeoutSeconds': livenessTimeout.inSeconds,
      });

      if (result.success) {
        availableCharacteristics.value = result.characteristics;
        characteristicStreamsVersion.value++;
        return;
      }
    }

    throw TimeoutException(
      'Connected, but no sensor data received',
      bleConnectionSessionExtendedProbeTimeout,
    );
  }

  void _watchLink(BleDevice device) {
    unawaited(_linkSubscription?.cancel());
    _linkSubscription = _platform.connectionState(device.id).listen(
      (state) {
        if (state == BleLinkState.disconnected &&
            _phase == BleConnectionPhase.connected &&
            !_userInitiatedDisconnect) {
          unawaited(_reconnect(device));
        }
      },
      onError: (Object error, StackTrace stackTrace) => _failConnection(
        device,
        BleConnectionFailurePhase.reconnection,
        error,
        stackTrace,
      ),
    );
  }

  Future<void> _reconnect(BleDevice device) async {
    if (_phase == BleConnectionPhase.reconnecting || selectedDevice != device) {
      return;
    }
    bool stopped() => _userInitiatedDisconnect || selectedDevice != device;

    _linkWatchDevice = device;
    _invalidatePublishedCharacteristics();
    _setPhase(BleConnectionPhase.reconnecting);
    _maybeVibrateOnUnexpectedDisconnect(device.id);
    try {
      await _connectWithRetries(
        device,
        timeLimit: reconnectTimeLimit,
        shouldStop: stopped,
      );
      _linkLostDueToAdapterPowerOff = false;
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
    await disconnectDevice(
      device: device,
      reason: BleDisconnectReason.connectionFailed,
    );
  }

  void resetConnectionError() {
    connectionErrorNotifier.value = false;
  }

  @visibleForTesting
  void debugSetConnectionPhase(BleConnectionPhase phase) => _setPhase(phase);

  @visibleForTesting
  void debugWatchLink(BleDevice device) => _watchLink(device);

  @visibleForTesting
  void debugMarkLinkLostDueToAdapterPowerOff() {
    _linkLostDueToAdapterPowerOff = true;
  }

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
    characteristicStreamsVersion.dispose();
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
        selectedDevice != null ||
        _userInitiatedDisconnect ||
        !isBluetoothEnabledNotifier.value ||
        _phase == BleConnectionPhase.connecting ||
        _phase == BleConnectionPhase.reconnecting) {
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
      if (found == null || selectedDevice != null || _userInitiatedDisconnect) {
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

  Future<void> _teardownLink(
    BleDevice? device, {
    required List<BleCharacteristicRef> characteristics,
    required Duration settleAfterDisconnect,
  }) async {
    try {
      await characteristicStreams.clear();
    } catch (_) {}

    if (device != null) {
      try {
        await _connectionSession.release(device);
      } catch (_) {}
    }

    try {
      await characteristicStreams.clear(characteristics: characteristics);
    } catch (_) {}

    if (device != null && settleAfterDisconnect > Duration.zero) {
      await Future<void>.delayed(settleAfterDisconnect);
    }
  }
}
