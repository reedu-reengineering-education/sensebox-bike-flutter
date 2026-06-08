import 'dart:async';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';
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

/// Library-agnostic adapter power state.
enum BleAdapterState {
  unknown,
  unsupported,
  unauthorized,
  poweredOff,
  ready,
}

/// Thin wrapper around the underlying BLE library (flutter_blue_plus) that
/// exposes only library-agnostic types to the rest of the app.
class BlePlatform {
  BlePlatform();

  final Map<String, BluetoothDevice> _devices = {};
  final Map<String, StreamSubscription<BluetoothConnectionState>>
      _connectionSubs = {};
  final Map<String, StreamController<BleLinkState>> _linkStateControllers = {};
  final Map<String, Map<String, BluetoothCharacteristic>> _characteristics = {};

  Stream<BleAdapterState> get statusStream =>
      FlutterBluePlus.adapterState.map(_mapAdapterState);

  Future<void> initialize() async {
    FlutterBluePlus.setLogLevel(LogLevel.error);
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
    final controller = _linkStateControllers[deviceId];
    return _connectionSubs.containsKey(deviceId) &&
        controller != null &&
        !controller.isClosed;
  }

  Stream<BleDevice> scanForDevices({
    List<BleUuid> withServices = const [],
  }) {
    late final StreamController<BleDevice> controller;
    StreamSubscription<List<ScanResult>>? scanSubscription;

    controller = StreamController<BleDevice>(
      onListen: () async {
        scanSubscription = FlutterBluePlus.scanResults.listen(
          (results) {
            for (final result in results) {
              if (!controller.isClosed) {
                controller.add(_bleDeviceFromScanResult(result));
              }
            }
          },
          onError: controller.addError,
        );
        FlutterBluePlus.cancelWhenScanComplete(scanSubscription!);
        try {
          await FlutterBluePlus.startScan(
            androidScanMode: AndroidScanMode.lowLatency,
            withServices: withServices.map(_toGuid).toList(),
          );
        } catch (error, stack) {
          controller.addError(error, stack);
        }
      },
      onCancel: () async {
        await scanSubscription?.cancel();
        scanSubscription = null;
        try {
          await FlutterBluePlus.stopScan();
        } catch (_) {}
      },
    );

    return controller.stream;
  }

  Future<void> connect(
    String deviceId, {
    Duration timeout = bleDeviceConnectTimeout,
  }) async {
    final device = _deviceFor(deviceId);

    await _connectionSubs[deviceId]?.cancel();
    _connectionSubs[deviceId] = device.connectionState.listen((state) {
      switch (state) {
        case BluetoothConnectionState.connected:
          _emitLinkState(deviceId, BleLinkState.connected);
        case BluetoothConnectionState.disconnected:
          _emitLinkState(deviceId, BleLinkState.disconnected);
        default:
          break;
      }
    });

    _emitLinkState(deviceId, BleLinkState.connecting);
    try {
      await device.connect(timeout: timeout);
      _emitLinkState(deviceId, BleLinkState.connected);
    } catch (error) {
      _emitLinkState(deviceId, BleLinkState.disconnected);
      rethrow;
    }
  }

  Future<void> disconnect(String deviceId) async {
    _emitLinkState(deviceId, BleLinkState.disconnecting);
    final device = _devices[deviceId];
    try {
      await device?.disconnect();
    } catch (_) {}
    await _connectionSubs[deviceId]?.cancel();
    _connectionSubs.remove(deviceId);
    _characteristics.remove(deviceId);
    _emitLinkState(deviceId, BleLinkState.disconnected);
  }

  Future<List<BleService>> discoverServices(String deviceId) async {
    final device = _deviceFor(deviceId);
    final services = await device.discoverServices();
    final charMap = _characteristics.putIfAbsent(deviceId, () => {});
    charMap.clear();

    final result = <BleService>[];
    for (final service in services) {
      final characteristicUuids = <BleUuid>[];
      for (final characteristic in service.characteristics) {
        final uuid = BleUuid(characteristic.uuid.str);
        charMap[uuid.compact] = characteristic;
        characteristicUuids.add(uuid);
      }
      result.add(
        BleService(
          serviceId: BleUuid(service.uuid.str),
          characteristics: characteristicUuids,
        ),
      );
    }
    return result;
  }

  Stream<List<int>> subscribeToCharacteristic(
    BleCharacteristicRef characteristic,
  ) {
    late final StreamController<List<int>> controller;
    StreamSubscription<List<int>>? valueSubscription;
    final target = _characteristics[characteristic.deviceId]
        ?[characteristic.characteristicUuid.compact];

    controller = StreamController<List<int>>(
      onListen: () async {
        if (target == null) {
          controller.addError(
            StateError(
              'Characteristic ${characteristic.uuidString} is not available '
              'on device ${characteristic.deviceId}.',
            ),
          );
          return;
        }
        try {
          await target.setNotifyValue(true);
        } catch (error, stack) {
          controller.addError(error, stack);
          return;
        }
        valueSubscription = target.onValueReceived.listen(
          controller.add,
          onError: controller.addError,
        );
      },
      onCancel: () async {
        await valueSubscription?.cancel();
        valueSubscription = null;
        try {
          await target
              ?.setNotifyValue(false)
              .timeout(bleNotificationDisableTimeout);
        } catch (_) {}
      },
    );

    return controller.stream;
  }

  BluetoothDevice _deviceFor(String deviceId) {
    return _devices.putIfAbsent(
      deviceId,
      () => BluetoothDevice.fromId(deviceId),
    );
  }

  BleDevice _bleDeviceFromScanResult(ScanResult result) {
    final device = result.device;
    final deviceId = device.remoteId.str;
    _devices[deviceId] = device;
    return BleDevice(id: deviceId, name: _scanResultDisplayName(result));
  }

  void _emitLinkState(String deviceId, BleLinkState state) {
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
    _devices.clear();
  }

  static Guid _toGuid(BleUuid uuid) => Guid(uuid.value);

  static String _scanResultDisplayName(ScanResult result) {
    final advName = result.advertisementData.advName;
    if (advName.isNotEmpty) {
      return advName;
    }
    if (result.device.advName.isNotEmpty) {
      return result.device.advName;
    }
    return result.device.platformName;
  }

  static BleAdapterState _mapAdapterState(BluetoothAdapterState state) {
    switch (state) {
      case BluetoothAdapterState.on:
        return BleAdapterState.ready;
      case BluetoothAdapterState.off:
      case BluetoothAdapterState.turningOff:
      case BluetoothAdapterState.turningOn:
        return BleAdapterState.poweredOff;
      case BluetoothAdapterState.unauthorized:
        return BleAdapterState.unauthorized;
      case BluetoothAdapterState.unavailable:
        return BleAdapterState.unsupported;
      case BluetoothAdapterState.unknown:
        return BleAdapterState.unknown;
    }
  }
}
