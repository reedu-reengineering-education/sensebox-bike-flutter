import 'package:sensebox_bike/ble/ble_uuids.dart';

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

class BleService {
  const BleService({
    required this.serviceId,
    required this.characteristics,
  });

  final BleUuid serviceId;
  final List<BleUuid> characteristics;
}
