import 'package:sensebox_bike/models/sensor_batch.dart';

class UploadBatch {
  final List<SensorBatch> batches;
  final String uploadId;
  final DateTime createdAt;

  UploadBatch({
    required this.batches,
    required this.uploadId,
    required this.createdAt,
  });

  List<int> get geoLocationIds {
    return batches.map((b) => b.geoLocation.id).toList();
  }

  @override
  String toString() {
    return 'UploadBatch(id: $uploadId, batches: ${batches.length}, '
        'geoIds: $geoLocationIds)';
  }
}

