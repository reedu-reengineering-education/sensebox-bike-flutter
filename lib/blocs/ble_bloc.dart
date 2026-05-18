import 'dart:async';

import 'dart:typed_data';
import 'package:flutter/widgets.dart';
import 'package:sensebox_bike/blocs/settings_bloc.dart';
import 'package:sensebox_bike/secrets.dart';
import 'package:flutter/material.dart';
import 'package:universal_ble/universal_ble.dart';

import 'package:sensebox_bike/services/custom_exceptions.dart';
import 'package:sensebox_bike/services/error_service.dart';
import 'package:vibration/vibration.dart';

const reconnectionDelay = Duration(seconds: 1);
const deviceConnectTimeout = Duration(seconds: 10);
const configurableReconnectionDelay = Duration(seconds: 1);
const dataListeningTimeout = Duration(seconds: 4);
const bleConnectionMaxAttempts = 3;

class BleBloc with ChangeNotifier {
  final SettingsBloc settingsBloc;

  final ValueNotifier<bool> isBluetoothEnabledNotifier = ValueNotifier(false);
  final ValueNotifier<bool> isScanningNotifier = ValueNotifier(false);
  final ValueNotifier<bool> isConnectingNotifier = ValueNotifier(false);
  final ValueNotifier<bool> isReconnectingNotifier = ValueNotifier(false);
  final ValueNotifier<BleDevice?> selectedDeviceNotifier =
      ValueNotifier(null);
  final ValueNotifier<List<BleCharacteristic>> availableCharacteristics =
      ValueNotifier([]);
  final ValueNotifier<int> characteristicStreamsVersion = ValueNotifier(0);
  final ValueNotifier<bool> connectionErrorNotifier = ValueNotifier(false);

  final List<BleDevice> devicesList = [];
  final StreamController<List<BleDevice>> _devicesListController =
      StreamController.broadcast();
  Stream<List<BleDevice>> get devicesListStream =>
      _devicesListController.stream;

  BleDevice? selectedDevice;
  bool _isConnected = false;
  bool _isReconnecting = false;
  bool _userInitiatedDisconnect = false;
  bool _isInRetryMode = false;
  int _reconnectionAttempts = 0;
  bool _hasVibrated = false;
  static const int _maxReconnectionAttempts = 10;

  StreamSubscription<bool>? _reconnectionListener;
  StreamSubscription<BleDevice>? _scanSubscription;
  StreamSubscription<AvailabilityState>? _availabilitySubscription;

  final Map<String, StreamController<List<double>>> _characteristicStreams = {};
  final Map<String, StreamSubscription<Uint8List>>
      _characteristicSubscriptions = {};

  bool get isConnected => _isConnected;

  BleBloc(this.settingsBloc) {
    UniversalBle.setLogLevel(BleLogLevel.error);
    _availabilitySubscription =
        UniversalBle.availabilityStream.listen((state) {
      updateBluetoothStatus(state == AvailabilityState.poweredOn);
    });

    _initializeBluetoothStatus();
  }

  Future<void> _initializeBluetoothStatus() async {
    final currentState = await UniversalBle.getBluetoothAvailabilityState();
    updateBluetoothStatus(currentState == AvailabilityState.poweredOn);
  }

  void updateBluetoothStatus(bool isEnabled) {
    if (isBluetoothEnabledNotifier.value != isEnabled) {
      isBluetoothEnabledNotifier.value = isEnabled;
      notifyListeners();
    }
  }

  Future<void> _beginScan() async {
    await UniversalBle.requestPermissions();
    _scanSubscription?.cancel();
    _scanSubscription = UniversalBle.scanStream.listen(_onScanResult);

    await UniversalBle.startScan();
  }

  void _onScanResult(BleDevice device) {
    final deviceName = device.name ?? '';
    if (!deviceName.startsWith('senseBox')) {
      return;
    }

    final existingIndex = devicesList.indexWhere(
      (d) => d.deviceId == device.deviceId,
    );
    if (existingIndex >= 0) {
      devicesList[existingIndex] = device;
    } else {
      devicesList.add(device);
    }
    _devicesListController.add(List.from(devicesList));
    notifyListeners();
  }

