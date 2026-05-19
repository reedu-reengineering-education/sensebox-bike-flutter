import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:sensebox_bike/blocs/settings_bloc.dart';
import 'package:sensebox_bike/models/ble_connection_result.dart';
import 'package:sensebox_bike/secrets.dart';
import 'package:sensebox_bike/services/custom_exceptions.dart';
import 'package:sensebox_bike/services/error_service.dart';
import 'package:sensebox_bike/utils/sensor_utils.dart';
import 'package:vibration/vibration.dart';

const deviceConnectTimeout = Duration(seconds: 10);
const configurableReconnectionDelay = Duration(seconds: 1);
const _delayAfterDiscoverServices = Duration(milliseconds: 400);
const _delayBetweenCharacteristicSubscriptions = Duration(milliseconds: 150);

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
  bool _isReconnecting = false;
  bool _userInitiatedDisconnect = false;
  bool _isInRetryMode = false;
  int _reconnectionAttempts = 0;
  bool _hasVibrated = false;
  static const int _maxReconnectionAttempts = 10;

  StreamSubscription<BluetoothAdapterState>? _adapterStateSubscription;
  StreamSubscription<List<ScanResult>>? _scanResultsSubscription;
  StreamSubscription<bool>? _isScanningSubscription;
  StreamSubscription<List<ScanResult>>? _connectToIdScanSubscription;
  StreamSubscription<BluetoothConnectionState>? _reconnectionListener;

  final Map<String, StreamController<List<double>>> _characteristicStreams = {};
  final Map<String, StreamSubscription<List<int>>>
      _characteristicSubscriptions = {};

  bool get isConnected => _isConnected;

  bool get isReadyForRecording {
    final device = selectedDevice;
    return _isConnected &&
        device != null &&
        device.isConnected &&
        !_isReconnecting &&
        !isConnectingNotifier.value &&
        !connectionErrorNotifier.value &&
        availableCharacteristics.value.isNotEmpty;
  }

  BleBloc(this.settingsBloc) {
    FlutterBluePlus.setLogLevel(LogLevel.error);
    _adapterStateSubscription =
        FlutterBluePlus.adapterState.listen((state) {
      updateBluetoothStatus(state == BluetoothAdapterState.on);
    });

    _initializeBluetoothStatus();
  }

  Future<void> _initializeBluetoothStatus() async {
    final currentState = await FlutterBluePlus.adapterState.first;
    updateBluetoothStatus(currentState == BluetoothAdapterState.on);
  }

  void updateBluetoothStatus(bool isEnabled) {
    if (isBluetoothEnabledNotifier.value != isEnabled) {
      isBluetoothEnabledNotifier.value = isEnabled;
      notifyListeners();
    }
  }

  Future<void> startScanning() async {
    if (_hasDeviceConnection()) {
      disconnectDevice();
    }

    await _cancelScanSubscriptions();
    isScanningNotifier.value = true;

    try {
      await FlutterBluePlus.startScan(timeout: deviceConnectTimeout);
    } catch (e) {
      isScanningNotifier.value = false;
      throw ScanPermissionDenied();
    }

    _scanResultsSubscription =
        FlutterBluePlus.scanResults.listen(_onScanResults);
    _isScanningSubscription = FlutterBluePlus.isScanning.listen((scanning) {
      isScanningNotifier.value = scanning;
    });
  }

  Future<void> stopScanning() async {
    await _cancelScanSubscriptions();
    await FlutterBluePlus.stopScan();
    isScanningNotifier.value = false;
  }

  Future<void> _cancelScanSubscriptions() async {
    await _scanResultsSubscription?.cancel();
    _scanResultsSubscription = null;
    await _isScanningSubscription?.cancel();
    _isScanningSubscription = null;
  }

  bool _hasDeviceConnection() {
    return selectedDevice != null || _isConnected;
  }

  void _onScanResults(List<ScanResult> results) {
    devicesList.clear();
    for (final result in results) {
      if (result.device.platformName.startsWith('senseBox')) {
        devicesList.add(result.device);
      }
    }
    _devicesListController.add(devicesList);
    notifyListeners();
  }

  void disconnectDevice() {
    _userInitiatedDisconnect = true;
    _isInRetryMode = false;
    selectedDevice?.disconnect();
    _clearSelectedDevice();
    availableCharacteristics.value = [];
    _reconnectionListener?.cancel();
    _reconnectionListener = null;
    resetConnectionError();
    _resetReconnectionState();
    notifyListeners();
  }

  Future<void> connectToId(String id, BuildContext context) async {
    resetConnectionError();
    await _connectToIdScanSubscription?.cancel();

    await FlutterBluePlus.startScan(withNames: [id]);
    _connectToIdScanSubscription =
        FlutterBluePlus.scanResults.listen((results) async {
      for (final result in results) {
        if (result.device.advName.toString() != id) {
          continue;
        }

        await _connectToIdScanSubscription?.cancel();
        _connectToIdScanSubscription = null;
        await stopScanning();
        await connectToDevice(result.device, context);
        break;
      }
    });
  }

  Future<BleConnectionResult> connectToDevice(
    BluetoothDevice device,
    BuildContext context,
  ) async {
    try {
      resetConnectionError();
      isConnectingNotifier.value = true;
      notifyListeners();

      if (isScanningNotifier.value) {
        await stopScanning();
      }

      try {
        await device.connect(timeout: deviceConnectTimeout);
      } catch (e) {
        await _disconnectDeviceSafe(device);
        _clearSelectedDevice();
        return BleConnectionResult.failure(
          reason: BleConnectionResult.fromException(e),
        );
      }

      final result = await _attemptSingleConnection(device);

      if (result.success) {
        _completeConnection(device, context);
      } else {
        await _disconnectDeviceSafe(device);
        _clearSelectedDevice();
      }

      return result;
    } catch (e) {
      ErrorService.handleError(e, StackTrace.current);

      await _disconnectDeviceSafe(device);
      _clearSelectedDevice();

      return BleConnectionResult.failure(
        reason: BleConnectionResult.fromException(e),
      );
    } finally {
      isConnectingNotifier.value = false;
      _isInRetryMode = false;
      notifyListeners();
    }
  }

  void _completeConnection(BluetoothDevice device, BuildContext context) {
    _handleDeviceReconnection(device, context);
    selectedDevice = device;
    selectedDeviceNotifier.value = device;
    _isConnected = true;
    _userInitiatedDisconnect = false;
  }

  Future<BleConnectionResult> _reconnectWithRetries(
    BluetoothDevice device,
    BuildContext context,
  ) async {
    _isInRetryMode = true;
    BleConnectionResult? lastResult;

    for (var attempt = 0; attempt < _maxReconnectionAttempts; attempt++) {
      _reconnectionAttempts++;

      if (attempt > 0) {
        _isConnected = false;
      }

      lastResult = await _attemptSingleConnection(
        device,
        updateConnectionState: false,
      );

      if (lastResult.success) {
        _isInRetryMode = false;
        return lastResult;
      }

      if (attempt < _maxReconnectionAttempts - 1) {
        try {
          if (!await _prepareForRetry(device)) {
            lastResult = BleConnectionResult.failure(
              reason: BleConnectionFailureReason.connectionTimeout,
            );
          }
        } catch (e) {
          lastResult = BleConnectionResult.failure(
            reason: BleConnectionResult.fromException(e),
          );
        }
      }
    }

    _isInRetryMode = false;
    _handleConnectionError(context: context);

    return lastResult ??
        BleConnectionResult.failure(reason: BleConnectionFailureReason.noData);
  }

  Future<BleConnectionResult> _attemptSingleConnection(
    BluetoothDevice device, {
    bool updateConnectionState = true,
  }) async {
    try {
      if (!device.isConnected) {
        return BleConnectionResult.failure(
          reason: BleConnectionFailureReason.connectionTimeout,
        );
      }

      _clearCharacteristicStreams();

      final services = await device.discoverServices();
      if (!device.isConnected) {
        return BleConnectionResult.failure(
          reason: BleConnectionFailureReason.connectionTimeout,
        );
      }

      if (services.isEmpty) {
        return BleConnectionResult.failure(
          reason: BleConnectionFailureReason.noService,
        );
      }

      final senseBoxService = _findSenseBoxService(services);
      if (senseBoxService == null) {
        return BleConnectionResult.failure(
          reason: BleConnectionFailureReason.noService,
        );
      }

      if (senseBoxService.characteristics.isEmpty) {
        return BleConnectionResult.failure(
          reason: BleConnectionFailureReason.noCharacteristics,
        );
      }

      await Future.delayed(_delayAfterDiscoverServices);

      final knownCharacteristics = senseBoxService.characteristics
          .where(
            (c) => knownSensorCharacteristicUuids
                .contains(_characteristicUuid(c)),
          )
          .toList();

      if (knownCharacteristics.isEmpty) {
        return BleConnectionResult.failure(
          reason: BleConnectionFailureReason.noCharacteristics,
        );
      }

      final subscribed =
          await _applyConnection(device, knownCharacteristics);

      if (!device.isConnected) {
        return BleConnectionResult.failure(
          reason: BleConnectionFailureReason.connectionTimeout,
        );
      }

      if (subscribed.isEmpty) {
        return BleConnectionResult.failure(
          reason: BleConnectionFailureReason.noData,
        );
      }

      if (updateConnectionState) {
        _markConnected();
      }
      return BleConnectionResult.fullSuccess();
    } catch (e) {
      return BleConnectionResult.failure(
        reason: BleConnectionResult.fromException(e),
      );
    }
  }

  Future<List<BluetoothCharacteristic>> _applyConnection(
    BluetoothDevice device,
    List<BluetoothCharacteristic> characteristics,
  ) async {
    final subscribed = <BluetoothCharacteristic>[];

    for (var i = 0; i < characteristics.length; i++) {
      if (!device.isConnected) {
        break;
      }
      if (i > 0) {
        await Future.delayed(_delayBetweenCharacteristicSubscriptions);
      }

      try {
        await _listenToCharacteristic(characteristics[i]);
        subscribed.add(characteristics[i]);
      } catch (e) {
        // Skip individual characteristics that fail to subscribe.
      }
    }

    availableCharacteristics.value = subscribed;
    if (subscribed.isNotEmpty) {
      characteristicStreamsVersion.value++;
    }
    return subscribed;
  }

  Future<void> _disconnectDeviceSafe(BluetoothDevice device) async {
    try {
      await device.disconnect();
    } catch (e) {
      // Device may already be disconnected
    }
  }

  void _clearSelectedDevice() {
    selectedDevice = null;
    selectedDeviceNotifier.value = null;
    _isConnected = false;
  }

  static String _characteristicUuid(BluetoothCharacteristic characteristic) {
    return characteristic.uuid.toString().toLowerCase();
  }

  void _markConnected() {
    _isConnected = true;
    _userInitiatedDisconnect = false;
    notifyListeners();
  }

  Future<bool> _prepareForRetry(BluetoothDevice device) async {
    try {
      try {
        await device.disconnect();
      } catch (e) {
        // Device may already be disconnected
      }

      await Future.delayed(configurableReconnectionDelay);

      await device.connect(timeout: deviceConnectTimeout);
      await Future.delayed(configurableReconnectionDelay);

      return device.isConnected;
    } catch (e) {
      return false;
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

  BluetoothService? _findSenseBoxService(List<BluetoothService> services) {
    for (final service in services) {
      if (service.uuid == senseBoxServiceUUID) {
        return service;
      }
    }
    return null;
  }

  void _handleDeviceReconnection(
    BluetoothDevice device,
    BuildContext context,
  ) {
    _reconnectionListener?.cancel();

    _userInitiatedDisconnect = false;
    _hasVibrated = false;
    _reconnectionAttempts = 0;

    _reconnectionListener = device.connectionState.listen((state) async {
      try {
        if (state == BluetoothConnectionState.disconnected &&
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
      _handleConnectionError(context: context);
    });
  }

  void _startReconnectionProcess(
    BluetoothDevice device,
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

    final result = await _reconnectWithRetries(device, context);

    if (result.success) {
      _isConnected = true;
      selectedDevice = device;
      selectedDeviceNotifier.value = device;
      _userInitiatedDisconnect = false;
      _hasVibrated = false;
      _reconnectionAttempts = 0;
      isReconnectingNotifier.value = false;
      _isReconnecting = false;
      _isInRetryMode = false;

      notifyListeners();
    }

    if (!result.success &&
        _reconnectionAttempts >= _maxReconnectionAttempts) {
      _handleConnectionError(context: context);
    }
  }

  void _handleConnectionError({required BuildContext context}) {
    _clearSelectedDevice();
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

    notifyListeners();
  }

  void resetConnectionError() {
    connectionErrorNotifier.value = false;

    _reconnectionListener?.cancel();
    _reconnectionListener = null;

    _resetReconnectionState();
    notifyListeners();
  }

  void _resetReconnectionState() {
    _isReconnecting = false;
    _isInRetryMode = false;
    _reconnectionAttempts = 0;
    _hasVibrated = false;
    isReconnectingNotifier.value = false;
  }

  Future<void> _listenToCharacteristic(
    BluetoothCharacteristic characteristic,
  ) async {
    final uuid = _characteristicUuid(characteristic);

    await _characteristicSubscriptions[uuid]?.cancel();
    _characteristicSubscriptions.remove(uuid);

    if (_characteristicStreams.containsKey(uuid)) {
      await _characteristicStreams[uuid]?.close();
      _characteristicStreams.remove(uuid);
    }

    final controller = StreamController<List<double>>.broadcast();
    _characteristicStreams[uuid] = controller;

    if (!characteristic.isNotifying) {
      await characteristic.setNotifyValue(true);
    }
    final subscription = characteristic.onValueReceived.listen((value) {
      if (!controller.isClosed) {
        final parsedData = _parseData(Uint8List.fromList(value));
        controller.add(parsedData);
      }
    });
    _characteristicSubscriptions[uuid] = subscription;
  }

  bool hasCharacteristicStream(String characteristicUuid) {
    return _characteristicStreams
        .containsKey(characteristicUuid.toLowerCase());
  }

  Stream<List<double>> getCharacteristicStream(String characteristicUuid) {
    final uuid = characteristicUuid.toLowerCase();
    if (!_characteristicStreams.containsKey(uuid)) {
      throw BleCharacteristicStreamNotFoundException(characteristicUuid);
    }
    return _characteristicStreams[uuid]!.stream;
  }

  List<double> _parseData(Uint8List value) {
    final parsedValues = <double>[];
    for (var i = 0; i < value.length; i += 4) {
      if (i + 4 <= value.length) {
        parsedValues.add(
          ByteData.sublistView(value, i, i + 4).getFloat32(0, Endian.little),
        );
      }
    }
    return parsedValues;
  }

  @override
  void dispose() {
    _adapterStateSubscription?.cancel();
    _connectToIdScanSubscription?.cancel();
    _cancelScanSubscriptions();
    _reconnectionListener?.cancel();
    _devicesListController.close();
    _clearCharacteristicStreams();
    selectedDeviceNotifier.dispose();
    isBluetoothEnabledNotifier.dispose();
    isScanningNotifier.dispose();
    isConnectingNotifier.dispose();
    isReconnectingNotifier.dispose();
    availableCharacteristics.dispose();
    characteristicStreamsVersion.dispose();
    connectionErrorNotifier.dispose();
    super.dispose();
  }

  Future<void> requestEnableBluetooth() async {
    return FlutterBluePlus.turnOn();
  }
}
