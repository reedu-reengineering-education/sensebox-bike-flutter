import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:sensebox_bike/blocs/settings_bloc.dart';
import 'package:sensebox_bike/secrets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import 'package:sensebox_bike/services/custom_exceptions.dart';
import 'package:sensebox_bike/services/error_service.dart';
import 'package:vibration/vibration.dart';

const reconnectionDelay = Duration(seconds: 1);
const deviceConnectTimeout = Duration(seconds: 10);
const configurableReconnectionDelay = Duration(seconds: 1);
const dataListeningTimeout = Duration(seconds: 4); 

class BleBloc with ChangeNotifier, WidgetsBindingObserver {
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

  final StreamController<List<BluetoothDevice>> _devicesListController =
      StreamController.broadcast();
  Stream<List<BluetoothDevice>> get devicesListStream =>
      _devicesListController.stream;

  bool _isConnected = false;
  bool _isReconnecting = false;
  bool _userInitiatedDisconnect = false;
  bool _isInRetryMode = false;
  int _reconnectionAttempts = 0;
  bool _hasVibrated = false;
  static const int _maxReconnectionAttempts = 10;

  StreamSubscription<BluetoothConnectionState>? _reconnectionListener;

  final Map<String, StreamController<List<double>>> _characteristicStreams = {};
  final Map<String, StreamSubscription<List<int>>> _characteristicSubscriptions = {};
  final Map<String, BluetoothCharacteristic> _characteristics = {};
  final Set<String> _recoveringCharacteristics = {};

  bool get isConnected => _isConnected;
  BluetoothDevice? get selectedDevice => selectedDeviceNotifier.value;