  Future<void> startScanning() async {
    isScanningNotifier.value = true;
    devicesList.clear();
    _devicesListController.add(devicesList);

    try {
      await _beginScan();
    } catch (e) {
      isScanningNotifier.value = false;
      throw ScanPermissionDenied();
    }
  }

  Future<void> stopScanning() async {
    _scanSubscription?.cancel();
    _scanSubscription = null;
    await UniversalBle.stopScan();
    isScanningNotifier.value = false;
  }

  Future<void> scanForNewDevices() async {
    disconnectDevice();
    isScanningNotifier.value = true;

    try {
      await _beginScan();
    } catch (e) {
      isScanningNotifier.value = false;
      throw ScanPermissionDenied();
    }
  }

  void disconnectDevice() {
    _userInitiatedDisconnect = true;
    _isInRetryMode = false;
    final device = selectedDevice;
    if (device != null) {
      device.disconnect();
    }
    _isConnected = false;
    selectedDevice = null;
    selectedDeviceNotifier.value = null;
    availableCharacteristics.value = [];
    _reconnectionListener?.cancel();
    _reconnectionListener = null;
    resetConnectionError();
    _resetReconnectionState();

    notifyListeners();
  }

  Future<void> connectToId(String id, BuildContext context) async {
    resetConnectionError();

    await UniversalBle.startScan(
      scanFilter: ScanFilter(withNamePrefix: [id]),
    );
    _scanSubscription?.cancel();
    _scanSubscription = UniversalBle.scanStream.listen((device) async {
      final deviceName = device.name ?? '';
      if (deviceName == id) {
        await stopScanning();
        await connectToDevice(device, context);
      }
    });
  }

  Future<void> connectToDevice(BleDevice device, BuildContext context) async {
    try {
      resetConnectionError();

      isConnectingNotifier.value = true;
      notifyListeners();

      if (isScanningNotifier.value) {
        await stopScanning();
      }

      final success = await _attemptConnectionWithRetries(
        device,
        context: context,
        maxAttempts: bleConnectionMaxAttempts,
      );
      _isConnected = success;

      if (_isConnected) {
        _handleDeviceReconnection(device, context);

        selectedDevice = device;
        selectedDeviceNotifier.value = selectedDevice;
      } else {
        selectedDevice = null;
        selectedDeviceNotifier.value = null;
      }
    } catch (e) {
      ErrorService.handleError(e, StackTrace.current);

      selectedDevice = null;
      selectedDeviceNotifier.value = null;
      _isConnected = false;

      _handleConnectionError(context: context, isInitialConnection: true);
    } finally {
      isConnectingNotifier.value = false;
      _isInRetryMode = false;
      notifyListeners();
    }
  }

  Future<bool> _executeConnectionAttempts(
    BleDevice device,
    BuildContext? context, {
    required int maxAttempts,
    required bool isReconnection,
    required Future<bool> Function(BleDevice, BuildContext?) attemptConnection,
    required Future<void> Function(BleDevice) prepareForRetry,
    required void Function(
            {required BuildContext context, bool isInitialConnection})
        handleError,
  }) async {
    _isInRetryMode = true;

    for (int attempt = 0; attempt < maxAttempts; attempt++) {
      if (attempt > 0) {
        _isConnected = false;
      }

      try {
        bool success = false;
        try {
          success = await attemptConnection(device, context);
        } catch (e) {
          success = false;
        }

        if (success) {
          _isInRetryMode = false;
          return true;
        }

        if (attempt < maxAttempts - 1) {
          try {
            await prepareForRetry(device);
          } catch (e) {
            // Continue with next attempt anyway
          }
        }
      } catch (e) {
        if (attempt < maxAttempts - 1) {
          try {
            await prepareForRetry(device);
          } catch (e) {
            // Continue with next attempt anyway
          }
        }
      }
    }

    _isInRetryMode = false;

    if (context != null) {
      handleError(context: context, isInitialConnection: !isReconnection);
    }
    return false;
  }

