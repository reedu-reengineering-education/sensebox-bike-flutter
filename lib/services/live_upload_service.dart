import 'dart:async';
import 'dart:math';
import 'package:flutter/widgets.dart';
import 'package:sensebox_bike/blocs/settings_bloc.dart';
import 'package:sensebox_bike/models/geolocation_data.dart';
import 'package:sensebox_bike/models/sensebox.dart';
import 'package:sensebox_bike/services/custom_exceptions.dart';
import 'package:sensebox_bike/services/error_service.dart';
import 'package:sensebox_bike/services/isar_service.dart';
import 'package:sensebox_bike/services/isar_service/optimized_database_service.dart';
import 'package:sensebox_bike/services/opensensemap_service.dart';
import 'package:sensebox_bike/utils/sensor_utils.dart';
import 'package:sensebox_bike/constants.dart';

class LiveUploadService {
  final OpenSenseMapService openSenseMapService;
  final SettingsBloc settingsBloc;
  final IsarService isarService;
  final SenseBox? Function() getCurrentSenseBox; 

  final int trackId;

  // vars to handle connectivity issues
  DateTime? _lastSuccessfulUpload;
  int _consecutiveFails = 0;

  // save uploaded ids to prevent double uploads
  final List<int> _uploadedIds = [];
  
  // Upload state management
  bool _isUploading = false;
  Timer? _uploadTimer;
  Timer? _debounceTimer;
  static const Duration _uploadInterval =
      Duration(seconds: uploadIntervalSeconds);
  static const Duration _debounceDelay =
      Duration(seconds: 2); // Debounce rapid triggers
  static const Duration _minUploadInterval =
      Duration(seconds: 5); // Minimum time between uploads

  // Performance optimization: track last processed count to avoid unnecessary processing
  int _lastProcessedCount = 0;
  int _lastKnownCount = 0;
  DateTime? _lastUploadAttempt;

  LiveUploadService({
    required this.openSenseMapService,
    required this.settingsBloc,
    required this.isarService,
    required this.getCurrentSenseBox,
    required this.trackId,
  });

  void startUploading() {
    // Start periodic upload timer as a fallback
    _uploadTimer = Timer.periodic(_uploadInterval, (_) {
      _performUpload();
    });
    
    // Also perform initial upload after a short delay to let data accumulate
    Timer(const Duration(seconds: 10), () {
      _performUpload();
    });
  }

