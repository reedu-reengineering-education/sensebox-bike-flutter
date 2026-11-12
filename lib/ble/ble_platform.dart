import 'dart:async';

import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:sensebox_bike/ble/ble_characteristic_ref.dart';
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

bool isBluetoothAdapterEnabled(BleAdapterState status) =>
    status == BleAdapterState.ready;

class BlePlatform {
  BlePlatform({
    FlutterReactiveBle? reactiveBle,
    this.dataStaleTimeout = bleDataStaleTimeout,
  }) : _reactiveBle = reactiveBle ?? FlutterReactiveBle();

  final FlutterReactiveBle _reactiveBle;
  final Duration dataStaleTimeout;

  final Map<String, StreamSubscription<ConnectionStateUpdate>> _connectionSubs =
      {};
  final Map<String, StreamController<BleLinkState>> _linkStateControllers = {};
  final Map<String, BleLinkState> _linkStates = {};
  final Map<String, Set<String>> _characteristics = {};
  final Map<String, Timer> _dataWatchdogs = {};

  Stream<BleAdapterState> get statusStream =>
      _reactiveBle.statusStream.map(_mapAdapterState);

  Future<bool> isAdapterEnabled() async {
    final status = await statusStream.firstWhere(
      (state) => state != BleAdapterState.unknown,
    );
    return isBluetoothAdapterEnabled(status);
  }

  Stream<BleLinkState> connectionState(String deviceId) {
    return _linkStateControllers
        .putIfAbsent(
          deviceId,
          () => StreamController<BleLinkState>.broadcast(),
        )
        .stream;
  }

  bool isConnected(String deviceId) {
    return _linkStates[deviceId] == BleLinkState.connected;
  }

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
    await _connectionSubs[deviceId]?.cancel();
    _connectionSubs.remove(deviceId);

    final connected = Completer<void>();

    _connectionSubs[deviceId] = _reactiveBle
        .connectToDevice(
      id: deviceId,
      connectionTimeout: timeout,
    )
        .listen(
      (update) {
        final state = _mapConnectionState(update.connectionState);
        _emitLinkState(deviceId, state, error: update.failure);
        if (state == BleLinkState.connected && !connected.isCompleted) {
          connected.complete();
        }
      },
      onError: (Object error, StackTrace stack) {
        _emitLinkState(deviceId, BleLinkState.disconnected,
            source: 'connect-error', error: error);
        if (!connected.isCompleted) {
          connected.completeError(error, stack);
        }
      },
      onDone: () {
        _emitLinkState(deviceId, BleLinkState.disconnected,
            source: 'connect-stream-closed');
        if (!connected.isCompleted) {
          connected.completeError(
            TimeoutException('BLE connection stream closed before connected'),
          );
        }
      },
    );

    _emitLinkState(deviceId, BleLinkState.connecting, source: 'app-connect');
    try {
      await connected.future.timeout(timeout);
    } catch (error) {
      _emitLinkState(deviceId, BleLinkState.disconnected,
          source: 'connect-failed', error: error);
      rethrow;
    }
  }

  Future<void> disconnect(
    String deviceId, {
    String source = 'app-disconnect',
  }) async {
    _cancelDataWatchdog(deviceId);
    _emitLinkState(deviceId, BleLinkState.disconnecting, source: source);

    await _connectionSubs[deviceId]?.cancel();
    _connectionSubs.remove(deviceId);

    _characteristics.remove(deviceId);
    _emitLinkState(deviceId, BleLinkState.disconnected, source: source);
  }

  Future<List<BleService>> discoverServices(String deviceId) async {
    await _reactiveBle.discoverAllServices(deviceId);
    final services = await _reactiveBle.getDiscoveredServices(deviceId);
    final discovered = _characteristics.putIfAbsent(deviceId, () => <String>{});
    discovered.clear();

    final result = <BleService>[];
    for (final service in services) {
      final characteristicUuids = <BleUuid>[];
      for (final characteristic in service.characteristics) {
        final uuid = BleUuid(characteristic.id.toString());
        discovered.add(uuid.compact);
        characteristicUuids.add(uuid);
      }
      result.add(
        BleService(
          serviceId: BleUuid(service.id.toString()),
          characteristics: characteristicUuids,
        ),
      );
    }
    return result;
  }

  Stream<List<int>> subscribeToCharacteristic(
    BleCharacteristicRef characteristic,
  ) {
    final discovered = _characteristics[characteristic.deviceId];
    if (discovered == null ||
        !discovered.contains(characteristic.characteristicUuid.compact)) {
      return Stream<List<int>>.error(
        StateError(
          'Characteristic ${characteristic.uuidString} is not available '
          'on device ${characteristic.deviceId}.',
        ),
      );
    }

    final deviceId = characteristic.deviceId;
    return _reactiveBle
        .subscribeToCharacteristic(
      QualifiedCharacteristic(
        serviceId: _toUuid(characteristic.serviceUuid),
        characteristicId: _toUuid(characteristic.characteristicUuid),
        deviceId: deviceId,
      ),
    )
        .map((value) {
      _armDataWatchdog(deviceId);
      return value;
    }).handleError((Object error) {
      _emitLinkState(
        deviceId,
        BleLinkState.disconnected,
        source: 'notify-error',
        error: error,
      );
    });
  }

  void _armDataWatchdog(String deviceId) {
    _dataWatchdogs[deviceId]?.cancel();
    _dataWatchdogs[deviceId] = Timer(dataStaleTimeout, () {
      unawaited(disconnect(deviceId, source: 'watchdog'));
    });
  }

  void _cancelDataWatchdog(String deviceId) {
    _dataWatchdogs.remove(deviceId)?.cancel();
  }

  void _emitLinkState(
    String deviceId,
    BleLinkState state, {
    String source = 'platform',
    Object? error,
  }) {
    final previous = _linkStates[deviceId];
    if (previous != state) {
      ErrorService.logEvent('ble', 'link ${state.name}', data: {
        'device': deviceId,
        'from': previous?.name,
        'source': source,
        if (error != null) 'error': error.toString(),
      });
    }
    if (state != BleLinkState.connected) {
      _cancelDataWatchdog(deviceId);
    }
    _linkStates[deviceId] = state;
    final controller = _linkStateControllers[deviceId];
    if (controller != null && !controller.isClosed) {
      controller.add(state);
    }
  }

  Future<void> dispose() async {
    final deviceIds = _connectionSubs.keys.toList();
    for (final deviceId in deviceIds) {
      await disconnect(deviceId);
    }
    for (final timer in _dataWatchdogs.values) {
      timer.cancel();
    }
    for (final controller in _linkStateControllers.values) {
      await controller.close();
    }

    _dataWatchdogs.clear();
    _linkStateControllers.clear();
    _characteristics.clear();
    _linkStates.clear();
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
