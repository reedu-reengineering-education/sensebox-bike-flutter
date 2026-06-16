import 'dart:async';
import 'dart:typed_data';

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
    try {
      await streams.clear();

      final services = await _platform.discoverServices(device.id);
      if (services.isEmpty) {
        return const BleConnectionSessionResult(success: false);
      }

      BleService senseBoxService;
      try {
        senseBoxService = findSenseBoxService(services);
      } catch (_) {
        return const BleConnectionSessionResult(success: false);
      }

      if (senseBoxService.characteristics.isEmpty) {
        return const BleConnectionSessionResult(success: false);
      }

      final characteristics = characteristicRefsFromService(
        deviceId: device.id,
        service: senseBoxService,
      );

      // Subscribe to every characteristic up front so notifications stay
      // enabled for the whole session, then verify the link is actually
      // delivering data. Doing it in this order avoids the
      // enable/disable/enable churn (and dropped first packets) of probing on
      // a throwaway subscription before the real ones are attached.
      await streams.subscribeAll(characteristics);

      final linkIsLive = await _awaitLiveness(characteristics.first);
      if (!linkIsLive) {
        return const BleConnectionSessionResult(success: false);
      }

      return BleConnectionSessionResult(
        success: true,
        characteristics: characteristics,
      );
    } catch (_) {
      return const BleConnectionSessionResult(success: false);
    }
  }

  Future<void> release(
    BleDevice device, {
    Duration settle = Duration.zero,
  }) async {
    try {
      await _platform.disconnect(device.id);
    } catch (_) {}
    if (settle > Duration.zero) {
      await Future<void>.delayed(settle);
    }
  }

  Future<bool> _awaitLiveness(BleCharacteristicRef characteristic) async {
    final dataReceivedCompleter = Completer<bool>();
    Uint8List? receivedData;

    // The characteristic is already subscribed via [subscribeAll], so this
    // extra listener does not toggle notifications off when it is cancelled.
    final subscription =
        _platform.subscribeToCharacteristic(characteristic).listen(
      (value) {
        if (!dataReceivedCompleter.isCompleted) {
          receivedData = Uint8List.fromList(value);
          dataReceivedCompleter.complete(true);
        }
      },
    );

    try {
      await Future.any([
        dataReceivedCompleter.future,
        Future.delayed(probeTimeout),
      ]);
    } finally {
      await subscription.cancel();
    }

    return receivedData != null && isValidCharacteristicPayload(receivedData!);
  }
}
