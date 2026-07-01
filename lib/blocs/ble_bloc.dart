import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:sensebox_bike/ble/ble_characteristic_ref.dart';
import 'package:sensebox_bike/ble/ble_characteristic_streams.dart';
import 'package:sensebox_bike/ble/ble_connection_session.dart';
import 'package:sensebox_bike/ble/ble_constants.dart';
import 'package:sensebox_bike/ble/ble_device.dart';
import 'package:sensebox_bike/ble/ble_platform.dart';
import 'package:sensebox_bike/ble/ble_reconnection_coordinator.dart';
import 'package:sensebox_bike/ble/ble_scanner.dart';
import 'package:sensebox_bike/ble/ble_session_retry_runner.dart';
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
  })  : _platform = platform ?? BlePlatform(),
        _adapterOffDebounce = adapterOffDebounce {
    _scanner = BleScanner(
      platform: _platform,
      isScanningNotifier: isScanningNotifier,
    );
    _connectionSession = BleConnectionSession(platform: _platform);
    _sessionRetryRunner = BleSessionRetryRunner();
    characteristicStreams = BleCharacteristicStreams(platform: _platform);
    _platform.onLinkStateChanged = _handlePlatformLinkStateChange;
    _reconnectionCoordinator = BleReconnectionCoordinator(platform: _platform);

    if (initializePlatformBle) {
      _refreshBluetoothEnabledStatus();
      _adapterStatusSubscription =
          _platform.statusStream.listen(_onAdapterStatusChanged);
    }
  }

  final SettingsBloc settingsBloc;
  final BlePlatform _platform;
  final Duration _adapterOffDebounce;

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
  late final BleReconnectionCoordinator _reconnectionCoordinator;
  late final BleConnectionSession _connectionSession;
  late final BleSessionRetryRunner _sessionRetryRunner;
  late final BleCharacteristicStreams characteristicStreams;

  StreamSubscription<BleAdapterState>? _adapterStatusSubscription;

  List<BleDevice> get devicesList => _scanner.devicesList;
  Stream<List<BleDevice>> get devicesListStream => _scanner.devicesListStream;

  BleDevice? selectedDevice;
  BleDevice? _linkWatchDevice;
  BleConnectionPhase _phase = BleConnectionPhase.idle;
  int _operationEpoch = 0;
  bool _scanAfterDisconnect = false;
  bool _linkLostDueToAdapterPowerOff = false;
  String? _vibratedForDisconnectDeviceId;

  bool get isConnected => _phase == BleConnectionPhase.connected;

  void _setPhase(BleConnectionPhase phase) {
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
    final operationEpoch = _operationEpoch;
    if (selectedDevice == null) {
      return;
    }
    if (!_isConnectedOrReconnectingPhase()) {
      return;
    }

    if (_adapterOffDebounce > Duration.zero) {
      await Future<void>.delayed(_adapterOffDebounce);
    }

    if (!_isCurrentOperation(operationEpoch)) {
      return;
    }

    if (selectedDevice == null) {
      return;
    }
    if (!_isConnectedOrReconnectingPhase()) {
      return;
    }
    if (_platform.isConnected(selectedDevice!.id)) {
      return;
    }

    _linkLostDueToAdapterPowerOff = true;
    final deviceId = selectedDevice!.id;

    try {
      await _platform.disconnect(deviceId);
    } catch (_) {}

    _maybeVibrateOnUnexpectedDisconnect(deviceId);

    if (!_reconnectionCoordinator.canStartReconnectionEpisode()) {
      return;
    }
    await _reconnectionCoordinator.notifyUnexpectedLinkLost();
  }

  Future<void> _onBluetoothPoweredOn() async {
    final operationEpoch = _operationEpoch;
    if (selectedDevice == null) {
      return;
    }
    if (_phase == BleConnectionPhase.connecting) {
      return;
    }
    if (!_reconnectionCoordinator.canStartReconnectionEpisode()) {
      return;
    }
    final device = selectedDevice!;
    if (_phase == BleConnectionPhase.connected &&
        _platform.isConnected(device.id) &&
        !_linkLostDueToAdapterPowerOff) {
      return;
    }
    if (!_isCurrentOperation(operationEpoch)) {
      return;
    }
    _linkLostDueToAdapterPowerOff = false;
    _setPhase(BleConnectionPhase.reconnecting);
    await _reconnectionCoordinator.notifyUnexpectedLinkLost();
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
      debugPrint('[BLE] vibrate skipped: setting disabled');
      return;
    }
    if (_shouldCancelReconnectWork()) {
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
    debugPrint('[BLE] vibrate on unexpected disconnect $deviceId');
    unawaited(_pulseDisconnectVibration(deviceId));
  }

  Future<void> _pulseDisconnectVibration(String deviceId) async {
    await vibrateDisconnectFeedback();

    await Future<void>.delayed(const Duration(milliseconds: 1200));
    if (_vibratedForDisconnectDeviceId != deviceId) {
      return;
    }
    if (_shouldCancelReconnectWork()) {
      return;
    }
    if (_platform.isConnected(deviceId)) {
      return;
    }
    debugPrint('[BLE] vibrate retry after disconnect $deviceId');
    await vibrateDisconnectFeedback();
  }

  Future<void> _waitForBluetoothReady() async {
    while (!isBluetoothEnabledNotifier.value) {
      if (_shouldCancelReconnectWork()) {
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
  }

  void updateBluetoothStatus(bool isEnabled) {
    if (isBluetoothEnabledNotifier.value != isEnabled) {
      isBluetoothEnabledNotifier.value = isEnabled;
      notifyListeners();
    }
  }

  Future<void> startScanning() async {
    isScanningNotifier.value = true;
    try {
      final afterDisconnect = _scanAfterDisconnect;
      _scanAfterDisconnect = false;
      await _scanner.startScanning(afterDisconnect: afterDisconnect);
    } catch (_) {
      isScanningNotifier.value = false;
      rethrow;
    }
  }

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
      _clearUnexpectedDisconnectIndicators();
      _cancelReconnectionFlow();
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
    } finally {
      if (!keepSession) {
        _finalizeFullDisconnect();
      }
    }
  }

  void _clearUnexpectedDisconnectIndicators() {
    _linkLostDueToAdapterPowerOff = false;
    _vibratedForDisconnectDeviceId = null;
  }

  void _cancelReconnectionFlow() {
    _reconnectionCoordinator.cancelReconnection();
  }

  void _clearReconnectionStateForFreshFlows() {
    _reconnectionCoordinator.detach();
    _reconnectionCoordinator.reset();
  }

  int _beginExclusiveOperation() {
    _operationEpoch++;
    return _operationEpoch;
  }

  bool _isCurrentOperation(int operationEpoch) {
    return operationEpoch == _operationEpoch;
  }

  bool _isConnectedOrReconnectingPhase() {
    return _phase == BleConnectionPhase.connected ||
        _phase == BleConnectionPhase.reconnecting;
  }

  bool _shouldCancelReconnectWork() {
    return _reconnectionCoordinator.shouldCancelReconnectWork();
  }

  Future<void> _teardownForDisconnect(
    BleDevice? target, {
    required List<BleCharacteristicRef> characteristics,
    required bool keepSession,
  }) async {
    await _teardownLink(
      target,
      characteristics: characteristics,
      settleAfterDisconnect: keepSession
          ? bleLinkOnlyDisconnectSettleDelay
          : blePostDisconnectSettleDelay,
    );
  }

  Future<void> _applyDisconnectOutcome(BleDisconnectReason reason) async {
    _scanAfterDisconnect = true;

    if (reason == BleDisconnectReason.connectionFailed) {
      connectionErrorNotifier.value = true;
      _reconnectionCoordinator.reset();
      return;
    }

    connectionErrorNotifier.value = false;
    await _scanner.stopScanning();
    _scanner.clearDiscoveredDevices();
  }

  void _finalizeFullDisconnect() {
    selectedDevice = null;
    selectedDeviceNotifier.value = null;
    _linkWatchDevice = null;
    _setPhase(BleConnectionPhase.idle);
  }

  Future<void> connectToId(String id) async {
    await _connectToBox(id);
  }

  Future<void> _connectToBox(String name) async {
    resetConnectionError();

    await _scanner.scanForBox(
      name: name,
      onDeviceFound: _connectResolvedDevice,
    );
  }

  Future<void> connectToDevice(BleDevice device) async {
    await _connectResolvedDevice(device);
  }

  Future<void> _connectResolvedDevice(BleDevice device) async {
    final operationEpoch = _operationEpoch;
    if (_phase == BleConnectionPhase.connecting ||
        _phase == BleConnectionPhase.reconnecting) {
      return;
    }

    _linkWatchDevice = device;

    try {
      resetConnectionError();
      _setPhase(BleConnectionPhase.connecting);

      final success = await _runConnectionSessions(
        device,
        reconnectMode: false,
        failurePhase: BleConnectionFailurePhase.initialConnect,
        operationEpoch: operationEpoch,
      );

      if (!_isCurrentOperation(operationEpoch)) {
        return;
      }

      if (success) {
        selectedDevice = device;
        selectedDeviceNotifier.value = selectedDevice;
        _linkWatchDevice = device;
        _setPhase(BleConnectionPhase.connected);
        _attachReconnectionListener(device);
      }
    } catch (e, stack) {
      await disconnectDevice(
        device: device,
        reason: BleDisconnectReason.connectionFailed,
      );
      await ErrorService.reportToSentry(
        BleConnectionFailed(BleConnectionFailurePhase.initialConnect, e),
        stack,
      );
    } finally {
      if (_isCurrentOperation(operationEpoch) &&
          _phase != BleConnectionPhase.connected) {
        _linkWatchDevice = null;
        _setPhase(BleConnectionPhase.idle);
      }
    }
  }

  Future<bool> _runConnectionSessions(
    BleDevice device, {
    required bool reconnectMode,
    required BleConnectionFailurePhase failurePhase,
    int? operationEpoch,
    bool publishConnectedState = true,
    Future<void> Function()? onExhausted,
  }) async {
    Object? initialLinkError;
    StackTrace? initialLinkErrorStack;

    await _waitForBluetoothReady();
    if (reconnectMode && _shouldCancelReconnectWork()) {
      return false;
    }

    if (!_platform.isConnected(device.id)) {
      try {
        await _connectLink(device);
      } catch (error, stack) {
        initialLinkError ??= error;
        initialLinkErrorStack ??= stack;
      }
    }

    return _sessionRetryRunner.run(
      device: device,
      maxAttempts: bleConnectMaxAttempts,
      attemptSession: (_, __) => _attemptSingleConnection(
        device,
        publishConnectedState: publishConnectedState,
      ),
      prepareForRetry: _prepareForRetry,
      onExhausted: onExhausted ??
          () => _onSessionRetriesExhausted(
            device,
            failurePhase,
            operationEpoch: operationEpoch ?? _operationEpoch,
            cause: initialLinkError,
            stackTrace: initialLinkErrorStack,
          ),
    );
  }

  Future<BleDevice?> _waitForAdvertisingTarget(BleDevice device) {
    return _scanner.waitForAdvertisingDevice(
      device,
      shouldCancel: _shouldCancelReconnectWork,
    );
  }

  Future<void> _platformConnect(BleDevice device) async {
    if (isScanningNotifier.value) {
      await stopScanning();
    }
    await _platform.connect(device.id);
  }

  Future<BleDevice> _connectLink(BleDevice device) async {
    final advertised = await _waitForAdvertisingTarget(device);
    if (advertised == null) {
      throw StateError('BLE device not advertising');
    }
    await _platformConnect(advertised);
    return advertised;
  }

  Future<void> _onSessionRetriesExhausted(
    BleDevice device,
    BleConnectionFailurePhase failurePhase,
    {
    required int operationEpoch,
    Object? cause,
    StackTrace? stackTrace,
  }
  ) async {
    if (!_isCurrentOperation(operationEpoch)) {
      return;
    }
    await ErrorService.reportToSentry(
      BleConnectionFailed(failurePhase, cause),
      stackTrace ?? StackTrace.current,
    );
    await disconnectDevice(
      device: device,
      reason: BleDisconnectReason.connectionFailed,
    );
  }

  Future<bool> _attemptSingleConnection(
    BleDevice device, {
    bool publishConnectedState = true,
  }) async {
    if (!_platform.isConnected(device.id)) {
      return false;
    }

    for (var probe = 0; probe < bleEstablishProbeAttemptsPerLink; probe++) {
      if (!_platform.isConnected(device.id)) {
        return false;
      }

      final livenessTimeout = probe == 0
          ? bleConnectionSessionProbeTimeout
          : bleConnectionSessionExtendedProbeTimeout;

      final result = await _connectionSession.establish(
        device,
        streams: characteristicStreams,
        livenessTimeout: livenessTimeout,
      );

      if (result.success) {
        availableCharacteristics.value = result.characteristics;
        characteristicStreamsVersion.value++;
        if (publishConnectedState) {
          _setPhase(BleConnectionPhase.connected);
        }
        return true;
      }
    }

    await disconnectDevice(
      device: device,
      reason: BleDisconnectReason.retryRelease,
    );
    return false;
  }

  Future<void> _prepareForRetry(BleDevice device) async {
    if (_phase == BleConnectionPhase.reconnecting && selectedDevice != device) {
      return;
    }
    await _waitForBluetoothReady();
    if (_phase == BleConnectionPhase.reconnecting &&
        _shouldCancelReconnectWork()) {
      return;
    }
    await _sessionRetryRunner.prepareDeviceLink(
      device,
      disconnect: () => disconnectDevice(
        device: device,
        reason: BleDisconnectReason.retryRelease,
      ),
      connect: () => _connectLink(device),
    );
  }

  void _attachReconnectionListener(BleDevice device) {
    final listenerEpoch = _operationEpoch;
    _reconnectionCoordinator.attach(
      device,
      shouldIgnoreDisconnect: () =>
          !_isCurrentOperation(listenerEpoch) ||
          _shouldCancelReconnectWork() ||
          _phase == BleConnectionPhase.connecting ||
          _phase == BleConnectionPhase.reconnecting,
      onLinkLost: () {
        if (!_isCurrentOperation(listenerEpoch)) {
          return;
        }
        _invalidatePublishedCharacteristics();
        _setPhase(BleConnectionPhase.reconnecting);
        _maybeVibrateOnUnexpectedDisconnect(device.id);
      },
      runReconnectSessions: _runReconnectionSessions,
      onReconnectSucceeded: () {
        if (!_isCurrentOperation(listenerEpoch)) {
          return;
        }
        _linkLostDueToAdapterPowerOff = false;
        _setPhase(BleConnectionPhase.connected);
      },
      onReconnectEpisodeEnded: (success) {
        if (!_isCurrentOperation(listenerEpoch)) {
          return;
        }
        if (success) {
          _attachReconnectionListener(device);
          return;
        }
        if (_shouldCancelReconnectWork()) {
          return;
        }
        if (_phase == BleConnectionPhase.connecting) {
          return;
        }
        if (selectedDevice == device) {
          unawaited(disconnectDevice(
            device: device,
            reason: BleDisconnectReason.connectionFailed,
          ));
        }
      },
      onListenerError: (device, error) async {
        if (!_isCurrentOperation(listenerEpoch)) {
          return;
        }
        await ErrorService.reportToSentry(
          BleConnectionFailed(BleConnectionFailurePhase.reconnection, error),
          StackTrace.current,
        );
        await disconnectDevice(
          device: device,
          reason: BleDisconnectReason.connectionFailed,
        );
      },
    );
  }

  Future<bool> _runReconnectionSessions(BleDevice device) async {
    final operationEpoch = _operationEpoch;
    if (_shouldCancelReconnectWork() ||
        selectedDevice != device) {
      return false;
    }
    if (!_isCurrentOperation(operationEpoch)) {
      return false;
    }
    _linkWatchDevice = device;

    return _runConnectionSessions(
      device,
      reconnectMode: true,
      failurePhase: BleConnectionFailurePhase.reconnection,
      operationEpoch: operationEpoch,
      publishConnectedState: false,
      onExhausted: () async {
        if (!_isCurrentOperation(operationEpoch) ||
            _shouldCancelReconnectWork() ||
            selectedDevice != device) {
          return;
        }
        await _onSessionRetriesExhausted(
          device,
          BleConnectionFailurePhase.reconnection,
          operationEpoch: operationEpoch,
        );
      },
    );
  }

  void resetConnectionError() {
    connectionErrorNotifier.value = false;
    _clearReconnectionStateForFreshFlows();
  }

  @visibleForTesting
  void debugSetConnectionPhase(BleConnectionPhase phase) => _setPhase(phase);

  @visibleForTesting
  void debugAttachReconnectionListener(BleDevice device) =>
      _attachReconnectionListener(device);

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
    _reconnectionCoordinator.detach();
    _scanner.dispose();
    unawaited(characteristicStreams.clear());
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

  Future<void> requestEnableBluetooth() async {
    await PermissionService.ensureBluetoothPermissionsGranted();
    await _refreshBluetoothEnabledStatus();
  }

  Future<void> recoverBleStack() async {
    final recoveryEpoch = _beginExclusiveOperation();
    final recoveryDeviceIds = <String>{
      if (selectedDevice != null) selectedDevice!.id,
      if (_linkWatchDevice != null) _linkWatchDevice!.id,
    };

    Future<void> runRecoveryCleanup(
      String stage,
      Future<void> Function() action,
    ) async {
      try {
        await action();
      } catch (error, stack) {
        await ErrorService.reportToSentry(
          StateError('BLE recovery cleanup failed at $stage: $error'),
          stack,
        );
      }
    }

    _cancelReconnectionFlow();
    _clearUnexpectedDisconnectIndicators();
    _scanAfterDisconnect = false;

    await runRecoveryCleanup('stopScanning', _scanner.stopScanning);
    await runRecoveryCleanup(
      'clearCharacteristicStreams',
      () => characteristicStreams.clear(),
    );

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      for (final deviceId in recoveryDeviceIds) {
        if (!_platform.isConnected(deviceId)) {
          continue;
        }
        await runRecoveryCleanup(
          'clearGattCache($deviceId)',
          () => _platform.clearGattCache(deviceId),
        );
      }
    }

    await Future<void>.delayed(blePreDisconnectFenceDelay);
    await runRecoveryCleanup(
      'platformResetRuntimeState',
      _platform.resetRuntimeState,
    );

    await Future<void>.delayed(blePostDisconnectSettleDelay);

    if (!_isCurrentOperation(recoveryEpoch)) {
      return;
    }

    _scanner.clearDiscoveredDevices();
    _invalidatePublishedCharacteristics();
    connectionErrorNotifier.value = false;
    _finalizeFullDisconnect();

    _clearReconnectionStateForFreshFlows();

    await runRecoveryCleanup(
      'refreshBluetoothEnabledStatus',
      _refreshBluetoothEnabledStatus,
    );
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
      await Future<void>.delayed(blePreDisconnectFenceDelay);
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
