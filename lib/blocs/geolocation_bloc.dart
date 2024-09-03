// File: lib/blocs/geolocation_bloc.dart
import 'dart:async';
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

  GeolocationBloc(this.isarService) {
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

    // Listen to position stream
    Geolocator.getPositionStream().listen((Position position) async {
      GeolocationData geolocationData = GeolocationData()
        ..latitude = position.latitude
        ..longitude = position.longitude
        ..speed = position.speed
        ..timestamp = position.timestamp;

      await _saveGeolocationData(geolocationData); // Save to database
      _geolocationController.add(geolocationData);
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
