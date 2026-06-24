const defaultCollectionIntervalSeconds = 60;
const minCollectionIntervalSeconds = 5;

enum DataCollectionMode {
  postRide,
  periodic;

  static DataCollectionMode fromJson(String? value) {
    switch (value) {
      case 'periodic':
        return DataCollectionMode.periodic;
      case 'postRide':
      case null:
        return DataCollectionMode.postRide;
      default:
        throw FormatException(
          'DataCollectionMode.fromJson: unknown value "$value"',
        );
    }
  }

  String toJson() {
    switch (this) {
      case DataCollectionMode.postRide:
        return 'postRide';
      case DataCollectionMode.periodic:
        return 'periodic';
    }
  }
}

extension DataCollectionModeBehavior on DataCollectionMode {
  bool get usesGpsDrivenGeolocation => this == DataCollectionMode.postRide;

  bool get usesPeriodicTimer => this == DataCollectionMode.periodic;

  bool get aggregatesSensorValues => this == DataCollectionMode.postRide;
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
