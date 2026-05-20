import 'dart:async';

import 'dart:typed_data';
import 'package:sensebox_bike/blocs/settings_bloc.dart';
import 'package:sensebox_bike/secrets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import 'package:sensebox_bike/models/ble_connection_result.dart';
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
  final ValueNotifier<BluetoothDevice?> selectedDeviceNotifier =
      ValueNotifier(null);
  final ValueNotifier<List<BluetoothCharacteristic>> availableCharacteristics =
      ValueNotifier([]);
  final ValueNotifier<int> characteristicStreamsVersion = ValueNotifier(0);
  final ValueNotifier<bool> connectionErrorNotifier = ValueNotifier(false);
  final ValueNotifier<bool> isReadyForRecordingNotifier = ValueNotifier(false);

  List<String> failedCharacteristicUuids = [];
  late final VoidCallback _readyForRecordingDependencyListener;
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

  StreamSubscription<BluetoothConnectionState>? _reconnectionListener;
  StreamSubscription<List<ScanResult>>? _scanResultsSubscription;
  StreamSubscription<bool>? _isScanningSubscription;
  StreamSubscription<List<ScanResult>>? _connectToIdScanSubscription;
  Timer? _connectToIdTimeout;

  BluetoothService? _pendingSenseBoxService;
  List<String> _pendingValidUuids = [];

  final Map<String, StreamController<List<double>>> _characteristicStreams = {};
  final Map<String, StreamSubscription<List<int>>>
      _characteristicSubscriptions = {};

  bool get isConnected => _isConnected;

  /// True while a partial connection is live but the user has not confirmed
  /// via the blocking dialog yet.
  bool get isAwaitingPartialConnectionAcceptance =>
      _pendingSenseBoxService != null;

  bool get isReadyForRecording {
    final device = selectedDevice;
    return _isConnected &&
        !isAwaitingPartialConnectionAcceptance &&
        device != null &&
        device.isConnected &&
        !_isReconnecting &&
        !isConnectingNotifier.value &&
        !connectionErrorNotifier.value &&
        availableCharacteristics.value.isNotEmpty;
  }

  BleBloc(this.settingsBloc) {
    _readyForRecordingDependencyListener = _syncReadyForRecordingNotifier;
    selectedDeviceNotifier.addListener(_readyForRecordingDependencyListener);
    availableCharacteristics.addListener(_readyForRecordingDependencyListener);
    connectionErrorNotifier.addListener(_readyForRecordingDependencyListener);
    isReconnectingNotifier.addListener(_readyForRecordingDependencyListener);
    isConnectingNotifier.addListener(_readyForRecordingDependencyListener);

    FlutterBluePlus.setLogLevel(LogLevel.error);
    FlutterBluePlus.adapterState.listen((state) {
      updateBluetoothStatus(state == BluetoothAdapterState.on);
    });

    _initializeBluetoothStatus();
  }

  void _syncReadyForRecordingNotifier() {
    final ready = isReadyForRecording;
    if (isReadyForRecordingNotifier.value != ready) {
      isReadyForRecordingNotifier.value = ready;
    }
  }

  Future<void> _initializeBluetoothStatus() async {
    BluetoothAdapterState currentState =
        await FlutterBluePlus.adapterState.first;
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

    isScanningNotifier.value = true;

    try {
      await FlutterBluePlus.startScan(timeout: deviceConnectTimeout);
    } catch (e) {
      isScanningNotifier.value = false;
      throw ScanPermissionDenied();
    }

    await _cancelScanSubscriptions();
    _scanResultsSubscription =
        FlutterBluePlus.scanResults.listen(_onScanResults);
    _isScanningSubscription = FlutterBluePlus.isScanning.listen((scanning) {
      isScanningNotifier.value = scanning;
    });
  }

  Future<void> _cancelScanSubscriptions() async {
    await _scanResultsSubscription?.cancel();
    _scanResultsSubscription = null;
    await _isScanningSubscription?.cancel();
    _isScanningSubscription = null;
  }

  Future<void> _cancelConnectToIdScanSubscription() async {
    _connectToIdTimeout?.cancel();
    _connectToIdTimeout = null;
    await _connectToIdScanSubscription?.cancel();
    _connectToIdScanSubscription = null;
  }

  Future<void> stopScanning() async {
    await FlutterBluePlus.stopScan();
    await _cancelScanSubscriptions();
    isScanningNotifier.value = false;
  }

  bool _hasDeviceConnection() {
    return selectedDevice != null ||
        _isConnected ||
        _pendingSenseBoxService != null;
  }

  void _onScanResults(List<ScanResult> results) {
    final devices = <BluetoothDevice>[];
    for (final result in results) {
      if (result.device.platformName.startsWith('senseBox')) {
        devices.add(result.device);
      }
    }
    _devicesListController.add(devices);
  }

  void _setSelectedDevice(BluetoothDevice? device) {
    selectedDevice = device;
    selectedDeviceNotifier.value = device;
  }

  void _clearSelectedDevice() {
    _setSelectedDevice(null);
    _isConnected = false;
    _syncReadyForRecordingNotifier();
  }

  void _invalidateCharacteristicStreams() {
    _clearCharacteristicStreams();
    availableCharacteristics.value = [];
    characteristicStreamsVersion.value++;
  }

  void _clearReconnectionState({
    bool clearConnectionError = false,
    bool cancelReconnectionListener = false,
    bool clearConnecting = false,
  }) {
    if (clearConnectionError) {
      connectionErrorNotifier.value = false;
    }
    if (cancelReconnectionListener) {
      _reconnectionListener?.cancel();
      _reconnectionListener = null;
    }
    _isReconnecting = false;
    _isInRetryMode = false;
    _reconnectionAttempts = 0;
    _hasVibrated = false;
    isReconnectingNotifier.value = false;
    if (clearConnecting) {
      isConnectingNotifier.value = false;
    }
  }

  void disconnectDevice() {
    _userInitiatedDisconnect = true;
    selectedDevice?.disconnect();
    _clearSelectedDevice();
    _invalidateCharacteristicStreams();
    failedCharacteristicUuids = [];
    _clearPendingConnection();
    _reconnectionListener?.cancel();
    _reconnectionListener = null;
    resetConnectionError();
  }

  Future<BleConnectionResult?> connectToId(String id, BuildContext context) async {
    resetConnectionError();

    await _cancelConnectToIdScanSubscription();
    final resultCompleter = Completer<BleConnectionResult?>();

    await FlutterBluePlus.startScan(withNames: [id], timeout: deviceConnectTimeout);

    _connectToIdTimeout = Timer(deviceConnectTimeout, () async {
      await _cancelConnectToIdScanSubscription();
      try {
        await FlutterBluePlus.stopScan();
      } catch (_) {
        // Scan may already be stopped.
      }
      if (!resultCompleter.isCompleted) {
        resultCompleter.complete(null);
      }
    });

    _connectToIdScanSubscription =
        FlutterBluePlus.scanResults.listen((results) async {
      for (ScanResult result in results) {
        if (result.device.advName.toString() != id) {
          continue;
        }

        _connectToIdTimeout?.cancel();
        _connectToIdTimeout = null;
        await _cancelConnectToIdScanSubscription();
        try {
          await FlutterBluePlus.stopScan();
        } catch (_) {
          // Scan may already be stopped.
        }

        final connectionResult =
            await connectToDevice(result.device, context);
        if (!resultCompleter.isCompleted) {
          resultCompleter.complete(connectionResult);
        }
        break;
      }
    });

    return resultCompleter.future;
  }

  Future<BleConnectionResult> connectToDevice(
      BluetoothDevice device, BuildContext context) async {
    try {
      resetConnectionError();
      _clearPendingConnection();

      isConnectingNotifier.value = true;

      if (isScanningNotifier.value == true) {
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

      final result = await _runConnectionAttempt(
        device,
        autoAcceptPartial: false,
      );

      if (result.success) {
        _completeConnection(device, context);
      } else if (result.needsUserDecision) {
        // Preview: show device + live sensor data, but block recording until
        // the user accepts via the partial-connection dialog.
        _setSelectedDevice(device);
        _syncReadyForRecordingNotifier();
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
    }
  }

  Future<BleConnectionResult> finalizePartialConnection(
    BluetoothDevice device,
    BuildContext context,
  ) async {
    if (_pendingSenseBoxService == null || _pendingValidUuids.isEmpty) {
      return BleConnectionResult.failure(
        reason: BleConnectionFailureReason.bluetoothError,
      );
    }

    try {
      final validUuids = _pendingValidUuids.toSet();
      final characteristics = _pendingSenseBoxService!.characteristics
          .where((c) => validUuids.contains(_characteristicUuid(c)))
          .toList();

      failedCharacteristicUuids = _pendingSenseBoxService!.characteristics
          .map(_characteristicUuid)
          .where(
            (uuid) =>
                knownSensorCharacteristicUuids.contains(uuid) &&
                !validUuids.contains(uuid),
          )
          .toList();

      final subscribed = _characteristicsAlreadySubscribed(characteristics)
          ? characteristics
          : await _applyConnection(device, characteristics);
      if (subscribed.isEmpty) {
        _clearPendingConnection();
        return BleConnectionResult.failure(
          reason: BleConnectionFailureReason.noData,
        );
      }

      _completeConnection(device, context);
      _clearPendingConnection();

      return BleConnectionResult.fullSuccess();
    } catch (e) {
      await _disconnectDeviceSafe(device);
      _clearPendingConnection();
      return BleConnectionResult.failure(
        reason: BleConnectionFailureReason.bluetoothError,
      );
    }
  }

  bool _characteristicsAlreadySubscribed(
    List<BluetoothCharacteristic> characteristics,
  ) {
    if (characteristics.isEmpty) {
      return false;
    }

    final activeUuids =
        availableCharacteristics.value.map(_characteristicUuid).toSet();
    return characteristics.every(
      (characteristic) =>
          activeUuids.contains(_characteristicUuid(characteristic)),
    );
  }

  void _completeConnection(BluetoothDevice device, BuildContext context) {
    _handleDeviceReconnection(device, context);
    _setSelectedDevice(device);
    _isConnected = true;
    _userInitiatedDisconnect = false;
    _syncReadyForRecordingNotifier();
  }

  Future<BleConnectionResult> _runConnectionAttempt(
    BluetoothDevice device, {
    bool updateConnectionState = true,
    bool autoAcceptPartial = false,
  }) async {
    try {
      return await _attemptSingleConnection(
        device,
        updateConnectionState: updateConnectionState,
        autoAcceptPartial: autoAcceptPartial,
      );
    } catch (e) {
      return BleConnectionResult.failure(
        reason: BleConnectionResult.fromException(e),
      );
    }
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
        _syncReadyForRecordingNotifier();
      }

      lastResult = await _runConnectionAttempt(
        device,
        updateConnectionState: false,
        autoAcceptPartial: true,
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
    _handleConnectionError(context: context, isInitialConnection: false);

    return lastResult ??
        BleConnectionResult.failure(reason: BleConnectionFailureReason.noData);
  }

  Future<BleConnectionResult> _attemptSingleConnection(
    BluetoothDevice device, {
    bool updateConnectionState = true,
    bool autoAcceptPartial = false,
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

      final subscribedUuids =
          subscribed.map(_characteristicUuid).toSet();

      final probes = knownCharacteristics.map((characteristic) {
        final uuid = _characteristicUuid(characteristic);
        final isValid = subscribedUuids.contains(uuid);
        return BleCharacteristicProbeResult(
          uuid: uuid,
          isValid: isValid,
          reason: isValid ? null : BleConnectionFailureReason.noData,
        );
      }).toList();

      failedCharacteristicUuids =
          probes.where((probe) => !probe.isValid).map((probe) => probe.uuid).toList();

      if (subscribed.isNotEmpty &&
          failedCharacteristicUuids.isNotEmpty &&
          !autoAcceptPartial) {
        _pendingSenseBoxService = senseBoxService;
        _pendingValidUuids = subscribed.map(_characteristicUuid).toList();
        return BleConnectionResult.needsUserDecision(probes: probes);
      }

      if (updateConnectionState) {
        _markConnected();
      }
      return BleConnectionResult.fullSuccess(probes: probes);
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
    _syncReadyForRecordingNotifier();
    return subscribed;
  }

  Future<void> _disconnectDeviceSafe(BluetoothDevice device) async {
    try {
      await device.disconnect();
    } catch (e) {
      // Device may already be disconnected
    }
  }

  void _clearPendingConnection() {
    _pendingSenseBoxService = null;
    _pendingValidUuids = [];
  }

  static String _characteristicUuid(BluetoothCharacteristic characteristic) {
    return characteristic.uuid.toString().toLowerCase();
  }

  void _markConnected() {
    _isConnected = true;
    _userInitiatedDisconnect = false;
    _syncReadyForRecordingNotifier();
  }

  /// Disconnects and reconnects before the next connection attempt.
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
    for (var subscription in _characteristicSubscriptions.values) {
      subscription.cancel();
    }
    _characteristicSubscriptions.clear();

    for (var controller in _characteristicStreams.values) {
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

  void _handleDeviceReconnection(BluetoothDevice device, BuildContext context) {
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
              await _startReconnectionProcess(device, context);
            } catch (e, stackTrace) {
              ErrorService.logToConsole(e, stackTrace);
              _clearReconnectionState();
            }
          }
        }
      } catch (e, stackTrace) {
        ErrorService.logToConsole(e, stackTrace);
      }
    });

    _reconnectionListener?.onError((error) {
      _handleConnectionError(context: context, isInitialConnection: false);
    });
  }

  Future<void> _startReconnectionProcess(
    BluetoothDevice device,
    BuildContext context,
  ) async {
    if (_isReconnecting) {
      if (_reconnectionAttempts >= _maxReconnectionAttempts) {
        _clearReconnectionState();
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
      _setSelectedDevice(device);
      _userInitiatedDisconnect = false;
      _clearReconnectionState();
    }

    if (!result.success &&
        _reconnectionAttempts >= _maxReconnectionAttempts) {
      _handleConnectionError(context: context, isInitialConnection: false);
    }
  }

  void _handleConnectionError(
      {required BuildContext context, bool isInitialConnection = false}) {
    if (isInitialConnection) {
      _clearSelectedDevice();
      _userInitiatedDisconnect = false;
      _clearReconnectionState(clearConnecting: true);
    } else {
      _clearSelectedDevice();
      connectionErrorNotifier.value = true;
      _reconnectionListener?.cancel();
      _reconnectionListener = null;
      _invalidateCharacteristicStreams();
      _clearReconnectionState(clearConnecting: true);
    }
  }

  void resetConnectionError() {
    _clearReconnectionState(
      clearConnectionError: true,
      cancelReconnectionListener: true,
    );
  }

  Future<void> _listenToCharacteristic(
      BluetoothCharacteristic characteristic) async {
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
        List<double> parsedData = _parseData(Uint8List.fromList(value));

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
    List<double> parsedValues = [];
    for (int i = 0; i < value.length; i += 4) {
      if (i + 4 <= value.length) {
        parsedValues.add(
            ByteData.sublistView(value, i, i + 4).getFloat32(0, Endian.little));
      }
    }
    return parsedValues;
  }

  void dispose() {
    selectedDeviceNotifier.removeListener(_readyForRecordingDependencyListener);
    availableCharacteristics.removeListener(_readyForRecordingDependencyListener);
    connectionErrorNotifier.removeListener(_readyForRecordingDependencyListener);
    isReconnectingNotifier.removeListener(_readyForRecordingDependencyListener);
    isConnectingNotifier.removeListener(_readyForRecordingDependencyListener);

    _reconnectionListener?.cancel();
    _cancelScanSubscriptions();
    _cancelConnectToIdScanSubscription();
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
    isReadyForRecordingNotifier.dispose();
  }

  Future<void> requestEnableBluetooth() async {
    return FlutterBluePlus.turnOn();
  }
}
