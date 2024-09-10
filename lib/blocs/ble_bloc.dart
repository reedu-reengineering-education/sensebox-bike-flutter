import 'dart:async';
import 'dart:typed_data';
import 'package:sensebox_bike/secrets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:provider/provider.dart'; // Assuming you're using Provider for state management
import 'package:sensebox_bike/blocs/recording_bloc.dart'; // Import the RecordingBloc

class BleBloc with ChangeNotifier {
  final List<BluetoothDevice> devicesList = [];
  final StreamController<List<BluetoothDevice>> _devicesListController =
      StreamController.broadcast();
  Stream<List<BluetoothDevice>> get devicesListStream =>
      _devicesListController.stream;

  BluetoothDevice? selectedDevice;
  bool _isConnected = false; // Track the connection status
  bool _userInitiatedDisconnect =
      false; // Track if disconnect was user-initiated
  final Map<String, StreamController<List<double>>> _characteristicStreams = {};

  // ValueNotifier to notify about the selected device's connection state
  final ValueNotifier<BluetoothDevice?> selectedDeviceNotifier =
      ValueNotifier(null);

  bool get isConnected => _isConnected; // Expose the connection status

  BleBloc() {
    startScanning();
    FlutterBluePlus.setLogLevel(LogLevel.none);
  }

  void startScanning() {
    disconnectDevice(); // Disconnect if there's a current connection
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
    _userInitiatedDisconnect = true; // Mark this as a user-initiated disconnect
    selectedDevice?.disconnect();
    _isConnected = false; // Mark the device as disconnected
    selectedDevice = null;
    selectedDeviceNotifier.value = null; // Notify disconnection
    notifyListeners();
  }

  Future<void> connectToDevice(
      BluetoothDevice device, BuildContext context) async {
    try {
      await FlutterBluePlus.stopScan();
      await device.connect();
      _isConnected = true; // Mark as connected
      _userInitiatedDisconnect =
          false; // Reset this since it's a new connection

      await _discoverAndListenToCharacteristics(device);

      selectedDevice = device;
      selectedDeviceNotifier.value = selectedDevice; // Notify connection
      notifyListeners();

      // Handle reconnection if the connection is lost
      _handleDeviceReconnection(device, context);
    } catch (e) {
      _isConnected = false; // Ensure the flag is set correctly on failure
      // Handle connection error
    }
  }

  Future<void> _discoverAndListenToCharacteristics(
      BluetoothDevice device) async {
    await device.discoverServices().then((services) async {
      // find senseBox service
      var senseBoxService =
          services.firstWhere((service) => service.uuid == senseBoxServiceUUID);

      for (var characteristic in senseBoxService.characteristics) {
        await _listenToCharacteristic(characteristic);
      }
    });
  }

  void _handleDeviceReconnection(BluetoothDevice device, BuildContext context) {
    device.connectionState.listen((state) async {
      if (state == BluetoothConnectionState.disconnected &&
          !_userInitiatedDisconnect) {
        _isConnected = false; // Mark as disconnected

        // Attempt to reconnect the device (up to 5 tries)
        for (int i = 0; i < 5; i++) {
          try {
            await device.connect(timeout: const Duration(seconds: 5));
            _isConnected = true; // Mark as connected if successful
            _discoverAndListenToCharacteristics(device);
            break; // Stop retrying if reconnection is successful
          } catch (e) {
            // Retry logic continues if reconnection fails
          }
        }

        if (!_isConnected) {
          selectedDeviceNotifier.value = null; // Notify disconnection
          notifyListeners();

          // Notify RecordingBloc to stop recording if Bluetooth disconnects
          RecordingBloc recordingBloc =
              Provider.of<RecordingBloc>(context, listen: false);
          if (recordingBloc.isRecording) {
            recordingBloc.stopRecording();
          }
        }
      }
    });
  }

  Future<void> _listenToCharacteristic(
      BluetoothCharacteristic characteristic) async {
    final controller = StreamController<List<double>>();
    _characteristicStreams[characteristic.uuid.toString()] = controller;

    await characteristic.setNotifyValue(true);
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
