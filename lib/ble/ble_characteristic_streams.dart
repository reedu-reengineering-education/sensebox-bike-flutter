import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:sensebox_bike/ble/ble_characteristic_helpers.dart';
import 'package:sensebox_bike/ble/ble_constants.dart';
import 'package:sensebox_bike/ble/ble_platform.dart';
import 'package:sensebox_bike/ble/ble_uuids.dart';

class BleCharacteristicStreams {
  BleCharacteristicStreams({
    required BlePlatform platform,
    this.probeTimeout = bleConnectionSessionProbeTimeout,
  }) : _platform = platform;

  final BlePlatform _platform;
  final Duration probeTimeout;
  final Map<String, StreamController<List<double>>> _streams = {};
  final Map<String, StreamSubscription<List<int>>> _subscriptions = {};
  final Set<String> _livePayloadUuids = {};
  final ValueNotifier<int> livePayloadVersion = ValueNotifier(0);

  bool hasLivePayload(String characteristicUuid) =>
      _livePayloadUuids.contains(characteristicUuid);

  Stream<List<double>> characteristicStream(String characteristicUuid) {
    final controller = _streams[characteristicUuid];
    if (controller == null) {
      throw StateError(
        'Characteristic stream not found for UUID: $characteristicUuid',
      );
    }
    return controller.stream;
  }

  Future<List<BleUuid>> establish() async {
    await clear();
    final characteristics = await _platform.discoverCharacteristics();
    if (characteristics.isEmpty) {
      throw StateError('senseBox service has no characteristics');
    }

    final firstPayload = Completer<void>();
    void onLivePayload() {
      if (!firstPayload.isCompleted) {
        firstPayload.complete();
      }
    }

    livePayloadVersion.addListener(onLivePayload);
    try {
      characteristics.forEach(_subscribe);
      await firstPayload.future.timeout(
        probeTimeout,
        onTimeout: () => throw TimeoutException(
          'Connected, but no sensor data received',
          probeTimeout,
        ),
      );
      return characteristics;
    } finally {
      livePayloadVersion.removeListener(onLivePayload);
    }
  }

  void _subscribe(BleUuid characteristic) {
    final uuid = '$characteristic';
    final controller = StreamController<List<double>>.broadcast();
    _streams[uuid] = controller;
    _subscriptions[uuid] =
        _platform.subscribeToCharacteristic(characteristic).listen((value) {
      final parsed = parseCharacteristicPayload(Uint8List.fromList(value));
      if (parsed.isNotEmpty && _livePayloadUuids.add(uuid)) {
        livePayloadVersion.value++;
      }
      controller.add(parsed);
    });
  }

  Future<void> clear() async {
    final subscriptions = _subscriptions.values.toList();
    final controllers = _streams.values.toList();
    _subscriptions.clear();
    _streams.clear();
    _livePayloadUuids.clear();
    livePayloadVersion.value++;
    for (final subscription in subscriptions) {
      await subscription.cancel();
    }
    for (final controller in controllers) {
      await controller.close();
    }
  }

  void dispose() {
    livePayloadVersion.dispose();
  }
}
