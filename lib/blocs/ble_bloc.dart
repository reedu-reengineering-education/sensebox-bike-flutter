import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:sensebox_bike/blocs/ble_connection_manager.dart';
import 'package:sensebox_bike/blocs/ble_connection_state.dart';
import 'package:sensebox_bike/blocs/sensor_data_liveness.dart';
import 'package:sensebox_bike/blocs/settings_bloc.dart';
import 'package:sensebox_bike/secrets.dart';
import 'package:sensebox_bike/services/custom_exceptions.dart';
import 'package:sensebox_bike/services/error_service.dart';
import 'package:vibration/vibration.dart';

const reconnectionDelay = Duration(seconds: 1);
const deviceConnectTimeout = Duration(seconds: 10);
const configurableReconnectionDelay = Duration(seconds: 1);
const dataListeningTimeout = Duration(seconds: 4);
const sensorDataStaleTimeout = Duration(seconds: 8);

class BleBloc with ChangeNotifier {
  final SettingsBloc settingsBloc;

  final ValueNotifier<bool> isBluetoothEnabledNotifier = ValueNotifier(false);
  final ValueNotifier<bool> isScanningNotifier = ValueNotifier(false);
  final ValueNotifier<bool> isConnectingNotifier = ValueNotifier(false);
  final ValueNotifier<bool> isReconnectingNotifier = ValueNotifier(false);
  final ValueNotifier<BleConnectionState> connectionStateNotifier =
      ValueNotifier(BleConnectionState.disconnected);
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
    late final BleConnectionManager _connectionManager;
    final SensorDataLiveness _sensorDataLiveness =
      SensorDataLiveness(noDataTimeout: sensorDataStaleTimeout);

  final Map<String, StreamController<List<double>>> _characteristicStreams = {};
  final Map<String, StreamSubscription<List<int>>> _characteristicSubscriptions =
      {};

  bool get isConnected => _isConnected;

  BleBloc(this.settingsBloc) {
    _connectionManager = BleConnectionManager(
      deviceConnectTimeout: deviceConnectTimeout,
      retryDelay: configurableReconnectionDelay,
    );

    _sensorDataLiveness.hasValidDataNotifier
        .addListener(_onSensorDataValidityChanged);

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
    } catch (_) {
      isScanningNotifier.value = false;
      throw ScanPermissionDenied();
    }

