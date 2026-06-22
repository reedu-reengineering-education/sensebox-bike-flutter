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
    Duration? livenessTimeout,
    Duration? stabilityDwell,
  }) async {
    _platform.beginSessionEstablishment(device.id);
    try {
      if (!_platform.isConnected(device.id)) {
        return const BleConnectionSessionResult(success: false);
      }

      await streams.clear();

      final services = await _platform.discoverServices(device.id);
      if (services.isEmpty) {
        return const BleConnectionSessionResult(success: false);
      }

      if (!_platform.isConnected(device.id)) {
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

      final linkIsLive = await _subscribeAllAndAwaitLiveness(
        characteristics,
        streams: streams,
        deviceId: device.id,
        timeout: livenessTimeout ?? probeTimeout,
      );
      if (!linkIsLive) {
        return const BleConnectionSessionResult(success: false);
      }

      final dwell = stabilityDwell ?? Duration.zero;
      if (dwell > Duration.zero) {
        final linkIsStable = await _awaitStabilityDwell(
          deviceId: device.id,
          dwell: dwell,
        );
        if (!linkIsStable) {
          return const BleConnectionSessionResult(success: false);
        }
      }

      return BleConnectionSessionResult(
        success: true,
        characteristics: characteristics,
      );
    } catch (_) {
      return const BleConnectionSessionResult(success: false);
    } finally {
      _platform.endSessionEstablishment(device.id);
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

  Future<bool> _subscribeAllAndAwaitLiveness(
    List<BleCharacteristicRef> characteristics, {
    required BleCharacteristicStreams streams,
    required String deviceId,
    required Duration timeout,
  }) async {
    final dataReceivedCompleter = Completer<bool>();
    final livenessSubscriptions = <StreamSubscription<List<double>>>[];

    void onPayload(List<double> values) {
      if (!dataReceivedCompleter.isCompleted &&
          _isValidParsedPayload(values)) {
        dataReceivedCompleter.complete(true);
      }
    }

    try {
      for (final characteristic in characteristics) {
        if (!_platform.isConnected(deviceId)) {
          return false;
        }

        await streams.subscribe(characteristic);

        livenessSubscriptions.add(
          streams
              .characteristicStream(characteristic.uuidString)
              .listen(onPayload),
        );

        if (streams.hasLivePayload(characteristic.uuidString)) {
          return true;
        }
        if (dataReceivedCompleter.isCompleted) {
          return true;
        }
      }

      if (!_platform.isConnected(deviceId)) {
        return false;
      }

      await Future.any([
        dataReceivedCompleter.future,
        Future.delayed(timeout),
      ]);
      return dataReceivedCompleter.isCompleted;
    } finally {
      for (final subscription in livenessSubscriptions) {
        await subscription.cancel();
      }
    }
  }

  Future<bool> _awaitStabilityDwell({
    required String deviceId,
    required Duration dwell,
  }) async {
    final deadline = DateTime.now().add(dwell);
    while (DateTime.now().isBefore(deadline)) {
      if (!_platform.isConnected(deviceId)) {
        return false;
      }
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    return true;
  }

  static bool _isValidParsedPayload(List<double> values) {
    return BleCharacteristicStreams.isLivePayload(values);
  }
}
