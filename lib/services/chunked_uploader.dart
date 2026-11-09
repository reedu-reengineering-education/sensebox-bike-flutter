import 'package:flutter/foundation.dart';
import 'package:retry/retry.dart';
import 'package:sensebox_bike/models/geolocation_data.dart';
import 'package:sensebox_bike/models/sensebox.dart';
import 'package:sensebox_bike/services/custom_exceptions.dart';
import 'package:sensebox_bike/services/opensensemap_service.dart';
import 'package:sensebox_bike/services/error_service.dart';
import 'package:sensebox_bike/utils/track_utils.dart';
import 'package:sensebox_bike/utils/sensor_utils.dart';

/// Service responsible for uploading track data in chunks to handle large datasets
/// and comply with API limitations (max 2500 points per chunk).
class ChunkedUploader {
  /// Worst case: 2 x [chunkRequestTimeout] + ~3 s delay, i.e. under a minute.
  static const RetryOptions chunkRetryOptions = RetryOptions(
    maxAttempts: 2,
    delayFactor: Duration(seconds: 2),
    maxDelay: Duration(seconds: 3),
  );
  static const Duration chunkRequestTimeout = Duration(seconds: 25);

  final OpenSenseMapService _openSenseMapService;
  final UploadDataPreparer _dataPreparer;

  ChunkedUploader({
    required OpenSenseMapService openSenseMapService,
    required SenseBox senseBox,
  })  : _openSenseMapService = openSenseMapService,
        _dataPreparer = UploadDataPreparer(senseBox: senseBox);

  /// Splits a list of GeolocationData into chunks that will generate at most 2000 measurements each.
  ///
  /// This ensures compliance with OpenSenseMap API limitations while maintaining
  /// chronological order of data points. Each GPS point can generate multiple measurements
  /// (speed + sensor data), so we need to estimate the total measurement count.
  /// Using 2000 instead of 2500 provides a significant safety buffer to avoid hitting the API limit.
  ///
  /// [geolocations] - The list of GPS points to split into chunks
  /// [senseBox] - SenseBox configuration to estimate measurements per point
  /// Returns a list of chunks, each estimated to generate at most 2000 measurements
  List<List<GeolocationData>> splitIntoChunks(
      List<GeolocationData> geolocations, SenseBox senseBox) {
    const int maxMeasurements = 2000;
    final List<List<GeolocationData>> chunks = [];

    if (geolocations.isEmpty) {
      return chunks;
    }

    // Estimate measurements per GPS point based on available sensors
    final int estimatedMeasurementsPerPoint = _estimateMeasurementsPerPoint(senseBox);
    
    // Calculate safe chunk size based on measurement estimation
    final int safeChunkSize = (maxMeasurements / estimatedMeasurementsPerPoint).floor();
    final int actualChunkSize = safeChunkSize > 0 ? safeChunkSize : 1; // Minimum 1 point per chunk

    _logInfo('Chunk size calculation', 
        'Estimated $estimatedMeasurementsPerPoint measurements per point, using chunk size of $actualChunkSize points', 
        null);

    for (int i = 0; i < geolocations.length; i += actualChunkSize) {
      final int end = (i + actualChunkSize < geolocations.length)
          ? i + actualChunkSize
          : geolocations.length;
      chunks.add(geolocations.sublist(i, end));
    }

    return chunks;
  }

