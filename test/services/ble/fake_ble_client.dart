import 'dart:async';

import 'package:sensebox_bike/services/ble/ble_client.dart';
import 'package:sensebox_bike/services/ble/sensebox_constants.dart';
import 'package:sensebox_bike/services/ble/sensebox_device.dart';

class FakeBleClient implements BleClient {
  bool adapterEnabled = true;
  bool isScanning = false;
  bool shouldThrowOnScan = false;
  bool shouldFailConnect = false;
  bool shouldFailDiscovery = false;
  bool shouldFailProbe = false;

  final Map<String, BleConnectionState> connectionStates = {};
  final Map<String, StreamController<BleConnectionState>>
      connectionStateControllers = {};
  final Map<String, List<BleCharacteristicRef>> characteristicsByDevice = {};
  final Map<String, StreamController<List<int>>> notificationControllers = {};
  final List<SenseBoxDevice> scanResults = [];

  final StreamController<bool> _adapterController =
      StreamController.broadcast();
  final StreamController<bool> _scanningController =
      StreamController.broadcast();
  final StreamController<List<SenseBoxDevice>> _scanResultsController =
      StreamController.broadcast();

  @override
  Stream<bool> get isAdapterEnabledStream => _adapterController.stream;

  @override
  Future<bool> isAdapterEnabled() async => adapterEnabled;

  @override
  Future<void> requestEnableBluetooth() async {
    adapterEnabled = true;
    _adapterController.add(true);
  }

  @override
  Stream<bool> get isScanningStream => _scanningController.stream;

  @override
  Future<void> startScan({
    Duration timeout = deviceConnectTimeout,
    List<String>? withNames,
  }) async {
    if (shouldThrowOnScan) {
      throw Exception('scan denied');
    }
    isScanning = true;
    _scanningController.add(true);
    _scanResultsController.add(List.from(scanResults));
  }

  @override
  Future<void> stopScan() async {
    isScanning = false;
    _scanningController.add(false);
  }

  @override
  Stream<List<SenseBoxDevice>> get scanResultsStream =>
      _scanResultsController.stream;

  @override
  Future<void> connect(String deviceId, {Duration? timeout}) async {
    if (shouldFailConnect) {
      throw Exception('connect failed');
    }
    connectionStates[deviceId] = BleConnectionState.connected;
    _connectionController(deviceId).add(BleConnectionState.connected);
  }

  @override
  Future<void> disconnect(String deviceId) async {
    connectionStates[deviceId] = BleConnectionState.disconnected;
    _connectionController(deviceId).add(BleConnectionState.disconnected);
  }

  @override
  Stream<BleConnectionState> connectionStateStream(String deviceId) {
    return _connectionController(deviceId).stream;
  }

  @override
  Future<List<BleCharacteristicRef>> discoverCharacteristics(
    String deviceId,
    String serviceUuid,
  ) async {
    if (shouldFailDiscovery) {
      throw Exception('discovery failed');
    }
    return characteristicsByDevice[deviceId] ?? [];
  }

  @override
  Stream<List<int>> subscribeToCharacteristic(
    String deviceId,
    BleCharacteristicRef characteristic,
  ) {
    if (shouldFailProbe) {
      return const Stream.empty();
    }

    final key = _notificationKey(deviceId, characteristic);
    final controller = notificationControllers.putIfAbsent(
      key,
      StreamController<List<int>>.broadcast,
    );
    return controller.stream;
  }

  @override
  Future<void> unsubscribeFromCharacteristic(
    String deviceId,
    BleCharacteristicRef characteristic,
  ) async {}

  void emitNotification(
    String deviceId,
    BleCharacteristicRef characteristic,
    List<int> data,
  ) {
    final key = _notificationKey(deviceId, characteristic);
    notificationControllers[key]?.add(data);
  }

  StreamController<BleConnectionState> _connectionController(String deviceId) {
    return connectionStateControllers.putIfAbsent(
      deviceId,
      () => StreamController<BleConnectionState>.broadcast(),
    );
  }

  String _notificationKey(String deviceId, BleCharacteristicRef characteristic) {
    return '$deviceId:${characteristic.characteristicUuid}';
  }

  @override
  void dispose() {
    _adapterController.close();
    _scanningController.close();
    _scanResultsController.close();
    for (final controller in connectionStateControllers.values) {
      controller.close();
    }
    for (final controller in notificationControllers.values) {
      controller.close();
    }
  }
}
