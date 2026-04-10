import 'dart:async';

import 'dart:typed_data';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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

@immutable
class BleState {
  const BleState({
    required this.isConnected,
    required this.isBluetoothEnabled,
    required this.isScanning,
    required this.isConnecting,
    required this.isReconnecting,
    required this.selectedDevice,
    required this.availableCharacteristics,
    required this.characteristicStreamsVersion,
    required this.connectionError,
  });

  final bool isConnected;
  final bool isBluetoothEnabled;
  final bool isScanning;
  final bool isConnecting;
  final bool isReconnecting;
  final BluetoothDevice? selectedDevice;
  final List<BluetoothCharacteristic> availableCharacteristics;
  final int characteristicStreamsVersion;
  final bool connectionError;
}

class BleBloc extends Cubit<BleState> {
  final SettingsBloc settingsBloc;

  final List<BluetoothDevice> devicesList = [];
  final StreamController<List<BluetoothDevice>> _devicesListController =
      StreamController.broadcast();
  Stream<List<BluetoothDevice>> get devicesListStream =>
      _devicesListController.stream;
  StreamSubscription<List<ScanResult>>? _scanResultsSubscription;
  StreamSubscription<bool>? _isScanningSubscription;

  bool _isBluetoothEnabled = false;
  bool _isScanning = false;
  bool _isConnecting = false;
  BluetoothDevice? _selectedDevice;
  List<BluetoothCharacteristic> _availableCharacteristics = [];
  int _characteristicStreamsVersion = 0;
  bool _connectionError = false;

  BluetoothDevice? get selectedDevice => _selectedDevice;
  set selectedDevice(BluetoothDevice? device) {
    _selectedDevice = device;
  }

  bool _isConnected = false;
  bool _isReconnecting = false;
  bool _userInitiatedDisconnect = false;
  bool _isInRetryMode = false;
  int _reconnectionAttempts = 0;
  bool _hasVibrated = false;
  static const int _maxReconnectionAttempts = 10;

  StreamSubscription<BluetoothConnectionState>? _reconnectionListener;

  final Map<String, StreamController<List<double>>> _characteristicStreams = {};
  final Map<String, StreamSubscription<List<int>>>
      _characteristicSubscriptions = {};

  bool get isConnected => _isConnected;

  BleBloc(this.settingsBloc)
      : super(const BleState(
          isConnected: false,
          isBluetoothEnabled: false,
          isScanning: false,
          isConnecting: false,
          isReconnecting: false,
          selectedDevice: null,
          availableCharacteristics: <BluetoothCharacteristic>[],
          characteristicStreamsVersion: 0,
          connectionError: false,
        )) {
    FlutterBluePlus.setLogLevel(LogLevel.error);
    FlutterBluePlus.adapterState.listen((state) {
      updateBluetoothStatus(state == BluetoothAdapterState.on);
    });

    _initializeBluetoothStatus();
  }

  void _emitState() {
    if (!isClosed) {
      emit(BleState(
        isConnected: _isConnected,
        isBluetoothEnabled: _isBluetoothEnabled,
        isScanning: _isScanning,
        isConnecting: _isConnecting,
        isReconnecting: _isReconnecting,
        selectedDevice: _selectedDevice,
        availableCharacteristics: List<BluetoothCharacteristic>.from(
          _availableCharacteristics,
        ),
        characteristicStreamsVersion: _characteristicStreamsVersion,
        connectionError: _connectionError,
      ));
    }
  }

  Future<void> _initializeBluetoothStatus() async {
    BluetoothAdapterState currentState =
        await FlutterBluePlus.adapterState.first;
    updateBluetoothStatus(currentState == BluetoothAdapterState.on);
  }

  void updateBluetoothStatus(bool isEnabled) {
    if (_isBluetoothEnabled != isEnabled) {
      _isBluetoothEnabled = isEnabled;
      _emitState();
    }
  }

  Future<void> startScanning() async {
    _ensureScanListeners();
    _isScanning = true;
    _emitState();

    try {
      await FlutterBluePlus.startScan(timeout: deviceConnectTimeout);
    } catch (e) {
      _isScanning = false;
      _emitState();
      throw ScanPermissionDenied();
    }
  }

  Future<void> stopScanning() async {
    await FlutterBluePlus.stopScan();
    _isScanning = false;
    _emitState();
  }

  Future<void> scanForNewDevices() async {
    _ensureScanListeners();
    // Clear all existing state before scanning
    disconnectDevice();

    _isScanning = true;
    _emitState();

    try {
      await FlutterBluePlus.startScan(timeout: deviceConnectTimeout);
    } catch (e) {
      _isScanning = false;
      _emitState();
      throw ScanPermissionDenied();
    }
  }

