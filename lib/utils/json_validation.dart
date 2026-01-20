/// Validates and extracts a required String field from JSON
/// 
/// Throws [FormatException] with descriptive message if field is missing or wrong type
String requireString(Map<String, dynamic> json, String fieldName, String className) {
  if (!json.containsKey(fieldName)) {
    throw FormatException('$className.fromJson: missing required field "$fieldName"');
  }
  final value = json[fieldName];
  if (value is! String) {
    throw FormatException('$className.fromJson: field "$fieldName" must be a String, got ${value.runtimeType}');
  }
  return value;
}

/// Validates and extracts a required List field from JSON
/// 
/// Throws [FormatException] with descriptive message if field is missing or wrong type
List<T> requireList<T>(Map<String, dynamic> json, String fieldName, String className, T Function(dynamic) mapper) {
  if (!json.containsKey(fieldName)) {
    throw FormatException('$className.fromJson: missing required field "$fieldName"');
  }
  final value = json[fieldName];
  if (value is! List) {
    throw FormatException('$className.fromJson: field "$fieldName" must be a List, got ${value.runtimeType}');
  }
  return value.map((item) => mapper(item)).toList();
}