  BleBloc(this.settingsBloc) {
    FlutterBluePlus.setLogLevel(LogLevel.error);
    FlutterBluePlus.adapterState.listen((state) {
      updateBluetoothStatus(state == BluetoothAdapterState.on);
    });

    _initializeBluetoothStatus();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && defaultTargetPlatform == TargetPlatform.iOS) {
      _reenableAllNotifications();
    }
  }

  Future<void> _reenableAllNotifications() async {
    if (!_isConnected || selectedDeviceNotifier.value?.isConnected != true) {
      return;
    }

    for (var entry in _characteristics.entries) {
      final characteristic = entry.value;
      try {
        await _toggleCharacteristicNotifications(characteristic);
      } catch (e, stack) {
        ErrorService.handleError(e, stack);
      }
    }
  }

  Future<void> _toggleCharacteristicNotifications(
      BluetoothCharacteristic characteristic) async {
    await characteristic.setNotifyValue(false);
    await Future.delayed(const Duration(milliseconds: 200));
    await characteristic.setNotifyValue(true);
  }

  Future<void> _initializeBluetoothStatus() async {
    BluetoothAdapterState currentState =
        await FlutterBluePlus.adapterState.first;
    updateBluetoothStatus(currentState == BluetoothAdapterState.on);
  }

  void updateBluetoothStatus(bool isEnabled) {
    if (isBluetoothEnabledNotifier.value != isEnabled) {
      isBluetoothEnabledNotifier.value = isEnabled;
      notifyListeners();
    }
  }

  Future<void> startScanning() async {
    await _performScan();
  }

  Future<void> stopScanning() async {
    await FlutterBluePlus.stopScan();
    isScanningNotifier.value = false;
  }

  Future<void> scanForNewDevices() async {
    disconnectDevice();
    await _performScan();
  }

  Future<void> _performScan() async {
    isScanningNotifier.value = true;

    try {
      await FlutterBluePlus.startScan(timeout: deviceConnectTimeout);
    } catch (e) {
      isScanningNotifier.value = false;
      throw ScanPermissionDenied();
    }

    FlutterBluePlus.scanResults.listen((results) {
      final devices = results
          .where((result) => result.device.platformName.startsWith("senseBox"))
          .map((result) => result.device)
          .toList();
      _devicesListController.add(devices);
      notifyListeners();
    });

    FlutterBluePlus.isScanning.listen((scanning) {
      isScanningNotifier.value = scanning;
    });
  }

  void disconnectDevice() {
    _userInitiatedDisconnect = true;
    _isInRetryMode = false;
    selectedDeviceNotifier.value?.disconnect();
    _resetConnectionState();
    availableCharacteristics.value = [];
    _reconnectionListener?.cancel();
    _reconnectionListener = null;
    resetConnectionError();
    notifyListeners();
  }

  void _resetConnectionState() {
    _isConnected = false;
    selectedDeviceNotifier.value = null;
  }

  Future<void> connectToId(String id, BuildContext context) async {
    resetConnectionError();
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
      resetConnectionError();

      isConnectingNotifier.value = true;
      notifyListeners();

      if (isScanningNotifier.value) {
        await stopScanning();
      }

      await device.connect();

      final success =
          await _attemptConnectionWithRetries(device, context: context);
      _isConnected = success;

      if (_isConnected) {
        _handleDeviceReconnection(device, context);
        selectedDeviceNotifier.value = device;
      } else {
        selectedDeviceNotifier.value = null;
      }
    } catch (e) {
      ErrorService.handleError(e, StackTrace.current);
      _resetConnectionState();
      await _handleConnectionError(context: context, isInitialConnection: true);
    } finally {
      isConnectingNotifier.value = false;
      _isInRetryMode = false;
      notifyListeners();
    }
  }

  Future<bool> _executeConnectionAttempts(
    BluetoothDevice device,
    BuildContext? context, {
    required int maxAttempts,
    required bool isReconnection,
    required Future<bool> Function(BluetoothDevice, BuildContext?)
        attemptConnection,
    required Future<void> Function(BluetoothDevice) prepareForRetry,
    required Future<void> Function(
            {required BuildContext context, bool isInitialConnection})
        handleError,
  }) async {
    _isInRetryMode = true;

    for (int attempt = 0; attempt < maxAttempts; attempt++) {
      if (attempt > 0) {
        _isConnected = false;
      }

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
    }

    _isInRetryMode = false;

    if (context != null) {
      await handleError(context: context, isInitialConnection: !isReconnection);
    }
    return false;
  }

  Future<bool> _attemptConnectionWithRetries(
    BluetoothDevice device, {
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
    BluetoothDevice device,
    BuildContext? context, {
    bool updateConnectionState = true,
  }) async {
    try {
      await _clearCharacteristicStreams();

      final services = await device.discoverServices();
      if (services.isEmpty) {
        return false;
      }

      BluetoothService? senseBoxService;
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

      await firstCharacteristic.setNotifyValue(true);
      Uint8List? receivedData;
      final subscription = firstCharacteristic.onValueReceived.listen((value) {
        if (!dataReceivedCompleter.isCompleted) {
          receivedData = Uint8List.fromList(value);
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
        await firstCharacteristic.setNotifyValue(false);
      }

      if (dataReceived && receivedData != null) {
        bool isDataMeaningful = _validateReceivedData(receivedData!);

        if (isDataMeaningful) {
          for (var characteristic in senseBoxService.characteristics) {
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
        }
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<void> _prepareForRetry(BluetoothDevice device) async {
    try {
      try {
        await device.disconnect();
      } catch (e, stack) {
        ErrorService.handleError(e, stack);
      }

      await Future.delayed(configurableReconnectionDelay);

      try {
        await device.connect(timeout: deviceConnectTimeout);
      } catch (e, stack) {
        ErrorService.handleError(e, stack);
        return;
      }

      await Future.delayed(configurableReconnectionDelay);
    } catch (e, stack) {
      ErrorService.handleError(e, stack);
    }
  }

  Future<void> _clearCharacteristicStreams() async {
    final uuids = _characteristicSubscriptions.keys.toList();
    await Future.wait(uuids.map((uuid) => _cleanupCharacteristic(uuid)));
    _characteristicSubscriptions.clear();
    _characteristicStreams.clear();
    _characteristics.clear();
    _recoveringCharacteristics.clear();
  }

  Future<void> _cleanupCharacteristic(String uuid) async {
    await _characteristicSubscriptions[uuid]?.cancel();
    _characteristicSubscriptions.remove(uuid);
    final controller = _characteristicStreams[uuid];
    if (controller != null) {
      await controller.close();
      _characteristicStreams.remove(uuid);
    }
    _characteristics.remove(uuid);
  }

  BluetoothService _findSenseBoxService(List<BluetoothService> services) {
    return services.firstWhere(
      (service) => service.uuid == senseBoxServiceUUID,
      orElse: () => throw Exception('senseBox service not found'),
    );
  }

  void _handleDeviceReconnection(BluetoothDevice device, BuildContext context) {
    _reconnectionListener?.cancel();

    _userInitiatedDisconnect = false;
    _hasVibrated = false;
    _reconnectionAttempts = 0;

    _reconnectionListener = device.connectionState.listen((state) async {
      if (state == BluetoothConnectionState.disconnected &&
          !_userInitiatedDisconnect &&
          !_isInRetryMode &&
          !_isReconnecting) {
        _isConnected = false;
        isReconnectingNotifier.value = true;
        try {
          _startReconnectionProcess(device, context);
        } catch (e, stack) {
          ErrorService.handleError(e, stack);
          _isReconnecting = false;
          isReconnectingNotifier.value = false;
        }
      }
    });

    _reconnectionListener?.onError((error) async {
      await _handleConnectionError(context: context, isInitialConnection: false);
    });
  }

  void _startReconnectionProcess(
    BluetoothDevice device,
    BuildContext context,
  ) async {
    if (_isReconnecting) {
      if (_reconnectionAttempts >= _maxReconnectionAttempts) {
        _resetReconnectionState();
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
      _resetReconnectionState();
      notifyListeners();
    } else if (_reconnectionAttempts >= _maxReconnectionAttempts) {
      await _handleConnectionError(context: context, isInitialConnection: false);
    }
  }

  Future<void> _handleConnectionError(
      {required BuildContext context, bool isInitialConnection = false}) async {
    if (isInitialConnection) {
      _resetConnectionState();
      _userInitiatedDisconnect = false;
      _resetReconnectionState();
      isConnectingNotifier.value = false;
      connectionErrorNotifier.value = false;
    } else {
      _resetConnectionState();
      connectionErrorNotifier.value = true;
      _reconnectionListener?.cancel();
      _reconnectionListener = null;
      await _clearCharacteristicStreams();
      _resetReconnectionState();
      isConnectingNotifier.value = false;
    }
    notifyListeners();
  }

  void resetConnectionError() {
    connectionErrorNotifier.value = false;
    _resetReconnectionState();
  }

  void _resetReconnectionState() {
    _reconnectionListener?.cancel();
    _reconnectionListener = null;
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

    bool allZeros = data.every((byte) => byte == 0);
    if (allZeros) {
      return false;
    }

    if (data.length < 4) {
      return false;
    }

    return true;
  }

  Future<void> _listenToCharacteristic(
      BluetoothCharacteristic characteristic) async {
    final uuid = characteristic.uuid.toString();
    await _cleanupCharacteristic(uuid);

    final controller = StreamController<List<double>>.broadcast();
    _characteristicStreams[uuid] = controller;
    _characteristics[uuid] = characteristic;

    try {
      await characteristic.setNotifyValue(true);
      _createCharacteristicSubscription(uuid, characteristic, controller);
    } catch (e) {
      await _cleanupCharacteristic(uuid);
      rethrow;
    }
  }

  void _createCharacteristicSubscription(
      String uuid,
      BluetoothCharacteristic characteristic,
      StreamController<List<double>> controller) {
    final subscription = characteristic.onValueReceived.listen(
      (value) {
        if (!controller.isClosed) {
          List<double> parsedData = _parseData(Uint8List.fromList(value));
          controller.add(parsedData);
        }
      },
      onError: (error) {
        debugPrint('[BleBloc] Characteristic $uuid stream error: $error');
        _handleCharacteristicStreamError(uuid, characteristic);
      },
      cancelOnError: false,
    );
    _characteristicSubscriptions[uuid] = subscription;
  }

  Future<void> _handleCharacteristicStreamError(
      String uuid, BluetoothCharacteristic characteristic) async {
    if (_recoveringCharacteristics.contains(uuid)) {
      return;
    }

    _recoveringCharacteristics.add(uuid);
    try {
      await _characteristicSubscriptions[uuid]?.cancel();
      _characteristicSubscriptions.remove(uuid);

      await Future.delayed(const Duration(milliseconds: 500));

      if (_isConnected && selectedDeviceNotifier.value?.isConnected == true) {
        await _toggleCharacteristicNotifications(characteristic);

        final controller = _characteristicStreams[uuid];
        if (controller != null && !controller.isClosed) {
          _createCharacteristicSubscription(uuid, characteristic, controller);
        }
      }
    } catch (e, stack) {
      ErrorService.handleError(e, stack);
      await _cleanupCharacteristic(uuid);
    } finally {
      _recoveringCharacteristics.remove(uuid);
    }
  }

  Stream<List<double>> getCharacteristicStream(String characteristicUuid) {
    final controller = _characteristicStreams[characteristicUuid];
    if (controller == null) {
      debugPrint('Characteristic stream not found');
      return const Stream.empty();
    }
    return controller.stream;
  }

  List<double> _parseData(Uint8List value) {
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
    WidgetsBinding.instance.removeObserver(this);
    _reconnectionListener?.cancel();
    _devicesListController.close();
    unawaited(_clearCharacteristicStreams());
    selectedDeviceNotifier.dispose();
    isBluetoothEnabledNotifier.dispose();
    isScanningNotifier.dispose();
    isConnectingNotifier.dispose();
    isReconnectingNotifier.dispose();
    availableCharacteristics.dispose();
    super.dispose();
  }

  Future<void> requestEnableBluetooth() async {
    return FlutterBluePlus.turnOn();
  }
}
