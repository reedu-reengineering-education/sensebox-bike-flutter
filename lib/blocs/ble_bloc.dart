import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:sensebox_bike/ble/ble_adapter.dart';
import 'package:sensebox_bike/ble/ble_connection_session.dart';
import 'package:sensebox_bike/ble/ble_characteristic_streams.dart';
import 'package:sensebox_bike/ble/ble_scanner.dart';
import 'package:sensebox_bike/blocs/settings_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import 'package:sensebox_bike/services/custom_exceptions.dart';
import 'package:sensebox_bike/services/error_service.dart';
import 'package:vibration/vibration.dart';

const reconnectionDelay = Duration(seconds: 1);
const deviceConnectTimeout = Duration(seconds: 10);
const configurableReconnectionDelay = Duration(seconds: 1);

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
  final BleConnectionSession _connectionSession = const BleConnectionSession();
  List<BluetoothDevice> get devicesList => _scanner.devicesList;
  Stream<List<BluetoothDevice>> get devicesListStream =>
      _scanner.devicesListStream;

  BluetoothDevice? selectedDevice;
  bool _isConnected = false;
  bool _isReconnecting = false;
  bool _userInitiatedDisconnect = false;
  bool _isInRetryMode = false;
  int _reconnectionAttempts = 0;
  bool _hasVibrated = false;
  static const int _maxReconnectionAttempts = 10;
  
  StreamSubscription<BluetoothConnectionState>? _reconnectionListener;

  final BleCharacteristicStreams characteristicStreams =
      BleCharacteristicStreams();

  bool get isConnected => _isConnected;

  BleBloc(
    this.settingsBloc, {
    bool initializePlatformBle = true,
  }) {
    _adapter = BleAdapter();
    _scanner = BleScanner(isScanningNotifier: isScanningNotifier);

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

  Future<void> startScanning() => _scanner.startScanning();

  Future<void> stopScanning() => _scanner.stopScanning();

  Future<void> scanForNewDevices() async {
    disconnectDevice(userInitiated: true);
    await _scanner.startScanning();
  }

  Future<void> disconnectDevice({
    BluetoothDevice? device,
    bool userInitiated = false,
    bool showConnectionError = false,
  }) async {
    if (userInitiated) {
      _userInitiatedDisconnect = true;
      _isInRetryMode = false;
    }

    final target = device ?? selectedDevice;
    if (target != null) {
      try {
        await target.disconnect();
      } catch (_) {
        // Device may already be disconnected.
      }
    }

    _isConnected = false;
    selectedDevice = null;
    selectedDeviceNotifier.value = null;
    availableCharacteristics.value = [];
    characteristicStreams.clear();

    _reconnectionListener?.cancel();
    _reconnectionListener = null;

    if (showConnectionError) {
      _userInitiatedDisconnect = false;
      connectionErrorNotifier.value = true;
      _isReconnecting = false;
      _isInRetryMode = false;
      _reconnectionAttempts = 0;
      _hasVibrated = false;
      isReconnectingNotifier.value = false;
      isConnectingNotifier.value = false;
    } else {
      resetConnectionError();
      _resetReconnectionState();
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

  Future<void> connectToDevice(
      BluetoothDevice device, BuildContext context) async {
    try {
      resetConnectionError();

      isConnectingNotifier.value = true;
      notifyListeners();

      if (isScanningNotifier.value == true) {
        await stopScanning();
      }

      await device.connect();

      final success =
          await _attemptConnectionWithRetries(device, context: context);
      _isConnected = success;

      if (_isConnected) {
        _handleDeviceReconnection(device, context);
        
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

  Future<bool> _executeConnectionAttempts(
    BluetoothDevice device,
    BuildContext? context, {
    required int maxAttempts,
    required BleConnectionFailurePhase failurePhase,
    required Future<bool> Function(BluetoothDevice, BuildContext?)
        attemptConnection,
    required Future<void> Function(BluetoothDevice) prepareForRetry,
  }) async {
    _isInRetryMode = true;

    for (int attempt = 0; attempt < maxAttempts; attempt++) {
      if (attempt > 0) {
        _isConnected = false;
      }

      try {
        bool success = false;
        try {
          success = await attemptConnection(device, context);
        } catch (e) {
          success = false;
        }

        if (success) {
          _isInRetryMode = false;
          return true;
        }

        if (attempt < maxAttempts - 1) {
          try {
            await prepareForRetry(device);
          } catch (e) {
            // Continue with next attempt anyway
          }
        }
      } catch (e) {
        if (attempt < maxAttempts - 1) {
          try {
            await prepareForRetry(device);
          } catch (e) {
            // Continue with next attempt anyway
          }
        }
      }
    }

    _isInRetryMode = false;
    ErrorService.reportToSentry(
      BleConnectionFailed(failurePhase),
      StackTrace.current,
    );
    await disconnectDevice(device: device, showConnectionError: true);
    return false;
  }

  Future<bool> _attemptConnectionWithRetries(
    BluetoothDevice device, {
    BuildContext? context,
    int maxAttempts = 5,
  }) async {
    return _executeConnectionAttempts(
      device,
      context,
      maxAttempts: maxAttempts,
      failurePhase: BleConnectionFailurePhase.initialConnect,
      attemptConnection: (device, context) => _attemptSingleConnection(
        device,
        updateConnectionState: true,
      ),
      prepareForRetry: _prepareForRetry,
    );
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
      await disconnectDevice(device: device);
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

  /// Prepares device for retry by disconnecting and reconnecting
  Future<void> _prepareForRetry(BluetoothDevice device) async {
    try {
      // Disconnect device (catch any disconnect exceptions)
      await disconnectDevice(device: device);

      await Future.delayed(configurableReconnectionDelay);
      
      try {
        await device.connect(timeout: deviceConnectTimeout);
      } catch (e) {
        // Don't throw - let the retry continue, next attempt might work
        return;
      }

      await Future.delayed(configurableReconnectionDelay);
    } catch (e) {
      // Don't throw - let reconnection continue with next attempt
    }
  }

  void _handleDeviceReconnection(BluetoothDevice device, BuildContext context) {
    _reconnectionListener?.cancel();
    
    _userInitiatedDisconnect = false;
    _hasVibrated = false;
    _reconnectionAttempts = 0;

    _reconnectionListener = device.connectionState.listen((state) async {
      try {
        if (state == BluetoothConnectionState.disconnected &&
            !_userInitiatedDisconnect &&
            !_isInRetryMode) {
          if (!_isReconnecting) {
            _isConnected = false;
            isReconnectingNotifier.value = true;

            // Start the actual reconnection process
            try {
              _startReconnectionProcess(device, context);
            } catch (e) {
              // Reset state if reconnection process fails to start
              _isReconnecting = false;
              isReconnectingNotifier.value = false;
            }
          }
        }
      } catch (e) {
        // Don't throw - let the reconnection process handle it
      }
    });

    _reconnectionListener?.onError((error) {
      ErrorService.reportToSentry(
        BleConnectionFailed(BleConnectionFailurePhase.reconnection, error),
        StackTrace.current,
      );
      unawaited(disconnectDevice(device: device, showConnectionError: true));
    });
  }

  void _startReconnectionProcess(
    BluetoothDevice device,
    BuildContext context,
  ) async {

    
    // Check if reconnection is already in progress
    if (_isReconnecting) {
      // If we've been trying for too long, reset and start fresh
      if (_reconnectionAttempts >= _maxReconnectionAttempts) {
        _isReconnecting = false;
        _reconnectionAttempts = 0;
        _hasVibrated = false;
        isReconnectingNotifier.value = false;
      } else {
        return;
      }
    }

    _isReconnecting = true;
    _isInRetryMode = true;

    if (!_hasVibrated && settingsBloc.vibrateOnDisconnect) {
      Vibration.vibrate();
      _hasVibrated = true;
    }

    final success = await _executeConnectionAttempts(
      device,
      context,
      maxAttempts: _maxReconnectionAttempts,
      failurePhase: BleConnectionFailurePhase.reconnection,
      attemptConnection: (device, context) async {
        _reconnectionAttempts++;
        return _attemptSingleConnection(
          device,
          updateConnectionState: false,
        );
      },
      prepareForRetry: _prepareForRetry,
    );

    if (success) {
      _isConnected = true;
      _userInitiatedDisconnect = false;
      _hasVibrated = false;
      _reconnectionAttempts = 0;
      isReconnectingNotifier.value = false;
      _isReconnecting = false;
      _isInRetryMode = false;

      notifyListeners();
    }
  }

  void resetConnectionError() {
    connectionErrorNotifier.value = false;

    // Cancel any ongoing reconnection listener
    _reconnectionListener?.cancel();
    _reconnectionListener = null;

    // Reset reconnection state
    _isReconnecting = false;
    _isInRetryMode = false;
    _reconnectionAttempts = 0;
    _hasVibrated = false;
    isReconnectingNotifier.value = false;
    
    notifyListeners();
  }

  void _resetReconnectionState() {
    _isReconnecting = false;
    _isInRetryMode = false;
    _reconnectionAttempts = 0;
    _hasVibrated = false;

    isReconnectingNotifier.value = false;
    notifyListeners();
  }



  @override
  void dispose() {
    _reconnectionListener?.cancel();
    _scanner.dispose();
    characteristicStreams.clear();
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
}
