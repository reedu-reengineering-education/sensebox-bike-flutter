import 'dart:async';

import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:sensebox_bike/ble/ble_constants.dart';
import 'package:sensebox_bike/ble/ble_device.dart';
import 'package:sensebox_bike/ble/ble_uuids.dart';
import 'package:sensebox_bike/services/error_service.dart';

enum BleLinkState {
  disconnected,
  connecting,
  connected,
  disconnecting,
}

enum BleAdapterState {
  unknown,
  unsupported,
  unauthorized,
  poweredOff,
  ready,
}

class BlePlatform {
  BlePlatform({
    FlutterReactiveBle? reactiveBle,
    this.dataStaleTimeout = bleDataStaleTimeout,
  }) : _reactiveBle = reactiveBle ?? FlutterReactiveBle();

  final FlutterReactiveBle _reactiveBle;
  final Duration dataStaleTimeout;

  final StreamController<BleLinkState> _linkStates =
      StreamController<BleLinkState>.broadcast();
  BleLinkState _linkState = BleLinkState.disconnected;
  String? _deviceId;
  StreamSubscription<ConnectionStateUpdate>? _connection;
  Timer? _dataWatchdog;

  Stream<BleAdapterState> get statusStream =>
      _reactiveBle.statusStream.map(_mapAdapterState);

  Stream<BleLinkState> get linkStates => _linkStates.stream;

  bool get isConnected => _linkState == BleLinkState.connected;

  Stream<BleDevice> scanForDevices({List<BleUuid> withServices = const []}) =>
      _reactiveBle
          .scanForDevices(
            withServices: withServices.map(_toUuid).toList(),
            scanMode: ScanMode.lowLatency,
          )
          .map((device) => BleDevice(
                id: device.id,
                name: device.name,
                serviceUuids: [
                  for (final uuid in device.serviceUuids) BleUuid('$uuid'),
                ],
              ));

  Future<void> connect(
    String deviceId, {
    Duration timeout = bleDeviceConnectTimeout,
  }) async {
    await _connection?.cancel();
    _deviceId = deviceId;
    final connected = Completer<void>();

    _connection = _reactiveBle
        .connectToDevice(id: deviceId, connectionTimeout: timeout)
        .listen(
      (update) {
        final state = _mapConnectionState(update.connectionState);
        _emitLinkState(state, error: update.failure);
        if (state == BleLinkState.connected && !connected.isCompleted) {
          connected.complete();
        }
      },
      onError: (Object error, StackTrace stack) {
        _emitLinkState(BleLinkState.disconnected,
            source: 'connect-error', error: error);
        if (!connected.isCompleted) {
          connected.completeError(error, stack);
        }
      },
      onDone: () {
        _emitLinkState(BleLinkState.disconnected,
            source: 'connect-stream-closed');
        if (!connected.isCompleted) {
          connected.completeError(
            TimeoutException('BLE connection stream closed before connected'),
          );
        }
      },
    );

    _emitLinkState(BleLinkState.connecting, source: 'app-connect');
    try {
      await connected.future.timeout(timeout);
    } catch (error) {
      _emitLinkState(BleLinkState.disconnected,
          source: 'connect-failed', error: error);
      rethrow;
    }
  }

  Future<void> disconnect({String source = 'app-disconnect'}) async {
    _emitLinkState(BleLinkState.disconnecting, source: source);
    final connection = _connection;
    _connection = null;
    await connection?.cancel();
    _emitLinkState(BleLinkState.disconnected, source: source);
  }

  Future<List<BleUuid>> discoverCharacteristics() async {
    final deviceId = _connectedDeviceId();
    await _reactiveBle.discoverAllServices(deviceId);
    final services = await _reactiveBle.getDiscoveredServices(deviceId);
    final senseBoxService = services.firstWhere(
      (service) => BleUuid('${service.id}') == senseBoxServiceUuid,
      orElse: () => throw StateError('senseBox service not found'),
    );
    return [
      for (final characteristic in senseBoxService.characteristics)
        BleUuid('${characteristic.id}'),
    ];
  }

  Stream<List<int>> subscribeToCharacteristic(BleUuid characteristic) {
    return _reactiveBle
        .subscribeToCharacteristic(QualifiedCharacteristic(
          serviceId: _toUuid(senseBoxServiceUuid),
          characteristicId: _toUuid(characteristic),
          deviceId: _connectedDeviceId(),
        ))
        .map((value) {
      _armDataWatchdog();
      return value;
    }).handleError((Object error) {
      _emitLinkState(BleLinkState.disconnected,
          source: 'notify-error', error: error);
    });
  }

  String _connectedDeviceId() =>
      _deviceId ?? (throw StateError('No BLE device connected'));

  void _armDataWatchdog() {
    _dataWatchdog?.cancel();
    _dataWatchdog = Timer(dataStaleTimeout, () {
      unawaited(disconnect(source: 'watchdog'));
    });
  }

  void _emitLinkState(
    BleLinkState state, {
    String source = 'platform',
    Object? error,
  }) {
    if (_linkState != state) {
      ErrorService.logEvent('ble', 'link ${state.name}', data: {
        'device': _deviceId,
        'from': _linkState.name,
        'source': source,
        if (error != null) 'error': error.toString(),
      });
    }
    if (state != BleLinkState.connected) {
      _dataWatchdog?.cancel();
    }
    _linkState = state;
    if (!_linkStates.isClosed) {
      _linkStates.add(state);
    }
  }

  Future<void> dispose() async {
    await disconnect();
    await _linkStates.close();
  }

  static Uuid _toUuid(BleUuid uuid) => Uuid.parse(uuid.value);

  static BleAdapterState _mapAdapterState(BleStatus state) {
    switch (state) {
      case BleStatus.ready:
        return BleAdapterState.ready;
      case BleStatus.poweredOff:
      case BleStatus.locationServicesDisabled:
        return BleAdapterState.poweredOff;
      case BleStatus.unauthorized:
        return BleAdapterState.unauthorized;
      case BleStatus.unsupported:
        return BleAdapterState.unsupported;
      case BleStatus.unknown:
        return BleAdapterState.unknown;
    }
  }

  static BleLinkState _mapConnectionState(DeviceConnectionState state) {
    switch (state) {
      case DeviceConnectionState.connected:
        return BleLinkState.connected;
      case DeviceConnectionState.connecting:
        return BleLinkState.connecting;
      case DeviceConnectionState.disconnecting:
        return BleLinkState.disconnecting;
      case DeviceConnectionState.disconnected:
        return BleLinkState.disconnected;
    }
  }
}
