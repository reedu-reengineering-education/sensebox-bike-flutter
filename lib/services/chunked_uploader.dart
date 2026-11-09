import 'dart:math';

import 'package:retry/retry.dart';
import 'package:sensebox_bike/models/geolocation_data.dart';
import 'package:sensebox_bike/models/sensebox.dart';
import 'package:sensebox_bike/services/custom_exceptions.dart';
import 'package:sensebox_bike/services/error_service.dart';
import 'package:sensebox_bike/services/opensensemap_service.dart';
import 'package:sensebox_bike/utils/sensor_utils.dart';
import 'package:sensebox_bike/utils/track_utils.dart';

class ChunkedUploader {
  /// The API accepts 2500 measurements per request; keep a safety margin.
  static const int maxMeasurementsPerChunk = 2000;

  /// Worst case: 2 x [chunkRequestTimeout] + ~3 s delay, i.e. under a minute.
  static const RetryOptions chunkRetryOptions = RetryOptions(
    maxAttempts: 2,
    delayFactor: Duration(seconds: 2),
    maxDelay: Duration(seconds: 3),
  );
  static const Duration chunkRequestTimeout = Duration(seconds: 25);

  final OpenSenseMapService _openSenseMapService;
  final SenseBox _senseBox;
  final UploadDataPreparer _dataPreparer;

  ChunkedUploader({
    required OpenSenseMapService openSenseMapService,
    required SenseBox senseBox,
  })  : _openSenseMapService = openSenseMapService,
        _senseBox = senseBox,
        _dataPreparer = UploadDataPreparer(senseBox: senseBox);

  /// Each sensor of the box gets at most one value per point, so the sensor
  /// count bounds the measurements per point.
  List<List<GeolocationData>> splitIntoChunks(
      List<GeolocationData> geolocations) {
    final sensorCount = max(1, _senseBox.sensors?.length ?? 0);
    final chunkSize = max(1, maxMeasurementsPerChunk ~/ sensorCount);
    return [
      for (var i = 0; i < geolocations.length; i += chunkSize)
        geolocations.sublist(i, min(i + chunkSize, geolocations.length)),
    ];
  }

  /// [shouldSend] is checked right before the request goes out, so work the
  /// caller has given up on does not upload data in the background.
  Future<void> uploadChunk(
    List<GeolocationData> chunk, {
    bool Function()? shouldSend,
    void Function()? onSending,
    void Function(Object error)? onRetry,
  }) async {
    final groupedData = {
      for (final geolocation in chunk)
        geolocation: await _loadSensorValues(geolocation),
    };
    final uploadData =
        _dataPreparer.prepareDataFromGroupedData(groupedData, chunk);
    if (uploadData.isEmpty) return;

    if (shouldSend != null && !shouldSend()) {
      throw const UploadCancelledException();
    }
    onSending?.call();

    await _openSenseMapService.uploadData(
      _senseBox,
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
            a.title, a.attribute, b.title, b.attribute));
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
}
