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
import 'package:sensebox_bike/utils/privacy_zone_checker.dart';

class GeolocationBloc with ChangeNotifier {
  final StreamController<GeolocationData> _geolocationController =
      StreamController.broadcast();
  Stream<GeolocationData> get geolocationStream =>
      _geolocationController.stream;

  StreamSubscription<Position>? _positionStreamSubscription;
  GeolocationData? _lastEmittedPosition;
  Timer? _stationaryLocationTimer;
  final PrivacyZoneChecker _privacyZoneChecker = PrivacyZoneChecker();

  final IsarService isarService;
  final RecordingBloc recordingBloc;
  final SettingsBloc settingsBloc;

  GeolocationBloc(this.isarService, this.recordingBloc, this.settingsBloc) {
    _privacyZoneChecker.updatePrivacyZones(settingsBloc.privacyZones);
  }

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

      _positionStreamSubscription =
          Geolocator.getPositionStream(locationSettings: locationSettings)
              .listen((Position position) async {
        final geolocationData = _createGeolocationFromPosition(position);

        if (_shouldSkipGeolocation(geolocationData)) {
          return;
        }

        _lastEmittedPosition = geolocationData;
        _resetStationaryLocationTimer();

        await _saveGeolocationIfRecording(geolocationData);
        _emitGeolocation(geolocationData);
      });
      
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
      final geolocationData = _createGeolocationFromPosition(position);

      if (_shouldSkipGeolocation(geolocationData)) {
        return;
      }

      _lastEmittedPosition = geolocationData;
      await _saveGeolocationIfRecording(geolocationData);
      _emitGeolocation(geolocationData);
    } catch (e, stack) {
      ErrorService.handleError(e, stack);
    }
  }

  void _startStationaryLocationTimer() {
    _stopStationaryLocationTimer();
    
    if (!recordingBloc.isRecording) {
      return;
    }
    
    _stationaryLocationTimer = Timer.periodic(const Duration(seconds: 20), (timer) async {
      if (!recordingBloc.isRecording) {
        _stopStationaryLocationTimer();
        return;
      }
      
      if (_lastEmittedPosition != null) {
        final geolocationData = GeolocationData()
          ..latitude = _lastEmittedPosition!.latitude
          ..longitude = _lastEmittedPosition!.longitude
          ..speed = _lastEmittedPosition!.speed
          ..timestamp = DateTime.now().toUtc();

        if (_shouldSkipGeolocation(geolocationData)) {
          return;
        }

        await _saveGeolocationIfRecording(geolocationData);
        _emitGeolocation(geolocationData);
      } else {
        try {
          await getCurrentLocationAndEmit();
        } catch (e) {
        }
      }
    });
  }
  
  void _resetStationaryLocationTimer() {
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

  GeolocationData _createGeolocationFromPosition(Position position) {
    return GeolocationData()
      ..latitude = position.latitude
      ..longitude = position.longitude
      ..speed = position.speed
      ..timestamp = position.timestamp.isUtc
          ? position.timestamp
          : position.timestamp.toUtc();
  }

  bool _shouldSkipGeolocation(GeolocationData geolocationData) {
    if (_lastEmittedPosition != null &&
        _lastEmittedPosition!.timestamp == geolocationData.timestamp &&
        _lastEmittedPosition!.latitude == geolocationData.latitude &&
        _lastEmittedPosition!.longitude == geolocationData.longitude) {
      return true;
    }

    if (recordingBloc.isRecording) {
      _privacyZoneChecker.updatePrivacyZones(settingsBloc.privacyZones);
    }

    if (_privacyZoneChecker.isInsidePrivacyZone(geolocationData)) {
      return true;
    }

    return false;
  }

  Future<void> _saveGeolocationIfRecording(
      GeolocationData geolocationData) async {
    if (!recordingBloc.isRecording || recordingBloc.currentTrack == null) {
      return;
    }

    geolocationData.track.value = recordingBloc.currentTrack;

    try {
      final savedId = await isarService.geolocationService
          .saveGeolocationData(geolocationData);
      geolocationData.id = savedId;

      final gpsSpeedSensorData = createGpsSpeedSensorData(geolocationData);
      if (shouldStoreSensorData(gpsSpeedSensorData)) {
        try {
          await isarService.sensorService.saveSensorData(gpsSpeedSensorData);
        } catch (e) {}
      }
    } catch (e) {
      geolocationData.id = 0;
    }
  }

  void _emitGeolocation(GeolocationData geolocationData) {
    _geolocationController.add(geolocationData);
    notifyListeners();
  }

  @override
  void dispose() {
    _privacyZoneChecker.dispose();
    _geolocationController.close();
    super.dispose();
  }
}
