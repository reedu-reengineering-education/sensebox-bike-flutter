import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:sensebox_bike/ble/ble_characteristic_helpers.dart';
import 'package:sensebox_bike/ble/ble_characteristic_streams.dart';
import 'package:sensebox_bike/ble/ble_constants.dart';

class BleConnectionSessionResult {
  final bool success;
  final List<BluetoothCharacteristic> characteristics;

  const BleConnectionSessionResult({
    required this.success,
    this.characteristics = const [],
  });
}

class BleConnectionSession {
  const BleConnectionSession({this.probeTimeout = bleConnectionSessionProbeTimeout});

  final Duration probeTimeout;

  Future<BleConnectionSessionResult> establish(
    BluetoothDevice device, {
    required BleCharacteristicStreams streams,
  }) async {
    try {
      streams.clear();

      final services = await device.discoverServices();
      if (services.isEmpty) {
        return const BleConnectionSessionResult(success: false);
      }

      BluetoothService senseBoxService;
      try {
        senseBoxService = findSenseBoxService(services);
      } catch (_) {
        return const BleConnectionSessionResult(success: false);
      }

      if (senseBoxService.characteristics.isEmpty) {
        return const BleConnectionSessionResult(success: false);
      }

      final probeCharacteristic = senseBoxService.characteristics.first;
      final probeReceived = await _probeCharacteristic(probeCharacteristic);
      if (!probeReceived) {
        return const BleConnectionSessionResult(success: false);
      }

      await streams.subscribeAll(senseBoxService.characteristics);

      return BleConnectionSessionResult(
        success: true,
        characteristics: senseBoxService.characteristics,
      );
    } catch (_) {
      return const BleConnectionSessionResult(success: false);
    }
  }

  Future<bool> _probeCharacteristic(BluetoothCharacteristic characteristic) async {
    final dataReceivedCompleter = Completer<bool>();
    Uint8List? receivedData;

    await characteristic.setNotifyValue(true);
    final subscription = characteristic.onValueReceived.listen((value) {
      if (!dataReceivedCompleter.isCompleted) {
        receivedData = Uint8List.fromList(value);
        dataReceivedCompleter.complete(true);
      }
    });

    try {
      await Future.any([
        dataReceivedCompleter.future,
        Future.delayed(probeTimeout),
      ]);
    } finally {
      await subscription.cancel();
      await characteristic.setNotifyValue(false);
    }

    return receivedData != null && isValidCharacteristicPayload(receivedData!);
  }
}
