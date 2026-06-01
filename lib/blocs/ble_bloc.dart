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

const deviceConnectTimeout = Duration(seconds: 10);
const dataListeningTimeout = Duration(seconds: 4);
const sensorDataStaleTimeout = Duration(seconds: 8);

class BleBloc with ChangeNotifier {
  final SettingsBloc settingsBloc;

  final ValueNotifier<bool> isBluetoothEnabledNotifier = ValueNotifier(false);
  final ValueNotifier<bool> isScanningNotifier = ValueNotifier(false);
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

  bool _userInitiatedDisconnect = false;

  late final BleConnectionManager _connectionManager;
  final SensorDataLiveness _sensorDataLiveness =
      SensorDataLiveness(noDataTimeout: sensorDataStaleTimeout);

  final Map<String, StreamController<List<double>>> _characteristicStreams = {};
  final Map<String, StreamSubscription<List<int>>> _characteristicSubscriptions =
      {};

  bool get isConnected =>
      connectionStateNotifier.value == BleConnectionState.connected;

  BluetoothDevice? get selectedDevice => selectedDeviceNotifier.value;
  set selectedDevice(BluetoothDevice? device) {
    selectedDeviceNotifier.value = device;
  }

  BleBloc(this.settingsBloc) {
    _connectionManager = BleConnectionManager(
      deviceConnectTimeout: deviceConnectTimeout,
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
    selectedDevice?.disconnect();
    _sensorDataLiveness.resetTracking();
    _setConnectionState(BleConnectionState.disconnected);
    selectedDevice = null;
    availableCharacteristics.value = [];
    _connectionManager.cancelReconnection();
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
      _sensorDataLiveness.resetTracking();

      _setConnectionState(BleConnectionState.connecting);
      notifyListeners();

      if (isScanningNotifier.value == true) {
        await stopScanning();
      }

      await device.connect();

      final success = await _connectionManager.attemptConnectionWithRetries(
        device,
        context: context,
        attemptConnection: (device, context) =>
            _attemptSingleConnection(device, context, updateConnectionState: true),
        handleError: _handleConnectionError,
        onRetryAttempt: () => _setConnectionState(BleConnectionState.connecting),
      );

      if (success) {
        selectedDevice = device;
        _connectionManager.watchForDisconnect(
          device,
          shouldSkipReconnect: () => _userInitiatedDisconnect,
          attemptReconnection: (device, context) =>
              _attemptSingleConnection(device, context, updateConnectionState: false),
          onReconnectSuccess: () {
            _userInitiatedDisconnect = false;
            _setConnectionState(
              _sensorDataLiveness.hasValidData
                  ? BleConnectionState.connected
                  : BleConnectionState.waitingForData,
            );
            notifyListeners();
          },
          onStateChange: _setConnectionState,
          onPermanentFailure: _handleConnectionError,
          vibrateOnDisconnect: settingsBloc.vibrateOnDisconnect,
          context: context,
        );
      } else {
        selectedDevice = null;
        _setConnectionState(BleConnectionState.disconnected);
      }
    } catch (e) {
      ErrorService.handleError(e, StackTrace.current);
      selectedDevice = null;
      _setConnectionState(BleConnectionState.disconnected);
      _handleConnectionError(context: context, isInitialConnection: true);
    } finally {
      notifyListeners();
    }
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
      if (services.isEmpty) return false;

      BluetoothService? senseBoxService;
      try {
        senseBoxService = _findSenseBoxService(services);
      } catch (_) {
        return false;
      }

      if (senseBoxService.characteristics.isEmpty) return false;

      for (var characteristic in senseBoxService.characteristics) {
        await _listenToCharacteristic(characteristic);
      }

      availableCharacteristics.value = senseBoxService.characteristics;
      characteristicStreamsVersion.value++;

      if (updateConnectionState) {
        _setConnectionState(BleConnectionState.waitingForData);
      }

      final hasFirstValidData =
          await _sensorDataLiveness.waitForFirstValidData(dataListeningTimeout);

      if (!hasFirstValidData) return false;

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

  void _handleConnectionError(
      {required BuildContext context, bool isInitialConnection = false}) {
    selectedDevice = null;
    _setConnectionState(BleConnectionState.disconnected);
    _connectionManager.cancelReconnection();

    if (isInitialConnection) {
      _userInitiatedDisconnect = false;
      connectionErrorNotifier.value = false;
    } else {
      connectionErrorNotifier.value = true;
      _clearCharacteristicStreams();
      _sensorDataLiveness.resetTracking();
    }

    notifyListeners();
  }

  void resetConnectionError() {
    connectionErrorNotifier.value = false;
    _connectionManager.cancelReconnection();

    if (selectedDeviceNotifier.value == null) {
      _setConnectionState(BleConnectionState.disconnected);
    }

    notifyListeners();
  }

  void _setConnectionState(BleConnectionState state) {
    connectionStateNotifier.value = state;
  }

  void _onSensorDataValidityChanged() {
    final hasValidData = _sensorDataLiveness.hasValidData;

    if (selectedDevice == null || _userInitiatedDisconnect) return;

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
    if (data.isEmpty) return false;
    if (data.every((byte) => byte == 0)) return false;
    if (data.length < 4) return false;
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
        controller.add(_parseData(rawData));
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
    _connectionManager.dispose();
    _sensorDataLiveness.hasValidDataNotifier
        .removeListener(_onSensorDataValidityChanged);
    _sensorDataLiveness.dispose();
    _devicesListController.close();
    _clearCharacteristicStreams();
    selectedDeviceNotifier.dispose();
    connectionStateNotifier.dispose();
    isBluetoothEnabledNotifier.dispose();
    isScanningNotifier.dispose();
    connectionErrorNotifier.dispose();
    characteristicStreamsVersion.dispose();
    availableCharacteristics.dispose();
    super.dispose();
  }

  Future<void> requestEnableBluetooth() async {
    return FlutterBluePlus.turnOn();
  }
}
