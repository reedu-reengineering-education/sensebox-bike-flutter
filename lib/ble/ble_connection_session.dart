import 'dart:async';

import 'package:sensebox_bike/ble/ble_characteristic_helpers.dart';
import 'package:sensebox_bike/ble/ble_characteristic_ref.dart';
import 'package:sensebox_bike/ble/ble_characteristic_streams.dart';
import 'package:sensebox_bike/ble/ble_constants.dart';
import 'package:sensebox_bike/ble/ble_device.dart';
import 'package:sensebox_bike/ble/ble_platform.dart';

class BleConnectionSessionResult {
  final bool success;
  final List<BleCharacteristicRef> characteristics;

  const BleConnectionSessionResult({
    required this.success,
    this.characteristics = const [],
  });
}

class BleConnectionSession {
  BleConnectionSession({
    required BlePlatform platform,
    this.probeTimeout = bleConnectionSessionProbeTimeout,
  }) : _platform = platform;

  final BlePlatform _platform;
  final Duration probeTimeout;

  Future<BleConnectionSessionResult> establish(
    BleDevice device, {
    required BleCharacteristicStreams streams,
  }) async {
    const failure = BleConnectionSessionResult(success: false);
    if (!_platform.isConnected(device.id)) {
      return failure;
    }
    try {
      await streams.clear();
      final services = await _platform.discoverServices(device.id);
      final characteristics = characteristicRefsFromService(
        deviceId: device.id,
        service: findSenseBoxService(services),
      );
      if (characteristics.isEmpty ||
          !await _awaitFirstPayload(characteristics, streams)) {
        return failure;
      }
      return BleConnectionSessionResult(
        success: true,
        characteristics: characteristics,
      );
    } catch (_) {
      return failure;
    }
  }

  Future<bool> _awaitFirstPayload(
    List<BleCharacteristicRef> characteristics,
    BleCharacteristicStreams streams,
  ) async {
    final firstPayload = Completer<void>();
    final subscriptions = <StreamSubscription<List<double>>>[];
    try {
      for (final characteristic in characteristics) {
        await streams.subscribe(characteristic);
        subscriptions.add(streams
            .characteristicStream(characteristic.uuidString)
            .listen((values) {
          if (BleCharacteristicStreams.isLivePayload(values) &&
              !firstPayload.isCompleted) {
            firstPayload.complete();
          }
        }));
      }
      await firstPayload.future.timeout(probeTimeout);
      return true;
    } on TimeoutException {
      return false;
    } finally {
      for (final subscription in subscriptions) {
        await subscription.cancel();
      }
    }
  }
}
