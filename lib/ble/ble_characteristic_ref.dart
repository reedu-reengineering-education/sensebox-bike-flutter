import 'package:sensebox_bike/ble/ble_uuids.dart';

/// Library-agnostic reference to a GATT characteristic.
class BleCharacteristicRef {
  const BleCharacteristicRef({
    required this.deviceId,
    required this.serviceUuid,
    required this.characteristicUuid,
  });

  final String deviceId;
  final BleUuid serviceUuid;
  final BleUuid characteristicUuid;

  String get uuidString => characteristicUuid.toString();

  factory BleCharacteristicRef.fromDiscovered({
    required String deviceId,
    required BleUuid serviceUuid,
    required BleUuid characteristicUuid,
  }) {
    return BleCharacteristicRef(
      deviceId: deviceId,
      serviceUuid: serviceUuid,
      characteristicUuid: characteristicUuid,
    );
  }
}

/// Library-agnostic representation of a discovered GATT service.
class BleService {
  const BleService({
    required this.serviceId,
    required this.characteristics,
  });

  final BleUuid serviceId;
  final List<BleUuid> characteristics;
}
