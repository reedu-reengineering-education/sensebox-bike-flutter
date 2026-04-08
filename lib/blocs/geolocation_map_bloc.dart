import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sensebox_bike/blocs/geolocation_bloc.dart';
import 'package:sensebox_bike/blocs/recording_bloc.dart';
import 'package:sensebox_bike/blocs/opensensemap_bloc.dart';
import 'package:sensebox_bike/models/geolocation_data.dart';
import 'package:geolocator/geolocator.dart' as geolocator;

@immutable
class GeolocationMapState {
  const GeolocationMapState({
    required this.gpsBuffer,
    required this.isRecording,
    required this.latestLocation,
    required this.isAuthenticated,
  });

  final List<GeolocationData> gpsBuffer;
  final bool isRecording;
  final GeolocationData? latestLocation;
  final bool isAuthenticated;
}

class GeolocationMapBloc extends Cubit<GeolocationMapState> {
  static const double _mapNotificationDistanceMeters = 3.0;
  static const int _maxBufferedGpsPoints = 2000;

  // Dependencies
  final GeolocationBloc geolocationBloc;
  final RecordingBloc recordingBloc;
  final OpenSenseMapBloc osemBloc;

  // State management
  final List<GeolocationData> _gpsBuffer = [];
  bool _isRecording = false;
  GeolocationData? _latestLocation;
  GeolocationData? _lastNotifiedLocation;

  // Stream subscriptions
  StreamSubscription<GeolocationData>? _gpsSubscription;
  StreamSubscription<RecordingState>? _recordingSubscription;
  StreamSubscription<OpenSenseMapState>? _osemSubscription;

  // Getters
  List<GeolocationData> get gpsBuffer => List.unmodifiable(_gpsBuffer);
  bool get isRecording => _isRecording;
  bool get isAuthenticated => osemBloc.isAuthenticated;
  GeolocationData? get latestLocation => _latestLocation;
  bool get hasGpsData => _gpsBuffer.isNotEmpty;

  GeolocationMapBloc({
    required this.geolocationBloc,
    required this.recordingBloc,
    required this.osemBloc,
  }) : super(const GeolocationMapState(
          gpsBuffer: <GeolocationData>[],
          isRecording: false,
          latestLocation: null,
          isAuthenticated: false,
        )) {
    _initialize();
  }

  void _emitState() {
    if (!isClosed) {
      emit(GeolocationMapState(
        gpsBuffer: List<GeolocationData>.unmodifiable(_gpsBuffer),
        isRecording: _isRecording,
        latestLocation: _latestLocation,
        isAuthenticated: osemBloc.isAuthenticated,
      ));
    }
  }

  void _initialize() {
    _isRecording = recordingBloc.isRecording;

    _setupRecordingListener();
    _setupGpsListener();
    _setupAuthenticationListener();
  }

  void _setupRecordingListener() {
    _recordingSubscription = recordingBloc.stream.listen((recordingState) {
      final newRecordingState = recordingState.isRecording;
      if (_isRecording && !newRecordingState) {
        // Recording stopped - clear buffer
        _clearGpsBuffer();
      }

      _isRecording = newRecordingState;
      _emitState();
    });
  }

  void _setupGpsListener() {
    _gpsSubscription =
        geolocationBloc.geolocationStream.listen(_onGpsDataReceived);
  }

  void _setupAuthenticationListener() {
    _osemSubscription = osemBloc.stream.listen((_) {
      _emitState();
    });
  }

  void _onGpsDataReceived(GeolocationData geoData) {
    // Skip invalid GPS coordinates
    if (geoData.latitude == 0.0 && geoData.longitude == 0.0) {
      return;
    }

    _latestLocation = geoData;
    bool shouldNotify = false;
    if (_lastNotifiedLocation == null) {
      shouldNotify = true;
    } else {
      final dist = geolocator.Geolocator.distanceBetween(
        _lastNotifiedLocation!.latitude,
        _lastNotifiedLocation!.longitude,
        geoData.latitude,
        geoData.longitude,
      );
      if (dist >= _mapNotificationDistanceMeters) {
        shouldNotify = true;
      }
    }
    if (shouldNotify) {
      _lastNotifiedLocation = geoData;
      if (_isRecording) {
        _addToGpsBuffer(geoData);
      }
      _emitState();
    }
  }

  // GPS Buffer Management
  void _addToGpsBuffer(GeolocationData geoData) {
    if (_isDuplicatePoint(geoData)) return;
    _gpsBuffer.add(geoData);
    if (_gpsBuffer.length > _maxBufferedGpsPoints) {
      _gpsBuffer.removeAt(0);
    }
  }

  bool _isDuplicatePoint(GeolocationData geoData) {
    if (_gpsBuffer.isEmpty) return false;
    final lastPoint = _gpsBuffer.last;
    return lastPoint.latitude == geoData.latitude &&
        lastPoint.longitude == geoData.longitude &&
        lastPoint.timestamp == geoData.timestamp;
  }

  void _clearGpsBuffer() {
    _gpsBuffer.clear();
  }

  // Public methods
  void clearGpsBuffer() {
    _clearGpsBuffer();
    _emitState();
  }

  // Map state queries
  bool get shouldShowTrack => _isRecording && _gpsBuffer.isNotEmpty;
  bool get shouldShowCurrentLocation =>
      !_isRecording && _latestLocation != null;

  // Get the last location for map navigation
  GeolocationData? get lastLocationForMap {
    if (_gpsBuffer.isNotEmpty) {
      return _gpsBuffer.last;
    }
    return _latestLocation;
  }

  @override
  Future<void> close() async {
    _cleanupSubscriptions();
    return super.close();
  }

  void dispose() {
    unawaited(close());
  }

  void _cleanupSubscriptions() {
    _gpsSubscription?.cancel();
    _recordingSubscription?.cancel();
    _osemSubscription?.cancel();
  }
}
