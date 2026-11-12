import 'dart:typed_data';

List<double> parseCharacteristicPayload(Uint8List value) {
  final parsedValues = <double>[];
  for (var i = 0; i + 4 <= value.length; i += 4) {
    parsedValues.add(
      ByteData.sublistView(value, i, i + 4).getFloat32(0, Endian.little),
    );
  }
  return parsedValues;
}
