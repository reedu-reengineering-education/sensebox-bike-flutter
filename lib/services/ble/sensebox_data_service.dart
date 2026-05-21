import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:sensebox_bike/services/ble/ble_client.dart';
import 'package:sensebox_bike/services/ble/sensebox_constants.dart';

class SenseBoxDataService {
  final BleClient _bleClient;

  final Map<String, StreamController<List<double>>> _characteristicStreams = {};
  final Map<String, StreamSubscription<List<int>>> _characteristicSubscriptions =
      {};

  final ValueNotifier<List<BleCharacteristicRef>> availableCharacteristics =
      ValueNotifier([]);
  final ValueNotifier<int> characteristicStreamsVersion = ValueNotifier(0);

  SenseBoxDataService(this._bleClient);

  Stream<List<double>> getCharacteristicStream(String characteristicUuid) {
    if (!_characteristicStreams.containsKey(characteristicUuid)) {
      throw Exception(
        'Characteristic stream not found for UUID: $characteristicUuid. '
        'The characteristic may not be available yet or the device may not be connected.',
      );
    }
    return _characteristicStreams[characteristicUuid]!.stream;
  }

  Future<bool> validateConnectionProbe(
    String deviceId,
    BleCharacteristicRef characteristic,
  ) async {
    final dataCompleter = Completer<Uint8List?>();
    StreamSubscription<List<int>>? subscription;

    try {
      subscription = _bleClient
          .subscribeToCharacteristic(deviceId, characteristic)
          .listen((value) {
        if (!dataCompleter.isCompleted) {
          dataCompleter.complete(Uint8List.fromList(value));
        }
      });

      final receivedData = await Future.any<Uint8List?>([
        dataCompleter.future,
        Future<Uint8List?>.delayed(dataListeningTimeout),
      ]);

      if (receivedData == null) {
        return false;
      }
      return validateReceivedData(receivedData);
    } finally {
      await subscription?.cancel();
      await _bleClient.unsubscribeFromCharacteristic(deviceId, characteristic);
    }
  }

  Future<void> startStreaming(
    String deviceId,
    List<BleCharacteristicRef> characteristics,
  ) async {
    clearStreams();

    for (final characteristic in characteristics) {
      await _listenToCharacteristic(deviceId, characteristic);
    }

    availableCharacteristics.value = characteristics;
    characteristicStreamsVersion.value++;
  }

  Future<void> _listenToCharacteristic(
    String deviceId,
    BleCharacteristicRef characteristic,
  ) async {
    final uuid = characteristic.characteristicUuid;

    await _characteristicSubscriptions[uuid]?.cancel();
    _characteristicSubscriptions.remove(uuid);

    if (_characteristicStreams.containsKey(uuid)) {
      await _characteristicStreams[uuid]?.close();
      _characteristicStreams.remove(uuid);
    }

    final controller = StreamController<List<double>>.broadcast();
    _characteristicStreams[uuid] = controller;

    final subscription = _bleClient
        .subscribeToCharacteristic(deviceId, characteristic)
        .listen((value) {
      if (!controller.isClosed) {
        controller.add(parseData(Uint8List.fromList(value)));
      }
    });
    _characteristicSubscriptions[uuid] = subscription;
  }

  void clearStreams() {
    for (final subscription in _characteristicSubscriptions.values) {
      subscription.cancel();
    }
    _characteristicSubscriptions.clear();

    for (final controller in _characteristicStreams.values) {
      controller.close();
    }
    _characteristicStreams.clear();
    availableCharacteristics.value = [];
  }

  bool validateReceivedData(Uint8List data) {
    if (data.isEmpty) {
      return false;
    }

    if (data.every((byte) => byte == 0)) {
      return false;
    }

    if (data.length < 4) {
      return false;
    }

    return true;
  }

  List<double> parseData(Uint8List value) {
    final parsedValues = <double>[];
    for (var i = 0; i < value.length; i += 4) {
      if (i + 4 <= value.length) {
        parsedValues.add(
          ByteData.sublistView(value, i, i + 4).getFloat32(0, Endian.little),
        );
      }
    }
    return parsedValues;
  }

  void dispose() {
    clearStreams();
    availableCharacteristics.dispose();
    characteristicStreamsVersion.dispose();
  }
}
