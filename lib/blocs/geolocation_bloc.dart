// File: lib/blocs/geolocation_bloc.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sensebox_bike/blocs/recording_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sensebox_bike/blocs/settings_bloc.dart';
import 'package:sensebox_bike/models/data_collection_mode.dart';
import 'package:sensebox_bike/models/geolocation_data.dart';
import 'package:sensebox_bike/models/sensor_data.dart';
import 'package:sensebox_bike/services/error_service.dart';
import 'package:sensebox_bike/services/isar_service.dart';
import 'package:sensebox_bike/services/location_permission_platform.dart';
import 'package:sensebox_bike/services/permission_service.dart';
import 'package:sensebox_bike/utils/sensor_utils.dart';
import 'package:sensebox_bike/utils/privacy_zone_checker.dart';
import 'package:sensebox_bike/utils/geolocation_utils.dart';

class GeolocationBloc with ChangeNotifier {
  final StreamController<GeolocationData> _geolocationController =
      StreamController.broadcast();
  Stream<GeolocationData> get geolocationStream =>
      _geolocationController.stream;

  StreamSubscription<Position>? _positionStreamSubscription;
  StreamSubscription<List<String>>? _privacyZonesSubscription;
  GeolocationData? _lastEmittedPosition;
  Timer? _stationaryLocationTimer;
  Timer? _periodicCollectionTimer;
  bool _isCapturingSample = false;
  VoidCallback? _recordingListener;
  final PrivacyZoneChecker _privacyZoneChecker = PrivacyZoneChecker();
  bool _isListening = false;

  bool _isForegroundServiceStartError(Object error) {
    return error is PlatformException &&
        error.message != null &&
        error.message!.contains('Starting FGS with type location');
  }

  Future<void> _handlePositionStreamError(Object error, StackTrace stack) async {
    ErrorService.handleError(error, stack);

    await _positionStreamSubscription?.cancel();
    _positionStreamSubscription = null;
    _stopStationaryLocationTimer();
    _stopPeriodicCollectionTimer();
    _isListening = false;

    if (_isForegroundServiceStartError(error)) {
      // Keep state consistent when Android disallows starting location FGS
      // from background (e.g. missing background location runtime grant).
      notifyListeners();
      return;
    }

    notifyListeners();
  }

  bool get isListening => _isListening;

  final IsarService isarService;
  final RecordingBloc recordingBloc;
  final SettingsBloc settingsBloc;

  /// Returns whether box sensor data is currently flowing (i.e. the BLE link is
  /// live). When this returns false, geolocations (and their GPS speed) are not
  /// persisted, so a dropped link mid-ride can't produce a GPS-only "ghost"
  /// track. Defaults to always-active when not provided (e.g. in tests).
  final bool Function()? _isSensorDataActive;

  /// For periodic / on-tap: collect last BLE readings to persist with the sample.
  List<SensorData> Function(GeolocationData geo)? _collectInstantSensorData;

  GeolocationBloc(this.isarService, this.recordingBloc, this.settingsBloc,
      {bool Function()? isSensorDataActive})
      : _isSensorDataActive = isSensorDataActive {
    _privacyZoneChecker.updatePrivacyZones(settingsBloc.privacyZones);
    _privacyZonesSubscription = settingsBloc.privacyZonesStream.listen((zones) {
      _privacyZoneChecker.updatePrivacyZones(zones);
    });

    _recordingListener = _onRecordingChanged;
    recordingBloc.isRecordingNotifier.addListener(_recordingListener!);
  }

  void _onRecordingChanged() {
    if (recordingBloc.isRecording) {
      if (recordingBloc.activeCollectionMode.usesPeriodicTimer) {
        _startPeriodicCollectionTimer();
      } else if (recordingBloc.activeCollectionMode.usesGpsStreamPersistence) {
        _stopPeriodicCollectionTimer();
        _startStationaryLocationTimer();
      } else {
        // onTap: no auto timers; GPS stream only refreshes last position.
        _stopPeriodicCollectionTimer();
        _stopStationaryLocationTimer();
      }
    } else {
      _stopPeriodicCollectionTimer();
      _stopStationaryLocationTimer();
    }
  }