  void triggerUpload() {
    final now = DateTime.now();
    if (_lastUploadAttempt != null) {
      final timeSinceLastAttempt = now.difference(_lastUploadAttempt!);
      if (timeSinceLastAttempt < _minUploadInterval) {
        return;
      }
    }
    
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounceDelay, () {
      _lastUploadAttempt = DateTime.now();
      _performUpload();
    });
  }

  void stopUploading() {
    _uploadTimer?.cancel();
    _uploadTimer = null;
    _debounceTimer?.cancel();
    _debounceTimer = null;
    _isUploading = false;
  }

  Future<void> _performUpload() async {
    if (_isUploading) {
      return; // Prevent concurrent uploads
    }

    _isUploading = true;

    try {
      final senseBox = getCurrentSenseBox();
      if (senseBox == null) {
        return;
      }
      await Future.delayed(const Duration(milliseconds: 100));

      int currentCount;
      try {
        currentCount =
            await OptimizedDatabaseService.getGeolocationCount(trackId);
        _lastKnownCount = currentCount;
      } catch (e) {
        // Use last known count as fallback
        currentCount = _lastKnownCount;
      }
      
      // Only process if we have new data (more than 2 records and more than last processed)
      if (currentCount < 2 || currentCount <= _lastProcessedCount) {
        return;
      }

      // Use optimized processing for large datasets
      List<Map<String, dynamic>> processedData;
      try {
        processedData = await OptimizedDatabaseService.processDataInChunks(
          trackId,
          _uploadedIds,
          chunkSize: 25, 
        );
      } catch (e) {
        // If processing fails, try again later
        return;
      }

      if (processedData.isNotEmpty) {
        final dataToUpload =
            _convertProcessedDataToUploadFormat(processedData, senseBox);

        await uploadDataWithRetry(dataToUpload, senseBox.id!);

        // Mark as uploaded
        _uploadedIds.addAll(processedData.map((d) => d['id'] as int));
        _lastSuccessfulUpload = DateTime.now();
        _consecutiveFails = 0;
        _lastProcessedCount = currentCount;
      }
    } catch (e) {
      _consecutiveFails++;
      
      // Handle database and upload errors
      if (e.toString().contains('Instance has already been opened') ||
          e.toString().contains('Database processing error')) {
        // Don't count database processing errors as upload failures
        _consecutiveFails = max(0, _consecutiveFails - 1);
      } else {
        final lastSuccessfulUploadPeriod = DateTime.now()
            .subtract(Duration(minutes: premanentConnectivityFalurePeriod));
        final isPermanentConnectivityIssue = _lastSuccessfulUpload != null &&
            _lastSuccessfulUpload!.isBefore(lastSuccessfulUploadPeriod);
        final isMaxRetries = _consecutiveFails >= maxRetries;

        if (isPermanentConnectivityIssue || isMaxRetries) {
          stopUploading();
          ErrorService.handleError(
              'Permanent connectivity failure: No connection for more than $premanentConnectivityFalurePeriod minutes.',
              StackTrace.current);
          return;
        }
      }
    } finally {
      _isUploading = false;
    }
  }

  /// Convert processed background data to upload format
  Map<String, dynamic> _convertProcessedDataToUploadFormat(
    List<Map<String, dynamic>> processedData,
    SenseBox senseBox, // Pass senseBox as parameter
  ) {
    Map<String, dynamic> data = {};
    for (final geoData in processedData) {
      final timestamp = DateTime.parse(geoData['timestamp'] as String);
      final sensorDataList = geoData['sensorData'] as List;

      for (final sensorData in sensorDataList) {
        final title = sensorData['title'] as String;
        final attribute = sensorData['attribute'] as String?;
        final value = sensorData['value'] as double;

        String? sensorTitle = getTitleFromSensorKey(title, attribute);

        if (sensorTitle == null) {
          continue;
        }

        Sensor? sensor =
            getMatchingSensor(sensorTitle, senseBox); // Pass senseBox

        // Skip if sensor is not found
        if (sensor == null || value.isNaN) {
          continue;
        }

        data[sensor.id! + timestamp.toIso8601String()] = {
          'sensor': sensor.id,
          'value': value.toStringAsFixed(2),
          'createdAt': timestamp.toUtc().toIso8601String(),
          'location': {
            'lat': geoData['latitude'] as double,
            'lng': geoData['longitude'] as double,
          }
        };
      }

      String speedSensorId = getSpeedSensorId(senseBox); // Pass senseBox

      data['speed_${timestamp.toIso8601String()}'] = {
        'sensor': speedSensorId,
        'value': (geoData['speed'] as double).toStringAsFixed(2),
        'createdAt': timestamp.toUtc().toIso8601String(),
        'location': {
          'lat': geoData['latitude'] as double,
          'lng': geoData['longitude'] as double,
        }
      };
    }

    return data;
  }

  Future<void> uploadDataWithRetry(
      Map<String, dynamic> data, String senseBoxId) async {
    try {
      await uploadDataToOpenSenseMap(data, senseBoxId);
    } catch (e) {
      if (e is TooManyRequestsException) {
        debugPrint(
            'Received 429 Too Many Requests. Retrying after ${e.retryAfter} seconds.');
        await Future.delayed(Duration(seconds: e.retryAfter));
        await uploadDataToOpenSenseMap(
            data, senseBoxId); // Retry once after waiting
      } else {
        rethrow; // Propagate other exceptions
      }
    }
  }

  // Legacy method - kept for compatibility but not used in optimized flow
  Map<String, dynamic> prepareDataToUpload(
      List<GeolocationData> geoDataToUpload) {
    Map<String, dynamic> data = {};

    // Get current senseBox and check if it's available
    final senseBox = getCurrentSenseBox();
    if (senseBox == null) {
      return data;
    }

    for (var geoData in geoDataToUpload) {
      for (var sensorData in geoData.sensorData) {
        String? sensorTitle =
            getTitleFromSensorKey(sensorData.title, sensorData.attribute);

        if (sensorTitle == null) {
          continue;
        }

        Sensor? sensor = getMatchingSensor(
            sensorTitle, senseBox); // Use non-nullable senseBox

        // Skip if sensor is not found
        if (sensor == null || sensorData.value.isNaN) {
          continue;
        }

        data[sensor.id! + geoData.timestamp.toIso8601String()] = {
          'sensor': sensor.id,
          'value': sensorData.value.toStringAsFixed(2),
          'createdAt': geoData.timestamp.toUtc().toIso8601String(),
          'location': {
            'lat': geoData.latitude,
            'lng': geoData.longitude,
          }
        };
      }

      String speedSensorId =
          getSpeedSensorId(senseBox); // Use non-nullable senseBox

      data['speed_${geoData.timestamp.toIso8601String()}'] = {
        'sensor': speedSensorId,
        'value': geoData.speed.toStringAsFixed(2),
        'createdAt': geoData.timestamp.toUtc().toIso8601String(),
        'location': {
          'lat': geoData.latitude,
          'lng': geoData.longitude,
        }
      };
    }

    return data;
  }

  Sensor? getMatchingSensor(String sensorTitle, SenseBox senseBox) {
    return senseBox.sensors!
        .where((sensor) =>
            sensor.title!.toLowerCase() == sensorTitle.toLowerCase())
        .firstOrNull;
  }

  String getSpeedSensorId(SenseBox senseBox) {
    return senseBox.sensors!
        .firstWhere((sensor) => sensor.title == 'Speed')
        .id!;
  }

  Future<void> uploadDataToOpenSenseMap(
      Map<String, dynamic> data, String senseBoxId) async {
    try {
      await openSenseMapService.uploadData(senseBoxId, data);
    } catch (error, stack) {
      ErrorService.handleError(error, stack, sendToSentry: false);
    }
  }
}
