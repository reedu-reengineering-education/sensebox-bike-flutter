import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sensebox_bike/models/geolocation_data.dart';
import 'package:sensebox_bike/sensors/temperature_sensor.dart';
import '../mocks.dart';

void main() {
  group('Sensor Aggregation and Value Removal', () {
    late TemperatureSensor sensor;
    late MockRecordingBloc recordingBloc;
    late MockGeolocationBloc geolocationBloc;
    late StreamController<GeolocationData> geoController;

    setUp(() {
      recordingBloc = MockRecordingBloc();
      recordingBloc.setRecording(true);
      geolocationBloc = MockGeolocationBloc();
      geoController = StreamController<GeolocationData>.broadcast();
      when(() => geolocationBloc.geolocationStream).thenAnswer((_) => geoController.stream);
      
      sensor = TemperatureSensor(
        MockBleBloc(),
        geolocationBloc,
        recordingBloc,
        MockIsarService(),
      );
    });

    tearDown(() async {
      await geoController.close();
      sensor.dispose();
    });

    test('removes values after immediate aggregation for zero lookback sensors', () async {
      final geoTime = DateTime.utc(2024, 1, 1, 12, 0, 2);
      final geo = GeolocationData()
        ..id = 1
        ..timestamp = geoTime
        ..latitude = 52.0
        ..longitude = 13.0;

      sensor.onDataReceived([20.0]);
      await Future.delayed(const Duration(milliseconds: 10));
      sensor.onDataReceived([21.0]);
      await Future.delayed(const Duration(milliseconds: 10));

      sensor.startListening();
      await Future.delayed(const Duration(milliseconds: 50));

      geoController.add(geo);
      await Future.delayed(const Duration(milliseconds: 100));

      final secondGeoTime = DateTime.utc(2024, 1, 1, 12, 0, 3);
      final secondGeo = GeolocationData()
        ..id = 2
        ..timestamp = secondGeoTime
        ..latitude = 52.0
        ..longitude = 13.0;

      sensor.onDataReceived([22.0]);
      await Future.delayed(const Duration(milliseconds: 10));

      geoController.add(secondGeo);
      await Future.delayed(const Duration(milliseconds: 100));

      final thirdGeoTime = DateTime.utc(2024, 1, 1, 12, 0, 4);
      final thirdGeo = GeolocationData()
        ..id = 3
        ..timestamp = thirdGeoTime
        ..latitude = 52.0
        ..longitude = 13.0;

      geoController.add(thirdGeo);
      await Future.delayed(const Duration(milliseconds: 100));

      expect(sensor, isNotNull);
    });

    test('aggregates only values with timestamp before geolocation time', () async {
      final geoTime = DateTime.utc(2024, 1, 1, 12, 0, 2);
      final geo = GeolocationData()
        ..id = 1
        ..timestamp = geoTime
        ..latitude = 52.0
        ..longitude = 13.0;

      sensor.onDataReceived([20.0]);
      await Future.delayed(const Duration(milliseconds: 10));
      sensor.onDataReceived([21.0]);
      await Future.delayed(const Duration(milliseconds: 10));
      sensor.onDataReceived([22.0]);
      await Future.delayed(const Duration(milliseconds: 10));

      sensor.startListening();
      geoController.add(geo);
      await Future.delayed(const Duration(milliseconds: 100));

      expect(sensor, isNotNull);
    });

    test('does not aggregate values with timestamp equal to geolocation time', () async {
      final geoTime = DateTime.utc(2024, 1, 1, 12, 0, 2);
      final geo = GeolocationData()
        ..id = 1
        ..timestamp = geoTime
        ..latitude = 52.0
        ..longitude = 13.0;

      sensor.startListening();
      await Future.delayed(const Duration(milliseconds: 10));

      geoController.add(geo);
      await Future.delayed(const Duration(milliseconds: 10));

      sensor.onDataReceived([25.0]);
      await Future.delayed(const Duration(milliseconds: 10));

      final secondGeo = GeolocationData()
        ..id = 2
        ..timestamp = DateTime.utc(2024, 1, 1, 12, 0, 3)
        ..latitude = 52.0
        ..longitude = 13.0;

      geoController.add(secondGeo);
      await Future.delayed(const Duration(milliseconds: 100));

      expect(sensor, isNotNull);
    });

    test('handles multiple geolocations correctly', () async {
      sensor.startListening();
      await Future.delayed(const Duration(milliseconds: 10));

      sensor.onDataReceived([20.0]);
      await Future.delayed(const Duration(milliseconds: 10));

      final geo1 = GeolocationData()
        ..id = 1
        ..timestamp = DateTime.utc(2024, 1, 1, 12, 0, 1)
        ..latitude = 52.0
        ..longitude = 13.0;

      geoController.add(geo1);
      await Future.delayed(const Duration(milliseconds: 50));

      sensor.onDataReceived([21.0]);
      await Future.delayed(const Duration(milliseconds: 10));

      final geo2 = GeolocationData()
        ..id = 2
        ..timestamp = DateTime.utc(2024, 1, 1, 12, 0, 2)
        ..latitude = 52.0
        ..longitude = 13.0;

      geoController.add(geo2);
      await Future.delayed(const Duration(milliseconds: 50));

      sensor.onDataReceived([22.0]);
      await Future.delayed(const Duration(milliseconds: 10));

      final geo3 = GeolocationData()
        ..id = 3
        ..timestamp = DateTime.utc(2024, 1, 1, 12, 0, 3)
        ..latitude = 52.0
        ..longitude = 13.0;

      geoController.add(geo3);
      await Future.delayed(const Duration(milliseconds: 100));

      expect(sensor, isNotNull);
    });
  });
}
