// File: lib/blocs/geolocation_bloc.dart
import 'dart:async';
import 'package:permission_handler/permission_handler.dart';
import 'package:sensebox_bike/blocs/recording_bloc.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sensebox_bike/models/geolocation_data.dart';
import 'package:sensebox_bike/services/isar_service.dart';

class GeolocationBloc with ChangeNotifier {
  final StreamController<GeolocationData> _geolocationController =
      StreamController.broadcast();
  Stream<GeolocationData> get geolocationStream =>
      _geolocationController.stream;

  final IsarService isarService;
  final RecordingBloc recordingBloc;

  GeolocationBloc(this.isarService, this.recordingBloc) {
    // Start listening to geolocation changes
    _startListening();
  }

  void _startListening() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Check if location services are enabled
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return Future.error('Location services are disabled.');
    }

    // Check and request location permissions
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return Future.error('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return Future.error('Location permissions are permanently denied.');
    }

    late LocationSettings locationSettings;

    if (defaultTargetPlatform == TargetPlatform.android) {
      PermissionStatus status = await Permission.notification.request();
      if (status.isGranted) {
        locationSettings = AndroidSettings(
            accuracy: LocationAccuracy.high,
            foregroundNotificationConfig: const ForegroundNotificationConfig(
              notificationText:
                  "Example app will continue to receive your location even when you aren't using it",
              notificationTitle: "Running in Background",
              enableWakeLock: true,
            ));
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
    Geolocator.getPositionStream(locationSettings: locationSettings)
        .listen((Position position) async {
      print('Position: $position');
      print(recordingBloc.isRecording);
      print(recordingBloc.currentTrack);
      if (recordingBloc.isRecording && recordingBloc.currentTrack != null) {
        GeolocationData geolocationData = GeolocationData()
          ..latitude = position.latitude
          ..longitude = position.longitude
          ..speed = position.speed
          ..timestamp = position.timestamp
          ..track.value = recordingBloc.currentTrack!;

        await _saveGeolocationData(geolocationData); // Save to database
        _geolocationController.add(geolocationData);
      }
      notifyListeners();
    });
  }

  Future<void> _saveGeolocationData(GeolocationData data) async {
    try {
      await isarService.saveGeolocationData(data);
    } catch (e) {
      print('Error saving geolocation data: $e');
    }
  }

  @override
  void dispose() {
    _geolocationController.close();
    super.dispose();
  }
}
