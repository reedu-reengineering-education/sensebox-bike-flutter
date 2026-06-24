import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:sensebox_bike/ble/ble_characteristic_helpers.dart';
import 'package:sensebox_bike/ble/ble_characteristic_ref.dart';
import 'package:sensebox_bike/ble/ble_platform.dart';

class BleCharacteristicStreams {
  BleCharacteristicStreams({required BlePlatform platform}) : _platform = platform;

  final BlePlatform _platform;
  final Map<String, StreamController<List<double>>> _streams = {};
  final Map<String, StreamSubscription<List<int>>> _subscriptions = {};
  final Set<String> _livePayloadUuids = {};
  final ValueNotifier<int> livePayloadVersion = ValueNotifier(0);

  Iterable<String> get subscribedCharacteristicUuids => _streams.keys;

  bool hasLivePayload(String characteristicUuid) =>
      _livePayloadUuids.contains(characteristicUuid);

  static bool isLivePayload(List<double> values) => values.isNotEmpty;

  Stream<List<double>> characteristicStream(String characteristicUuid) {
    if (!_streams.containsKey(characteristicUuid)) {
      throw Exception(
        'Characteristic stream not found for UUID: $characteristicUuid. '
        'The characteristic may not be available yet or the device may not be connected.',
      );
    }
    return _streams[characteristicUuid]!.stream;
  }

  Future<void> subscribe(BleCharacteristicRef characteristic) async {
    final uuid = characteristic.uuidString;

    await _subscriptions[uuid]?.cancel();
    _subscriptions.remove(uuid);
    _livePayloadUuids.remove(uuid);

    if (_streams.containsKey(uuid)) {
      await _streams[uuid]?.close();
      _streams.remove(uuid);
    }

    final controller = StreamController<List<double>>.broadcast();
    _streams[uuid] = controller;

    _subscriptions[uuid] =
        _platform.subscribeToCharacteristic(characteristic).listen(
      (value) {
        if (!controller.isClosed) {
          final parsed = parseCharacteristicPayload(Uint8List.fromList(value));
          if (isLivePayload(parsed) && _livePayloadUuids.add(uuid)) {
            livePayloadVersion.value++;
          }
          controller.add(parsed);
        }
      },
    );
  }

  Future<void> clear({
    Iterable<BleCharacteristicRef> characteristics = const [],
  }) async {
    final subscriptions = _subscriptions.values.toList();
    _subscriptions.clear();
    _livePayloadUuids.clear();
    livePayloadVersion.value++;
    for (final subscription in subscriptions) {
      await subscription.cancel();
    }

    final controllers = _streams.values.toList();
    _streams.clear();
    for (final controller in controllers) {
      await controller.close();
    }
  }

  void dispose() {
    livePayloadVersion.dispose();
  }
}
