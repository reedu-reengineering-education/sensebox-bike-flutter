import 'dart:async';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:sensebox_bike/services/ble/ble_client.dart';
import 'package:sensebox_bike/services/ble/sensebox_constants.dart';
import 'package:sensebox_bike/services/ble/sensebox_device.dart';

class FlutterBluePlusBleClient implements BleClient {
  final Map<String, BluetoothDevice> _devices = {};
  StreamSubscription<List<ScanResult>>? _scanResultsSubscription;
  StreamSubscription<bool>? _isScanningSubscription;
  final StreamController<List<SenseBoxDevice>> _scanResultsController =
      StreamController.broadcast();

  FlutterBluePlusBleClient() {
    FlutterBluePlus.setLogLevel(LogLevel.error);
  }

  @override
  Stream<bool> get isAdapterEnabledStream =>
      FlutterBluePlus.adapterState.map(
        (state) => state == BluetoothAdapterState.on,
      );

  @override
  Future<bool> isAdapterEnabled() async {
    final state = await FlutterBluePlus.adapterState.first;
    return state == BluetoothAdapterState.on;
  }

  @override
  Future<void> requestEnableBluetooth() => FlutterBluePlus.turnOn();

  @override
  Stream<bool> get isScanningStream => FlutterBluePlus.isScanning;

  @override
  Future<void> startScan({
    Duration timeout = deviceConnectTimeout,
    List<String>? withNames,
  }) async {
    await _scanResultsSubscription?.cancel();
    await _isScanningSubscription?.cancel();

    if (withNames != null && withNames.isNotEmpty) {
      await FlutterBluePlus.startScan(
        timeout: timeout,
        withNames: withNames,
      );
    } else {
      await FlutterBluePlus.startScan(timeout: timeout);
    }

    _scanResultsSubscription = FlutterBluePlus.scanResults.listen((results) {
      final devices = <SenseBoxDevice>[];
      for (final result in results) {
        final device = result.device;
        _devices[device.remoteId.str] = device;
        if (device.platformName.startsWith('senseBox')) {
          devices.add(_toSenseBoxDevice(device));
        }
      }
      _scanResultsController.add(devices);
    });
  }

  @override
  Future<void> stopScan() async {
    await FlutterBluePlus.stopScan();
  }

  @override
  Stream<List<SenseBoxDevice>> get scanResultsStream =>
      _scanResultsController.stream;

  @override
  Future<void> connect(String deviceId, {Duration? timeout}) async {
    final device = _requireDevice(deviceId);
    await device.connect(timeout: timeout ?? deviceConnectTimeout);
  }

  @override
  Future<void> disconnect(String deviceId) async {
    final device = _devices[deviceId];
    if (device == null) return;
    await device.disconnect();
  }

  @override
  Stream<BleConnectionState> connectionStateStream(String deviceId) {
    final device = _requireDevice(deviceId);
    return device.connectionState.map(_mapConnectionState);
  }

  @override
  Future<List<BleCharacteristicRef>> discoverCharacteristics(
    String deviceId,
    String serviceUuid,
  ) async {
    final device = _requireDevice(deviceId);
    final services = await device.discoverServices();
    final service = services.firstWhere(
      (s) => s.uuid.str.toUpperCase() == serviceUuid.toUpperCase(),
      orElse: () => throw Exception('Service not found: $serviceUuid'),
    );

    return service.characteristics
        .map(
          (characteristic) => BleCharacteristicRef(
            serviceUuid: serviceUuid,
            characteristicUuid: characteristic.uuid.str,
          ),
        )
        .toList();
  }

  @override
  Stream<List<int>> subscribeToCharacteristic(
    String deviceId,
    BleCharacteristicRef characteristic,
  ) async* {
    final device = _requireDevice(deviceId);
    final services = await device.discoverServices();
    final bleCharacteristic = _findCharacteristic(
      services,
      characteristic.serviceUuid,
      characteristic.characteristicUuid,
    );

    await bleCharacteristic.setNotifyValue(true);
    yield* bleCharacteristic.onValueReceived;
  }

  @override
  Future<void> unsubscribeFromCharacteristic(
    String deviceId,
    BleCharacteristicRef characteristic,
  ) async {
    final device = _devices[deviceId];
    if (device == null) return;

    final services = await device.discoverServices();
    final bleCharacteristic = _findCharacteristic(
      services,
      characteristic.serviceUuid,
      characteristic.characteristicUuid,
    );
    await bleCharacteristic.setNotifyValue(false);
  }

  BluetoothDevice _requireDevice(String deviceId) {
    final device = _devices[deviceId];
    if (device == null) {
      throw Exception('Device not found: $deviceId');
    }
    return device;
  }

  BluetoothCharacteristic _findCharacteristic(
    List<BluetoothService> services,
    String serviceUuid,
    String characteristicUuid,
  ) {
    final service = services.firstWhere(
      (s) => s.uuid.str.toUpperCase() == serviceUuid.toUpperCase(),
      orElse: () => throw Exception('Service not found: $serviceUuid'),
    );

    return service.characteristics.firstWhere(
      (c) => c.uuid.str.toUpperCase() == characteristicUuid.toUpperCase(),
      orElse: () =>
          throw Exception('Characteristic not found: $characteristicUuid'),
    );
  }

  SenseBoxDevice _toSenseBoxDevice(BluetoothDevice device) {
    return SenseBoxDevice(
      id: device.remoteId.str,
      displayName:
          device.platformName.isNotEmpty ? device.platformName : '(Unknown)',
      advName: device.advName.isNotEmpty ? device.advName : null,
      isConnected: device.isConnected,
    );
  }

  BleConnectionState _mapConnectionState(BluetoothConnectionState state) {
    switch (state) {
      case BluetoothConnectionState.disconnected:
        return BleConnectionState.disconnected;
      case BluetoothConnectionState.connecting:
        return BleConnectionState.connecting;
      case BluetoothConnectionState.connected:
        return BleConnectionState.connected;
      case BluetoothConnectionState.disconnecting:
        return BleConnectionState.disconnecting;
    }
  }

  void registerDevice(BluetoothDevice device) {
    _devices[device.remoteId.str] = device;
  }

  @override
  void dispose() {
    _scanResultsSubscription?.cancel();
    _isScanningSubscription?.cancel();
    _scanResultsController.close();
  }
}
