import 'dart:async';

import 'dart:typed_data';
import 'package:sensebox_bike/blocs/settings_bloc.dart';
import 'package:sensebox_bike/secrets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:provider/provider.dart';
import 'package:sensebox_bike/blocs/recording_bloc.dart';
import 'package:sensebox_bike/services/custom_exceptions.dart';
import 'package:vibration/vibration.dart';

const reconnectionDelay = Duration(seconds: 5);
// Minimum number of services to consider a valid connection
const minimumServices = 7;
const maximumRetriesToDiscoverServices =
    5; // Maximum retries to discover services

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
  final ValueNotifier<int> characteristicStreamsVersion = ValueNotifier(0);
  final ValueNotifier<bool> connectionErrorNotifier = ValueNotifier(false);

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

      await _discoverAndListenToCharacteristics(device, context: context);

      selectedDevice = device;
      selectedDeviceNotifier.value = selectedDevice;
      notifyListeners();

      _handleDeviceReconnection(device, context);

    } catch (e) {
      throw Exception('Error connecting to device: $e');
    } finally {
      isConnectingNotifier.value = false; 
    }
    notifyListeners();
  }

  Future<void> _discoverAndListenToCharacteristics(
    BluetoothDevice device, {
    BuildContext? context,
    int globalRetry = 0,
    int maxGlobalRetries = 5,
  }) async {
    _clearCharacteristicStreams();

    final services = await _retryServiceDiscovery(device);
    if (services.isNotEmpty) {
      var senseBoxService = services.firstWhere(
        (service) => service.uuid == senseBoxServiceUUID,
        orElse: () => throw Exception('Service not found'),
      );
      for (var characteristic in senseBoxService.characteristics) {
        await _listenToCharacteristic(characteristic);
      }
      availableCharacteristics.value = senseBoxService.characteristics;
      characteristicStreamsVersion.value++;
      notifyListeners();
    } else if (globalRetry < maxGlobalRetries && context != null) {
      print(
          'Still not enough services after retries. Forcing disconnect and reconnect (retry $globalRetry)...');
      try {
        await _forceReconnect(device);
        await _discoverAndListenToCharacteristics(
          device,
          context: context,
          globalRetry: globalRetry + 1,
          maxGlobalRetries: maxGlobalRetries,
        );
      } catch (e) {
        throw Exception('Reconnect failed: $e');
      }
    }
  }

Future<void> _forceReconnect(BluetoothDevice device) async {
    try {
      await device.disconnect();
      await Future.delayed(reconnectionDelay);
      await device.connect(timeout: const Duration(seconds: 10));
      await Future.delayed(reconnectionDelay);
    } catch (_) {}
  }

  void _clearCharacteristicStreams() {
    for (var controller in _characteristicStreams.values) {
      controller.close();
    }
    _characteristicStreams.clear();
    for (var controller in _characteristicStringStreams.values) {
      controller.close();
    }
    _characteristicStringStreams.clear();
  }

  Future<List<BluetoothService>> _retryServiceDiscovery(
    BluetoothDevice device, {
    int maxAttempts = 3,
    Duration delay = reconnectionDelay,
    int minimumServices = minimumServices,
  }) async {
    int attempts = 0;
    while (attempts < maxAttempts) {
      try {
        await Future.delayed(const Duration(milliseconds: 500));
        final services = await device.discoverServices();
        if (services.length >= minimumServices) {
          return services;
        }
        attempts++;
        await Future.delayed(delay);
      } catch (e) {
        attempts++;
        await Future.delayed(delay);
      }
    }
    return [];
  }

  void _handleDeviceReconnection(BluetoothDevice device, BuildContext context) {
    bool hasVibrated = false;
    int reconnectionAttempts = 0;
    const int maxReconnectionAttempts = 5;
    bool isFirstReconnection = true;

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
            debugPrint('Reconnection attempt $reconnectionAttempts');

            await device.disconnect();
            await Future.delayed(reconnectionDelay);
            await device.connect(timeout: const Duration(seconds: 10));
            await Future.delayed(reconnectionDelay);
            if (await device.connectionState.first ==
                BluetoothConnectionState.connected) {
              // After the first reconnection, wait 10 seconds before trying again
              // to allow the device to stabilize
              if (isFirstReconnection) {
                isFirstReconnection = false;
                await Future.delayed(const Duration(seconds: 10));
                continue;
              }
              _isConnected = true;
              hasVibrated = false;
              reconnectionAttempts = 0;
              await _discoverAndListenToCharacteristics(device,
                  context: context);
              break;
            }
          } catch (e) {
            debugPrint('Reconnection attempt $reconnectionAttempts failed: $e');
          }
          await Future.delayed(reconnectionDelay);
        }

        isReconnectingNotifier.value = false;
      
        if (!_isConnected && reconnectionAttempts >= maxReconnectionAttempts) {
          selectedDeviceNotifier.value = null;
          connectionErrorNotifier.value = true;
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
    final uuid = characteristic.uuid.toString();

    // If a controller exists for this characteristic, close and remove it first
    if (_characteristicStreams.containsKey(uuid)) {
      await _characteristicStreams[uuid]?.close();
      _characteristicStreams.remove(uuid);
    }

    final controller = StreamController<List<double>>.broadcast();
    _characteristicStreams[uuid] = controller;

    await characteristic.setNotifyValue(true);
    characteristic.onValueReceived.listen((value) {
      if (!controller.isClosed) {
        List<double> parsedData = _parseData(Uint8List.fromList(value));
        controller.add(parsedData);
      }
    });
  }

  // Future<void> _listenToDeviceInfoCharacteristic(
  //     BluetoothCharacteristic characteristic) async {
  //   final controller = StreamController<List<String>>();
  //   _characteristicStringStreams[characteristic.uuid.toString()] = controller;

  //   await characteristic.setNotifyValue(true);
  //   characteristic.onValueReceived.listen((value) {
  //     print('Received value: $value');
  //     print('Decoded value: ${utf8.decode(value)}');
  //     List<String> parsedData = [utf8.decode(value)];
  //     controller.add(parsedData);
  //   });
  // }

  Stream<List<double>> getCharacteristicStream(String characteristicUuid) {
    if (!_characteristicStreams.containsKey(characteristicUuid)) {
      throw Exception('Characteristic stream not found');
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
  void dispose() {
    _devicesListController.close();
    _clearCharacteristicStreams();
    selectedDeviceNotifier.dispose();
    isBluetoothEnabledNotifier.dispose();
    isScanningNotifier.dispose();
    isConnectingNotifier.dispose();
    isReconnectingNotifier.dispose();
    availableCharacteristics.dispose();
    super.dispose();
  }
}
