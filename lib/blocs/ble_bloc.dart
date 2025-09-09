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
const deviceConnectTimeout = Duration(seconds: 10);
const configurableReconnectionDelay = Duration(seconds: 1);
const dataListeningTimeout = Duration(seconds: 4); 

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
  bool _isReconnecting = false;
  bool _userInitiatedDisconnect = false;
  bool _isInRetryMode = false;
  int _reconnectionAttempts = 0;
  bool _hasVibrated = false;
  static const int _maxReconnectionAttempts = 10;
  
  StreamSubscription<BluetoothConnectionState>? _reconnectionListener;

  final Map<String, StreamController<List<double>>> _characteristicStreams = {};

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
    if (isBluetoothEnabledNotifier.value != isEnabled) {
      isBluetoothEnabledNotifier.value = isEnabled;
      notifyListeners();
    }
  }

  Future<void> startScanning() async {
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

  Future<void> scanForNewDevices() async {
    // Clear all existing state before scanning
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
    _userInitiatedDisconnect = true;
    _isInRetryMode = false;
    selectedDevice?.disconnect();
    _isConnected = false;
    selectedDevice = null;
    selectedDeviceNotifier.value = null;
    availableCharacteristics.value = [];
    _reconnectionListener?.cancel();
    _reconnectionListener = null;
    resetConnectionError();
    
    // Ensure reconnection state is fully reset
    _resetReconnectionState();


    
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

      final success =
          await _attemptConnectionWithRetries(device, context: context);
      _isConnected = success;

      if (_isConnected) {
        _handleDeviceReconnection(device, context);
        
        selectedDevice = device;
        selectedDeviceNotifier.value = selectedDevice;
      } else {
        selectedDevice = null;
        selectedDeviceNotifier.value = null;
      }
    } catch (e) {
      ErrorService.handleError(e, StackTrace.current);
      
      selectedDevice = null;
      selectedDeviceNotifier.value = null;
      _isConnected = false;
      
      _handleConnectionError(context: context, isInitialConnection: true);
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
    required bool isReconnection,
    required Future<bool> Function(BluetoothDevice, BuildContext?)
        attemptConnection,
    required Future<void> Function(BluetoothDevice) prepareForRetry,
    required void Function(
            {required BuildContext context, bool isInitialConnection})
        handleError,
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

    if (context != null) {
      handleError(context: context, isInitialConnection: !isReconnection);
    }
    return false;
  }

  Future<bool> _attemptConnectionWithRetries(
    BluetoothDevice device, {
    BuildContext? context,
    int maxAttempts = 5,
    bool isReconnection = false,
  }) async {
    return _executeConnectionAttempts(
      device,
      context,
      maxAttempts: maxAttempts,
      isReconnection: isReconnection,
      attemptConnection: (device, context) => _attemptSingleConnection(
        device,
        context,
        updateConnectionState: true,
      ),
      prepareForRetry: _prepareForRetry,
      handleError: _handleConnectionError,
    );
  }

  /// Attempts a single connection without retries
  Future<bool> _attemptSingleConnection(
    BluetoothDevice device,
    BuildContext? context, {
    bool updateConnectionState = true,
  }) async {
    try {
      _clearCharacteristicStreams();

      final services = await device.discoverServices();
      if (services.isEmpty) {
        return false;
      }

      BluetoothService? senseBoxService;
      try {
        senseBoxService = _findSenseBoxService(services);
      } catch (e) {
        return false;
      }

      if (senseBoxService.characteristics.isEmpty) {
        return false;
      }

      final firstCharacteristic = senseBoxService.characteristics.first;

      bool dataReceived = false;
      final dataReceivedCompleter = Completer<bool>();

      await firstCharacteristic.setNotifyValue(true);
      Uint8List? receivedData;
      final subscription = firstCharacteristic.onValueReceived.listen((value) {
        if (!dataReceivedCompleter.isCompleted) {
          receivedData = Uint8List.fromList(value);
          dataReceived = true;
          dataReceivedCompleter.complete(true);
        }
      });

      try {
        await Future.any([
          dataReceivedCompleter.future,
          Future.delayed(dataListeningTimeout),
        ]);
      } finally {
        subscription.cancel();
        await firstCharacteristic.setNotifyValue(false);
      }

      if (dataReceived && receivedData != null) {
        bool isDataMeaningful = _validateReceivedData(receivedData!);

        if (isDataMeaningful) {
          for (var characteristic in senseBoxService.characteristics) {
            await _listenToCharacteristic(characteristic);
          }

          availableCharacteristics.value = senseBoxService.characteristics;
          characteristicStreamsVersion.value++;

          if (updateConnectionState) {
            _isConnected = true;
            _userInitiatedDisconnect = false;
              
            notifyListeners();
          }

          return true;
        } else {
          return false;
        }
      } else if (dataReceived && receivedData == null) {
        return false;
      } else {
        return false;
      }
    } catch (e) {
      return false;
    }
  }

  /// Prepares device for retry by disconnecting and reconnecting
  Future<void> _prepareForRetry(BluetoothDevice device) async {
    try {
      // Disconnect device (catch any disconnect exceptions)
      try {
        await device.disconnect();
      } catch (e) {
        // Continue anyway, device might already be disconnected
      }

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

  void _clearCharacteristicStreams() {
    for (var controller in _characteristicStreams.values) {
      controller.close();
    }
    _characteristicStreams.clear();
  }

  BluetoothService _findSenseBoxService(List<BluetoothService> services) {
    return services.firstWhere(
      (service) => service.uuid == senseBoxServiceUUID,
      orElse: () => throw Exception('senseBox service not found'),
    );
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
      _handleConnectionError(context: context, isInitialConnection: false);
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
      isReconnection: true,
      attemptConnection: (device, context) async {
        _reconnectionAttempts++;
        return _attemptSingleConnection(
          device,
          context,
          updateConnectionState: false,
        );
      },
      prepareForRetry: _prepareForRetry,
      handleError: _handleConnectionError,
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

    // Only handle permanent connection failure if max attempts reached
    if (!_isConnected && _reconnectionAttempts >= _maxReconnectionAttempts) {
      _handleConnectionError(context: context, isInitialConnection: false);
    }
  }

  void _handleConnectionError(
      {required BuildContext context, bool isInitialConnection = false}) {
    if (isInitialConnection) {
      selectedDeviceNotifier.value = null;
      _isConnected = false;
      _userInitiatedDisconnect = false;
      _resetReconnectionState();
      isConnectingNotifier.value = false; 
      connectionErrorNotifier.value = false; // Reset connection error state
    } else {
      // Max reconnection attempts reached - handle as permanent connection failure
      // Reset state and notify connection error
      selectedDevice = null;
      selectedDeviceNotifier.value = null;
      _isConnected = false;
      connectionErrorNotifier.value = true;
      
      // Cancel any ongoing reconnection listener
      _reconnectionListener?.cancel();
      _reconnectionListener = null;

      // Clear characteristic streams
      _clearCharacteristicStreams();

      // Reset reconnection state
      _isReconnecting = false;
      _isInRetryMode = false;
      _reconnectionAttempts = 0;
      _hasVibrated = false;
      isReconnectingNotifier.value = false;
      isConnectingNotifier.value = false;
    }

    notifyListeners();
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



  bool _validateReceivedData(Uint8List data) {
    if (data.isEmpty) {
      return false;
    }
    
    bool allZeros = data.every((byte) => byte == 0);
    if (allZeros) {
      return false;
    }
    
    if (data.length < 4) {
      return false;
    }
    
    return true;
  }

  Future<void> _listenToCharacteristic(
      BluetoothCharacteristic characteristic) async {
    final uuid = characteristic.uuid.toString();

    // If a controller exists for this characteristic, close and remove it firs
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
