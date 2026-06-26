class BleUuid {
  BleUuid(String value) : _canonical = _toDashed(value);

  final String _canonical;

  String get value => _canonical;

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
