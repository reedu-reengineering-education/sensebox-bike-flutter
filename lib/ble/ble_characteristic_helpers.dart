import 'dart:typed_data';

import 'package:sensebox_bike/ble/ble_characteristic_ref.dart';
import 'package:sensebox_bike/ble/ble_uuids.dart';

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

BleService findSenseBoxService(List<BleService> services) {
  return services.firstWhere(
    (service) => service.serviceId == senseBoxServiceUuid,
    orElse: () => throw Exception('senseBox service not found'),
  );
}

List<BleCharacteristicRef> characteristicRefsFromService({
  required String deviceId,
  required BleService service,
}) {
  return service.characteristics
      .map(
        (characteristicUuid) => BleCharacteristicRef.fromDiscovered(
          deviceId: deviceId,
          serviceUuid: service.serviceId,
          characteristicUuid: characteristicUuid,
        ),
      )
      .toList();
}
