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
import 'package:sensebox_bike/models/geolocation_dto.dart';
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

  // Buffering for background writes
  final List<GeolocationDto> _geoBuffer = [];
  final int _bufferSize = 10; // Adjust as needed
  bool _isWriting = false;

  GeolocationBloc(this.isarService, this.recordingBloc, this.settingsBloc);

  void startListening() async {
    try {
      await PermissionService.ensureLocationPermissionsGranted();

      late LocationSettings locationSettings;

      if (defaultTargetPlatform == TargetPlatform.android) {
        PermissionStatus status = await Permission.notification.request();
        if (status.isGranted) {
          locationSettings = AndroidSettings(
              accuracy: LocationAccuracy.best,
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
          accuracy: LocationAccuracy.best,
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

          await _bufferGeolocationData(
              geolocationData); // Buffer instead of immediate save
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
    await PermissionService.ensureLocationPermissionsGranted();

    return Geolocator.getCurrentPosition();
  }

  // function to stop listening to geolocation changes
  void stopListening() {
    _positionStreamSubscription?.cancel();
    // Flush any remaining buffered data
    _flushGeolocationBuffer();
  }

  /// Buffer geolocation data and write in batches
  Future<void> _bufferGeolocationData(GeolocationData data) async {
    try {
      // Get the privacy zones from the settings bloc
      final privacyZones = settingsBloc.privacyZones
          .map((e) => Turf.Polygon.fromJson(jsonDecode(e)));

      // Check if the current location is in a privacy zone
      bool isInZone = isInsidePrivacyZone(privacyZones, data);

      if (!isInZone) {
        // Convert to DTO for buffering
        final dto = GeolocationDto(
          latitude: data.latitude,
          longitude: data.longitude,
          speed: data.speed,
          timestamp: data.timestamp,
          trackId: recordingBloc.currentTrack!.id,
        );

        _geoBuffer.add(dto);

        // If buffer is full and not already writing, flush in background
        if (_geoBuffer.length >= _bufferSize && !_isWriting) {
          await _flushGeolocationBuffer();
        }
      }
    } catch (e) {
      print('Error buffering geolocation data: $e');
    }
  }

  /// Flush buffered geolocations to background write
  Future<void> _flushGeolocationBuffer() async {
    if (_geoBuffer.isNotEmpty && !_isWriting) {
      _isWriting = true;
      final batch = List<GeolocationDto>.from(_geoBuffer);
      _geoBuffer.clear();

      try {
        await isarService.geolocationService.saveGeolocationsBatch(batch);
      } catch (e) {
        print('Error writing geolocation batch: $e');
        // Optionally add back to buffer on error
        _geoBuffer.addAll(batch);
      } finally {
        _isWriting = false;
      }
    }
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
