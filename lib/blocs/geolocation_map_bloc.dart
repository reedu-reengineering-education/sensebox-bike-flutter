import 'dart:async';
import 'package:flutter/material.dart';
import 'package:sensebox_bike/blocs/geolocation_bloc.dart';
import 'package:sensebox_bike/blocs/recording_bloc.dart';
import 'package:sensebox_bike/blocs/opensensemap_bloc.dart';
import 'package:sensebox_bike/blocs/ble_bloc.dart';
import 'package:sensebox_bike/models/geolocation_data.dart';

class GeolocationMapBloc extends ChangeNotifier {
  // Dependencies
  final GeolocationBloc geolocationBloc;
  final RecordingBloc recordingBloc;
  final OpenSenseMapBloc osemBloc;
  final BleBloc bleBloc;

  // State management
  final List<GeolocationData> _gpsBuffer = [];
  bool _isRecording = false;
  bool _isConnected = false;
  GeolocationData? _latestLocation;

  // Stream subscriptions and listeners
  StreamSubscription<GeolocationData>? _gpsSubscription;
  VoidCallback? _recordingListener;
  VoidCallback? _osemListener;
  VoidCallback? _bleListener;

  // Getters
  List<GeolocationData> get gpsBuffer => List.unmodifiable(_gpsBuffer);
  bool get isRecording => _isRecording;
  bool get isAuthenticated => osemBloc.isAuthenticated;
  bool get isConnected => _isConnected;
  GeolocationData? get latestLocation => _latestLocation;
  bool get hasGpsData => _gpsBuffer.isNotEmpty;

  GeolocationMapBloc({
    required this.geolocationBloc,
    required this.recordingBloc,
    required this.osemBloc,
    required this.bleBloc,
  }) {
    _initialize();
  }

  void _initialize() {
    _isRecording = recordingBloc.isRecording;
    _isConnected = bleBloc.isConnected;
    
    _setupRecordingListener();
    _setupGpsListener();
    _setupAuthenticationListener();
    _setupBleListener();
  }

  void _setupRecordingListener() {
    _recordingListener = () {
      final newRecordingState = recordingBloc.isRecording;

      if (_isRecording && !newRecordingState) {
        // Recording stopped - clear buffer
        _clearGpsBuffer();
      }
      
      _isRecording = newRecordingState;
      notifyListeners();
    };
    recordingBloc.isRecordingNotifier.addListener(_recordingListener!);
  }

  void _setupGpsListener() {
    _gpsSubscription = geolocationBloc.geolocationStream.listen(_onGpsDataReceived);
  }

  void _setupAuthenticationListener() {
    _osemListener = () {
      notifyListeners();
    };
    osemBloc.addListener(_osemListener!);
  }

  void _setupBleListener() {
    _bleListener = () {
      _isConnected = bleBloc.isConnected;
      notifyListeners();
    };
    bleBloc.isConnectingNotifier.addListener(_bleListener!);
  }

  void _onGpsDataReceived(GeolocationData geoData) {
    // Skip invalid GPS coordinates
    if (geoData.latitude == 0.0 && geoData.longitude == 0.0) {
      return;
    }

    _latestLocation = geoData;

    if (_isRecording) {
      _addToGpsBuffer(geoData);
    }
    
    notifyListeners();
  }

  // GPS Buffer Management
  void _addToGpsBuffer(GeolocationData geoData) {
    if (_isDuplicatePoint(geoData)) return;
    _gpsBuffer.add(geoData);
  }

  bool _isDuplicatePoint(GeolocationData geoData) {
    return _gpsBuffer.any((point) =>
        point.latitude == geoData.latitude &&
        point.longitude == geoData.longitude &&
        point.timestamp == geoData.timestamp);
  }

  void _clearGpsBuffer() {
    _gpsBuffer.clear();
  }

  // Public methods
  void clearGpsBuffer() {
    _clearGpsBuffer();
    notifyListeners();
  }

  // Map state queries
  bool get shouldShowTrack => _isRecording && _gpsBuffer.isNotEmpty;
  bool get shouldShowCurrentLocation => !_isRecording && _latestLocation != null;
  
  // Get the last location for map navigation
  GeolocationData? get lastLocationForMap {
    if (_gpsBuffer.isNotEmpty) {
      return _gpsBuffer.last;
    }
    return _latestLocation;
  }

  @override
  void dispose() {
    _cleanupSubscriptions();
    _cleanupListeners();
    super.dispose();
  }

  void _cleanupSubscriptions() {
    _gpsSubscription?.cancel();
  }

  void _cleanupListeners() {
    if (_recordingListener != null) {
      recordingBloc.isRecordingNotifier.removeListener(_recordingListener!);
    }
    if (_osemListener != null) {
      osemBloc.removeListener(_osemListener!);
    }
    if (_bleListener != null) {
      bleBloc.isConnectingNotifier.removeListener(_bleListener!);
    }
  }
} 