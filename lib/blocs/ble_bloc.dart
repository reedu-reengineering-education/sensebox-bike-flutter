import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:sensebox_bike/blocs/settings_bloc.dart';
import 'package:sensebox_bike/models/ble_connection_phase.dart';
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

class BleBloc {
  final SettingsBloc settingsBloc;

  final ValueNotifier<bool> isBluetoothEnabledNotifier = ValueNotifier(false);
  final ValueNotifier<bool> isScanningNotifier = ValueNotifier(false);
  final ValueNotifier<bool> isConnectingNotifier = ValueNotifier(false);
  final ValueNotifier<bool> isReconnectingNotifier = ValueNotifier(false);
  final ValueNotifier<BleConnectionPhase> connectionPhaseNotifier =
      ValueNotifier(BleConnectionPhase.idle);
  final ValueNotifier<BluetoothDevice?> selectedDeviceNotifier =
      ValueNotifier(null);
  final ValueNotifier<List<BluetoothDevice>> discoveredDevicesNotifier =
      ValueNotifier([]);
  final ValueNotifier<List<BluetoothCharacteristic>> availableCharacteristics =
      ValueNotifier([]);
  final ValueNotifier<int> characteristicStreamsVersion = ValueNotifier(0);
  final ValueNotifier<bool> connectionErrorNotifier = ValueNotifier(false);

  BleConnectionPhase _connectionPhase = BleConnectionPhase.idle;
  bool _userInitiatedDisconnect = false;
  bool _hasVibrated = false;
  static const int _maxReconnectionAttempts = 10;

  StreamSubscription<BluetoothAdapterState>? _adapterStateSubscription;
  StreamSubscription<List<ScanResult>>? _scanResultsSubscription;
  StreamSubscription<bool>? _isScanningSubscription;
  StreamSubscription<BluetoothConnectionState>? _reconnectionListener;

  final Map<String, StreamController<List<double>>> _characteristicStreams = {};
  final Map<String, StreamSubscription<List<int>>>
      _characteristicSubscriptions = {};

  bool get isConnected => _connectionPhase == BleConnectionPhase.connected;

  bool get isReadyForRecording {
    final device = selectedDeviceNotifier.value;
    return _connectionPhase == BleConnectionPhase.connected &&
        device != null &&
        device.isConnected &&
        !connectionErrorNotifier.value &&
        availableCharacteristics.value.isNotEmpty;
  }

  BleBloc(this.settingsBloc) {
    unawaited(_initialize());
  }

  Future<void> _initialize() async {
    await FlutterBluePlus.setOptions(restoreState: true);
    FlutterBluePlus.setLogLevel(LogLevel.error);
    _adapterStateSubscription =
        FlutterBluePlus.adapterState.listen((state) {
      updateBluetoothStatus(state == BluetoothAdapterState.on);
    });

    await _initializeBluetoothStatus();
  }

  Future<void> _initializeBluetoothStatus() async {
    final currentState = await FlutterBluePlus.adapterState.first;
    updateBluetoothStatus(currentState == BluetoothAdapterState.on);
  }

  void updateBluetoothStatus(bool isEnabled) {
    if (isBluetoothEnabledNotifier.value != isEnabled) {
      isBluetoothEnabledNotifier.value = isEnabled;
    }
  }

  Future<void> startScanning() async {
    if (_hasDeviceConnection()) {
      disconnectDevice();
    }

    await _cancelScanSubscriptions();
    discoveredDevicesNotifier.value = [];
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
    return selectedDeviceNotifier.value != null || isConnected;
  }

  void _onScanResults(List<ScanResult> results) {
    final devices = <BluetoothDevice>[];
    for (final result in results) {
      if (result.device.platformName.startsWith('senseBox')) {
        devices.add(result.device);
      }
    }
    discoveredDevicesNotifier.value = devices;
  }

  void disconnectDevice() {
    _userInitiatedDisconnect = true;
    selectedDeviceNotifier.value?.disconnect();
    _clearSelectedDevice();
    availableCharacteristics.value = [];
    _reconnectionListener?.cancel();
    _reconnectionListener = null;
    resetConnectionError();
    _resetReconnectionState();
  }

  Future<BleConnectionResult?> connectToId(String id) async {
    resetConnectionError();
    await stopScanning();

    try {
      await FlutterBluePlus.startScan(
        withNames: [id],
        timeout: deviceConnectTimeout,
      );

      await for (final results
          in FlutterBluePlus.scanResults.timeout(deviceConnectTimeout)) {
        final device = _findScannedDevice(results, id);
        if (device == null) {
          continue;
        }

        await stopScanning();
        return connectToDevice(device);
      }
    } on TimeoutException {
      return null;
    } finally {
      await stopScanning();
    }

    return null;
  }

  BluetoothDevice? _findScannedDevice(List<ScanResult> results, String id) {
    for (final result in results) {
      if (result.device.advName.toString() == id) {
        return result.device;
      }
    }
    return null;
  }