    FlutterBluePlus.scanResults.listen((results) {
      devicesList.clear();
      for (ScanResult result in results) {
        if (result.device.platformName.startsWith('senseBox')) {
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
    disconnectDevice();

    isScanningNotifier.value = true;

    try {
      await FlutterBluePlus.startScan(timeout: deviceConnectTimeout);
    } catch (_) {
      isScanningNotifier.value = false;
      throw ScanPermissionDenied();
    }

    FlutterBluePlus.scanResults.listen((results) {
      devicesList.clear();
      for (ScanResult result in results) {
        if (result.device.platformName.startsWith('senseBox')) {
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
    _sensorDataLiveness.resetTracking();
    _setConnectionState(BleConnectionState.disconnected);
    selectedDevice = null;
    selectedDeviceNotifier.value = null;
    availableCharacteristics.value = [];
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

  Future<void> connectToDevice(
      BluetoothDevice device, BuildContext context) async {
    try {
      resetConnectionError();
      _sensorDataLiveness.resetTracking();

      isConnectingNotifier.value = true;
      _setConnectionState(BleConnectionState.connecting);
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
        _setConnectionState(BleConnectionState.disconnected);
      }
    } catch (e) {
      ErrorService.handleError(e, StackTrace.current);

      selectedDevice = null;
      selectedDeviceNotifier.value = null;
      _setConnectionState(BleConnectionState.disconnected);

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
    required void Function(
            {required BuildContext context, bool isInitialConnection})
        handleError,
    required VoidCallback onRetryAttempt,
  }) async {
    _isInRetryMode = true;

    final success = await _connectionManager.attemptConnectionWithRetries(
      device,
      context: context,
      maxAttempts: maxAttempts,
      isReconnection: isReconnection,
      attemptConnection: attemptConnection,
      handleError: handleError,
      onRetryAttempt: onRetryAttempt,
    );

    _isInRetryMode = false;
    return success;
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
      handleError: _handleConnectionError,
      onRetryAttempt: () {
        _setConnectionState(
          isReconnection
              ? BleConnectionState.reconnecting
              : BleConnectionState.connecting,
        );
      },
    );
  }

  Future<bool> _attemptSingleConnection(
    BluetoothDevice device,
    BuildContext? context, {
    bool updateConnectionState = true,
  }) async {
    try {
      _clearCharacteristicStreams();
      _sensorDataLiveness.resetTracking();

      final services = await device.discoverServices();
      if (services.isEmpty) {
        return false;
      }

      BluetoothService? senseBoxService;
      try {
        senseBoxService = _findSenseBoxService(services);
      } catch (_) {
        return false;
      }

      if (senseBoxService.characteristics.isEmpty) {
        return false;
      }

      for (var characteristic in senseBoxService.characteristics) {
        await _listenToCharacteristic(characteristic);
      }

      availableCharacteristics.value = senseBoxService.characteristics;
      characteristicStreamsVersion.value++;

      if (updateConnectionState) {
        _setConnectionState(BleConnectionState.waitingForData);
      }

      final hasFirstValidData =
          await _sensorDataLiveness.waitForFirstValidData(
        dataListeningTimeout,
      );

      if (!hasFirstValidData) {
        return false;
      }

      if (updateConnectionState) {
        _userInitiatedDisconnect = false;
        _setConnectionState(BleConnectionState.connected);
      }

      return true;
    } catch (_) {
      return false;
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
            _setConnectionState(BleConnectionState.reconnecting);
            isReconnectingNotifier.value = true;

            try {
              _startReconnectionProcess(device, context);
            } catch (_) {
              _isReconnecting = false;
              isReconnectingNotifier.value = false;
            }
          }
        }
      } catch (_) {
        // Reconnection loop handles failures.
      }
    });

    _reconnectionListener?.onError((_) {
      _handleConnectionError(context: context, isInitialConnection: false);
    });
  }

  void _startReconnectionProcess(
    BluetoothDevice device,
    BuildContext context,
  ) async {
    if (_isReconnecting) {
      if (_reconnectionAttempts >= _maxReconnectionAttempts) {
        _isReconnecting = false;
        _reconnectionAttempts = 0;
        _hasVibrated = false;
        isReconnectingNotifier.value = false;
        _setConnectionState(BleConnectionState.disconnected);
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
      attemptConnection: (device, context) {
        _reconnectionAttempts++;
        return _attemptSingleConnection(
          device,
          context,
          updateConnectionState: false,
        );
      },
      handleError: _handleConnectionError,
      onRetryAttempt: () {
        _setConnectionState(BleConnectionState.reconnecting);
      },
    );

    if (success) {
      _userInitiatedDisconnect = false;
      _hasVibrated = false;
      _reconnectionAttempts = 0;
      isReconnectingNotifier.value = false;
      _isReconnecting = false;
      _isInRetryMode = false;

      _setConnectionState(
        _sensorDataLiveness.hasValidData
            ? BleConnectionState.connected
            : BleConnectionState.waitingForData,
      );

      notifyListeners();
    }

    if (!_isConnected && _reconnectionAttempts >= _maxReconnectionAttempts) {
      _handleConnectionError(context: context, isInitialConnection: false);
    }
  }

  void _handleConnectionError(
      {required BuildContext context, bool isInitialConnection = false}) {
    if (isInitialConnection) {
      selectedDeviceNotifier.value = null;
      _setConnectionState(BleConnectionState.disconnected);
      _userInitiatedDisconnect = false;
      _resetReconnectionState();
      isConnectingNotifier.value = false;
      connectionErrorNotifier.value = false;
    } else {
      selectedDevice = null;
      selectedDeviceNotifier.value = null;
      _setConnectionState(BleConnectionState.disconnected);
      connectionErrorNotifier.value = true;

      _reconnectionListener?.cancel();
      _reconnectionListener = null;

      _clearCharacteristicStreams();
      _sensorDataLiveness.resetTracking();

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

    _reconnectionListener?.cancel();
    _reconnectionListener = null;

    _isReconnecting = false;
    _isInRetryMode = false;
    _reconnectionAttempts = 0;
    _hasVibrated = false;
    isReconnectingNotifier.value = false;

    if (selectedDeviceNotifier.value == null) {
      _setConnectionState(BleConnectionState.disconnected);
    }

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

  void _setConnectionState(BleConnectionState state) {
    connectionStateNotifier.value = state;
    _isConnected = state == BleConnectionState.connected;
  }

  void _onSensorDataValidityChanged() {
    final hasValidData = _sensorDataLiveness.hasValidData;
    final hasSelectedDevice = selectedDeviceNotifier.value != null;

    if (!hasSelectedDevice || _userInitiatedDisconnect) {
      return;
    }

    if (hasValidData) {
      if (connectionStateNotifier.value != BleConnectionState.connected) {
        _setConnectionState(BleConnectionState.connected);
        notifyListeners();
      }
      return;
    }

    if (connectionStateNotifier.value == BleConnectionState.connected) {
      _setConnectionState(BleConnectionState.waitingForData);
      notifyListeners();
    }
  }

  bool _validateReceivedData(Uint8List data) {
    if (data.isEmpty) {
      return false;
    }

    final allZeros = data.every((byte) => byte == 0);
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
        final rawData = Uint8List.fromList(value);
        if (_validateReceivedData(rawData)) {
          _sensorDataLiveness.markValidDataSeen();
        }

        final parsedData = _parseData(rawData);
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
    final parsedValues = <double>[];
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
    _sensorDataLiveness.hasValidDataNotifier
        .removeListener(_onSensorDataValidityChanged);
    _sensorDataLiveness.dispose();
    _devicesListController.close();
    _clearCharacteristicStreams();
    selectedDeviceNotifier.dispose();
    connectionStateNotifier.dispose();
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
