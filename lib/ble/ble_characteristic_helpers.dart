import 'dart:typed_data';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:sensebox_bike/secrets.dart';

List<double> parseCharacteristicPayload(Uint8List value) {
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

bool isValidCharacteristicPayload(Uint8List data) {
  if (data.isEmpty) return false;
  if (data.every((byte) => byte == 0)) return false;
  if (data.length < 4) return false;
  return true;
}

BluetoothService findSenseBoxService(List<BluetoothService> services) {
  return services.firstWhere(
    (service) => service.uuid == senseBoxServiceUUID,
    orElse: () => throw Exception('senseBox service not found'),
  );
}
