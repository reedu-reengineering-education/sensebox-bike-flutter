import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:sensebox_bike/blocs/settings_bloc.dart';
import 'package:sensebox_bike/secrets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:provider/provider.dart'; 
import 'package:sensebox_bike/blocs/recording_bloc.dart';
import 'package:sensebox_bike/services/ble_service.dart';
import 'package:sensebox_bike/services/custom_exceptions.dart';
import 'package:sensebox_bike/services/error_service.dart';
import 'package:vibration/vibration.dart';

const int maxReconnectionAttempts = 10;
const int reconnectionDelay = 5; // seconds

class BleBloc with ChangeNotifier {
  final SettingsBloc settingsBloc;
  final BleService bleService = BleService();

  // Add a ValueNotifier to track Bluetooth status
  final ValueNotifier<bool> isBluetoothEnabledNotifier = ValueNotifier(false);

  final List<BluetoothDevice> devicesList = [];
  final StreamController<List<BluetoothDevice>> _devicesListController =
      StreamController.broadcast();
  Stream<List<BluetoothDevice>> get devicesListStream =>
      _devicesListController.stream;

  BluetoothDevice? get selectedDevice => bleService.connectedDevice;
  bool _isConnected = false; // Track the connection status
  bool _userInitiatedDisconnect =
      false; // Track if disconnect was user-initiated
  bool _hasEverConnected = false;
  final Map<String, StreamController<List<double>>> _characteristicStreams = {};

  final Map<String, StreamController<List<String>>>
      _characteristicStringStreams = {};

  // create a value notifier that stores the available characteristics
  final ValueNotifier<List<BluetoothCharacteristic>> availableCharacteristics =
      ValueNotifier([]);

  // ValueNotifier to notify about the selected device's connection state
  final ValueNotifier<BluetoothDevice?> selectedDeviceNotifier =
      ValueNotifier(null);

  bool get isConnected => _isConnected; // Expose the connection status
  final ValueNotifier<bool> isConnectingNotifier = ValueNotifier(false);
  final ValueNotifier<bool> isReconnectingNotifier = ValueNotifier(false);

  BleBloc(this.settingsBloc) {
    // Listen for Bluetooth adapter state changes
    bleService.adapterState.listen((state) {
      updateBluetoothStatus(state == BluetoothAdapterState.on);
    });

    // Listen to BluetoothService status
    bleService.statusStream.listen((status) {
      if (status == BleStatus.connected) {
        selectedDeviceNotifier.value = bleService.connectedDevice;
      } else if (status == BleStatus.disconnected) {
        selectedDeviceNotifier.value = null;
      }
      notifyListeners();
    });

    // Initialize the Bluetooth status
    _initializeBluetoothStatus();
  }

  Future<void> _initializeBluetoothStatus() async {
    // Get the current adapter state
    BluetoothAdapterState currentState = await bleService.adapterState.first;
    updateBluetoothStatus(currentState == BluetoothAdapterState.on);
  }

  // Update Bluetooth status when it changes
  void updateBluetoothStatus(bool isEnabled) {
    isBluetoothEnabledNotifier.value = isEnabled;
    notifyListeners(); 
  }

  Future<void> startScanning() async {
    disconnectDevice(); // Disconnect if there's a current connection
    
    try {
      await bleService.startScan();
    } catch (e) {
      throw ScanPermissionDenied();
    }

    bleService.scanResults.listen((results) {
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

  Future<void> disconnectDevice({bool userInitiated = false}) async {
    _userInitiatedDisconnect = userInitiated;
    await bleService.disconnectDevice();
    availableCharacteristics.value = [];

    notifyListeners();
  }

  Future<void> connectToId(String id, BuildContext context) async {
    await bleService.startScan(withNames: [id]);
    bleService.scanResults.listen((results) async {
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
      isConnectingNotifier.value = true; // Notify that we're connecting
      notifyListeners();

      await bleService.stopScan();
      await bleService.connectToDevice(device);
      _userInitiatedDisconnect = false;
      await _discoverAndListenToCharacteristics(device);
      _hasEverConnected = true; 
      selectedDeviceNotifier.value = selectedDevice; // Notify connection
      notifyListeners();
      
      // Start monitoring for disconnects and handle reconnection
      // only if the device has been connected before
      if (_hasEverConnected) {
        _handleDeviceReconnection(device, context);
      }
    } catch (error, stack) {
      ErrorService.handleError(error, stack);
    } finally {
      isConnectingNotifier.value = false; // Notify that we're done connecting
    }
    notifyListeners();
  }

  Future<void> _discoverAndListenToCharacteristics(
      BluetoothDevice device) async {
    _characteristicStreams.clear();
    availableCharacteristics.value = [];

    int attempts = 0;
    while (attempts < maxReconnectionAttempts) {
      try {
        List<BluetoothService> services = await device.discoverServices();

        // find senseBox service
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
        if (attempts >= maxReconnectionAttempts) {
          // Handle the error after max attempts
          throw Exception(
              'Failed to discover services after $attempts attempts: $e');
        }
        debugPrint('Error discovering services, attempt $attempts: $e');
        await Future.delayed(const Duration(seconds: reconnectionDelay));
      }
    }
  }

  void _handleDeviceReconnection(BluetoothDevice device, BuildContext context) {
    bool hasVibrated = false; // Flag to track vibration
    int reconnectionAttempts = 0; // Track the number of reconnection attempts
    debugPrint(
        'Listening for disconnection events from device: ${device.name}');
    device.connectionState.listen((state) async {
      if (state == BluetoothConnectionState.disconnected &&
          !_userInitiatedDisconnect) {
        _isConnected = false; // Mark as disconnected

        // Set isReconnecting to true and notify listeners
        isReconnectingNotifier.value = true;

        // Vibrate only once after the disconnection
        if (!hasVibrated && settingsBloc.vibrateOnDisconnect) {
          Vibration.vibrate();
          hasVibrated = true; // Set the flag to prevent repeated vibration
        }

        // Attempt to reconnect the device (up to maxReconnectionAttempts)
        while (
            reconnectionAttempts < maxReconnectionAttempts && !_isConnected) {
          try {
            reconnectionAttempts++;
            await device.connect(
                timeout: const Duration(seconds: reconnectionDelay));

            // Check if the device is successfully connected
            if (await device.connectionState.first ==
                BluetoothConnectionState.connected) {
              _isConnected = true; // Mark as connected
              hasVibrated = false; // Reset the flag on successful reconnection
              reconnectionAttempts =
                  0; // Reset attempts on successful reconnection
              await _discoverAndListenToCharacteristics(device);
              break; // Exit the loop if reconnected
            }
          } catch (e) {
            // If reconnection fails, log the error and continue
            debugPrint('Reconnection attempt $reconnectionAttempts failed: $e');
          }
          // Add a delay between reconnection attempts
          await Future.delayed(const Duration(seconds: reconnectionDelay));
        }

        // Once done, set isReconnecting to false and notify listeners
        isReconnectingNotifier.value = false;

        if (!_isConnected && reconnectionAttempts >= maxReconnectionAttempts) {
          debugPrint(
              'Failed to reconnect after $maxReconnectionAttempts attempts');
          selectedDeviceNotifier.value = null; // Notify disconnection
          notifyListeners();

          if (!context.mounted) return;
          // Notify RecordingBloc to stop recording if Bluetooth disconnects
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
    selectedDeviceNotifier.dispose();
    isBluetoothEnabledNotifier.dispose();
    bleService.dispose();
    super.dispose();
  }
}
