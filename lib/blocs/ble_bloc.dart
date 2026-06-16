import 'dart:async';

import 'package:flutter/material.dart';
import 'package:sensebox_bike/ble/ble_adapter.dart';
import 'package:sensebox_bike/ble/ble_characteristic_ref.dart';
import 'package:sensebox_bike/ble/ble_characteristic_streams.dart';
import 'package:sensebox_bike/ble/ble_connection_session.dart';
import 'package:sensebox_bike/ble/ble_constants.dart';
import 'package:sensebox_bike/ble/ble_device.dart';
import 'package:sensebox_bike/ble/ble_platform.dart';
import 'package:sensebox_bike/ble/ble_reconnection_coordinator.dart';
import 'package:sensebox_bike/ble/ble_scanner.dart';
import 'package:sensebox_bike/ble/ble_session_retry_runner.dart';
import 'package:sensebox_bike/ble/ble_uuids.dart';
import 'package:sensebox_bike/blocs/settings_bloc.dart';
import 'package:sensebox_bike/services/custom_exceptions.dart';
import 'package:sensebox_bike/services/error_service.dart';

class BleBloc with ChangeNotifier {
  BleBloc(
    this.settingsBloc, {
    bool initializePlatformBle = true,
    BlePlatform? platform,
  }) : _platform = platform ?? BlePlatform() {
    _adapter = BleAdapter(platform: _platform);
    _scanner = BleScanner(
      platform: _platform,
      isScanningNotifier: isScanningNotifier,
    );
    _connectionSession = BleConnectionSession(platform: _platform);
    _sessionRetryRunner = BleSessionRetryRunner();
    characteristicStreams = BleCharacteristicStreams(platform: _platform);
    _reconnectionCoordinator = BleReconnectionCoordinator(
      platform: _platform,
      isReconnectingNotifier: isReconnectingNotifier,
      getVibrateOnDisconnect: () => settingsBloc.vibrateOnDisconnect,
    );

    if (initializePlatformBle) {
      _adapter.configure();
      _refreshBluetoothEnabledStatus();
      _adapterStatusSubscription =
          _adapter.statusStream.listen(_onAdapterStatusChanged);
    }
  }

  final SettingsBloc settingsBloc;
  final BlePlatform _platform;

  final ValueNotifier<bool> isBluetoothEnabledNotifier = ValueNotifier(false);
  final ValueNotifier<bool> isScanningNotifier = ValueNotifier(false);
  final ValueNotifier<bool> isConnectingNotifier = ValueNotifier(false);
  final ValueNotifier<bool> isReconnectingNotifier = ValueNotifier(false);
  final ValueNotifier<BleDevice?> selectedDeviceNotifier =
      ValueNotifier(null);
  final ValueNotifier<List<BleCharacteristicRef>> availableCharacteristics =
      ValueNotifier([]);
  final ValueNotifier<int> characteristicStreamsVersion = ValueNotifier(0);
  final ValueNotifier<bool> connectionErrorNotifier = ValueNotifier(false);

  late final BleAdapter _adapter;
  late final BleScanner _scanner;
  late final BleReconnectionCoordinator _reconnectionCoordinator;
  late final BleConnectionSession _connectionSession;
  late final BleSessionRetryRunner _sessionRetryRunner;
  late final BleCharacteristicStreams characteristicStreams;

  StreamSubscription<BleAdapterState>? _adapterStatusSubscription;

  List<BleDevice> get devicesList => _scanner.devicesList;
  Stream<List<BleDevice>> get devicesListStream => _scanner.devicesListStream;

  BleDevice? selectedDevice;
  bool _isConnected = false;
  bool _userInitiatedDisconnect = false;
  bool _isInRetryMode = false;
  bool _scanAfterDisconnect = false;

  bool get isConnected => _isConnected;

  Future<void> _refreshBluetoothEnabledStatus() async {
    updateBluetoothStatus(await _adapter.isEnabled());
  }

  void _onAdapterStatusChanged(BleAdapterState status) {
    updateBluetoothStatus(isBluetoothAdapterEnabled(status));
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
    await disconnectDevice(userInitiated: true);
    await startScanning();
  }