  void startListening() async {
    if (_isListening) {
      return;
    }
    
    try {
      await PermissionService.ensureLocationPermissionsGranted();

      late LocationSettings locationSettings;

      if (isAndroidPlatform) {
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
          throw Exception('Notification permissions are denied');
        }
      } else if (isIosPlatform) {
        locationSettings = AppleSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          distanceFilter: 0,
          activityType: ActivityType.fitness,
          pauseLocationUpdatesAutomatically: false,
          showBackgroundLocationIndicator: true,
          allowBackgroundLocationUpdates: true,
        );
      }

      await _positionStreamSubscription?.cancel();
        _positionStreamSubscription =
          Geolocator.getPositionStream(locationSettings: locationSettings)
            .listen((Position position) async {
        final geolocationData = _createGeolocationFromPosition(position);

        if (shouldSkipGeolocation(geolocationData)) {
          return;
        }

        _lastEmittedPosition = geolocationData;

        if (!recordingBloc.activeCollectionMode.usesGpsStreamPersistence) {
          // periodic / onTap: refresh last known position only.
          return;
        }

        _resetStationaryLocationTimer();

        final shouldEmit = await _saveGeolocationIfRecording(geolocationData);
        if (shouldEmit) {
          _emitGeolocation(geolocationData);
        }

        await _applyIncomingGpsPosition(
          geolocationData,
          resetStationaryTimer: true,
        );
      }, onError: (Object error, StackTrace stack) {
        unawaited(_handlePositionStreamError(error, stack));
      }, cancelOnError: true);
      
