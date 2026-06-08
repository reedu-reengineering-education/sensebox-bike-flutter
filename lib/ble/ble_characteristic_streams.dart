import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:sensebox_bike/ble/ble_characteristic_helpers.dart';
import 'package:sensebox_bike/ble/ble_constants.dart';

class BleCharacteristicStreams {
  final Map<String, StreamController<List<double>>> _streams = {};
  final Map<String, StreamSubscription<List<int>>> _subscriptions = {};

  Iterable<String> get subscribedCharacteristicUuids => _streams.keys;

  Stream<List<double>> characteristicStream(String characteristicUuid) {
    if (!_streams.containsKey(characteristicUuid)) {
      throw Exception(
        'Characteristic stream not found for UUID: $characteristicUuid. '
        'The characteristic may not be available yet or the device may not be connected.',
      );
    }
    return _streams[characteristicUuid]!.stream;
  }

  Future<void> subscribe(BluetoothCharacteristic characteristic) async {
    final uuid = characteristic.uuid.toString();

    await _subscriptions[uuid]?.cancel();
    _subscriptions.remove(uuid);

    if (_streams.containsKey(uuid)) {
      await _streams[uuid]?.close();
      _streams.remove(uuid);
    }

    final controller = StreamController<List<double>>.broadcast();
    _streams[uuid] = controller;

    await characteristic.setNotifyValue(true);
    _subscriptions[uuid] = characteristic.onValueReceived.listen((value) {
      if (!controller.isClosed) {
        controller.add(parseCharacteristicPayload(Uint8List.fromList(value)));
      }
    });
  }

  Future<void> subscribeAll(List<BluetoothCharacteristic> characteristics) async {
    for (final characteristic in characteristics) {
      await subscribe(characteristic);
    }
  }

  Future<void> clear({
    Iterable<BluetoothCharacteristic> characteristics = const [],
  }) async {
    final subscriptions = _subscriptions.values.toList();
    _subscriptions.clear();
    for (final subscription in subscriptions) {
      await subscription.cancel();
    }

    final controllers = _streams.values.toList();
    _streams.clear();
    for (final controller in controllers) {
      await controller.close();
    }

    for (final characteristic in characteristics) {
      try {
        await characteristic
            .setNotifyValue(false)
            .timeout(bleNotificationDisableTimeout);
      } catch (_) {}
    }
  }
}
