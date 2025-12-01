/// Represents a sensor value with its timestamp
/// Used for retroactive aggregation with lookback windows
class TimestampedSensorValue {
  final List<double> values;
  final DateTime timestamp;

  TimestampedSensorValue({
    required this.values,
    required this.timestamp,
  });

  @override
  String toString() {
    return 'TimestampedSensorValue(values: $values, timestamp: $timestamp)';
  }
}


