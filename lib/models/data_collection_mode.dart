const defaultCollectionIntervalSeconds = 60;
const minCollectionIntervalSeconds = 5;
const collectionIntervalPresetsSeconds = [30, 60, 120];

enum DataCollectionMode {
  gpsDriven,
  periodic,
  onTap;

  static DataCollectionMode fromJson(String? value) {
    switch (value) {
      case 'periodic':
        return DataCollectionMode.periodic;
      case 'onTap':
        return DataCollectionMode.onTap;
      case 'gpsDriven':
      case 'postRide': // legacy alias from WIP branch
      case null:
        return DataCollectionMode.gpsDriven;
      default:
        throw FormatException(
          'DataCollectionMode.fromJson: unknown value "$value"',
        );
    }
  }

  String toJson() {
    switch (this) {
      case DataCollectionMode.gpsDriven:
        return 'gpsDriven';
      case DataCollectionMode.periodic:
        return 'periodic';
      case DataCollectionMode.onTap:
        return 'onTap';
    }
  }
}

extension DataCollectionModeBehavior on DataCollectionMode {
  /// Continuous GPS-driven collection (stream persistence + sensor aggregation).
  bool get isGpsDriven => this == DataCollectionMode.gpsDriven;

  bool get usesPeriodicTimer => this == DataCollectionMode.periodic;

  bool get showsManualSampleButton => this == DataCollectionMode.onTap;
}

int parseCollectionIntervalSeconds(dynamic value) {
  if (value == null) {
    return defaultCollectionIntervalSeconds;
  }
  if (value is! int) {
    throw FormatException(
      'collectionIntervalSeconds must be an int, got ${value.runtimeType}',
    );
  }
  if (value < minCollectionIntervalSeconds) {
    throw FormatException(
      'collectionIntervalSeconds must be at least $minCollectionIntervalSeconds, got $value',
    );
  }
  return value;
}