      if (recordingBloc.isRecording) {
        _onRecordingChanged();
      } else if (recordingBloc.activeCollectionMode.usesGpsStreamPersistence) {
        _startStationaryLocationTimer();
      }
      _isListening = true;
    } catch (e, stack) {
      _positionStreamSubscription?.cancel();
      _positionStreamSubscription = null;
      _stopStationaryLocationTimer();
      _stopPeriodicCollectionTimer();
      _isListening = false;
      ErrorService.handleError(e, stack);
    }
  }

  // function to get the current location
  Future<Position> getCurrentLocation() async {
    await PermissionService.ensureLocationPermissionsGranted();

    return Geolocator.getCurrentPosition();
  }

  /// Single write/emit path for GPS-driven stationary ticks, periodic timer,
  /// and on-tap manual samples.
  Future<void> captureSample({DateTime? at}) async {
    if (_isCapturingSample) {
      return;
    }
    if (!recordingBloc.isRecording || recordingBloc.currentTrack == null) {
      return;
    }

    _isCapturingSample = true;
    try {
      GeolocationData? source = _lastEmittedPosition;
      if (source == null) {
        try {
          final position = await getCurrentLocation();
          source = _createGeolocationFromPosition(position);
          _lastEmittedPosition = source;
        } catch (e, stack) {
          ErrorService.handleError(e, stack);
          return;
        }
      }

      final geolocationData = _cloneGeolocationWithTimestamp(
        source,
        (at ?? DateTime.now()).toUtc(),
      );

      // Manual/periodic samples skip the 1s GPS throttle; still respect privacy.
      if (_privacyZoneChecker.isInsidePrivacyZone(geolocationData)) {
        return;
      }

      _lastEmittedPosition = geolocationData;

      if (!recordingBloc.activeCollectionMode.usesGpsStreamPersistence) {
        // Avoid dense GPS-driven samples when in periodic/onTap mode.
        return;
      }

      final shouldEmit = await _saveGeolocationIfRecording(geolocationData);
      if (shouldEmit) {
        _lastEmittedPosition = geolocationData;
      }
    } finally {
      _isCapturingSample = false;
    }
  }

  /// Single write/emit path for GPS-driven stationary ticks, periodic timer,
  /// and on-tap manual samples.
  Future<void> captureSample({DateTime? at}) async {
    if (_isCapturingSample) {
      return;
    }
    if (!recordingBloc.isRecording || recordingBloc.currentTrack == null) {
      return;
    }

    _isCapturingSample = true;
    try {
      GeolocationData? source = _lastEmittedPosition;
      if (source == null) {
        try {
          final position = await getCurrentLocation();
          source = _createGeolocationFromPosition(position);
          _lastEmittedPosition = source;
        } catch (e, stack) {
          ErrorService.handleError(e, stack);
          return;
        }
      }

      final geolocationData = GeolocationData()
        ..latitude = source.latitude
        ..longitude = source.longitude
        ..speed = source.speed
        ..timestamp = (at ?? DateTime.now()).toUtc();

      // Manual/periodic samples skip the 1s GPS throttle; still respect privacy.
      if (_privacyZoneChecker.isInsidePrivacyZone(geolocationData)) {
        return;
      }

      final shouldEmit = await _saveGeolocationIfRecording(geolocationData);
      if (shouldEmit) {
        _lastEmittedPosition = geolocationData;
        _emitGeolocation(geolocationData);
      }
    } finally {
      _isCapturingSample = false;
    }
  }

  void _startStationaryLocationTimer() {
    _stopStationaryLocationTimer();
    
    if (!recordingBloc.isRecording ||
        !recordingBloc.activeCollectionMode.usesGpsStreamPersistence) {
      return;
    }
    
    _stationaryLocationTimer = Timer.periodic(const Duration(seconds: 20), (timer) async {
      if (!recordingBloc.isRecording ||
          !recordingBloc.activeCollectionMode.usesGpsStreamPersistence) {
        _stopStationaryLocationTimer();
        return;
      }

      await captureSample();
    });
  }
  
  void _stopStationaryLocationTimer() {
    _stationaryLocationTimer?.cancel();
    _stationaryLocationTimer = null;
  }

  void _startPeriodicCollectionTimer() {
    _stopPeriodicCollectionTimer();
    _stopStationaryLocationTimer();

    if (!recordingBloc.isRecording ||
        !recordingBloc.activeCollectionMode.usesPeriodicTimer) {
      return;
    }

    final interval =
        Duration(seconds: recordingBloc.collectionIntervalSeconds);
    _periodicCollectionTimer = Timer.periodic(interval, (_) {
      unawaited(captureSample());
    });
  }

  void _stopPeriodicCollectionTimer() {
    _periodicCollectionTimer?.cancel();
    _periodicCollectionTimer = null;
  }

  // function to stop listening to geolocation changes
  void stopListening() {
    _positionStreamSubscription?.cancel();
    _stopStationaryLocationTimer();
    _stopPeriodicCollectionTimer();
    _lastEmittedPosition = null;
    _isListening = false;
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

  bool shouldSkipGeolocation(GeolocationData geolocationData,
      {GeolocationData? lastEmittedPosition}) {
    final lastPosition = lastEmittedPosition ?? _lastEmittedPosition;

    if (lastPosition == null) {
      final inPrivacyZone =
          _privacyZoneChecker.isInsidePrivacyZone(geolocationData);

      return inPrivacyZone;
    }

    if (shouldSkipGeolocationByTime(geolocationData, lastPosition)) {
      return true;
    }

    if (_privacyZoneChecker.isInsidePrivacyZone(geolocationData)) {
      return true;
    }

    return false;
  }

  GeolocationData _cloneGeolocationWithTimestamp(
    GeolocationData source,
    DateTime timestamp,
  ) {
    return GeolocationData()
      ..latitude = source.latitude
      ..longitude = source.longitude
      ..speed = source.speed
      ..timestamp = timestamp;
  }

  Future<void> _applyIncomingGpsPosition(
    GeolocationData geolocationData, {
    bool resetStationaryTimer = false,
  }) async {
    if (shouldSkipGeolocation(geolocationData)) {
      return;
    }

    _lastEmittedPosition = geolocationData;

    // Defensive: stream handler should already gate this; async gaps can still
    // reach here after the user switched to on-tap / periodic.
    if (!recordingBloc.isRecording ||
        !recordingBloc.activeCollectionMode.isGpsDriven) {
      return;
    }

    if (resetStationaryTimer) {
      _startStationaryLocationTimer();
    }

    await _persistAndEmit(geolocationData);
  }

  Future<bool> _persistAndEmit(
    GeolocationData geolocationData, {
    bool allowFinalGeolocation = false,
  }) async {
    final shouldEmit = await _saveGeolocationIfRecording(
      geolocationData,
      allowFinalGeolocation: allowFinalGeolocation,
    );
    if (shouldEmit) {
      _emitGeolocation(geolocationData);
    }
    return shouldEmit;
  }

  Future<bool> _saveGeolocationIfRecording(
      GeolocationData geolocationData,
      {bool allowFinalGeolocation = false}) async {
    if ((!recordingBloc.isRecording && !allowFinalGeolocation) ||
        recordingBloc.currentTrack == null) {
      return false;
    }

    // Only persist geolocations while box sensor data is actively arriving.
    // Prevents GPS-only "ghost" tracks when the BLE link drops mid-ride (e.g.
    // Android power-save disabling the adapter or background BLE scanning).
    if (!(_isSensorDataActive?.call() ?? true)) {
      return false;
    }

    geolocationData.track.value = recordingBloc.currentTrack;

    try {
      final gpsSpeedSensorData = createGpsSpeedSensorData(geolocationData);
      final sensorRows = <SensorData>[
        if (shouldStoreSensorData(gpsSpeedSensorData)) gpsSpeedSensorData,
      ];

      // Periodic / on-tap: persist last BLE readings with the sample (no
      // lookback aggregation). Skip GPS-only samples when nothing is available.
      if (!recordingBloc.activeCollectionMode.isGpsDriven) {
        final instantRows =
            _collectInstantSensorData?.call(geolocationData) ?? const [];
        if (instantRows.isEmpty) {
          return false;
        }
        sensorRows.addAll(instantRows);
      }

      final savedId = await isarService.geolocationService
          .saveGeolocationWithSensors(geolocationData, sensorRows);
      geolocationData.id = savedId;

      return true;
    } catch (e) {
      geolocationData.id = 0;
      return false;
    }
  }

  void _emitGeolocation(GeolocationData geolocationData) {
    _geolocationController.add(geolocationData);
    notifyListeners();
  }

  Future<void> emitFinalGeolocation() async {
    if (_lastEmittedPosition == null || recordingBloc.currentTrack == null) {
      return;
    }

    final stopTimestamp =
        recordingBloc.lastRecordingStopTimestamp ?? DateTime.now().toUtc();

    final finalGeolocation = _cloneGeolocationWithTimestamp(
      _lastEmittedPosition!,
      stopTimestamp,
    );

    final lastTimestamp =
        _lastEmittedPosition!.timestamp.millisecondsSinceEpoch;
    final stopTimestampMs = stopTimestamp.millisecondsSinceEpoch;

    if (lastTimestamp == stopTimestampMs) {
      return;
    }

    if (_privacyZoneChecker.isInsidePrivacyZone(finalGeolocation)) {
      return;
    }

    final shouldEmit = await _persistAndEmit(
      finalGeolocation,
      allowFinalGeolocation: true,
    );
    if (shouldEmit) {
      _lastEmittedPosition = finalGeolocation;
    }
  }

  @override
  void dispose() {
    if (_recordingListener != null) {
      recordingBloc.isRecordingNotifier.removeListener(_recordingListener!);
      _recordingListener = null;
    }
    stopListening();
    _privacyZonesSubscription?.cancel();
    _privacyZoneChecker.dispose();
    _geolocationController.close();
    super.dispose();
  }
}
