// File: lib/blocs/geolocation_bloc.dart
import 'dart:async';
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
import 'package:sensebox_bike/utils/sensor_utils.dart';

class GeolocationBloc with ChangeNotifier {
  final StreamController<GeolocationData> _geolocationController =
      StreamController.broadcast();
  Stream<GeolocationData> get geolocationStream =>
      _geolocationController.stream;

  StreamSubscription<Position>? _positionStreamSubscription;
  GeolocationData? _lastEmittedPosition;

  final IsarService isarService;
  final RecordingBloc recordingBloc;
  final SettingsBloc settingsBloc;

  GeolocationBloc(this.isarService, this.recordingBloc, this.settingsBloc);

  void startListening() async {
    try {
      await PermissionService.ensureLocationPermissionsGranted();

      late LocationSettings locationSettings;

      if (defaultTargetPlatform == TargetPlatform.android) {
        PermissionStatus status = await Permission.notification.request();
        if (status.isGranted) {
          locationSettings = AndroidSettings(
              accuracy: LocationAccuracy.bestForNavigation,
              distanceFilter: 0,
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
          accuracy: LocationAccuracy.bestForNavigation,
          distanceFilter: 0,
          activityType: ActivityType.fitness,
          pauseLocationUpdatesAutomatically: false,
          showBackgroundLocationIndicator: true,
          allowBackgroundLocationUpdates: true,
        );
      }

      // Listen to position stream
      _positionStreamSubscription =
          Geolocator.getPositionStream(locationSettings: locationSettings)
              .listen((Position position) async {
        
        // Create geolocation data object
        GeolocationData geolocationData = GeolocationData()
          ..latitude = position.latitude
          ..longitude = position.longitude
          ..speed = position.speed
          ..timestamp = position.timestamp;

        // Filter duplicates (iOS often emits same position multiple times)
        if (_lastEmittedPosition != null &&
            _lastEmittedPosition!.timestamp == geolocationData.timestamp &&
            _lastEmittedPosition!.latitude == geolocationData.latitude &&
            _lastEmittedPosition!.longitude == geolocationData.longitude) {
          return;
        }
        _lastEmittedPosition = geolocationData;

        if (recordingBloc.isRecording && recordingBloc.currentTrack != null) {
          geolocationData.track.value = recordingBloc.currentTrack;
          
          // Save geolocation immediately to avoid race conditions from multiple sensors
          try {
            final savedId = await isarService.geolocationService
                .saveGeolocationData(geolocationData);
            geolocationData.id = savedId;

            // Save GPS speed as SensorData for consistent UI display
            final gpsSpeedSensorData =
                createGpsSpeedSensorData(geolocationData);
            if (shouldStoreSensorData(gpsSpeedSensorData)) {
              try {
                await isarService.sensorService
                    .saveSensorData(gpsSpeedSensorData);
              } catch (e) {
                // Continue on error
              }
            }
          } catch (e) {
            // Set id to 0 on failure so sensors skip this point
            geolocationData.id = 0;
          }
        }

        // Emit to stream for real-time updates (with ID already set if recording)
        _geolocationController.add(geolocationData);

        notifyListeners();
      });
    } catch (e, stack) {
      ErrorService.handleError(e, stack);
    }
  }

  // function to get the current location
  Future<Position> getCurrentLocation() async {
    await PermissionService.ensureLocationPermissionsGranted();

    return Geolocator.getCurrentPosition();
  }

  Future<void> getCurrentLocationAndEmit() async {
    try {
      final position = await getCurrentLocation();

      // Create geolocation data object
      GeolocationData geolocationData = GeolocationData()
        ..latitude = position.latitude
        ..longitude = position.longitude
        ..speed = position.speed
        ..timestamp = position.timestamp;

      if (recordingBloc.isRecording && recordingBloc.currentTrack != null) {
        geolocationData.track.value = recordingBloc.currentTrack;
        // Note: GPS points are now saved by sensor classes when they have associated sensor data
        // This prevents duplicate GPS point saves
      }

      _geolocationController.add(geolocationData);
      notifyListeners();
    } catch (e, stack) {
      ErrorService.handleError(e, stack);
    }
  }

  // function to stop listening to geolocation changes
  void stopListening() {
    _positionStreamSubscription?.cancel();
    _lastEmittedPosition = null;
  }

  @override
  void dispose() {
    _geolocationController.close();
    super.dispose();
  }
}
