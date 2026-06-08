/// Library-agnostic Bluetooth UUID value type.
///
/// Stores UUIDs in a canonical lowercase, dash-separated 128-bit form so that
/// equality and the [toString] representation are stable regardless of the
/// underlying BLE library. The 32-character dash-free [compact] form is used
/// for hashing and equality so short and long inputs compare correctly.
class BleUuid {
  BleUuid(String value) : _canonical = _toDashed(value);

  final String _canonical;

  /// Canonical lowercase, dash-separated representation
  /// (e.g. `cf06a218-f68e-e0be-ad04-8ebc1eb0bc84`).
  String get value => _canonical;

  /// Lowercase representation without dashes, used for comparison.
  String get compact => _canonical.replaceAll('-', '');

  @override
  String toString() => _canonical;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is BleUuid && other.compact == compact);

  @override
  int get hashCode => compact.hashCode;

  static String _toDashed(String input) {
    final hex = input.replaceAll('-', '').toLowerCase();
    if (hex.length == 32) {
      return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
          '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
          '${hex.substring(20)}';
    }
    return hex;
  }
}

final BleUuid senseBoxServiceUuid =
    BleUuid('CF06A218-F68E-E0BE-AD04-8EBC1EB0BC84');

final BleUuid deviceInfoServiceUuid =
    BleUuid('CF06A218-F68E-E0BE-AD04-8EBC1EB0BC85');
