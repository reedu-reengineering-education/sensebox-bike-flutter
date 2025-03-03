import 'dart:async';
import 'dart:isolate';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sensebox_bike/blocs/ble_bloc.dart';
import 'package:sensebox_bike/blocs/geolocation_bloc.dart';
import 'package:sensebox_bike/models/sensor_data.dart';
import 'package:sensebox_bike/models/geolocation_data.dart';
import 'package:sensebox_bike/models/track_data.dart';
import 'package:sensebox_bike/services/isar_service.dart';
import 'package:flutter/material.dart';

abstract class Sensor {
  final String characteristicUuid;
  final String title;
  final List<String> attributes;

  final BleBloc bleBloc;
  final GeolocationBloc geolocationBloc;
  final IsarService isarService;
  StreamSubscription<List<double>>? _subscription;

  final StreamController<List<double>> _valueController =
      StreamController<List<double>>.broadcast();
  Stream<List<double>> get valueStream => _valueController.stream;

  final List<List<double>> _valueBuffer = [];

  final List<SensorData> _sensorDataBuffer = [];
  final int _batchSize = 10; // Define the batch size

  late int uiPriority;

  late Icon uiIcon;
  late Color uiColor;

  Sensor(
    this.characteristicUuid,
    this.title,
    this.attributes,
    this.bleBloc,
    this.geolocationBloc,
    this.isarService,
  );

  void startListening() async {
    try {
      // Listen to the sensor data stream
      _subscription = bleBloc
          .getCharacteristicStream(characteristicUuid)
          .stream
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

          _aggregateAndBufferData(
              geolocationData); // Aggregate and store sensor data
          _valueBuffer.clear(); // Clear the list after aggregation
        }
      });
    } catch (e) {
      print('Error starting sensor: $e');
    }
  }

  void stopListening() {
    _subscription?.cancel();
  }

  // Method to handle incoming sensor data
  void onDataReceived(List<double> data) {
    if (data.isNotEmpty) {
      _valueBuffer.add(data); // Buffer the sensor data
      _valueController.add(data); // Emit the latest sensor value to the stream
    }
  }

  // Aggregate sensor data and store it with the latest geolocation
  void _aggregateAndBufferData(GeolocationData geolocationData) {
    if (_valueBuffer.isEmpty) {
      return;
    }

    List<double> aggregatedValues = aggregateData(_valueBuffer);

    if (attributes.isEmpty) {
      _bufferSensorData(aggregatedValues[0], null, geolocationData);
    } else {
      if (attributes.length != aggregatedValues.length) {
        throw Exception(
            'Number of attributes does not match the number of aggregated values');
      }

      for (int i = 0; i < attributes.length; i++) {
        _bufferSensorData(aggregatedValues[i], attributes[i], geolocationData);
      }
    }
  }

  // Helper method to save sensor data
  void _bufferSensorData(
      double value, String? attribute, GeolocationData geolocationData) {
    isarService.geolocationService.saveGeolocationData(geolocationData);

    if (value.isNaN) {
      return;
    }

    final sensorData = SensorData()
      ..characteristicUuid = characteristicUuid
      ..title = title
      ..value = value
      ..attribute = attribute
      ..geolocationData.value = geolocationData;

    if (_sensorDataBuffer.length < _batchSize) {
      _sensorDataBuffer.add(sensorData);
    } else {
      Isolate.spawn(saveSensorDataBatch, _sensorDataBuffer).then(
          (value) => _sensorDataBuffer.clear(),
          onError: (error) => debugPrint('Error saving sensor data: $error'));
    }
  }

  // Abstract method to build a widget for the sensor (UI representation)
  Widget buildWidget();

  // Abstract method to aggregate sensor data
  List<double> aggregateData(List<List<double>> valueBuffer);

  void dispose() {
    stopListening();
    _valueController
        .close(); // Close the stream controller to prevent memory leaks
  }
}

Future<void> saveSensorDataBatch(List<SensorData> sensorDataList) async {
  final dir = await getApplicationDocumentsDirectory();
  final isar = await Isar.open(
    [
      TrackDataSchema,
      GeolocationDataSchema,
      SensorDataSchema,
    ],
    directory: dir.path,
    name: 'sensor_data_isolate',
  );

  isar.writeTxnSync(() {
    isar.sensorDatas.putAllSync(sensorDataList);
    for (var sensorData in sensorDataList) {
      sensorData.geolocationData.saveSync();
    }
  });
}
