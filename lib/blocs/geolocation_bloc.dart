// File: lib/blocs/geolocation_bloc.dart
import 'dart:async';
import 'package:ble_app/providers/recording_state_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:ble_app/models/geolocation_data.dart';
import 'package:ble_app/services/isar_service.dart';

class GeolocationBloc with ChangeNotifier {
  final StreamController<GeolocationData> _geolocationController =
      StreamController.broadcast();
  Stream<GeolocationData> get geolocationStream =>
      _geolocationController.stream;

  final IsarService isarService;
  final RecordingStateProvider recordingProvider;

  GeolocationBloc(this.isarService, this.recordingProvider) {
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
      locationSettings = AndroidSettings(
          accuracy: LocationAccuracy.high,
          forceLocationManager: true,
          foregroundNotificationConfig: const ForegroundNotificationConfig(
            notificationText:
                "Example app will continue to receive your location even when you aren't using it",
            notificationTitle: "Running in Background",
            enableWakeLock: true,
          ));
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
      if (recordingProvider.isRecording) {
        GeolocationData geolocationData = GeolocationData()
          ..latitude = position.latitude
          ..longitude = position.longitude
          ..speed = position.speed
          ..timestamp = position.timestamp;

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
