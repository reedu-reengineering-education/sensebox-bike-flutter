/// Library-agnostic representation of a discoverable BLE device.
class BleDevice {
  const BleDevice({
    required this.id,
    required this.name,
  });

  final String id;
  final String name;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is BleDevice && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
