import 'dart:async';

import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:sensebox_bike/services/ble/ble_client.dart';
import 'package:sensebox_bike/services/ble/sensebox_constants.dart';
import 'package:sensebox_bike/services/ble/sensebox_device.dart';

class ReactiveBleClient implements BleClient {
  final FlutterReactiveBle _ble = FlutterReactiveBle();
  final Uuid _senseBoxServiceUuid = Uuid.parse(senseBoxServiceUuid);

  final Map<String, SenseBoxDevice> _devices = {};
  final Map<String, StreamController<BleConnectionState>>
      _connectionStateControllers = {};
  final Map<String, StreamSubscription<ConnectionStateUpdate>>
      _connectionSubscriptions = {};
  final Map<String, StreamSubscription<List<int>>> _notifySubscriptions = {};

  StreamSubscription<DiscoveredDevice>? _scanSubscription;
  Timer? _scanTimeoutTimer;
  List<String>? _scanNameFilter;

  final StreamController<bool> _adapterEnabledController =
      StreamController.broadcast();
  final StreamController<bool> _scanningController =
      StreamController.broadcast();
  final StreamController<List<SenseBoxDevice>> _scanResultsController =
      StreamController.broadcast();

  StreamSubscription<BleStatus>? _statusSubscription;
  bool _isScanning = false;

  ReactiveBleClient() {
    _statusSubscription = _ble.statusStream.listen((status) {
      _adapterEnabledController.add(status == BleStatus.ready);
    });
  }

  Future<void> _ensureReady() async {
    await _ble.initialize();
    final status = await _ble.statusStream
        .firstWhere((status) => status != BleStatus.unknown);
    if (status != BleStatus.ready) {
      throw Exception('Bluetooth adapter is not ready: $status');
    }
  }

  @override
  Stream<bool> get isAdapterEnabledStream => _adapterEnabledController.stream;

  @override
  Future<bool> isAdapterEnabled() async {
    await _ble.initialize();
    return _ble.status == BleStatus.ready;
  }

  @override
  Future<void> requestEnableBluetooth() async {
    // flutter_reactive_ble does not expose a turn-on API; user must enable BT in settings.
  }

  @override
  Stream<bool> get isScanningStream => _scanningController.stream;

  @override
  Future<void> startScan({
    Duration timeout = deviceConnectTimeout,
    List<String>? withNames,
  }) async {
    await _ensureReady();
    await stopScan();

    _scanNameFilter = withNames;
    _isScanning = true;
    _scanningController.add(true);

    final discovered = <String, SenseBoxDevice>{};
    _scanSubscription = _ble
        .scanForDevices(
      withServices: [_senseBoxServiceUuid],
      scanMode: ScanMode.lowLatency,
    )
        .listen(
      (device) {
        if (!device.name.startsWith('senseBox')) {
          return;
        }
        if (_scanNameFilter != null &&
            _scanNameFilter!.isNotEmpty &&
            !_scanNameFilter!.any(
              (name) => device.name == name || device.id == name,
            )) {
          return;
        }

        final senseBoxDevice = _toSenseBoxDevice(device);
        _devices[device.id] = senseBoxDevice;
        discovered[device.id] = senseBoxDevice;
        _scanResultsController.add(discovered.values.toList());
      },
      onError: (_) {
        _finishScan();
        throw Exception('scan failed');
      },
    );

    _scanTimeoutTimer = Timer(timeout, stopScan);
  }

  @override
  Future<void> stopScan() async {
    _scanTimeoutTimer?.cancel();
    _scanTimeoutTimer = null;
    await _scanSubscription?.cancel();
    _scanSubscription = null;
    _scanNameFilter = null;
    _finishScan();
  }

  void _finishScan() {
    if (!_isScanning) return;
    _isScanning = false;
    _scanningController.add(false);
  }

  @override
  Stream<List<SenseBoxDevice>> get scanResultsStream =>
      _scanResultsController.stream;

