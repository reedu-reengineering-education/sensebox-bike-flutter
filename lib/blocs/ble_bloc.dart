import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:sensebox_bike/blocs/settings_bloc.dart';
import 'package:sensebox_bike/services/ble/ble_client.dart';
import 'package:sensebox_bike/services/ble/connection_events.dart';
import 'package:sensebox_bike/services/ble/reactive_ble_client.dart';
import 'package:sensebox_bike/services/ble/sensebox_connection_manager.dart';
import 'package:sensebox_bike/services/ble/sensebox_data_service.dart';
import 'package:sensebox_bike/services/ble/sensebox_device.dart';
import 'package:sensebox_bike/services/custom_exceptions.dart';
import 'package:vibration/vibration.dart';

class BleBloc with ChangeNotifier {
  final SettingsBloc settingsBloc;
  final BleClient _bleClient;
  late final SenseBoxConnectionManager _connectionManager;
  late final SenseBoxDataService _dataService;

  final ValueNotifier<bool> isBluetoothEnabledNotifier = ValueNotifier(false);
  final ValueNotifier<bool> isScanningNotifier = ValueNotifier(false);
  final ValueNotifier<bool> isConnectingNotifier = ValueNotifier(false);
  final ValueNotifier<bool> isReconnectingNotifier = ValueNotifier(false);
  final ValueNotifier<SenseBoxDevice?> selectedDeviceNotifier =
      ValueNotifier(null);
  final ValueNotifier<bool> connectionErrorNotifier = ValueNotifier(false);

  StreamSubscription<bool>? _adapterStateSubscription;
  StreamSubscription<bool>? _scanningStateSubscription;

  SenseBoxDevice? get selectedDevice => _connectionManager.selectedDevice;

  set selectedDevice(SenseBoxDevice? device) {
    _connectionManager.selectedDevice = device;
    selectedDeviceNotifier.value = device;
  }

  bool get isConnected => _connectionManager.isConnected;

  ValueNotifier<List<BleCharacteristicRef>> get availableCharacteristics =>
      _dataService.availableCharacteristics;

  ValueNotifier<int> get characteristicStreamsVersion =>
      _dataService.characteristicStreamsVersion;

  Stream<List<SenseBoxDevice>> get devicesListStream =>
      _connectionManager.devicesListStream;

  BleBloc(
    this.settingsBloc, {
    BleClient? bleClient,
    SenseBoxConnectionManager? connectionManager,
    SenseBoxDataService? dataService,
  }) : _bleClient = bleClient ?? ReactiveBleClient() {
    _dataService = dataService ?? SenseBoxDataService(_bleClient);
    _connectionManager = connectionManager ??
        SenseBoxConnectionManager(
          bleClient: _bleClient,
          dataService: _dataService,
          onConnectionEvent: _handleConnectionEvent,
          onDisconnectVibrate: _vibrateOnDisconnect,
        );

    _adapterStateSubscription =
        _bleClient.isAdapterEnabledStream.listen(updateBluetoothStatus);
    _initializeBluetoothStatus();
    _scanningStateSubscription =
        _bleClient.isScanningStream.listen((scanning) {
      isScanningNotifier.value = scanning;
      _connectionManager.isScanning = scanning;
    });
  }

  Future<void> _initializeBluetoothStatus() async {
    updateBluetoothStatus(await _bleClient.isAdapterEnabled());
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
      await _connectionManager.startScanning();
    } on ScanPermissionDenied {
      isScanningNotifier.value = false;
      rethrow;
    }
    notifyListeners();
  }

  Future<void> stopScanning() async {
    await _connectionManager.stopScanning();
    isScanningNotifier.value = false;
  }

  Future<void> scanForNewDevices() async {
    try {
      await _connectionManager.scanForNewDevices();
      selectedDeviceNotifier.value = null;
    } on ScanPermissionDenied {
      isScanningNotifier.value = false;
      rethrow;
    }
    notifyListeners();
  }

  void disconnectDevice() {
    _connectionManager.disconnectDevice();
    selectedDeviceNotifier.value = null;
    resetConnectionError();
    notifyListeners();
  }

  Future<void> connectToId(String id) async {
    resetConnectionError();
    await _connectionManager.connectToId(id);
    _syncConnectionState();
  }

  Future<void> connectToDevice(SenseBoxDevice device) async {
    resetConnectionError();
    isConnectingNotifier.value = true;
    notifyListeners();

    await _connectionManager.connectToDevice(device);
    _syncConnectionState();

    isConnectingNotifier.value = false;
    notifyListeners();
  }

  void resetConnectionError() {
    connectionErrorNotifier.value = false;
    _connectionManager.resetReconnectionState();
    notifyListeners();
  }

  Stream<List<double>> getCharacteristicStream(String characteristicUuid) {
    return _dataService.getCharacteristicStream(characteristicUuid);
  }

  Future<void> requestEnableBluetooth() {
    return _bleClient.requestEnableBluetooth();
  }

  void _syncConnectionState() {
    selectedDeviceNotifier.value = _connectionManager.selectedDevice;
    isReconnectingNotifier.value = _connectionManager.isReconnecting;
    notifyListeners();
  }

  void _handleConnectionEvent(ConnectionEvent event) {
    switch (event.type) {
      case ConnectionEventType.deviceConnected:
      case ConnectionEventType.reconnectionSucceeded:
        selectedDeviceNotifier.value = event.device;
        isReconnectingNotifier.value = false;
        connectionErrorNotifier.value = false;
        break;
      case ConnectionEventType.initialConnectionFailed:
        selectedDeviceNotifier.value = null;
        connectionErrorNotifier.value = false;
        _connectionManager.isConnected = false;
        break;
      case ConnectionEventType.reconnectionStarted:
        isReconnectingNotifier.value = true;
        break;
      case ConnectionEventType.reconnectionExhausted:
        selectedDeviceNotifier.value = null;
        connectionErrorNotifier.value = true;
        break;
      case ConnectionEventType.deviceDisconnected:
        break;
    }
    notifyListeners();
  }

  void _vibrateOnDisconnect() {
    if (settingsBloc.vibrateOnDisconnect) {
      Vibration.vibrate();
    }
  }

  @override
  void dispose() {
    _adapterStateSubscription?.cancel();
    _scanningStateSubscription?.cancel();
    _connectionManager.dispose();
    _dataService.dispose();
    _bleClient.dispose();
    selectedDeviceNotifier.dispose();
    isBluetoothEnabledNotifier.dispose();
    isScanningNotifier.dispose();
    isConnectingNotifier.dispose();
    isReconnectingNotifier.dispose();
    connectionErrorNotifier.dispose();
    super.dispose();
  }
}
