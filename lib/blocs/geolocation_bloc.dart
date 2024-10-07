// File: lib/blocs/geolocation_bloc.dart
import 'dart:async';
import 'package:flutter/material.dart';
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

  StreamSubscription<Position>? _positionStreamSubscription;

  final IsarService isarService;
  final RecordingBloc recordingBloc;

  GeolocationBloc(this.isarService, this.recordingBloc) {
    // Start listening to geolocation changes
    // _startListening();
  }

  _checkPermissions() async {
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
  }

  void startListening() async {
    await _checkPermissions();

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
                notificationIcon:
                    AndroidResource(name: "@mipmap/ic_stat_sensebox_bike_logo"),
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
      GeolocationData geolocationData = GeolocationData()
        ..latitude = position.latitude
        ..longitude = position.longitude
        ..speed = position.speed
        ..timestamp = position.timestamp;
      // ..track.value = recordingBloc.currentTrack;

      if (recordingBloc.isRecording && recordingBloc.currentTrack != null) {
        geolocationData.track.value = recordingBloc.currentTrack;
        await _saveGeolocationData(geolocationData); // Save to database
      }

      _geolocationController.add(geolocationData);

      notifyListeners();
    });
  }

  // function to get the current location
  Future<Position> getCurrentLocation() async {
    await _checkPermissions();

    return Geolocator.getCurrentPosition();
  }

  // function to stop listening to geolocation changes
  void stopListening() {
    _positionStreamSubscription?.cancel();
  }

  Future<void> _saveGeolocationData(GeolocationData data) async {
    try {
      await isarService.geolocationService.saveGeolocationData(data);
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
