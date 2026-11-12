import 'package:sensebox_bike/ble/ble_uuids.dart';

class BleDevice {
  const BleDevice({
    required this.id,
    required this.name,
    this.serviceUuids = const [],
  });

  final String id;
  final String name;
  final List<BleUuid> serviceUuids;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is BleDevice && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