  Future<bool> _attemptConnectionWithRetries(
    BleDevice device, {
    BuildContext? context,
    int maxAttempts = 5,
    bool isReconnection = false,
  }) async {
    return _executeConnectionAttempts(
      device,
      context,
      maxAttempts: maxAttempts,
      isReconnection: isReconnection,
      attemptConnection: (device, context) => _attemptSingleConnection(
        device,
        context,
        updateConnectionState: true,
      ),
      prepareForRetry: _prepareForRetry,
      handleError: _handleConnectionError,
    );
  }

  Future<bool> _attemptSingleConnection(
    BleDevice device,
    BuildContext? context, {
    bool updateConnectionState = true,
  }) async {
    try {
      if (!(await device.isConnected)) {
        await device.connect(timeout: deviceConnectTimeout);
      }

      _clearCharacteristicStreams();

      final services = await device.discoverServices();
      if (services.isEmpty) {
        return false;
      }

      BleService? senseBoxService;
      try {
        senseBoxService = _findSenseBoxService(services);
      } catch (e) {
        return false;
      }

      if (senseBoxService.characteristics.isEmpty) {
        return false;
      }

      final firstCharacteristic = senseBoxService.characteristics.first;

      bool dataReceived = false;
      final dataReceivedCompleter = Completer<bool>();

      await firstCharacteristic.notifications.subscribe();
      Uint8List? receivedData;
      final subscription =
          firstCharacteristic.onValueReceived.listen((value) {
        if (!dataReceivedCompleter.isCompleted) {
          receivedData = value;
          dataReceived = true;
          dataReceivedCompleter.complete(true);
        }
      });

      try {
        await Future.any([
          dataReceivedCompleter.future,
          Future.delayed(dataListeningTimeout),
        ]);
      } finally {
        subscription.cancel();
        await firstCharacteristic.unsubscribe();
      }

      if (dataReceived && receivedData != null) {
        final isDataMeaningful = _validateReceivedData(receivedData!);

        if (isDataMeaningful) {
          for (final characteristic in senseBoxService.characteristics) {
            await _listenToCharacteristic(characteristic);
          }

          availableCharacteristics.value = senseBoxService.characteristics;
          characteristicStreamsVersion.value++;

          if (updateConnectionState) {
            _isConnected = true;
            _userInitiatedDisconnect = false;

            notifyListeners();
          }

          return true;
        } else {
          return false;
        }
      } else if (dataReceived && receivedData == null) {
        return false;
      } else {
        return false;
      }
    } catch (e) {
      return false;
    }
  }

  Future<void> _prepareForRetry(BleDevice device) async {
    try {
      try {
        await device.disconnect();
      } catch (e) {
        // Continue anyway, device might already be disconnected
      }

      await Future.delayed(configurableReconnectionDelay);

      try {
        await device.connect(timeout: deviceConnectTimeout);
      } catch (e) {
        return;
      }

      await Future.delayed(configurableReconnectionDelay);
    } catch (e) {
      // Don't throw - let reconnection continue with next attempt
    }
  }

  void _clearCharacteristicStreams() {
    for (final subscription in _characteristicSubscriptions.values) {
      subscription.cancel();
    }
    _characteristicSubscriptions.clear();

    for (final controller in _characteristicStreams.values) {
      controller.close();
    }
    _characteristicStreams.clear();
  }

  BleService _findSenseBoxService(List<BleService> services) {
    return services.firstWhere(
      (service) =>
          BleUuidParser.compareStrings(service.uuid, senseBoxServiceUUID),
      orElse: () => throw Exception('senseBox service not found'),
    );
  }

  void _handleDeviceReconnection(BleDevice device, BuildContext context) {
    _reconnectionListener?.cancel();

    _userInitiatedDisconnect = false;
    _hasVibrated = false;
    _reconnectionAttempts = 0;

    _reconnectionListener = device.connectionStream.listen((isConnected) async {
      try {
        if (!isConnected &&
            !_userInitiatedDisconnect &&
            !_isInRetryMode) {
          if (!_isReconnecting) {
            _isConnected = false;
            isReconnectingNotifier.value = true;

            try {
              _startReconnectionProcess(device, context);
            } catch (e) {
              _isReconnecting = false;
              isReconnectingNotifier.value = false;
            }
          }
        }
      } catch (e) {
        // Don't throw - let the reconnection process handle it
      }
    });

    _reconnectionListener?.onError((error) {
      _handleConnectionError(context: context, isInitialConnection: false);
    });
  }

