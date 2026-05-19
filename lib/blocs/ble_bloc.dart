import 'dart:async';

import 'dart:typed_data';
import 'package:flutter/widgets.dart';
import 'package:sensebox_bike/blocs/settings_bloc.dart';
import 'package:sensebox_bike/secrets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import 'package:sensebox_bike/models/ble_connection_result.dart';
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
  List<String> failedCharacteristicUuids = [];
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

  BluetoothDevice? _pendingConnectionDevice;
  BluetoothService? _pendingSenseBoxService;
  List<String> _pendingValidUuids = [];

  final Map<String, StreamController<List<double>>> _characteristicStreams = {};
  final Map<String, StreamSubscription<List<int>>>
      _characteristicSubscriptions = {};

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
    _pendingConnectionDevice?.disconnect();
    _isConnected = false;
    selectedDevice = null;
    selectedDeviceNotifier.value = null;
    availableCharacteristics.value = [];
    failedCharacteristicUuids = [];
    _clearPendingConnection();
    _reconnectionListener?.cancel();
    _reconnectionListener = null;
    resetConnectionError();

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

  Future<BleConnectionResult> connectToDevice(
      BluetoothDevice device, BuildContext context) async {
    try {
      resetConnectionError();
      _clearPendingConnection();

      isConnectingNotifier.value = true;
      notifyListeners();

      if (isScanningNotifier.value == true) {
        await stopScanning();
      }

      await device.connect();

      final result = await _attemptConnectionWithRetries(
        device,
        context: context,
        autoAcceptPartial: false,
      );

      if (result.success) {
        _completeConnection(device, context);
      } else if (result.needsUserDecision) {
        _pendingConnectionDevice = device;
        _isConnected = false;
        selectedDevice = null;
        selectedDeviceNotifier.value = null;
      } else {
        await _disconnectDeviceSafe(device);
        selectedDevice = null;
        selectedDeviceNotifier.value = null;
        _isConnected = false;
      }

      return result;
    } catch (e) {
      ErrorService.handleError(e, StackTrace.current);

      await _disconnectDeviceSafe(device);
      selectedDevice = null;
      selectedDeviceNotifier.value = null;
      _isConnected = false;

      return BleConnectionResult.failure(
        reason: BleConnectionFailureReason.bluetoothError,
      );
    } finally {
      isConnectingNotifier.value = false;
      _isInRetryMode = false;
      notifyListeners();
    }
  }

  Future<BleConnectionResult> finalizePartialConnection(
    BluetoothDevice device,
    BuildContext context,
  ) async {
    if (_pendingSenseBoxService == null || _pendingValidUuids.isEmpty) {
      return BleConnectionResult.failure(
        reason: BleConnectionFailureReason.bluetoothError,
      );
    }

    try {
      final validUuids = _pendingValidUuids.map((u) => u.toLowerCase()).toSet();
      final characteristics = _pendingSenseBoxService!.characteristics
          .where((c) => validUuids.contains(c.uuid.toString().toLowerCase()))
          .toList();

      failedCharacteristicUuids = _pendingSenseBoxService!.characteristics
          .map((c) => c.uuid.toString())
          .where((uuid) => !validUuids.contains(uuid.toLowerCase()))
          .toList();

      await _applyConnection(device, characteristics);
      _completeConnection(device, context);
      _clearPendingConnection();

      return BleConnectionResult.fullSuccess();
    } catch (e) {
      await _disconnectDeviceSafe(device);
      return BleConnectionResult.failure(
        reason: BleConnectionFailureReason.bluetoothError,
      );
    } finally {
      notifyListeners();
    }
  }

  void _completeConnection(BluetoothDevice device, BuildContext context) {
    _handleDeviceReconnection(device, context);
    selectedDevice = device;
    selectedDeviceNotifier.value = selectedDevice;
    _isConnected = true;
    _userInitiatedDisconnect = false;
  }

  Future<BleConnectionResult> _executeConnectionAttempts(
    BluetoothDevice device,
    BuildContext? context, {
    required int maxAttempts,
    required bool isReconnection,
    required bool autoAcceptPartial,
    required Future<void> Function(BluetoothDevice) prepareForRetry,
    required void Function(
            {required BuildContext context, bool isInitialConnection})
        handleError,
  }) async {
    _isInRetryMode = true;
    BleConnectionResult? lastResult;

    for (int attempt = 0; attempt < maxAttempts; attempt++) {
      if (isReconnection) {
        _reconnectionAttempts++;
      }

      if (attempt > 0) {
        _isConnected = false;
      }

      try {
        BleConnectionResult result;
        try {
          result = await _attemptSingleConnection(
            device,
            updateConnectionState: !isReconnection,
            autoAcceptPartial: autoAcceptPartial,
          );
        } catch (e) {
          result = BleConnectionResult.failure(
            reason: BleConnectionFailureReason.bluetoothError,
          );
        }

        lastResult = result;

        if (result.success) {
          _isInRetryMode = false;
          return result;
        }

        if (result.needsUserDecision) {
          _isInRetryMode = false;
          return result;
        }

        if (attempt < maxAttempts - 1) {
          try {
            await prepareForRetry(device);
          } catch (e) {
            // Continue with next attempt anyway
          }
        }
      } catch (e) {
        lastResult = BleConnectionResult.failure(
          reason: BleConnectionFailureReason.bluetoothError,
        );
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

    if (context != null && isReconnection) {
      handleError(context: context, isInitialConnection: false);
    }

    return lastResult ??
        BleConnectionResult.failure(reason: BleConnectionFailureReason.noData);
  }

  Future<BleConnectionResult> _attemptConnectionWithRetries(
    BluetoothDevice device, {
    BuildContext? context,
    int maxAttempts = 5,
    bool isReconnection = false,
    bool autoAcceptPartial = false,
  }) async {
    return _executeConnectionAttempts(
      device,
      context,
      maxAttempts: maxAttempts,
      isReconnection: isReconnection,
      autoAcceptPartial: autoAcceptPartial,
      prepareForRetry: _prepareForRetry,
      handleError: _handleConnectionError,
    );
  }

  Future<BleConnectionResult> _attemptSingleConnection(
    BluetoothDevice device, {
    bool updateConnectionState = true,
    bool autoAcceptPartial = false,
  }) async {
    try {
      _clearCharacteristicStreams();

      final services = await device.discoverServices();
      if (services.isEmpty) {
        return BleConnectionResult.failure(
          reason: BleConnectionFailureReason.noService,
        );
      }

      BluetoothService senseBoxService;
      try {
        senseBoxService = _findSenseBoxService(services);
      } catch (e) {
        return BleConnectionResult.failure(
          reason: BleConnectionFailureReason.noService,
        );
      }

      if (senseBoxService.characteristics.isEmpty) {
        return BleConnectionResult.failure(
          reason: BleConnectionFailureReason.noCharacteristics,
        );
      }

      final probes = await _probeAllCharacteristics(senseBoxService);
      final validProbes = probes.where((p) => p.isValid).toList();
      final invalidProbes = probes.where((p) => !p.isValid).toList();

      if (validProbes.isEmpty) {
        return BleConnectionResult.failure(
          reason: BleConnectionResult.aggregateFailureReason(probes),
          probes: probes,
        );
      }

      final validUuids =
          validProbes.map((p) => p.uuid.toLowerCase()).toSet();
      final validCharacteristics = senseBoxService.characteristics
          .where((c) => validUuids.contains(c.uuid.toString().toLowerCase()))
          .toList();

      if (invalidProbes.isEmpty) {
        failedCharacteristicUuids = [];
        await _applyConnection(device, validCharacteristics);
        if (updateConnectionState) {
          _isConnected = true;
          _userInitiatedDisconnect = false;
          notifyListeners();
        }
        return BleConnectionResult.fullSuccess(probes: probes);
      }

      if (autoAcceptPartial) {
        failedCharacteristicUuids =
            invalidProbes.map((p) => p.uuid).toList();
        await _applyConnection(device, validCharacteristics);
        if (updateConnectionState) {
          _isConnected = true;
          _userInitiatedDisconnect = false;
          notifyListeners();
        }
        return BleConnectionResult.fullSuccess(probes: probes);
      }

      _pendingConnectionDevice = device;
      _pendingSenseBoxService = senseBoxService;
      _pendingValidUuids = validProbes.map((p) => p.uuid).toList();

      return BleConnectionResult.needsUserDecision(probes: probes);
    } catch (e) {
      return BleConnectionResult.failure(
        reason: BleConnectionFailureReason.bluetoothError,
      );
    }
  }

  Future<List<BleCharacteristicProbeResult>> _probeAllCharacteristics(
    BluetoothService senseBoxService,
  ) async {
    // Probe sequentially: parallel notify on many characteristics often
    // fails on BLE stacks even when the device is sending data.
    final results = <BleCharacteristicProbeResult>[];
    for (final characteristic in senseBoxService.characteristics) {
      results.add(await _probeCharacteristic(characteristic));
    }
    return results;
  }

  Future<BleCharacteristicProbeResult> _probeCharacteristic(
    BluetoothCharacteristic characteristic,
  ) async {
    final uuid = characteristic.uuid.toString().toLowerCase();
    final dataReceivedCompleter = Completer<bool>();
    Uint8List? receivedData;

    final subscription = characteristic.onValueReceived.listen((value) {
      if (!dataReceivedCompleter.isCompleted) {
        receivedData = Uint8List.fromList(value);
        dataReceivedCompleter.complete(true);
      }
    });

    try {
      await characteristic.setNotifyValue(true);

      await Future.any([
        dataReceivedCompleter.future,
        Future.delayed(dataListeningTimeout),
      ]);

      if (receivedData == null && characteristic.properties.read) {
        try {
          final value = await characteristic.read();
          if (value.isNotEmpty) {
            receivedData = Uint8List.fromList(value);
          }
        } catch (e) {
          // Fall through to no-data result
        }
      }
    } finally {
      await subscription.cancel();
      try {
        await characteristic.setNotifyValue(false);
      } catch (e) {
        // Ignore errors while tearing down probe subscription
      }
    }

    if (receivedData == null) {
      return BleCharacteristicProbeResult(
        uuid: uuid,
        isValid: false,
        reason: BleConnectionFailureReason.noData,
      );
    }

    if (!_validateReceivedData(receivedData!)) {
      final allZeros =
          receivedData!.isNotEmpty && receivedData!.every((byte) => byte == 0);
      return BleCharacteristicProbeResult(
        uuid: uuid,
        isValid: false,
        reason: allZeros
            ? BleConnectionFailureReason.invalidData
            : BleConnectionFailureReason.invalidData,
      );
    }

    return BleCharacteristicProbeResult(uuid: uuid, isValid: true);
  }

  Future<void> _applyConnection(
    BluetoothDevice device,
    List<BluetoothCharacteristic> characteristics,
  ) async {
    for (final characteristic in characteristics) {
      await _listenToCharacteristic(characteristic);
    }

    availableCharacteristics.value = characteristics;
    characteristicStreamsVersion.value++;
  }

  Future<void> _disconnectDeviceSafe(BluetoothDevice device) async {
    try {
      await device.disconnect();
    } catch (e) {
      // Device may already be disconnected
    }
  }

  void _clearPendingConnection() {
    _pendingConnectionDevice = null;
    _pendingSenseBoxService = null;
    _pendingValidUuids = [];
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
    for (var subscription in _characteristicSubscriptions.values) {
      subscription.cancel();
    }
    _characteristicSubscriptions.clear();
    
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

    final result = await _attemptConnectionWithRetries(
      device,
      context: context,
      maxAttempts: _maxReconnectionAttempts,
      isReconnection: true,
      autoAcceptPartial: true,
    );

    if (result.success) {
      _isConnected = true;
      selectedDevice = device;
      selectedDeviceNotifier.value = selectedDevice;
      _userInitiatedDisconnect = false;
      _hasVibrated = false;
      _reconnectionAttempts = 0;
      isReconnectingNotifier.value = false;
      _isReconnecting = false;
      _isInRetryMode = false;

      notifyListeners();
    }

    if (!result.success &&
        _reconnectionAttempts >= _maxReconnectionAttempts) {
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

    await _characteristicSubscriptions[uuid]?.cancel();
    _characteristicSubscriptions.remove(uuid);

    if (_characteristicStreams.containsKey(uuid)) {
      await _characteristicStreams[uuid]?.close();
      _characteristicStreams.remove(uuid);
    }

    final controller = StreamController<List<double>>.broadcast();
    _characteristicStreams[uuid] = controller;

    await characteristic.setNotifyValue(true);
    final subscription = characteristic.onValueReceived.listen((value) {
      if (!controller.isClosed) {
        List<double> parsedData = _parseData(Uint8List.fromList(value));

        controller.add(parsedData);
      }
    });
    _characteristicSubscriptions[uuid] = subscription;
  }



  Stream<List<double>> getCharacteristicStream(String characteristicUuid) {
    if (!_characteristicStreams.containsKey(characteristicUuid)) {
      throw Exception(
          'Characteristic stream not found for UUID: $characteristicUuid. '
          'The characteristic may not be available yet or the device may not be connected.');
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
    characteristicStreamsVersion.dispose();
    connectionErrorNotifier.dispose();
    super.dispose();
  }

  Future<void> requestEnableBluetooth() async {
    return FlutterBluePlus.turnOn();
  }
}