  /// Estimates the number of measurements that will be generated per GPS point
  /// based on the SenseBox sensor configuration.
  int _estimateMeasurementsPerPoint(SenseBox senseBox) {
    int count = 1; // Always have speed measurement
    
    if (senseBox.sensors == null) {
      return count;
    }

    // Count sensor types that typically generate measurements
    final sensorTitles = senseBox.sensors!.map((s) => s.title?.toLowerCase() ?? '').toSet();
    
    // Single-value sensors (1 measurement each)
    if (sensorTitles.any((title) => title.contains('temperature'))) count++;
    if (sensorTitles.any((title) => title.contains('humidity'))) count++;
    
    // Multi-value sensors (estimate based on typical configurations)
    if (sensorTitles.any((title) => title.contains('finedust'))) {
      // PM1, PM2.5, PM4, PM10 = 4 measurements
      count += 4;
    }
    
    // Surface classification sensors - count actual surface sensors
    int surfaceSensorCount = 0;
    if (sensorTitles.any((title) => title.contains('surface asphalt'))) surfaceSensorCount++;
    if (sensorTitles.any((title) => title.contains('surface sett'))) surfaceSensorCount++;
    if (sensorTitles.any((title) => title.contains('surface compacted'))) surfaceSensorCount++;
    if (sensorTitles.any((title) => title.contains('surface paving'))) surfaceSensorCount++;
    if (sensorTitles.any((title) => title.contains('standing'))) surfaceSensorCount++;
    count += surfaceSensorCount;
    
    // Distance sensors - count each distance sensor individually
    if (sensorTitles.any((title) => title.contains('overtaking distance'))) count++;
    if (sensorTitles.any((title) => title == 'distance left')) count++;
    if (sensorTitles.any((title) => title == 'distance right')) count++;
    
    // Overtaking manoeuvre sensor
    if (sensorTitles.any((title) => title.contains('overtaking manoeuvre'))) count++;
    
    // Surface anomaly
    if (sensorTitles.any((title) => title.contains('surface anomaly'))) count++;
    
    // Acceleration sensors (X, Y, Z)
    if (sensorTitles.any((title) => title.contains('acceleration x'))) count++;
    if (sensorTitles.any((title) => title.contains('acceleration y'))) count++;
    if (sensorTitles.any((title) => title.contains('acceleration z'))) count++;

    return count;
  }

  /// [shouldSend] is checked right before the request goes out, so work the
  /// caller has given up on does not upload data in the background.
  Future<void> uploadChunk(
    List<GeolocationData> chunk,
    SenseBox senseBox, {
    bool Function()? shouldSend,
    void Function()? onSending,
    void Function(Object error)? onRetry,
  }) async {
    if (chunk.isEmpty) return;

    final Map<GeolocationData, Map<String, List<double>>> groupedData = {};
    for (final geolocation in chunk) {
      groupedData[geolocation] = await _loadSensorValues(geolocation);
    }

    final uploadData =
        _dataPreparer.prepareDataFromGroupedData(groupedData, chunk);
    if (uploadData.isEmpty) return;

    if (shouldSend != null && !shouldSend()) {
      throw const UploadCancelledException();
    }
    onSending?.call();

    await _openSenseMapService.uploadData(
      senseBox,
      uploadData,
      retryOptions: chunkRetryOptions,
      requestTimeout: chunkRequestTimeout,
      reportErrors: false,
      onRetry: onRetry,
    );
  }

  Future<Map<String, List<double>>> _loadSensorValues(
      GeolocationData geolocation) async {
    final Map<String, List<double>> values = {};
    try {
      await geolocation.sensorData.load();
      final sensorDataList = geolocation.sensorData.toList()
        ..sort((a, b) => compareSensorsByCanonicalOrder(
              a.title,
              a.attribute,
              b.title,
              b.attribute,
            ));
      for (final sensorData in sensorDataList) {
        values.putIfAbsent(sensorData.title, () => []).add(sensorData.value);
      }
    } catch (e, stackTrace) {
      ErrorService.logToConsole(
          'Failed to load sensor data for geolocation ${geolocation.id}: $e',
          stackTrace);
    }
    return values;
  }

  /// Logs informational messages with structured format
  void _logInfo(String operation, String message, int? chunkIndex) {
    final timestamp = DateTime.now().toIso8601String();
    final chunkInfo = chunkIndex != null ? ' [Chunk: $chunkIndex]' : '';
    debugPrint(
        '[$timestamp] [ChunkedUploader] [INFO] [$operation]$chunkInfo $message');
  }
}
