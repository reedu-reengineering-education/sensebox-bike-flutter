import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:sensebox_bike/models/geolocation_data.dart';
import 'package:sensebox_bike/models/sensebox.dart';
import 'package:sensebox_bike/models/track_data.dart';
import 'package:sensebox_bike/models/chunk_upload_result.dart';
import 'package:sensebox_bike/services/opensensemap_service.dart';
import 'package:sensebox_bike/services/upload_error_classifier.dart';
import 'package:sensebox_bike/services/error_service.dart';
import 'package:sensebox_bike/utils/track_utils.dart';

/// Service responsible for uploading track data in chunks to handle large datasets
/// and comply with API limitations (max 2500 points per chunk).
class ChunkedUploader {
  final OpenSenseMapService _openSenseMapService;
  final UploadDataPreparer _dataPreparer;

  ChunkedUploader({
    required OpenSenseMapService openSenseMapService,
    required SenseBox senseBox,
  })  : _openSenseMapService = openSenseMapService,
        _dataPreparer = UploadDataPreparer(senseBox: senseBox);

  /// Splits a list of GeolocationData into chunks that will generate at most 2400 measurements each.
  ///
  /// This ensures compliance with OpenSenseMap API limitations while maintaining
  /// chronological order of data points. Each GPS point can generate multiple measurements
  /// (speed + sensor data), so we need to estimate the total measurement count.
  /// Using 2400 instead of 2500 provides a significant safety buffer to avoid hitting the API limit.
  ///
  /// [geolocations] - The list of GPS points to split into chunks
  /// [senseBox] - SenseBox configuration to estimate measurements per point
  /// Returns a list of chunks, each estimated to generate at most 2400 measurements
  List<List<GeolocationData>> splitIntoChunks(
      List<GeolocationData> geolocations, SenseBox senseBox) {
    const int maxMeasurements = 2400;
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
    
    // Overtaking sensors
    if (sensorTitles.any((title) => title.contains('overtaking distance'))) count++;
    if (sensorTitles.any((title) => title.contains('overtaking manoeuvre'))) count++;
    
    // Surface anomaly
    if (sensorTitles.any((title) => title.contains('surface anomaly'))) count++;
    
    // Acceleration sensors (X, Y, Z)
    if (sensorTitles.any((title) => title.contains('acceleration x'))) count++;
    if (sensorTitles.any((title) => title.contains('acceleration y'))) count++;
    if (sensorTitles.any((title) => title.contains('acceleration z'))) count++;

    return count;
  }

  /// Uploads a single chunk of geolocation data to OpenSenseMap with comprehensive error handling.
  ///
  /// Reuses the existing DirectUploadService data preparation logic to ensure
  /// consistency with the current upload format and sensor mapping.
  /// Implements data preservation on failures and detailed logging.
  ///
  /// [chunk] - List of GeolocationData points to upload (max 2400 points)
  /// [senseBox] - SenseBox configuration containing sensor mappings
  /// [chunkIndex] - Index of this chunk for tracking purposes
  ///
  /// Returns a ChunkUploadResult indicating success or failure with error details
  Future<ChunkUploadResult> uploadChunk(
    List<GeolocationData> chunk,
    SenseBox senseBox,
    int chunkIndex,
  ) async {
    try {
      if (chunk.isEmpty) {
        _logInfo('Empty chunk', 'Chunk $chunkIndex is empty, skipping upload',
            chunkIndex);
        return ChunkUploadResult.success(chunkIndex);
      }

      _logInfo(
          'Chunk upload start',
          'Starting upload of chunk $chunkIndex with ${chunk.length} points',
          chunkIndex);

      // Create grouped data structure expected by UploadDataPreparer
      // This mimics the format used by DirectUploadService
      final Map<GeolocationData, Map<String, List<double>>> groupedData = {};
      int sensorDataLoadFailures = 0;

      // For each GPS point, collect associated sensor data with error handling
      for (final geolocation in chunk) {
        final Map<String, List<double>> sensorDataForPoint = {};

        try {
          // Load sensor data for this geolocation point
          await geolocation.sensorData.load();

          // Group sensor data by sensor title (which acts as the sensor key)
          for (final sensorData in geolocation.sensorData) {
            final sensorKey = sensorData.title;
            if (!sensorDataForPoint.containsKey(sensorKey)) {
              sensorDataForPoint[sensorKey] = [];
            }
            sensorDataForPoint[sensorKey]!.add(sensorData.value);
          }
        } catch (e, stackTrace) {
          // If sensor data loading fails, continue with just GPS data
          sensorDataLoadFailures++;
          _logError(
              'Sensor data load failed',
              'Failed to load sensor data for geolocation in chunk $chunkIndex: $e',
              chunkIndex);

          // Report to error service for monitoring
          ErrorService.handleError(
            'Failed to load sensor data for geolocation in chunk $chunkIndex: $e',
            stackTrace,
            sendToSentry:
                false, // Don't spam Sentry with individual sensor data failures
          );
        }

        // Always include the geolocation, even if sensor data loading failed
        // The UploadDataPreparer will handle GPS-only data
        groupedData[geolocation] = sensorDataForPoint;
      }

      if (sensorDataLoadFailures > 0) {
        _logInfo(
            'Sensor data issues',
            'Chunk $chunkIndex had $sensorDataLoadFailures sensor data load failures, continuing with GPS data',
            chunkIndex);
      }

      // Prepare data using the same logic as DirectUploadService with error handling
      Map<String, dynamic> uploadData;
      try {
        uploadData = _dataPreparer.prepareDataFromGroupedData(
          groupedData,
          chunk, // GPS buffer is the chunk itself
        );
      } catch (e, stackTrace) {
        _logError('Data preparation failed',
            'Failed to prepare data for chunk $chunkIndex: $e', chunkIndex);
        ErrorService.handleError(
          'Failed to prepare data for chunk $chunkIndex: $e',
          stackTrace,
          sendToSentry: true,
        );
        return ChunkUploadResult.permanentFailure(
            chunkIndex, 'Data preparation failed: $e');
      }

      if (uploadData.isEmpty) {
        _logInfo(
            'No data to upload',
            'No data to upload for chunk $chunkIndex after preparation',
            chunkIndex);
        return ChunkUploadResult.success(chunkIndex);
      }

      // Upload the prepared data with error handling
      try {
        debugPrint('length: ${uploadData.keys.length.toString()}');
        await _openSenseMapService.uploadData(senseBox.id, uploadData);
      } catch (e, stackTrace) {
        _logError('Upload API failed',
            'API call failed for chunk $chunkIndex: $e', chunkIndex);

        // Report to error service for monitoring
        ErrorService.handleError(
          'Upload API call failed for chunk $chunkIndex: $e',
          stackTrace,
          sendToSentry: true,
        );

        rethrow; // Let the outer catch handle error classification
      }

      _logInfo(
          'Chunk upload success',
          'Successfully uploaded chunk $chunkIndex with ${chunk.length} points',
          chunkIndex);
      return ChunkUploadResult.success(chunkIndex);
    } catch (e, stackTrace) {
      _logError('Chunk upload failed', 'Failed to upload chunk $chunkIndex: $e',
          chunkIndex);

      // Classify error to determine if it's retryable and preserve data accordingly
      final errorType = UploadErrorClassifier.classifyError(e);
      final isRetryable = errorType == UploadErrorType.temporary;

      // Report to error service based on error type
      ErrorService.handleError(
        'Chunk upload failed for chunk $chunkIndex: $e',
        stackTrace,
        sendToSentry: !isRetryable, // Only send permanent errors to Sentry
      );

      if (isRetryable) {
        _logInfo(
            'Retryable failure',
            'Chunk $chunkIndex failed with retryable error, data preserved',
            chunkIndex);
        return ChunkUploadResult.retryableFailure(
            chunkIndex, '$e (Data preserved for retry)');
      } else {
        _logError(
            'Permanent failure',
            'Chunk $chunkIndex failed permanently, data preserved locally',
            chunkIndex);
        return ChunkUploadResult.permanentFailure(
            chunkIndex, '$e (Data preserved locally)');
      }
    }
  }

