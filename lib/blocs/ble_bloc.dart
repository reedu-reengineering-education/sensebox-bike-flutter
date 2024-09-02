import 'dart:async';
import 'package:flutter/material.dart';
***REMOVED***
import 'package:ble_app/sensors/sensor.dart';

class BleBloc with ChangeNotifier {
  final List<BluetoothDevice> devicesList = [];
  final StreamController<List<BluetoothDevice>> _devicesListController = StreamController.broadcast();

  Stream<List<BluetoothDevice>> get devicesListStream => _devicesListController.stream;

  BluetoothDevice? selectedDevice;
  final Map<String, StreamController<List<double>>> _characteristicStreams = {};

  BleBloc() {
    startScanning();
  }

  void startScanning() {
    disconnectDevice();
    FlutterBluePlus.startScan(timeout: Duration(seconds: 4));

    FlutterBluePlus.scanResults.listen((results) {
      devicesList.clear();
      for (ScanResult result in results) {
        if (result.device.name.startsWith("senseBox")) {
          devicesList.add(result.device);
        }
      }
      _devicesListController.add(devicesList);
      notifyListeners();
    });
  }

  void disconnectDevice() {
    selectedDevice?.disconnect();
    selectedDevice = null;
  }

  Future<void> connectToDevice(BluetoothDevice device) async {
    try {
      await device.connect();
      selectedDevice = device;
      await device.discoverServices().then((services) {
        for (var service in services) {
          for (var characteristic in service.characteristics) {
            _listenToCharacteristic(characteristic);
          }
        }
      });
    } catch (e) {
      // Handle connection error
    }
  }

  void _listenToCharacteristic(BluetoothCharacteristic characteristic) {
    final controller = StreamController<List<double>>();
    _characteristicStreams[characteristic.uuid.toString()] = controller;

    characteristic.setNotifyValue(true);
    characteristic.value.listen((value) {
      final doubleValues = value.map((e) => e.toDouble()).toList();
      controller.add(doubleValues);
    });
  }

  StreamController<List<double>> getCharacteristicStream(String characteristicUuid) {
    return _characteristicStreams[characteristicUuid]!;
  }

  @override
  void dispose() {
    _devicesListController.close();
    for (var controller in _characteristicStreams.values) {
      controller.close();
    }
    super.dispose();
  }
}
