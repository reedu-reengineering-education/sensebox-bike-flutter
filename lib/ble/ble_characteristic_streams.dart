import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:sensebox_bike/ble/ble_characteristic_helpers.dart';

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

  void clear() {
    for (final subscription in _subscriptions.values) {
      subscription.cancel();
    }
    _subscriptions.clear();

    for (final controller in _streams.values) {
      controller.close();
    }
    _streams.clear();
  }
}
