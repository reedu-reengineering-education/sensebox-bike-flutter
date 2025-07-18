import 'dart:async';
import 'package:sensebox_bike/blocs/ble_bloc.dart';
import 'package:sensebox_bike/blocs/geolocation_bloc.dart';
import 'package:sensebox_bike/blocs/recording_bloc.dart';
import 'package:sensebox_bike/models/sensor_data.dart';
import 'package:sensebox_bike/models/geolocation_data.dart';
import 'package:sensebox_bike/services/isar_service.dart';
import 'package:flutter/material.dart';

abstract class Sensor {
  final String characteristicUuid;
  final String title;
  final List<String> attributes;

  final BleBloc bleBloc;
  final GeolocationBloc geolocationBloc;
  final RecordingBloc recordingBloc;
  final IsarService isarService;
  StreamSubscription<List<double>>? _subscription;

  final StreamController<List<double>> _valueController =
      StreamController<List<double>>.broadcast();
  Stream<List<double>> get valueStream => _valueController.stream;

  final List<List<double>> _valueBuffer = [];

  late int uiPriority;

  late Icon uiIcon;
  late Color uiColor;

  Sensor(
    this.characteristicUuid,
    this.title,
    this.attributes,
    this.bleBloc,
    this.geolocationBloc,
    this.recordingBloc,
    this.isarService,
  );

  void startListening() async {
    try {
      // Listen to the sensor data stream
      _subscription = bleBloc
          .getCharacteristicStream(characteristicUuid)
          .listen((data) {
        onDataReceived(data);
      });

      // Listen to geolocation updates
      (await isarService.geolocationService.getGeolocationStream())
          .listen((_) async {
        if (_valueBuffer.isNotEmpty) {
          GeolocationData? geolocationData = await isarService
              .geolocationService
              .getLastGeolocationData(); // Get the latest geolocation data

          if (geolocationData == null) {
            return;
          }

          _aggregateAndStoreData(
              geolocationData); // Aggregate and store sensor data
          _valueBuffer.clear(); // Clear the list after aggregation
        }
      });
    } catch (e) {
      debugPrint('Error starting sensor $title: $e');
    }
  }

  Future<void> stopListening() async {
    await _subscription?.cancel();
    _subscription = null;
  }

  // Method to handle incoming sensor data
  void onDataReceived(List<double> data) {
    if (data.isNotEmpty) {
      _valueBuffer.add(data); // Buffer the sensor data
      _valueController.add(data); // Emit the latest sensor value to the stream
    }
  }

  // Aggregate sensor data and store it with the latest geolocation
  void _aggregateAndStoreData(GeolocationData geolocationData) {
    // Only process sensor data if recording is active
    if (!recordingBloc.isRecording || recordingBloc.currentTrack == null) {
      return;
    }

    if (_valueBuffer.isEmpty) {
      return;
    }

    List<double> aggregatedValues = aggregateData(_valueBuffer);

    if (attributes.isEmpty) {
      _saveSensorData(aggregatedValues[0], null, geolocationData);
    } else {
      if (attributes.length != aggregatedValues.length) {
        throw Exception(
            'Number of attributes does not match the number of aggregated values');
      }

      for (int i = 0; i < attributes.length; i++) {
        _saveSensorData(aggregatedValues[i], attributes[i], geolocationData);
      }
    }
  }

  // Helper method to save sensor data
  void _saveSensorData(
      double value, String? attribute, GeolocationData geolocationData) {
    // Double-check recording state before saving
    if (!recordingBloc.isRecording || recordingBloc.currentTrack == null) {
      return;
    }

    // Don't save geolocation data here - it's already saved by the geolocation bloc
    // Only save sensor data if we have a valid value
    if (value.isNaN) {
      return;
    }

    final sensorData = SensorData()
      ..characteristicUuid = characteristicUuid
      ..title = title
      ..value = value
      ..attribute = attribute
      ..geolocationData.value = geolocationData;

    isarService.sensorService.saveSensorData(sensorData);
    
    // Trigger live upload when new sensor data is saved
    recordingBloc.liveUploadService?.triggerUpload();
  }

  // Abstract method to build a widget for the sensor (UI representation)
  Widget buildWidget();

  // Abstract method to aggregate sensor data
  List<double> aggregateData(List<List<double>> valueBuffer);

  void dispose() {
    stopListening();
    _valueController.close();
  }
}
