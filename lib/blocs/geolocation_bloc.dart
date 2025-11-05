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
  Timer? _stationaryLocationTimer;

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

        // Reset stationary timer since we got a new position
        _resetStationaryLocationTimer();

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
      
      // Start timer to emit periodic location updates when stationary
      // This ensures sensors can upload data even when GPS isn't updating
      _startStationaryLocationTimer();
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
        
        // Save geolocation immediately to get an ID so sensors can use it
        // This is critical for direct upload to work when phone is stationary
        try {
          final savedId = await isarService.geolocationService
              .saveGeolocationData(geolocationData);
          geolocationData.id = savedId;
          debugPrint('[GeolocationBloc] getCurrentLocationAndEmit: Saved initial location with id=$savedId');

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
          debugPrint('[GeolocationBloc] getCurrentLocationAndEmit: Failed to save location: $e');
        }
      }

      // Update last emitted position to prevent duplicate filtering
      _lastEmittedPosition = geolocationData;
      
      _geolocationController.add(geolocationData);
      notifyListeners();
    } catch (e, stack) {
      debugPrint('[GeolocationBloc] getCurrentLocationAndEmit: Error getting location: $e');
      ErrorService.handleError(e, stack);
    }
  }

  /// Start a timer that periodically emits the last known location
  /// when the device is stationary. This ensures sensors can upload data
  /// even when GPS isn't providing new updates.
  void _startStationaryLocationTimer() {
    _stopStationaryLocationTimer();
    
    if (!recordingBloc.isRecording) {
      return;
    }
    
    // Emit location every 20 seconds when stationary
    // This allows sensors to flush and upload data regularly
    _stationaryLocationTimer = Timer.periodic(const Duration(seconds: 20), (timer) async {
      if (!recordingBloc.isRecording) {
        _stopStationaryLocationTimer();
        return;
      }
      
      if (_lastEmittedPosition != null) {
        // Create a new geolocation with updated timestamp
        final geolocationData = GeolocationData()
          ..latitude = _lastEmittedPosition!.latitude
          ..longitude = _lastEmittedPosition!.longitude
          ..speed = _lastEmittedPosition!.speed
          ..timestamp = DateTime.now();
        
        if (recordingBloc.currentTrack != null) {
          geolocationData.track.value = recordingBloc.currentTrack;
          
          try {
            final savedId = await isarService.geolocationService
                .saveGeolocationData(geolocationData);
            geolocationData.id = savedId;
            debugPrint('[GeolocationBloc] Stationary timer: Emitting location id=$savedId (stationary update)');
          } catch (e) {
            geolocationData.id = 0;
            debugPrint('[GeolocationBloc] Stationary timer: Failed to save location: $e');
          }
        }
        
        _geolocationController.add(geolocationData);
        notifyListeners();
      } else {
        // No last position yet, try to get current location
        try {
          await getCurrentLocationAndEmit();
        } catch (e) {
          debugPrint('[GeolocationBloc] Stationary timer: Failed to get location: $e');
        }
      }
    });
  }
  
  void _resetStationaryLocationTimer() {
    // Restart timer when new position arrives
    _startStationaryLocationTimer();
  }
  
  void _stopStationaryLocationTimer() {
    _stationaryLocationTimer?.cancel();
    _stationaryLocationTimer = null;
  }

  // function to stop listening to geolocation changes
  void stopListening() {
    _positionStreamSubscription?.cancel();
    _stopStationaryLocationTimer();
    _lastEmittedPosition = null;
  }

  @override
  void dispose() {
    _geolocationController.close();
    super.dispose();
  }
}