  Future<BleConnectionResult> connectToDevice(BluetoothDevice device) async {
    try {
      resetConnectionError();
      _setConnectionPhase(BleConnectionPhase.connecting);

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
        _completeConnection(device);
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
      if (_connectionPhase == BleConnectionPhase.connecting) {
        _setConnectionPhase(BleConnectionPhase.idle);
      }
    }
  }

  void _completeConnection(BluetoothDevice device) {
    _handleDeviceReconnection(device);
    selectedDeviceNotifier.value = device;
    _userInitiatedDisconnect = false;
    _setConnectionPhase(BleConnectionPhase.connected);
  }

  Future<BleConnectionResult> _reconnectWithRetries(
    BluetoothDevice device,
  ) async {
    BleConnectionResult? lastResult;

    for (var attempt = 0; attempt < _maxReconnectionAttempts; attempt++) {
      lastResult = await _attemptSingleConnection(
        device,
        updateConnectionState: false,
      );

      if (lastResult.success) {
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

    _handlePermanentConnectionLoss();

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
        _userInitiatedDisconnect = false;
        _setConnectionPhase(BleConnectionPhase.connected);
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

      final characteristic = characteristics[i];
      try {
        await _listenToCharacteristic(characteristic);
        subscribed.add(characteristic);
      } catch (e, stack) {
        debugPrint(
          'BLE subscribe failed for ${_characteristicUuid(characteristic)}: $e\n$stack',
        );
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
    selectedDeviceNotifier.value = null;
    _setConnectionPhase(BleConnectionPhase.idle);
  }

  void _setConnectionPhase(BleConnectionPhase phase) {
    if (_connectionPhase == phase) {
      return;
    }

    _connectionPhase = phase;
    connectionPhaseNotifier.value = phase;
    isConnectingNotifier.value = phase == BleConnectionPhase.connecting;
    isReconnectingNotifier.value = phase == BleConnectionPhase.reconnecting;
  }

  static String _characteristicUuid(BluetoothCharacteristic characteristic) {
    return characteristic.uuid.toString().toLowerCase();
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

  void _handleDeviceReconnection(BluetoothDevice device) {
    _reconnectionListener?.cancel();

    _userInitiatedDisconnect = false;
    _hasVibrated = false;

    _reconnectionListener = device.connectionState.listen((state) {
      if (state == BluetoothConnectionState.disconnected &&
          !_userInitiatedDisconnect &&
          _connectionPhase != BleConnectionPhase.reconnecting &&
          _connectionPhase != BleConnectionPhase.connecting) {
        _beginReconnection(device);
      }
    });

    _reconnectionListener?.onError((error) {
      _handlePermanentConnectionLoss();
    });
  }

  void _beginReconnection(BluetoothDevice device) {
    if (_connectionPhase == BleConnectionPhase.reconnecting) {
      return;
    }

    _setConnectionPhase(BleConnectionPhase.reconnecting);
    unawaited(_runReconnection(device));
  }

  Future<void> _runReconnection(BluetoothDevice device) async {
    if (!_hasVibrated && settingsBloc.vibrateOnDisconnect) {
      Vibration.vibrate();
      _hasVibrated = true;
    }

    final result = await _reconnectWithRetries(device);

    if (result.success) {
      selectedDeviceNotifier.value = device;
      _userInitiatedDisconnect = false;
      _resetReconnectionCounters();
      _setConnectionPhase(BleConnectionPhase.connected);
    }
  }

  void _handlePermanentConnectionLoss() {
    _clearSelectedDevice();
    connectionErrorNotifier.value = true;

    _reconnectionListener?.cancel();
    _reconnectionListener = null;

    _clearCharacteristicStreams();
    _resetReconnectionCounters();
    isConnectingNotifier.value = false;
  }

  void resetConnectionError() {
    connectionErrorNotifier.value = false;

    _reconnectionListener?.cancel();
    _reconnectionListener = null;

    _resetReconnectionState();
  }

  void _resetReconnectionState() {
    _resetReconnectionCounters();
    if (_connectionPhase == BleConnectionPhase.reconnecting) {
      _setConnectionPhase(BleConnectionPhase.idle);
    } else {
      isReconnectingNotifier.value = false;
    }
  }

  void _resetReconnectionCounters() {
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

  void dispose() {
    _adapterStateSubscription?.cancel();
    _cancelScanSubscriptions();
    _reconnectionListener?.cancel();
    _clearCharacteristicStreams();
    isBluetoothEnabledNotifier.dispose();
    isScanningNotifier.dispose();
    isConnectingNotifier.dispose();
    isReconnectingNotifier.dispose();
    connectionPhaseNotifier.dispose();
    selectedDeviceNotifier.dispose();
    discoveredDevicesNotifier.dispose();
    availableCharacteristics.dispose();
    characteristicStreamsVersion.dispose();
    connectionErrorNotifier.dispose();
  }

  Future<void> requestEnableBluetooth() async {
    return FlutterBluePlus.turnOn();
  }
}
