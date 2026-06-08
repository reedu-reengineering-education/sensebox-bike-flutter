import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:sensebox_bike/ble/ble_adapter.dart';
import 'package:sensebox_bike/ble/ble_connection_session.dart';
import 'package:sensebox_bike/ble/ble_characteristic_streams.dart';
import 'package:sensebox_bike/ble/ble_constants.dart';
import 'package:sensebox_bike/ble/ble_reconnection_coordinator.dart';
import 'package:sensebox_bike/ble/ble_scanner.dart';
import 'package:sensebox_bike/ble/ble_session_retry_runner.dart';
import 'package:sensebox_bike/blocs/settings_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:sensebox_bike/secrets.dart';

import 'package:sensebox_bike/services/custom_exceptions.dart';
import 'package:sensebox_bike/services/error_service.dart';

class BleBloc with ChangeNotifier {
  final SettingsBloc settingsBloc;

  final ValueNotifier<bool> isBluetoothEnabledNotifier = ValueNotifier(false);
  final ValueNotifier<bool> isScanningNotifier = ValueNotifier(false);
  final ValueNotifier<bool> isConnectingNotifier = ValueNotifier(false);
  final ValueNotifier<bool> isReconnectingNotifier = ValueNotifier(false);
  final ValueNotifier<BluetoothDevice?> selectedDeviceNotifier =
      ValueNotifier(null);
  final ValueNotifier<List<BluetoothCharacteristic>> availableCharacteristics =
      ValueNotifier([]);
  final ValueNotifier<int> characteristicStreamsVersion = ValueNotifier(0);
  final ValueNotifier<bool> connectionErrorNotifier = ValueNotifier(false);

  late final BleAdapter _adapter;
  late final BleScanner _scanner;
  late final BleReconnectionCoordinator _reconnectionCoordinator;
  final BleConnectionSession _connectionSession = const BleConnectionSession();
  final BleSessionRetryRunner _sessionRetryRunner =
      const BleSessionRetryRunner();
  List<BluetoothDevice> get devicesList => _scanner.devicesList;
  Stream<List<BluetoothDevice>> get devicesListStream =>
      _scanner.devicesListStream;

  BluetoothDevice? selectedDevice;
  bool _isConnected = false;
  bool _userInitiatedDisconnect = false;
  bool _isInRetryMode = false;
  bool _scanAfterDisconnect = false;

  final BleCharacteristicStreams characteristicStreams =
      BleCharacteristicStreams();

  bool get isConnected => _isConnected;

  BleBloc(
    this.settingsBloc, {
    bool initializePlatformBle = true,
  }) {
    _adapter = BleAdapter();
    _scanner = BleScanner(isScanningNotifier: isScanningNotifier);
    _reconnectionCoordinator = BleReconnectionCoordinator(
      isReconnectingNotifier: isReconnectingNotifier,
      getVibrateOnDisconnect: () => settingsBloc.vibrateOnDisconnect,
    );

    if (initializePlatformBle) {
      _adapter.configure();
      _refreshBluetoothEnabledStatus();
    }
  }

  Future<void> _refreshBluetoothEnabledStatus() async {
    updateBluetoothStatus(await _adapter.isEnabled());
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
    BluetoothDevice? device,
    bool userInitiated = false,
    bool showConnectionError = false,
    bool linkOnly = false,
  }) async {
    final target = device ?? selectedDevice;
    final characteristics =
        List<BluetoothCharacteristic>.from(availableCharacteristics.value);

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

    _userInitiatedDisconnect = false;
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

  Future<void> connectToDevice(
      BluetoothDevice device, BuildContext context) async {
    _userInitiatedDisconnect = false;

    try {
      resetConnectionError();

      isConnectingNotifier.value = true;
      notifyListeners();

      if (isScanningNotifier.value) {
        await stopScanning();
      }

      await device.connect();

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
    BluetoothDevice device, {
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
      prepareForRetry: _prepareForRetry,
      onExhausted: () => _onSessionRetriesExhausted(
        device,
        BleConnectionFailurePhase.initialConnect,
      ),
    );
  }

  Future<void> _onSessionRetriesExhausted(
    BluetoothDevice device,
    BleConnectionFailurePhase failurePhase,
  ) async {
    ErrorService.reportToSentry(
      BleConnectionFailed(failurePhase),
      StackTrace.current,
    );
    await disconnectDevice(device: device, showConnectionError: true);
  }

  Future<bool> _attemptSingleConnection(
    BluetoothDevice device, {
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
    characteristicStreamsVersion.value++;

    if (updateConnectionState) {
      _isConnected = true;
      _userInitiatedDisconnect = false;
      notifyListeners();
    }

    return true;
  }

  Future<void> _prepareForRetry(BluetoothDevice device) async {
    if (_userInitiatedDisconnect) {
      return;
    }
    if (isReconnectingNotifier.value && selectedDevice != device) {
      return;
    }
    await _sessionRetryRunner.prepareDeviceLink(
      device,
      disconnect: () => disconnectDevice(device: device, linkOnly: true),
    );
  }

  void _attachReconnectionListener(BluetoothDevice device) {
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

  Future<bool> _runReconnectionSessions(BluetoothDevice device) {
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
      prepareForRetry: _prepareForRetry,
      onExhausted: () => _onSessionRetriesExhausted(
        device,
        BleConnectionFailurePhase.reconnection,
      ),
    );
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
    _reconnectionCoordinator.detach();
    _scanner.dispose();
    unawaited(characteristicStreams.clear());
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
    BluetoothDevice device, {
    required List<BluetoothCharacteristic> characteristics,
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
      await _releaseSenseBoxSystemLinks(device.remoteId);
    }
    if (settleAfterDisconnect > Duration.zero) {
      await Future<void>.delayed(settleAfterDisconnect);
    }
  }

  Future<void> _releaseSenseBoxSystemLinks(DeviceIdentifier remoteId) async {
    try {
      for (final device in FlutterBluePlus.connectedDevices) {
        if (device.remoteId == remoteId) {
          await device.disconnect();
        }
      }
      final systemDevices =
          await FlutterBluePlus.systemDevices([senseBoxServiceUUID]);
      for (final device in systemDevices) {
        if (device.remoteId == remoteId) {
          await device.disconnect();
        }
      }
    } catch (_) {}
  }
}
