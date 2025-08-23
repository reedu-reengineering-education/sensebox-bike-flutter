import 'dart:async';

import 'dart:typed_data';
import 'package:flutter/widgets.dart';
import 'package:sensebox_bike/blocs/settings_bloc.dart';
import 'package:sensebox_bike/secrets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import 'package:sensebox_bike/services/custom_exceptions.dart';
import 'package:sensebox_bike/services/error_service.dart';
import 'package:vibration/vibration.dart';

const reconnectionDelay = Duration(seconds: 1);
const deviceConnectTimeout = Duration(seconds: 5);
const configurableReconnectionDelay =
    Duration(seconds: 1); // Can be adjusted for different use cases
const dataListeningTimeout =
    Duration(seconds: 3); // Timeout for listening to characteristic data


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

  final List<BluetoothDevice> devicesList = [];
  final StreamController<List<BluetoothDevice>> _devicesListController =
      StreamController.broadcast();
  Stream<List<BluetoothDevice>> get devicesListStream =>
      _devicesListController.stream;

  BluetoothDevice? selectedDevice;
  bool _isConnected = false;
  bool _isReconnecting = false; // ✅ Class-level variable
  bool _userInitiatedDisconnect = false;
  bool _isInRetryMode =
      false; // Flag to prevent listener interference during retries

  // ✅ FIX: Make reconnection state variables class-level to avoid scope issues
  bool _hasVibrated = false;
  int _reconnectionAttempts = 0;
  static const int _maxReconnectionAttempts = 10; // Increased from 5 to 10
  
  // Track reconnection listeners to prevent multiple active listeners
  StreamSubscription<BluetoothConnectionState>? _reconnectionListener;

  final Map<String, StreamController<List<double>>> _characteristicStreams = {};
  final Map<String, StreamController<List<String>>>
      _characteristicStringStreams = {};

  bool get isConnected => _isConnected;

  BleBloc(this.settingsBloc) {
    FlutterBluePlus.setLogLevel(LogLevel.error);
    FlutterBluePlus.adapterState.listen((state) {
      updateBluetoothStatus(state == BluetoothAdapterState.on);
    });

    _initializeBluetoothStatus();
  }

  Future<void> _initializeBluetoothStatus() async {
    BluetoothAdapterState currentState =
        await FlutterBluePlus.adapterState.first;
    updateBluetoothStatus(currentState == BluetoothAdapterState.on);
  }

  void updateBluetoothStatus(bool isEnabled) {
    isBluetoothEnabledNotifier.value = isEnabled;
    notifyListeners();
  }

  Future<void> startScanning() async {
    // Don't disconnect existing device when just scanning for new devices
    // This allows users to browse available devices without losing current connection
    isScanningNotifier.value = true;

    try {
      await FlutterBluePlus.startScan(timeout: deviceConnectTimeout);
    } catch (e) {
      isScanningNotifier.value = false;
      throw ScanPermissionDenied();
    }

    FlutterBluePlus.scanResults.listen((results) {
      devicesList.clear();
      for (ScanResult result in results) {
        if (result.device.platformName.startsWith("senseBox")) {
          devicesList.add(result.device);
        }
      }
      _devicesListController.add(devicesList);
      notifyListeners();
    });

    FlutterBluePlus.isScanning.listen((scanning) {
      isScanningNotifier.value = scanning;
    });
  }

  Future<void> stopScanning() async {
    await FlutterBluePlus.stopScan();
    isScanningNotifier.value = false;
  }

  /// Scan for new devices while disconnecting from current device
  /// Use this when user explicitly wants to disconnect and find new devices
  Future<void> scanForNewDevices() async {
    disconnectDevice();
    isScanningNotifier.value = true;

    try {
      await FlutterBluePlus.startScan(timeout: deviceConnectTimeout);
    } catch (e) {
      isScanningNotifier.value = false;
      throw ScanPermissionDenied();
    }

    FlutterBluePlus.scanResults.listen((results) {
      devicesList.clear();
      for (ScanResult result in results) {
        if (result.device.platformName.startsWith("senseBox")) {
          devicesList.add(result.device);
        }
      }
      _devicesListController.add(devicesList);
      notifyListeners();
    });

    FlutterBluePlus.isScanning.listen((scanning) {
      isScanningNotifier.value = scanning;
    });
  }

  void disconnectDevice() {
    debugPrint('[BleBloc] Manual disconnect initiated');
    
    _userInitiatedDisconnect = true;
    _isInRetryMode = false; // Reset retry mode on manual disconnect
    selectedDevice?.disconnect();
    _isConnected = false;
    selectedDevice = null;
    selectedDeviceNotifier.value = null;
    availableCharacteristics.value = [];
    
    _reconnectionListener?.cancel();
    _reconnectionListener = null;

    resetConnectionError();
    
    notifyListeners();
  }

  Future<void> connectToId(String id, BuildContext context) async {
    resetConnectionError();
    
    await FlutterBluePlus.startScan(withNames: [id]);
    FlutterBluePlus.scanResults.listen((results) async {
      for (ScanResult result in results) {
        if (result.device.advName.toString() == id) {
          await connectToDevice(result.device, context);
          break;
        }
      }
    });
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
      debugPrint('[BleBloc] Device connected at BLE level: ${device.remoteId}');

      final success =
          await _attemptConnectionWithRetries(device, context: context);
      _isConnected = success;

      if (_isConnected) {
        debugPrint(
            '[BleBloc] Setting up connection state listener after successful connection');
        _handleDeviceReconnection(device, context);
        
        // Only set selectedDevice when connection is successful
        selectedDevice = device;
        selectedDeviceNotifier.value = selectedDevice;
      } else {
        debugPrint(
            '[BleBloc] Initial connection failed, not setting up reconnection listener');
        
        // Clear selectedDevice when connection fails
        selectedDevice = null;
        selectedDeviceNotifier.value = null;
      }

      notifyListeners();
    } catch (e) {
      debugPrint('[BleBloc] Error during connectToDevice: $e');
      ErrorService.handleError(e, StackTrace.current);
      
      // Clear selectedDevice on any error
      selectedDevice = null;
      selectedDeviceNotifier.value = null;
      _isConnected = false;
      
      // Handle connection error to trigger reconnection logic if appropriate
      _handleConnectionError(context: context, isInitialConnection: true);
    } finally {
      isConnectingNotifier.value = false;
      _isInRetryMode = false; // Reset retry mode flag in case of early exit
    }
    notifyListeners();
  }

  /// Attempts to establish a connection with retry logic
  /// This method handles the entire connection process including retries
  Future<bool> _attemptConnectionWithRetries(
    BluetoothDevice device, {
    BuildContext? context,
    int maxAttempts = 5, // Reduced from 10 to 5 for initial connection
    bool isReconnection = false,
  }) async {
    debugPrint(
        '[BleBloc] Starting connection attempt with max attempts: $maxAttempts');

    _isInRetryMode =
        true; // Prevent connection listener interference during retries

    for (int attempt = 0; attempt < maxAttempts; attempt++) {
      debugPrint('[BleBloc] Connection attempt ${attempt + 1}/$maxAttempts');

      // Reset connection state for retry attempts
      if (attempt > 0) {
        _isConnected = false;
        debugPrint('[BleBloc] Connection state reset for retry attempt');
      }

      try {
        // Attempt connection
        bool success = false;
        try {
          success = await _attemptSingleConnection(device, context,
              updateConnectionState: true);
        } catch (e) {
          debugPrint(
              '[BleBloc] Error in _attemptSingleConnection during initial connection: $e');
          success = false; // Ensure success is false on any exception
        }

        if (success) {
          debugPrint(
              '[BleBloc] Connection successful on attempt ${attempt + 1}');
          _isInRetryMode = false; // Reset retry mode flag on success
          return true;
        }

        // Connection failed, prepare for retry
        if (attempt < maxAttempts - 1) {
          debugPrint('[BleBloc] Connection failed, preparing retry...');
          try {
            await _prepareForRetry(device);
          } catch (e) {
            debugPrint(
                '[BleBloc] Error in _prepareForRetry during initial connection: $e');
            // Continue with next attempt anyway
          }
        }
      } catch (e) {
        debugPrint(
            '[BleBloc] Unexpected error during connection attempt ${attempt + 1}: $e');

        // Prepare for retry if we have attempts left
        if (attempt < maxAttempts - 1) {
          try {
            await _prepareForRetry(device);
          } catch (e) {
            debugPrint(
                '[BleBloc] Error in _prepareForRetry after unexpected error: $e');
            // Continue with next attempt anyway
          }
        }
      }
    }

    // All attempts failed
    debugPrint('[BleBloc] All $maxAttempts connection attempts failed');
    _isInRetryMode = false; // Reset retry mode flag

    if (context != null) {
      _handleConnectionError(
          context: context, isInitialConnection: !isReconnection);
    }
    return false;
  }

  /// Attempts a single connection without retries
  Future<bool> _attemptSingleConnection(
    BluetoothDevice device,
    BuildContext? context, {
    bool updateConnectionState =
        true, // Control whether to update main connection state
  }) async {
    try {
      // Clear any existing streams
      _clearCharacteristicStreams();

      // Discover services
      final services = await device.discoverServices();
      if (services.isEmpty) {
        debugPrint('[BleBloc] No services found');
        return false;
      }

      // Find senseBox service
      BluetoothService? senseBoxService;
      try {
        senseBoxService = _findSenseBoxService(services);
      } catch (e) {
        debugPrint('[BleBloc] SenseBox service not found');
        return false;
      }

      if (senseBoxService.characteristics.isEmpty) {
        debugPrint('[BleBloc] No characteristics found');
        return false;
      }

      // Open first available characteristic stream
      final firstCharacteristic = senseBoxService.characteristics.first;
      debugPrint(
          '[BleBloc] Opening characteristic: ${firstCharacteristic.uuid}');

      // Listen for data with configurable timeout
      bool dataReceived = false;
      final dataReceivedCompleter = Completer<bool>();

      // Set up listener
      await firstCharacteristic.setNotifyValue(true);
      Uint8List? receivedData;
      final subscription = firstCharacteristic.onValueReceived.listen((value) {
        if (!dataReceivedCompleter.isCompleted) {
          receivedData = Uint8List.fromList(value);
          dataReceived = true;
          dataReceivedCompleter.complete(true);
        }
      });

      // Wait for configurable timeout or data
      try {
        await Future.any([
          dataReceivedCompleter.future,
          Future.delayed(dataListeningTimeout),
        ]);
      } finally {
        subscription.cancel();
        await firstCharacteristic.setNotifyValue(false);
      }

      // Check if data was received and validate it's meaningful
      if (dataReceived && receivedData != null) {
        // Validate that the data is meaningful (not just zeros or empty)
        bool isDataMeaningful = _validateReceivedData(receivedData!);
        
        if (isDataMeaningful) {
          debugPrint('[BleBloc] Meaningful data received! Connection successful.');
          debugPrint('[BleBloc] Data length: ${receivedData!.length}, Data: ${receivedData!.take(8).toList()}');

          // Set up all characteristics for normal operation
          for (var characteristic in senseBoxService.characteristics) {
            await _listenToCharacteristic(characteristic);
          }
          
          availableCharacteristics.value = senseBoxService.characteristics;
          characteristicStreamsVersion.value++;
          
          // Set connection state to true when verification succeeds (only if requested)
          if (updateConnectionState) {
            _isConnected = true;
            _userInitiatedDisconnect = false;
            debugPrint('[BleBloc] Connection state set to: $_isConnected');
            debugPrint('[BleBloc] Device connected: ${device.remoteId}');
            
            notifyListeners();
          } else {
            debugPrint(
                '[BleBloc] Connection verification successful but not updating main state (reconnection in progress)');
          }

          return true;
        } else {
          debugPrint('[BleBloc] Data received but not meaningful (all zeros or invalid). Connection failed.');
          return false;
        }
      } else if (dataReceived && receivedData == null) {
        debugPrint('[BleBloc] Data received but data is null. Connection failed.');
        return false;
      } else {
        debugPrint(
            '[BleBloc] No data received within ${dataListeningTimeout.inSeconds} seconds');
        return false;
      }
    } catch (e) {
      debugPrint('[BleBloc] Error during connection attempt: $e');
      // Don't crash on connection errors, just return false to trigger retry
      return false;
    }
  }

  /// Prepares device for retry by disconnecting and reconnecting
  Future<void> _prepareForRetry(BluetoothDevice device) async {
    debugPrint('[BleBloc] Preparing device for retry...');

    try {
      // Disconnect device (catch any disconnect exceptions)
      try {
        await device.disconnect();
        debugPrint('[BleBloc] Device disconnected for retry');
      } catch (e) {
        debugPrint('[BleBloc] Error during disconnect for retry: $e');
        // Continue anyway, device might already be disconnected
      }

      // Wait for disconnect to complete
      await Future.delayed(configurableReconnectionDelay);

      // Reconnect device (catch any connect exceptions)
      try {
        await device.connect(timeout: deviceConnectTimeout);
        debugPrint('[BleBloc] Device reconnected for retry');
      } catch (e) {
        debugPrint('[BleBloc] Error during connect for retry: $e');
        // Don't throw - let the retry continue, next attempt might work
        return;
      }

      // Wait for connection to stabilize
      await Future.delayed(configurableReconnectionDelay);

      debugPrint('[BleBloc] Device ready for retry');
    } catch (e) {
      debugPrint('[BleBloc] Unexpected error preparing device for retry: $e');
      // Don't throw - let reconnection continue with next attempt
    }
  }










  void _clearCharacteristicStreams() {
    for (var controller in _characteristicStreams.values) {
      controller.close();
    }
    _characteristicStreams.clear();
    for (var controller in _characteristicStringStreams.values) {
      controller.close();
    }
    _characteristicStringStreams.clear();
  }

  BluetoothService _findSenseBoxService(List<BluetoothService> services) {
    return services.firstWhere(
      (service) => service.uuid == senseBoxServiceUUID,
      orElse: () => throw Exception('senseBox service not found'),
    );
  }



  void _handleDeviceReconnection(BluetoothDevice device, BuildContext context) {
    debugPrint(
        '[BleBloc] Setting up automatic reconnection listener for device: ${device.remoteId}');
    _reconnectionListener?.cancel();
    
    _userInitiatedDisconnect = false;
    _hasVibrated = false;
    _reconnectionAttempts = 0;

    _reconnectionListener = device.connectionState.listen((state) async {
      try {
        debugPrint('[BleBloc] Connection state changed to: $state');
        
        if (state == BluetoothConnectionState.disconnected &&
            !_userInitiatedDisconnect &&
            !_isInRetryMode) {
          if (!_isReconnecting) {
            debugPrint(
                '[BleBloc] Automatic disconnection detected, starting reconnection process');

            _isConnected = false;
            isReconnectingNotifier.value = true;
          
            // Start the actual reconnection process
            try {
              _startReconnectionProcess(device, context);
            } catch (e) {
              debugPrint('[BleBloc] Error starting reconnection process: $e');
              // Reset state if reconnection process fails to start
              _isReconnecting = false;
              isReconnectingNotifier.value = false;
            }
          } else {
            debugPrint(
                '[BleBloc] Additional disconnection detected during reconnection');
          }
        } else if (state == BluetoothConnectionState.connected) {
          if (_isReconnecting) {
            debugPrint(
                '[BleBloc] Device BLE connection detected during reconnection, but not resetting state until verification completes');
            // Don't reset reconnection state here - let the reconnection process handle it
            // The reconnection process will reset the state only after successful data verification
          }
        }
      } catch (e) {
        debugPrint('[BleBloc] Error in connection state listener: $e');
        // Don't crash the app - just log the error
      }
    });

    _reconnectionListener?.onError((error) {
      debugPrint('[BleBloc] Connection state listener error: $error');
      _handleConnectionError(context: context, isInitialConnection: false);
    });
  }

  /// Starts the reconnection process when a device disconnects
  void _startReconnectionProcess(
    BluetoothDevice device,
    BuildContext context,
  ) async {
    // Check if reconnection is already in progress
    if (_isReconnecting) {
      debugPrint(
          '[BleBloc] Reconnection already in progress, checking if stuck...');
      debugPrint(
          '[BleBloc] Current reconnection state: attempts=$_reconnectionAttempts, max=$_maxReconnectionAttempts');

      // If we've been trying for too long, reset and start fresh
      if (_reconnectionAttempts >= _maxReconnectionAttempts) {
        debugPrint(
            '[BleBloc] Reconnection appears stuck, resetting state and starting fresh');
        _isReconnecting = false;
        _reconnectionAttempts = 0;
        _hasVibrated = false;
        isReconnectingNotifier.value = false;
      } else {
        debugPrint('[BleBloc] Reconnection in progress, skipping');
        return;
      }
    }

    // Set reconnection state now that we're actually starting
    _isReconnecting = true;
    debugPrint('[BleBloc] Reconnection state set to: $_isReconnecting');

    // Set retry mode to prevent connection listener interference during reconnection
    _isInRetryMode = true;

    if (!_hasVibrated && settingsBloc.vibrateOnDisconnect) {
      Vibration.vibrate();
      _hasVibrated = true;
    }

    final reconnectionStartTime = DateTime.now();
    final maxReconnectionDuration = Duration(minutes: 2); // 2 minute timeout

    while (_reconnectionAttempts < _maxReconnectionAttempts && !_isConnected) {
      // Check if we've been trying too long
      if (DateTime.now().difference(reconnectionStartTime) >
          maxReconnectionDuration) {
        debugPrint(
            '[BleBloc] Reconnection timeout reached, stopping reconnection attempts');
        break;
      }

      try {
        _reconnectionAttempts++;
        debugPrint(
            '[BleBloc] Reconnection attempt $_reconnectionAttempts/$_maxReconnectionAttempts');

        // Prepare device for reconnection attempt (except for first attempt)
        if (_reconnectionAttempts > 1) {
          try {
            await _prepareForRetry(device);
          } catch (e) {
            debugPrint(
                '[BleBloc] Error in _prepareForRetry during reconnection: $e');
            // Continue with the attempt anyway
          }
        }

        // Attempt the actual connection
        bool success = false;
        try {
          success = await _attemptSingleConnection(device, context,
              updateConnectionState: false);
        } catch (e) {
          debugPrint(
              '[BleBloc] Error in _attemptSingleConnection during reconnection: $e');
          success = false; // Ensure success is false on any exception
        }

        if (success) {
          // Reconnection successful - now update the main connection state
          _isConnected = true;
          _userInitiatedDisconnect = false;
          debugPrint(
              '[BleBloc] Reconnection successful, updating main connection state');

          _hasVibrated = false;
          _reconnectionAttempts = 0;
          isReconnectingNotifier.value = false;
          _isReconnecting = false;
          _isInRetryMode = false; // Reset retry mode flag
          debugPrint('[BleBloc] Reconnection successful, all state reset');

          // Notify listeners that connection is restored
          notifyListeners();
          break;
        } else {
          debugPrint(
              '[BleBloc] Reconnection attempt $_reconnectionAttempts failed, continuing to next attempt');
        }
      } catch (e) {
        debugPrint(
            '[BleBloc] Unexpected error during reconnection attempt $_reconnectionAttempts: $e');
        // Log the error but continue with next attempt
      }
      await Future.delayed(reconnectionDelay);
    }

    // Always reset reconnection state when the loop exits (success, failure, or timeout)
    if (!_isConnected) {
      debugPrint(
          '[BleBloc] Reconnection loop exited without success, resetting state');

      if (_reconnectionAttempts >= _maxReconnectionAttempts) {
        debugPrint(
            '[BleBloc] Max reconnection attempts reached, reconnection failed');
        _handleConnectionError(context: context, isInitialConnection: false);
      }
      
      // Reset all reconnection state regardless of exit reason
      debugPrint(
          '[BleBloc] Resetting reconnection state: _isReconnecting=false, _reconnectionAttempts=0');
      isReconnectingNotifier.value = false;
      _isReconnecting = false;
      _isInRetryMode = false;
      _reconnectionAttempts = 0;
      _hasVibrated = false;
    }
  }

  void _handleConnectionError(
      {required BuildContext context, bool isInitialConnection = false}) {
    if (isInitialConnection) {
      debugPrint('[BleBloc] Initial connection failed, resetting state');
      selectedDeviceNotifier.value = null;
      _isConnected = false;
      _userInitiatedDisconnect = false;
      isReconnectingNotifier.value = false;
      _isReconnecting = false;
      isConnectingNotifier.value =
          false; // Reset connecting state so UI shows connect button
      _isInRetryMode = false; // Reset retry mode flag
      _reconnectionAttempts = 0; // Reset reconnection attempts counter
      _hasVibrated = false; // Reset vibration flag
      connectionErrorNotifier.value = false; // Reset connection error state
    } else {
      debugPrint(
          '[BleBloc] Permanent connection error during normal operation');

      // Create custom exception for permanent BLE connection loss
      final deviceId = selectedDevice?.remoteId.toString();
      final exception = PermanentBleConnectionError(
          deviceId, 'Max reconnection attempts reached');

      // Use ErrorService to display error to user and send to Sentry
      ErrorService.handleError(exception, StackTrace.current);

      // Reset state and notify connection error
      selectedDeviceNotifier.value = null;
      _isConnected = false;
      connectionErrorNotifier.value = true;
      isReconnectingNotifier.value = false;
      _isReconnecting = false;
      isConnectingNotifier.value =
          false; // Reset connecting state so UI shows connect button
      _isInRetryMode = false; // Reset retry mode flag
      _reconnectionAttempts = 0; // Reset reconnection attempts counter
      _hasVibrated = false; // Reset vibration flag
    }

    notifyListeners();
  }

  void resetConnectionError() {
    connectionErrorNotifier.value = false;
    notifyListeners();
  }

  /// Force reset reconnection state - useful for debugging stuck reconnections
  void forceResetReconnectionState() {
    debugPrint('[BleBloc] Force resetting reconnection state');
    _isReconnecting = false;
    _isInRetryMode = false;
    _reconnectionAttempts = 0;
    _hasVibrated = false;
    isReconnectingNotifier.value = false;
    notifyListeners();
  }

  /// Validates that received data is meaningful (not null, not empty, not all zeros)
  bool _validateReceivedData(Uint8List data) {
    if (data.isEmpty) {
      debugPrint('[BleBloc] Data validation failed: data is empty');
      return false;
    }
    
    // Check if all bytes are zero (which would indicate no real sensor data)
    bool allZeros = data.every((byte) => byte == 0);
    if (allZeros) {
      debugPrint('[BleBloc] Data validation failed: all bytes are zero');
      return false;
    }
    
    // Check if data has reasonable length (should be at least a few bytes for sensor data)
    if (data.length < 4) {
      debugPrint('[BleBloc] Data validation failed: data too short (${data.length} bytes)');
      return false;
    }
    
    debugPrint('[BleBloc] Data validation passed: meaningful data received');
    return true;
  }

  Future<void> _listenToCharacteristic(
      BluetoothCharacteristic characteristic) async {
    final uuid = characteristic.uuid.toString();

    // If a controller exists for this characteristic, close and remove it first
    if (_characteristicStreams.containsKey(uuid)) {
      await _characteristicStreams[uuid]?.close();
      _characteristicStreams.remove(uuid);
    }

    final controller = StreamController<List<double>>.broadcast();
    _characteristicStreams[uuid] = controller;

    await characteristic.setNotifyValue(true);
    characteristic.onValueReceived.listen((value) {
      if (!controller.isClosed) {
        List<double> parsedData = _parseData(Uint8List.fromList(value));
        controller.add(parsedData);
      }
    });
  }

  // Future<void> _listenToDeviceInfoCharacteristic(
  //     BluetoothCharacteristic characteristic) async {
  //   final controller = StreamController<List<String>>();
  //   _characteristicStringStreams[characteristic.uuid.toString()] = controller;

  //   await characteristic.setNotifyValue(true);
  //   characteristic.onValueReceived.listen((value) {
  //     print('Received value: $value');
  //     print('Decoded value: ${utf8.decode(value)}');
  //     List<String> parsedData = [utf8.decode(value)];
  //     controller.add(parsedData);
  //   });
  // }

  Stream<List<double>> getCharacteristicStream(String characteristicUuid) {
    if (!_characteristicStreams.containsKey(characteristicUuid)) {
      // Supress sending report to Sentry and show error in UI
      debugPrint('Characteristic stream not found');
    }
    return _characteristicStreams[characteristicUuid]!.stream;
  }

  List<double> _parseData(Uint8List value) {
    // This method will convert the incoming data to a list of doubles
    List<double> parsedValues = [];
    for (int i = 0; i < value.length; i += 4) {
      if (i + 4 <= value.length) {
        parsedValues.add(
            ByteData.sublistView(value, i, i + 4).getFloat32(0, Endian.little));
      }
    }
    return parsedValues;
  }

  @override
  void dispose() {
    _reconnectionListener?.cancel();
    _devicesListController.close();
    _clearCharacteristicStreams();
    selectedDeviceNotifier.dispose();
    isBluetoothEnabledNotifier.dispose();
    isScanningNotifier.dispose();
    isConnectingNotifier.dispose();
    isReconnectingNotifier.dispose();
    availableCharacteristics.dispose();
    super.dispose();
  }

  Future<void> requestEnableBluetooth() async {
    return FlutterBluePlus.turnOn();
  }
}
