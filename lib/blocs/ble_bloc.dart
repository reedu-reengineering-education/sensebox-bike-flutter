import 'dart:async';
import 'dart:typed_data';
import 'package:sensebox_bike/secrets.dart';
import 'package:flutter/material.dart';
***REMOVED***

class BleBloc with ChangeNotifier {
  final List<BluetoothDevice> devicesList = [];
  final StreamController<List<BluetoothDevice>> _devicesListController =
      StreamController.broadcast();
  Stream<List<BluetoothDevice>> get devicesListStream =>
      _devicesListController.stream;

  BluetoothDevice? selectedDevice;
  final Map<String, StreamController<List<double>>> _characteristicStreams = {};

  // ValueNotifier to notify about the selected device's connection state
  final ValueNotifier<BluetoothDevice?> selectedDeviceNotifier =
      ValueNotifier(null);

  BleBloc() {
    startScanning();
    FlutterBluePlus.setLogLevel(LogLevel.none);
  }

  void startScanning() {
    disconnectDevice();
    FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));

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
  }

  void disconnectDevice() {
    selectedDevice?.disconnect();
    selectedDevice = null;
    selectedDeviceNotifier.value = null; // Notify disconnection
  }

  Future<void> connectToDevice(BluetoothDevice device) async {
    try {
      await FlutterBluePlus.stopScan();
      await device.connect();

      await device.discoverServices().then((services) {
        // find senseBox service
        var senseBoxService = services
            .firstWhere((service) => service.uuid == senseBoxServiceUUID);

        for (var characteristic in senseBoxService.characteristics) {
          _listenToCharacteristic(characteristic);
        }
      });
      selectedDevice = device;
      selectedDeviceNotifier.value = selectedDevice; // Notify connection
      notifyListeners();

      // implement reconnecting to the device if the connection is lost
      // try 5 times to reconnect to the device
      // ignore when the user disconnects the device
      device.connectionState.listen((state) async {
        if (state == BluetoothConnectionState.disconnected &&
            selectedDevice != null) {
          for (int i = 0; i < 5; i++) {
            await device.connect(timeout: const Duration(seconds: 5));
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
    characteristic.onValueReceived.listen((value) {
      List<double> parsedData = _parseData(Uint8List.fromList(value));
      controller.add(parsedData);
    });
  }

  StreamController<List<double>> getCharacteristicStream(
      String characteristicUuid) {
    if (!_characteristicStreams.containsKey(characteristicUuid)) {
      throw Exception('Characteristic stream not found');
    }
    return _characteristicStreams[characteristicUuid]!;
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
    _devicesListController.close();
    for (var controller in _characteristicStreams.values) {
      controller.close();
    }
    selectedDeviceNotifier.dispose(); // Dispose of the notifier
    super.dispose();
  }
}