  /// Uploads a complete track by splitting it into chunks and uploading them sequentially.
  ///
  /// This method handles the complete upload flow:
  /// 1. Loads all geolocation data for the track
  /// 2. Splits data into chunks of max 2500 points
  /// 3. Uploads each chunk sequentially to avoid overwhelming the API
  /// 4. Returns results for each chunk
  ///
  /// [track] - The TrackData to upload
  /// [senseBox] - SenseBox configuration containing sensor mappings
  ///
  /// Returns a list of ChunkUploadResult objects, one for each chunk
  Future<List<ChunkUploadResult>> uploadTrackInChunks(
    TrackData track,
    SenseBox senseBox,
  ) async {
    // Load all geolocation data for the track
    await track.geolocations.load();
    final List<GeolocationData> geolocations = track.geolocations.toList();

    if (geolocations.isEmpty) {
      debugPrint(
          '[ChunkedUploader] No geolocation data found for track ${track.id}');
      return [];
    }

    // Sort geolocations by timestamp to ensure chronological order
    geolocations.sort((a, b) => a.timestamp.compareTo(b.timestamp));

    // Split into chunks based on estimated measurement count
    final List<List<GeolocationData>> chunks = splitIntoChunks(geolocations, senseBox);
    final List<ChunkUploadResult> results = [];

    debugPrint(
        '[ChunkedUploader] Uploading track ${track.id} in ${chunks.length} chunks');

    // Upload each chunk sequentially
    for (int i = 0; i < chunks.length; i++) {
      final chunk = chunks[i];
      final result = await uploadChunk(chunk, senseBox, i);
      results.add(result);

      // If this chunk failed with a permanent error, stop uploading remaining chunks
      if (result.failed && !result.isRetryable) {
        debugPrint(
            '[ChunkedUploader] Stopping upload due to permanent error in chunk $i');
        break;
      }
    }

    final successfulChunks = results.where((r) => r.success).length;
    final failedChunks = results.where((r) => r.failed).length;

    debugPrint('[ChunkedUploader] Upload completed for track ${track.id}: '
        '$successfulChunks successful, $failedChunks failed chunks');

    return results;
  }

  /// Logs informational messages with structured format
  void _logInfo(String operation, String message, int? chunkIndex) {
    final timestamp = DateTime.now().toIso8601String();
    final chunkInfo = chunkIndex != null ? ' [Chunk: $chunkIndex]' : '';
    debugPrint(
        '[$timestamp] [ChunkedUploader] [INFO] [$operation]$chunkInfo $message');
  }

  /// Logs error messages with structured format
  void _logError(String operation, String message, int? chunkIndex) {
    final timestamp = DateTime.now().toIso8601String();
    final chunkInfo = chunkIndex != null ? ' [Chunk: $chunkIndex]' : '';
    debugPrint(
        '[$timestamp] [ChunkedUploader] [ERROR] [$operation]$chunkInfo $message');
  }
}