  @override
  Future<void> connect(String deviceId, {Duration? timeout}) async {
    await _ensureReady();

    final completer = Completer<void>();
    await _connectionSubscriptions[deviceId]?.cancel();

    final controller = _connectionStateController(deviceId);
    _connectionSubscriptions[deviceId] = _ble
        .connectToAdvertisingDevice(
      id: deviceId,
      withServices: [_senseBoxServiceUuid],
      prescanDuration: const Duration(seconds: 5),
      connectionTimeout: timeout ?? deviceConnectTimeout,
    )
        .listen(
      (update) {
        controller.add(_mapConnectionState(update.connectionState));
        if (update.connectionState == DeviceConnectionState.connected &&
            !completer.isCompleted) {
          completer.complete();
        }
        if (update.connectionState == DeviceConnectionState.disconnected &&
            update.failure != null &&
            !completer.isCompleted) {
          completer.completeError(Exception(update.failure.toString()));
        }
      },
      onError: (Object error) {
        if (!completer.isCompleted) {
          completer.completeError(error);
        }
      },
    );

    await completer.future.timeout(
      timeout ?? deviceConnectTimeout,
      onTimeout: () => throw Exception('Connection timed out'),
    );
  }

  @override
  Future<void> disconnect(String deviceId) async {
    for (final subscription in _notifySubscriptions.values) {
      await subscription.cancel();
    }
    _notifySubscriptions.clear();

    await _connectionSubscriptions[deviceId]?.cancel();
    _connectionSubscriptions.remove(deviceId);
    _connectionStateController(deviceId).add(BleConnectionState.disconnected);
  }

  @override
  Stream<BleConnectionState> connectionStateStream(String deviceId) {
    return _connectionStateController(deviceId).stream;
  }

  @override
  Future<List<BleCharacteristicRef>> discoverCharacteristics(
    String deviceId,
    String serviceUuid,
  ) async {
    await _ble.discoverAllServices(deviceId);
    final services = await _ble.getDiscoveredServices(deviceId);
    final service = services.firstWhere(
      (service) =>
          service.id.toString().toUpperCase() == serviceUuid.toUpperCase(),
      orElse: () => throw Exception('Service not found: $serviceUuid'),
    );

    return service.characteristics
        .map(
          (characteristic) => BleCharacteristicRef(
            serviceUuid: serviceUuid,
            characteristicUuid: characteristic.id.toString(),
          ),
        )
        .toList();
  }

  @override
  Stream<List<int>> subscribeToCharacteristic(
    String deviceId,
    BleCharacteristicRef characteristic,
  ) {
    final key = _notifyKey(deviceId, characteristic);
    _notifySubscriptions[key]?.cancel();

    final qualified = QualifiedCharacteristic(
      serviceId: Uuid.parse(characteristic.serviceUuid),
      characteristicId: Uuid.parse(characteristic.characteristicUuid),
      deviceId: deviceId,
    );

    final controller = StreamController<List<int>>.broadcast();
    _notifySubscriptions[key] =
        _ble.subscribeToCharacteristic(qualified).listen(
      controller.add,
      onError: controller.addError,
    );

    return controller.stream;
  }

  @override
  Future<void> unsubscribeFromCharacteristic(
    String deviceId,
    BleCharacteristicRef characteristic,
  ) async {
    final key = _notifyKey(deviceId, characteristic);
    await _notifySubscriptions[key]?.cancel();
    _notifySubscriptions.remove(key);
  }

  StreamController<BleConnectionState> _connectionStateController(
    String deviceId,
  ) {
    return _connectionStateControllers.putIfAbsent(
      deviceId,
      () => StreamController<BleConnectionState>.broadcast(),
    );
  }

  SenseBoxDevice _toSenseBoxDevice(DiscoveredDevice device) {
    return SenseBoxDevice(
      id: device.id,
      displayName: device.name.isNotEmpty ? device.name : '(Unknown)',
      advName: device.name.isNotEmpty ? device.name : null,
    );
  }

  BleConnectionState _mapConnectionState(DeviceConnectionState state) {
    switch (state) {
      case DeviceConnectionState.connecting:
        return BleConnectionState.connecting;
      case DeviceConnectionState.connected:
        return BleConnectionState.connected;
      case DeviceConnectionState.disconnecting:
        return BleConnectionState.disconnecting;
      case DeviceConnectionState.disconnected:
        return BleConnectionState.disconnected;
    }
  }

  String _notifyKey(String deviceId, BleCharacteristicRef characteristic) {
    return '$deviceId:${characteristic.characteristicUuid}';
  }

  @override
  void dispose() {
    _statusSubscription?.cancel();
    _scanTimeoutTimer?.cancel();
    _scanSubscription?.cancel();
    for (final subscription in _connectionSubscriptions.values) {
      subscription.cancel();
    }
    for (final subscription in _notifySubscriptions.values) {
      subscription.cancel();
    }
    for (final controller in _connectionStateControllers.values) {
      controller.close();
    }
    _adapterEnabledController.close();
    _scanningController.close();
    _scanResultsController.close();
  }
}
