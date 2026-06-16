import 'dart:async';

import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:sensebox_bike/ble/ble_characteristic_ref.dart';
import 'package:sensebox_bike/ble/ble_constants.dart';
import 'package:sensebox_bike/ble/ble_device.dart';
import 'package:sensebox_bike/ble/ble_uuids.dart';

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
  BlePlatform({FlutterReactiveBle? reactiveBle})
      : _reactiveBle = reactiveBle ?? FlutterReactiveBle();

  final FlutterReactiveBle _reactiveBle;

  final Map<String, StreamSubscription<ConnectionStateUpdate>> _connectionSubs =
      {};
  final Map<String, StreamController<BleLinkState>> _linkStateControllers = {};
  final Map<String, BleLinkState> _linkStates = {};
  final Map<String, Set<String>> _characteristics = {};

  Stream<BleAdapterState> get statusStream =>
      _reactiveBle.statusStream.map(_mapAdapterState);

  Future<void> initialize() async {}

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

  Stream<BleDevice> scanForDevices({
    List<BleUuid> withServices = const [],
  }) {
    late final StreamController<BleDevice> controller;
    StreamSubscription<DiscoveredDevice>? scanSubscription;

    controller = StreamController<BleDevice>(
      onListen: () async {
        scanSubscription = _reactiveBle
            .scanForDevices(
          withServices: withServices.map(_toUuid).toList(),
          scanMode: ScanMode.lowLatency,
        )
            .listen(
          (device) {
            if (!controller.isClosed) {
              controller.add(_bleDeviceFromScanResult(device));
            }
          },
          onError: controller.addError,
        );
      },
      onCancel: () async {
        await scanSubscription?.cancel();
        scanSubscription = null;
      },
    );

    return controller.stream;
  }

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
        _emitLinkState(deviceId, state);
        if (state == BleLinkState.connected && !connected.isCompleted) {
          connected.complete();
        }
      },
      onError: (Object error, StackTrace stack) {
        _emitLinkState(deviceId, BleLinkState.disconnected);
        if (!connected.isCompleted) {
          connected.completeError(error, stack);
        }
      },
      onDone: () {
        _emitLinkState(deviceId, BleLinkState.disconnected);
        if (!connected.isCompleted) {
          connected.completeError(
            TimeoutException('BLE connection stream closed before connected'),
          );
        }
      },
    );

    _emitLinkState(deviceId, BleLinkState.connecting);
    try {
      await connected.future.timeout(timeout);
    } catch (error) {
      _emitLinkState(deviceId, BleLinkState.disconnected);
      rethrow;
    }
  }

  /// Scans for the advertising device before connecting.
  ///
  /// The Android BLE stack can hang when connecting to a device that is no
  /// longer in range (e.g. after a supervision timeout). Scanning first and
  /// only connecting once the device advertises avoids that half-open state,
  /// which is the recommended approach for reconnection.
  Future<void> connectToAdvertising(
    String deviceId, {
    required List<BleUuid> withServices,
    Duration prescanDuration = bleReconnectPrescanDuration,
    Duration timeout = bleDeviceConnectTimeout,
  }) async {
    await _connectionSubs[deviceId]?.cancel();
    _connectionSubs.remove(deviceId);

    final connected = Completer<void>();

    _connectionSubs[deviceId] = _reactiveBle
        .connectToAdvertisingDevice(
      id: deviceId,
      withServices: withServices.map(_toUuid).toList(),
      prescanDuration: prescanDuration,
      connectionTimeout: timeout,
    )
        .listen(
      (update) {
        final state = _mapConnectionState(update.connectionState);
        _emitLinkState(deviceId, state);
        if (state == BleLinkState.connected && !connected.isCompleted) {
          connected.complete();
        }
      },
      onError: (Object error, StackTrace stack) {
        _emitLinkState(deviceId, BleLinkState.disconnected);
        if (!connected.isCompleted) {
          connected.completeError(error, stack);
        }
      },
      onDone: () {
        _emitLinkState(deviceId, BleLinkState.disconnected);
        if (!connected.isCompleted) {
          connected.completeError(
            TimeoutException('BLE connection stream closed before connected'),
          );
        }
      },
    );

    _emitLinkState(deviceId, BleLinkState.connecting);
    try {
      await connected.future.timeout(prescanDuration + timeout);
    } catch (error) {
      _emitLinkState(deviceId, BleLinkState.disconnected);
      rethrow;
    }
  }

  Future<void> disconnect(String deviceId) async {
    _emitLinkState(deviceId, BleLinkState.disconnecting);

    await _connectionSubs[deviceId]?.cancel();
    _connectionSubs.remove(deviceId);

    _characteristics.remove(deviceId);
    _emitLinkState(deviceId, BleLinkState.disconnected);
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

    return _reactiveBle
        .subscribeToCharacteristic(
          QualifiedCharacteristic(
            serviceId: _toUuid(characteristic.serviceUuid),
            characteristicId: _toUuid(characteristic.characteristicUuid),
            deviceId: characteristic.deviceId,
          ),
        );
  }

  BleDevice _bleDeviceFromScanResult(DiscoveredDevice device) {
    return BleDevice(id: device.id, name: device.name);
  }

  void _emitLinkState(String deviceId, BleLinkState state) {
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
    for (final controller in _linkStateControllers.values) {
      await controller.close();
    }

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