  Future<void> disconnectDevice({
    BleDevice? device,
    bool userInitiated = false,
    bool showConnectionError = false,
    bool linkOnly = false,
  }) async {
    final target = device ?? selectedDevice;
    final characteristics =
        List<BleCharacteristicRef>.from(availableCharacteristics.value);

    if (userInitiated) {
      _userInitiatedDisconnect = true;
      _isInRetryMode = false;
      _reconnectionCoordinator.cancelReconnection();
    }

    if (!linkOnly) {
      selectedDevice = null;
      selectedDeviceNotifier.value = null;
      if (!userInitiated) {
        _reconnectionCoordinator.detach();
      }
    }

    _isConnected = false;
    availableCharacteristics.value = [];

    final fullRelease = userInitiated || showConnectionError;
    if (target != null) {
      await _releaseBleSession(
        target,
        characteristics: characteristics,
        releaseSystemLinks: fullRelease,
        settleAfterDisconnect: fullRelease
            ? blePostDisconnectSettleDelay
            : const Duration(milliseconds: 300),
      );
    } else {
      await characteristicStreams.clear(characteristics: characteristics);
    }

    if (linkOnly) {
      notifyListeners();
      return;
    }

    if (showConnectionError) {
      connectionErrorNotifier.value = true;
      _isInRetryMode = false;
      _reconnectionCoordinator.reset();
      isConnectingNotifier.value = false;
      _scanAfterDisconnect = true;
    } else if (userInitiated) {
      connectionErrorNotifier.value = false;
    } else {
      resetConnectionError();
    }

    if (userInitiated) {
      _scanAfterDisconnect = true;
      await _scanner.stopScanning();
      _scanner.clearDiscoveredDevices();
    }

    // A user-initiated disconnect must keep [_userInitiatedDisconnect] set so
    // that any reconnection loop still in flight bails out instead of
    // auto-reconnecting to the device the user just left (or raising a spurious
    // connection error). The flag is cleared only when the user explicitly
    // connects again (see connectToDevice).
    if (!userInitiated) {
      _userInitiatedDisconnect = false;
    }
    notifyListeners();
  }

  Future<void> connectToId(String id, BuildContext context) async {
    await _connectToBox(id, context);
  }

  Future<void> _connectToBox(String name, BuildContext context) async {
    resetConnectionError();

    await _scanner.scanForBox(
      name: name,
      onDeviceFound: (device) => connectToDevice(device, context),
    );
  }

  Future<void> connectToDevice(BleDevice device, BuildContext context) async {
    _userInitiatedDisconnect = false;

    try {
      resetConnectionError();

      isConnectingNotifier.value = true;
      notifyListeners();

      if (isScanningNotifier.value) {
        await stopScanning();
      }

      await _platform.connect(device.id);

      final success = await _attemptConnectionWithRetries(device);

      _isConnected = success;

      if (_isConnected) {
        _attachReconnectionListener(device);
        selectedDevice = device;
        selectedDeviceNotifier.value = selectedDevice;
      }
    } catch (e, stack) {
      await disconnectDevice(device: device, showConnectionError: true);
      ErrorService.reportToSentry(
        BleConnectionFailed(BleConnectionFailurePhase.initialConnect, e),
        stack,
      );
    } finally {
      isConnectingNotifier.value = false;
      _isInRetryMode = false;
      notifyListeners();
    }
  }

  Future<bool> _attemptConnectionWithRetries(
    BleDevice device, {
    int maxAttempts = bleInitialConnectMaxAttempts,
  }) async {
    return _sessionRetryRunner.run(
      device: device,
      maxAttempts: maxAttempts,
      onEnterRetryMode: () => _isInRetryMode = true,
      onExitRetryMode: () => _isInRetryMode = false,
      onBetweenAttempts: (_) => _isConnected = false,
      attemptSession: (_, __) => _attemptSingleConnection(
        device,
        updateConnectionState: true,
      ),
      prepareForRetry: (retryDevice) => _prepareForRetry(
        retryDevice,
        connect: () => _platform.connect(retryDevice.id),
      ),
      onExhausted: () => _onSessionRetriesExhausted(
        device,
        BleConnectionFailurePhase.initialConnect,
      ),
    );
  }

  Future<void> _onSessionRetriesExhausted(
    BleDevice device,
    BleConnectionFailurePhase failurePhase,
  ) async {
    ErrorService.reportToSentry(
      BleConnectionFailed(failurePhase),
      StackTrace.current,
    );
    await disconnectDevice(device: device, showConnectionError: true);
  }

  Future<bool> _attemptSingleConnection(
    BleDevice device, {
    bool updateConnectionState = true,
  }) async {
    final result = await _connectionSession.establish(
      device,
      streams: characteristicStreams,
    );

    if (!result.success) {
      await disconnectDevice(device: device, linkOnly: true);
      return false;
    }

    availableCharacteristics.value = result.characteristics;
    // Mark the link as connected before bumping the stream version so that
    // listeners reacting to the new characteristic streams (e.g. SensorBloc)
    // observe `isConnected == true` and re-subscribe. On reconnection
    // `updateConnectionState` is false, but the session has still succeeded, so
    // the connected flag must be set here for sensors to restart.
    _isConnected = true;
    _userInitiatedDisconnect = false;
    characteristicStreamsVersion.value++;

    if (updateConnectionState) {
      notifyListeners();
    }

    return true;
  }

