// File: lib/blocs/geolocation_bloc.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sensebox_bike/blocs/recording_bloc.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sensebox_bike/blocs/settings_bloc.dart';
import 'package:sensebox_bike/models/geolocation_data.dart';
import 'package:sensebox_bike/services/error_service.dart';
import 'package:sensebox_bike/services/isar_service.dart';
import 'package:sensebox_bike/services/permission_service.dart';
import 'package:sensebox_bike/utils/geo_utils.dart';
import 'package:turf/turf.dart' as Turf;

class GeolocationBloc with ChangeNotifier {
  // final StreamController<GeolocationData> _geolocationController =
  //     StreamController.broadcast();
  // Stream<GeolocationData> get geolocationStream =>
  //     _geolocationController.stream;

  StreamSubscription<Position>? _positionStreamSubscription;

  final IsarService isarService;
  final RecordingBloc recordingBloc;
  final SettingsBloc settingsBloc;

  GeolocationBloc(this.isarService, this.recordingBloc, this.settingsBloc);

  void startListening() async {
    try {
      await PermissionService.checkLocationPermissions();

      late LocationSettings locationSettings;

      if (defaultTargetPlatform == TargetPlatform.android) {
        PermissionStatus status = await Permission.notification.request();
        if (status.isGranted) {
          locationSettings = AndroidSettings(
              accuracy: LocationAccuracy.high,
              foregroundNotificationConfig: const ForegroundNotificationConfig(
                  notificationText:
                      "senseBox:bike will record your location in the background",
                  notificationTitle: "Running in the background",
                  enableWakeLock: true,
                  notificationIcon: AndroidResource(
                      name: "@mipmap/ic_stat_sensebox_bike_logo"),
                  color: Colors.blue));
        } else {
          return Future.error('Notification permissions are denied');
        }
      } else if (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS) {
        locationSettings = AppleSettings(
          accuracy: LocationAccuracy.high,
          activityType: ActivityType.fitness,
          // Only set to true if our app will be started up in the background.
          showBackgroundLocationIndicator: false,
        );
      }

      // Listen to position stream
      _positionStreamSubscription =
          Geolocator.getPositionStream(locationSettings: locationSettings)
              .listen((Position position) async {
        // TODO: this is not a good practice to create a new object and not save it

        if (recordingBloc.isRecording && recordingBloc.currentTrack != null) {
          GeolocationData geolocationData = GeolocationData()
            ..latitude = position.latitude
            ..longitude = position.longitude
            ..speed = position.speed
            ..timestamp = position.timestamp
            ..track.value = recordingBloc.currentTrack;

          await _saveGeolocationData(geolocationData); // Save to database
        }

        // _geolocationController.add(geolocationData);

        notifyListeners();
      });

    } catch (e, stack) {
      ErrorService.handleError(e, stack);
    }
  }

  // function to get the current location
  Future<Position> getCurrentLocation() async {
    await PermissionService.checkLocationPermissions();

    return Geolocator.getCurrentPosition();
  }

  // function to stop listening to geolocation changes
  void stopListening() {
    _positionStreamSubscription?.cancel();
  }

  /// Save the geolocation data to the database
  /// Check if the current location is in a privacy zone
  Future<void> _saveGeolocationData(GeolocationData data) async {
    try {
      // Get the privacy zones from the settings bloc
      final privacyZones = settingsBloc.privacyZones
          .map((e) => Turf.Polygon.fromJson(jsonDecode(e)));

      // Close the privacy zones
      bool isInZone = isInsidePrivacyZone(privacyZones, data);

      if (!isInZone) {
        await isarService.geolocationService.saveGeolocationData(data);
      }
    } catch (e) {
      print('Error saving geolocation data: $e');
    }
  }

  @override
  void dispose() {
    // _geolocationController.close();
    super.dispose();
  }
}