  void _startReconnectionProcess(
    BleDevice device,
    BuildContext context,
  ) async {
    if (_isReconnecting) {
      if (_reconnectionAttempts >= _maxReconnectionAttempts) {
        _isReconnecting = false;
        _reconnectionAttempts = 0;
        _hasVibrated = false;
        isReconnectingNotifier.value = false;
      } else {
        return;
      }
    }

    _isReconnecting = true;
    _isInRetryMode = true;

    if (!_hasVibrated && settingsBloc.vibrateOnDisconnect) {
      Vibration.vibrate();
      _hasVibrated = true;
    }

    final success = await _executeConnectionAttempts(
      device,
      context,
      maxAttempts: _maxReconnectionAttempts,
      isReconnection: true,
      attemptConnection: (device, context) async {
        _reconnectionAttempts++;
        return _attemptSingleConnection(
          device,
          context,
          updateConnectionState: false,
        );
      },
      prepareForRetry: _prepareForRetry,
      handleError: _handleConnectionError,
    );

    if (success) {
      _isConnected = true;
      _userInitiatedDisconnect = false;
      _hasVibrated = false;
      _reconnectionAttempts = 0;
      isReconnectingNotifier.value = false;
      _isReconnecting = false;
      _isInRetryMode = false;

      notifyListeners();
    }

    if (!_isConnected && _reconnectionAttempts >= _maxReconnectionAttempts) {
      _handleConnectionError(context: context, isInitialConnection: false);
    }
  }

  void _handleConnectionError(
      {required BuildContext context, bool isInitialConnection = false}) {
    if (isInitialConnection) {
      selectedDeviceNotifier.value = null;
      _isConnected = false;
      _userInitiatedDisconnect = false;
      _resetReconnectionState();
      isConnectingNotifier.value = false;
      connectionErrorNotifier.value = false;
    } else {
      selectedDevice = null;
      selectedDeviceNotifier.value = null;
      _isConnected = false;
      connectionErrorNotifier.value = true;

      _reconnectionListener?.cancel();
      _reconnectionListener = null;

      _clearCharacteristicStreams();

      _isReconnecting = false;
      _isInRetryMode = false;
      _reconnectionAttempts = 0;
      _hasVibrated = false;
      isReconnectingNotifier.value = false;
      isConnectingNotifier.value = false;
    }

    notifyListeners();
  }

  void resetConnectionError() {
    connectionErrorNotifier.value = false;

    _reconnectionListener?.cancel();
    _reconnectionListener = null;

    _isReconnecting = false;
    _isInRetryMode = false;
    _reconnectionAttempts = 0;
    _hasVibrated = false;
    isReconnectingNotifier.value = false;

    notifyListeners();
  }

  void _resetReconnectionState() {
    _isReconnecting = false;
    _isInRetryMode = false;
    _reconnectionAttempts = 0;
    _hasVibrated = false;

    isReconnectingNotifier.value = false;
    notifyListeners();
  }

  bool _validateReceivedData(Uint8List data) {
    if (data.isEmpty) {
      return false;
    }

    final allZeros = data.every((byte) => byte == 0);
    if (allZeros) {
      return false;
    }

    if (data.length < 4) {
      return false;
    }

    return true;
  }

  Future<void> _listenToCharacteristic(BleCharacteristic characteristic) async {
    final uuid = characteristic.uuid;

    await _characteristicSubscriptions[uuid]?.cancel();
    _characteristicSubscriptions.remove(uuid);

    if (_characteristicStreams.containsKey(uuid)) {
      await _characteristicStreams[uuid]?.close();
      _characteristicStreams.remove(uuid);
    }

    final controller = StreamController<List<double>>.broadcast();
    _characteristicStreams[uuid] = controller;

    await characteristic.notifications.subscribe();
    final subscription = characteristic.onValueReceived.listen((value) {
      if (!controller.isClosed) {
        final parsedData = _parseData(value);
        controller.add(parsedData);
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
    _reconnectionListener?.cancel();
    _scanSubscription?.cancel();
    _availabilitySubscription?.cancel();
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

  Future<void> requestEnableBluetooth() async {
    await UniversalBle.enableBluetooth();
  }
}