  Future<void> _prepareForRetry(
    BleDevice device, {
    required Future<void> Function() connect,
  }) async {
    if (_userInitiatedDisconnect) {
      return;
    }
    if (isReconnectingNotifier.value && selectedDevice != device) {
      return;
    }
    await _sessionRetryRunner.prepareDeviceLink(
      device,
      disconnect: () => disconnectDevice(device: device, linkOnly: true),
      connect: connect,
    );
  }

  void _attachReconnectionListener(BleDevice device) {
    _userInitiatedDisconnect = false;
    _reconnectionCoordinator.attach(
      device,
      shouldIgnoreDisconnect: () =>
          _userInitiatedDisconnect || _isInRetryMode,
      onLinkLost: () {
        _isConnected = false;
        isReconnectingNotifier.value = true;
      },
      runReconnectSessions: _runReconnectionSessions,
      onReconnectSucceeded: () {
        _isConnected = true;
        _userInitiatedDisconnect = false;
        notifyListeners();
      },
      onListenerError: (device, error) async {
        ErrorService.reportToSentry(
          BleConnectionFailed(BleConnectionFailurePhase.reconnection, error),
          StackTrace.current,
        );
        await disconnectDevice(device: device, showConnectionError: true);
      },
    );
  }

  Future<bool> _runReconnectionSessions(BleDevice device) async {
    // The previous link is dead after an out-of-range disconnect. Fully release
    // it so the box drops the stale GATT connection and starts advertising
    // again, then scan for the advertising device before reconnecting. This
    // avoids the Android stack reusing a half-open link
    // (flutter_reactive_ble issue #770) and keeps the box discoverable.
    await _releaseLinkBeforeReconnect(device);
    try {
      await _platform.connectToAdvertising(
        device.id,
        withServices: [senseBoxServiceUuid],
      );
    } catch (_) {
      // prepareForRetry retries the scan-gated connect on the next attempt.
    }

    return _sessionRetryRunner.run(
      device: device,
      maxAttempts: bleMaxReconnectionAttempts,
      onEnterRetryMode: () => _isInRetryMode = true,
      onExitRetryMode: () => _isInRetryMode = false,
      onBetweenAttempts: (_) => _isConnected = false,
      attemptSession: (_, __) async {
        if (selectedDevice != device) {
          return false;
        }
        return _attemptSingleConnection(
          device,
          updateConnectionState: false,
        );
      },
      prepareForRetry: (retryDevice) => _prepareForRetry(
        retryDevice,
        connect: () => _platform.connectToAdvertising(
          retryDevice.id,
          withServices: [senseBoxServiceUuid],
        ),
      ),
      onExhausted: () async {
        // Do not surface a connection error if the user disconnected or
        // switched devices while the reconnection loop was still running.
        if (_userInitiatedDisconnect || selectedDevice != device) {
          return;
        }
        await _onSessionRetriesExhausted(
          device,
          BleConnectionFailurePhase.reconnection,
        );
      },
    );
  }

  Future<void> _releaseLinkBeforeReconnect(BleDevice device) async {
    try {
      await _platform.disconnect(device.id);
    } catch (_) {}
    await Future<void>.delayed(blePostDisconnectSettleDelay);
  }

  void resetConnectionError() {
    connectionErrorNotifier.value = false;
    _reconnectionCoordinator.detach();
    _reconnectionCoordinator.reset();
    _isInRetryMode = false;
    notifyListeners();
  }

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
    super.dispose();
  }

  Future<void> requestEnableBluetooth() async {
    await _adapter.requestEnable();
    await _refreshBluetoothEnabledStatus();
  }

  Future<void> _releaseBleSession(
    BleDevice device, {
    required List<BleCharacteristicRef> characteristics,
    required bool releaseSystemLinks,
    required Duration settleAfterDisconnect,
  }) async {
    try {
      await characteristicStreams.clear();
    } catch (_) {}

    try {
      await _connectionSession.release(device);
    } catch (_) {}

    try {
      await characteristicStreams.clear(characteristics: characteristics);
    } catch (_) {}

    if (releaseSystemLinks) {
      try {
        await _platform.disconnect(device.id);
      } catch (_) {}
    }
    if (settleAfterDisconnect > Duration.zero) {
      await Future<void>.delayed(settleAfterDisconnect);
    }
  }
}
