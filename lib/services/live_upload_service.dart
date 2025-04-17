import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:sensebox_bike/blocs/settings_bloc.dart';
import 'package:sensebox_bike/models/geolocation_data.dart';
import 'package:sensebox_bike/models/sensebox.dart';
import 'package:sensebox_bike/services/custom_exceptions.dart';
import 'package:sensebox_bike/services/isar_service.dart';
import 'package:sensebox_bike/services/opensensemap_service.dart';
import 'package:sensebox_bike/utils/sensor_utils.dart';
import "package:sensebox_bike/constants.dart";

class LiveUploadService {
  final OpenSenseMapService openSenseMapService;
  final SettingsBloc settingsBloc;
  final IsarService isarService = IsarService();
  final SenseBox senseBox; // ID of the senseBox to upload data to

  final int trackId;

  // vars to handle connectivity issues
  DateTime? _lastSuccessfulUpload;
  int _consecutiveFails = 0;

  // save uploaded ids to prevent double uploads
  final List<int> _uploadedIds = [];

  LiveUploadService({
    required this.openSenseMapService,
    required this.settingsBloc,
    required this.senseBox,
    required this.trackId,
  });

  void startUploading() {
    // a lock to prevent multiple uploads at the same time
    bool isUploading = false;

    isarService.geolocationService.getGeolocationStream().then((stream) {
      stream.listen((e) async {
        if (isUploading) {
          return;
        }

        isUploading = true;

        List<GeolocationData> geoData = await isarService.geolocationService
            .getGeolocationDataByTrackId(trackId);

        // remove latest item from the list, as it may still be filled with new data
        if (geoData.isNotEmpty) {
          geoData.removeLast();
        }

        List<GeolocationData> geoDataToUpload = geoData
            .where((element) => !_uploadedIds.contains(element.id))
            .toList();

        if (geoDataToUpload.isNotEmpty) {
          try {
            Map<String, dynamic> data = prepareDataToUpload(geoDataToUpload);

            //await uploadDataToOpenSenseMap(data);
            await uploadDataWithRetry(data);

            _uploadedIds.addAll(geoDataToUpload.map((e) => e.id));
            // track successful upload
            _lastSuccessfulUpload = DateTime.now();
            _consecutiveFails = 0;
          } catch (e) {
            // Handle upload error
            _consecutiveFails++;
            final lastSuccessfulUploadPeriod = DateTime.now()
                .subtract(Duration(minutes: premanentConnectivityFalurePeriod));
            final isPermanentConnectivityIssue =
                _lastSuccessfulUpload != null &&
                    _lastSuccessfulUpload!.isBefore(lastSuccessfulUploadPeriod);
            final isMaxRetries = _consecutiveFails >= maxRetries;

            if (isPermanentConnectivityIssue || isMaxRetries) {
              debugPrint(
                  'Permanent connectivity failure: No connection for more than $premanentConnectivityFalurePeriod minutes.');
              return;
            } else {
              // Retry posting data after the retry period if the number of consecutive fails is less than maxRetries
              debugPrint(
                  'Failed to upload data: $e. Retrying in $retryPeriod minutes (Attempt $_consecutiveFails of $maxRetries).');
              await Future.delayed(Duration(minutes: retryPeriod));
            }
          }
        }

        isUploading = false;
      });
    });
  }

  Future<void> uploadDataWithRetry(Map<String, dynamic> data) async {
    try {
      await uploadDataToOpenSenseMap(data);
    } catch (e) {
      if (e is TooManyRequestsException) {
        debugPrint(
            'Received 429 Too Many Requests. Retrying after ${e.retryAfter} seconds.');
        await Future.delayed(Duration(seconds: e.retryAfter));
        await uploadDataToOpenSenseMap(data); // Retry once after waiting
      } else {
        rethrow; // Propagate other exceptions
      }
    }
  }

  Map<String, dynamic> prepareDataToUpload(
      List<GeolocationData> geoDataToUpload) {
    Map<String, dynamic> data = {};

    for (var geoData in geoDataToUpload) {
      for (var sensorData in geoData.sensorData) {
        String? sensorTitle =
            getTitleFromSensorKey(sensorData.title, sensorData.attribute);

        if (sensorTitle == null) {
          continue;
        }

        Sensor? sensor = getMatchingSensor(sensorTitle);

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

      String speedSensorId = getSpeedSensorId();

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

  Sensor? getMatchingSensor(String sensorTitle) {
    return senseBox.sensors!
        .where((sensor) =>
            sensor.title!.toLowerCase() == sensorTitle.toLowerCase())
        .firstOrNull;
  }

  String getSpeedSensorId() {
    return senseBox.sensors!
        .firstWhere((sensor) => sensor.title == 'Speed')
        .id!;
  }

  Future<void> uploadDataToOpenSenseMap(Map<String, dynamic> data) async {
    await openSenseMapService.uploadData(senseBox.id, data);
  }
}