  void _ensureScanListeners() {
    _scanResultsSubscription ??=
        FlutterBluePlus.scanResults.listen(_handleScanResults);

    _isScanningSubscription ??= FlutterBluePlus.isScanning.listen((scanning) {
      if (_isScanning != scanning) {
        _isScanning = scanning;
        _emitState();
      }
    });
  }

  void _handleScanResults(List<ScanResult> results) {
    final nextDevices = <BluetoothDevice>[];
    for (final result in results) {
      if (result.device.platformName.startsWith("senseBox")) {
        nextDevices.add(result.device);
      }
    }

    if (_sameDeviceList(devicesList, nextDevices)) {
      return;
    }

    devicesList
      ..clear()
      ..addAll(nextDevices);
    _devicesListController.add(List<BluetoothDevice>.from(devicesList));
    _emitState();
  }

  bool _sameDeviceList(
    List<BluetoothDevice> current,
    List<BluetoothDevice> next,
  ) {
    if (current.length != next.length) {
      return false;
    }

    for (var i = 0; i < current.length; i++) {
      if (current[i].remoteId != next[i].remoteId) {
        return false;
      }
    }

    return true;
  }

  void disconnectDevice() {
    _userInitiatedDisconnect = true;
    _isInRetryMode = false;
    _selectedDevice?.disconnect();
    _isConnected = false;
    _selectedDevice = null;
    _availableCharacteristics = [];
    _reconnectionListener?.cancel();
    _reconnectionListener = null;
    resetConnectionError();

    // Ensure reconnection state is fully reset
    _resetReconnectionState();

    _emitState();
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

      _isConnecting = true;
      _emitState();

      if (_isScanning == true) {
        await stopScanning();
      }

      await device.connect();

      final success =
          await _attemptConnectionWithRetries(device, context: context);
      _isConnected = success;

      if (_isConnected) {
        _handleDeviceReconnection(device, context);

        _selectedDevice = device;
      } else {
        _selectedDevice = null;
      }
    } catch (e) {
      ErrorService.handleError(e, StackTrace.current);

      _selectedDevice = null;
      _isConnected = false;

      _handleConnectionError(context: context, isInitialConnection: true);
    } finally {
      _isConnecting = false;
      _isInRetryMode = false;
      _emitState();
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

          _availableCharacteristics = senseBoxService.characteristics;
          _characteristicStreamsVersion++;

          if (updateConnectionState) {
            _isConnected = true;
            _userInitiatedDisconnect = false;

            _emitState();
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
            _isReconnecting = true;
            _emitState();

            // Start the actual reconnection process
            try {
              _startReconnectionProcess(device, context);
            } catch (e) {
              // Reset state if reconnection process fails to start
              _isReconnecting = false;
              _emitState();
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
      _isReconnecting = false;
      _isInRetryMode = false;

      _emitState();
    }

    // Only handle permanent connection failure if max attempts reached
    if (!_isConnected && _reconnectionAttempts >= _maxReconnectionAttempts) {
      _handleConnectionError(context: context, isInitialConnection: false);
    }
  }

  void _handleConnectionError(
      {required BuildContext context, bool isInitialConnection = false}) {
    if (isInitialConnection) {
      _selectedDevice = null;
      _isConnected = false;
      _userInitiatedDisconnect = false;
      _resetReconnectionState();
      _isConnecting = false;
      _connectionError = false; // Reset connection error state
    } else {
      // Max reconnection attempts reached - handle as permanent connection failure
      // Reset state and notify connection error
      _selectedDevice = null;
      _isConnected = false;
      _connectionError = true;

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
      _isConnecting = false;
    }

    _emitState();
  }

  void resetConnectionError() {
    _connectionError = false;

    // Cancel any ongoing reconnection listener
    _reconnectionListener?.cancel();
    _reconnectionListener = null;

    // Reset reconnection state
    _isReconnecting = false;
    _isInRetryMode = false;
    _reconnectionAttempts = 0;
    _hasVibrated = false;

    _emitState();
  }

  void _resetReconnectionState() {
    _isReconnecting = false;
    _isInRetryMode = false;
    _reconnectionAttempts = 0;
    _hasVibrated = false;

    _emitState();
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
  Future<void> close() async {
    _reconnectionListener?.cancel();
    await _scanResultsSubscription?.cancel();
    await _isScanningSubscription?.cancel();
    await _devicesListController.close();
    _clearCharacteristicStreams();
    return super.close();
  }

  void dispose() {
    unawaited(close());
  }

  Future<void> requestEnableBluetooth() async {
    return FlutterBluePlus.turnOn();
  }
}
