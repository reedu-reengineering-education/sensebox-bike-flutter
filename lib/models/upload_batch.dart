import 'package:sensebox_bike/models/sensor_batch.dart';

/// Reference to sensor batches queued for upload
/// Stores references to SensorBatch objects, not copies of the data
/// This avoids memory duplication while maintaining upload queue state
class UploadBatch {
  final List<SensorBatch> batches;
  final String uploadId;
  final DateTime createdAt;
  int attemptCount = 0;
  DateTime? lastAttemptAt;

  UploadBatch({
    required this.batches,
    required this.uploadId,
    required this.createdAt,
  });

  /// Get all geolocation IDs in this upload batch
  List<int> get geoLocationIds {
    return batches.map((b) => b.geoLocation.id).toList();
  }

  /// Check if this batch has exceeded max retry attempts
  bool hasExceededMaxRetries({int maxRetries = 10}) {
    return attemptCount > maxRetries;
  }

  /// Mark this upload attempt
  void recordAttempt() {
    attemptCount++;
    lastAttemptAt = DateTime.now();
  }

  /// Get time since last attempt
  Duration? get timeSinceLastAttempt {
    if (lastAttemptAt == null) return null;
    return DateTime.now().difference(lastAttemptAt!);
  }

  @override
  String toString() {
    return 'UploadBatch(id: $uploadId, batches: ${batches.length}, '
        'attempts: $attemptCount, geoIds: $geoLocationIds)';
  }
}

