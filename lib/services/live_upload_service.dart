import 'dart:async';
import 'package:sensebox_bike/blocs/settings_bloc.dart';
import 'package:sensebox_bike/models/geolocation_data.dart';
import 'package:sensebox_bike/models/sensebox.dart';
import 'package:sensebox_bike/services/isar_service.dart';
import 'package:sensebox_bike/services/opensensemap_service.dart';
import 'package:sensebox_bike/utils/sensor_utils.dart';

class LiveUploadService {
  final OpenSenseMapService openSenseMapService;
  final SettingsBloc settingsBloc;
  final IsarService isarService = IsarService();
  final SenseBox senseBox; // ID of the senseBox to upload data to

  final int trackId;

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

            await uploadDataToOpenSenseMap(data);

            _uploadedIds.addAll(geoDataToUpload.map((e) => e.id));
          } catch (e) {
            // Handle upload error
            print('Failed to upload data: $e');
          }
        }

        isUploading = false;
      });
    });
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
