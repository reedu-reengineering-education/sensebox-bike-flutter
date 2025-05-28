import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:sensebox_bike/blocs/settings_bloc.dart';
import 'package:sensebox_bike/secrets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:provider/provider.dart'; // Assuming you're using Provider for state management
import 'package:sensebox_bike/blocs/recording_bloc.dart';
import 'package:sensebox_bike/services/custom_exceptions.dart';
import 'package:vibration/vibration.dart'; // Import the RecordingBloc

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

  final List<BluetoothDevice> devicesList = [];
  final StreamController<List<BluetoothDevice>> _devicesListController =
      StreamController.broadcast();
  Stream<List<BluetoothDevice>> get devicesListStream =>
      _devicesListController.stream;

  BluetoothDevice? selectedDevice;
  bool _isConnected = false;
  bool _userInitiatedDisconnect = false;

  final Map<String, StreamController<List<double>>> _characteristicStreams = {};
  final Map<String, StreamController<List<String>>>
      _characteristicStringStreams = {};

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
    isBluetoothEnabledNotifier.value = isEnabled;
    notifyListeners(); 
  }

  Future<void> startScanning() async {
    disconnectDevice(); 
    isScanningNotifier.value = true;

    try {
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));
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

  void disconnectDevice() {
    _userInitiatedDisconnect = true; 
    selectedDevice?.disconnect();
    _isConnected = false; 
    selectedDevice = null;
    selectedDeviceNotifier.value = null; 
    availableCharacteristics.value = [];
    notifyListeners();
  }

  Future<void> connectToId(String id, BuildContext context) async {
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
      isConnectingNotifier.value = true;
      notifyListeners();

      await stopScanning();
      await device.connect();
      _isConnected = true;
      _userInitiatedDisconnect = false; 

      await _discoverAndListenToCharacteristics(device);

      selectedDevice = device;
      selectedDeviceNotifier.value = selectedDevice;
      notifyListeners();

      _handleDeviceReconnection(device, context);

    } catch (e) {
      debugPrint('Error connecting to device: $e');
    } finally {
      isConnectingNotifier.value = false; 
    }
    notifyListeners();
  }

  Future<void> _discoverAndListenToCharacteristics(
      BluetoothDevice device) async {
    // Clear previous characteristic streams before listening again
    for (var controller in _characteristicStreams.values) {
      await controller.close();
    }
    _characteristicStreams.clear();
    for (var controller in _characteristicStringStreams.values) {
      await controller.close();
    }
    _characteristicStringStreams.clear();

    int maxAttempts = 5;
    int attempts = 0;
    while (attempts < maxAttempts) {
      try {
        // Add a delay to avoid stale GATT cache after reconnect
        await Future.delayed(const Duration(milliseconds: 500));
        List<BluetoothService> services = await device.discoverServices();

        var senseBoxService = services.firstWhere(
            (service) => service.uuid == senseBoxServiceUUID,
            orElse: () => throw Exception('Service not found'));

        availableCharacteristics.value = senseBoxService.characteristics;

        notifyListeners();

        for (var characteristic in senseBoxService.characteristics) {
          await _listenToCharacteristic(characteristic);
        }

        // var deviceInfoService = services.firstWhere(
        //     (service) => service.uuid == deviceInfoServiceUUID,
        //     orElse: () => throw Exception('Device Info Service not found'));

        // for (var characteristic in deviceInfoService.characteristics) {
        //   await _listenToDeviceInfoCharacteristic(characteristic);
        // }

        break; // Exit the loop if successful
      } catch (e) {
        attempts++;
        if (attempts >= maxAttempts) {
          // Handle the error after max attempts
          print('Failed to discover services after $attempts attempts: $e');
          break;
        }
        print('Error discovering services, attempt $attempts: $e');
        await Future.delayed(const Duration(seconds: 5));
      }
    }
  }

  void _handleDeviceReconnection(BluetoothDevice device, BuildContext context) {
    bool hasVibrated = false;
    int reconnectionAttempts = 0;
    const int maxReconnectionAttempts = 5;

    device.connectionState.listen((state) async {
      if (state == BluetoothConnectionState.disconnected &&
          !_userInitiatedDisconnect) {
        _isConnected = false;
        isReconnectingNotifier.value = true;
        if (!hasVibrated && settingsBloc.vibrateOnDisconnect) {
          Vibration.vibrate();
          hasVibrated = true;
        }
        while (
            reconnectionAttempts < maxReconnectionAttempts && !_isConnected) {
          try {
            reconnectionAttempts++;
            print('Reconnection attempt $reconnectionAttempts');
            try {
              await device.disconnect();
              await Future.delayed(const Duration(seconds: 2));
            } catch (_) {}
            await device.connect(timeout: const Duration(seconds: 10));
            await Future.delayed(const Duration(seconds: 2));
            if (await device.connectionState.first ==
                BluetoothConnectionState.connected) {
              _isConnected = true;
              hasVibrated = false;
              reconnectionAttempts = 0;
              await _discoverAndListenToCharacteristics(device);
              break;
            }
          } catch (e) {
            print('Reconnection attempt $reconnectionAttempts failed: $e');
          }
          await Future.delayed(const Duration(seconds: 5));
        }
        isReconnectingNotifier.value = false;
        if (!_isConnected && reconnectionAttempts >= maxReconnectionAttempts) {
          debugPrint(
              'Failed to reconnect after $maxReconnectionAttempts attempts');
          selectedDeviceNotifier.value = null;
          notifyListeners();
          if (!context.mounted) return;
          try {
            RecordingBloc? recordingBloc =
                Provider.of<RecordingBloc>(context, listen: false);
            if (recordingBloc.isRecording) {
              recordingBloc.stopRecording();
            }
          } catch (e) {
            debugPrint('RecordingBloc not found in the widget tree: $e');
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

  Future<void> _listenToDeviceInfoCharacteristic(
      BluetoothCharacteristic characteristic) async {
    final controller = StreamController<List<String>>();
    _characteristicStringStreams[characteristic.uuid.toString()] = controller;

    await characteristic.setNotifyValue(true);
    characteristic.onValueReceived.listen((value) {
      print('Received value: $value');
      print('Decoded value: ${utf8.decode(value)}');
      List<String> parsedData = [utf8.decode(value)];
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
    for (var controller in _characteristicStringStreams.values) {
      controller.close();
    }
    selectedDeviceNotifier.dispose();
    isBluetoothEnabledNotifier.dispose();
    isScanningNotifier.dispose();
    isConnectingNotifier.dispose();
    isReconnectingNotifier.dispose();
    availableCharacteristics.dispose();
    super.dispose();
  }
}
