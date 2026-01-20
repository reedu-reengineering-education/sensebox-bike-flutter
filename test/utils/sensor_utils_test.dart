import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:sensebox_bike/l10n/app_localizations.dart';
import 'package:sensebox_bike/models/sensor_data.dart';
import 'package:sensebox_bike/models/sensebox.dart';
import 'package:sensebox_bike/models/geolocation_data.dart';
import 'package:sensebox_bike/utils/sensor_utils.dart';
import 'package:sensebox_bike/sensors/distance_sensor.dart';
import 'package:sensebox_bike/sensors/distance_right_sensor.dart';
import 'package:sensebox_bike/sensors/overtaking_prediction_sensor.dart';
import 'package:sensebox_bike/sensors/temperature_sensor.dart';
import 'package:sensebox_bike/sensors/humidity_sensor.dart';
import 'package:sensebox_bike/sensors/acceleration_sensor.dart';
import 'package:sensebox_bike/sensors/gps_sensor.dart';
import 'package:sensebox_bike/sensors/surface_classification_sensor.dart';
import 'package:sensebox_bike/sensors/surface_anomaly_sensor.dart';
import 'package:sensebox_bike/sensors/finedust_sensor.dart';

void main() {
  final boxSensors = [
    Sensor(id: "67d937c2b6275400071c38c0", title: "Temperature", unit: "°C"),
    Sensor(id: "67d937c2b6275400071c38c1", title: "Rel. Humidity", unit: "%"),
    Sensor(
        id: "67d937c2b6275400071c38c2", title: "Finedust PM1", unit: "µg/m³"),
  ];
  
  group('findSensorIdByData', () {
    test('should return sensor ID when title and attribute match', () {
      final sensorData = SensorData()
        ..title = "finedust"
        ..attribute = "pm1";
      final sensorId = findSensorIdByData(sensorData, boxSensors);

      expect(sensorId, "67d937c2b6275400071c38c2");
    });

    test('should return sensor ID when title matches and attribute is null', () {
      final sensorData = SensorData()
        ..title = "temperature"
        ..attribute = null;

      final sensorId = findSensorIdByData(sensorData, boxSensors);

      expect(sensorId, "67d937c2b6275400071c38c0");
    });

    test('should return null when no matching sensor is found', () {
      final sensorData = SensorData()
        ..title = "unknown"
        ..attribute = null;

      final sensorId = findSensorIdByData(sensorData, boxSensors);

      expect(sensorId, isNull);
    });

    test('should return null when attribute does not match', () {
      final sensorData = SensorData()
        ..title = "finedust"
        ..attribute = "pm15";

      final sensorId = findSensorIdByData(sensorData, boxSensors);

      expect(sensorId, isNull);
    });
  });

  group('createGpsSpeedSensorData', () {
    late GeolocationData mockGeoData;

    setUp(() {
      mockGeoData = GeolocationData()
        ..latitude = 52.52
        ..longitude = 13.405
        ..speed = 15.5
        ..timestamp = DateTime.parse('2025-01-01T12:00:00');
    });

    test('creates GPS speed sensor data correctly', () {
      final sensorData = createGpsSpeedSensorData(mockGeoData);

      expect(sensorData.title, equals('gps')); // Match GPS sensor format
      expect(sensorData.attribute, equals('speed')); // Match GPS sensor format
      expect(sensorData.value, equals(15.5));
      expect(sensorData.characteristicUuid,
          equals('8edf8ebb-1246-4329-928d-ee0c91db2389'));
      expect(sensorData.geolocationData.value, equals(mockGeoData));
    });
  });

  group('shouldStoreSensorData', () {
    test('returns true for valid sensor data', () {
      final sensorData = SensorData()
        ..title = 'temperature'
        ..value = 22.5;

      expect(shouldStoreSensorData(sensorData), isTrue);
    });

    test('returns false for NaN values', () {
      final sensorData = SensorData()
        ..title = 'temperature'
        ..value = double.nan;

      expect(shouldStoreSensorData(sensorData), isFalse);
    });

    test('returns false for infinite values', () {
      final sensorData = SensorData()
        ..title = 'temperature'
        ..value = double.infinity;

      expect(shouldStoreSensorData(sensorData), isFalse);
    });

    test('returns false for zero GPS coordinates', () {
      final sensorData = SensorData()
        ..title = 'gps'
        ..attribute = 'latitude'
        ..value = 0.0;

      expect(shouldStoreSensorData(sensorData), isFalse);
    });
  });

  group('findSpeedSensorId', () {
    test('returns exact speed sensor match', () {
      final speedSensor = Sensor(id: 'speedId', title: 'Speed');
      final senseBox = SenseBox(sensors: [speedSensor]);

      final result = findSpeedSensorId(senseBox);

      expect(result, 'speedId');
    });

    test('matches speed sensor case-insensitively', () {
      final speedSensor = Sensor(id: 'speedId', title: 'SPEED');
      final senseBox = SenseBox(sensors: [speedSensor]);

      final result = findSpeedSensorId(senseBox);

      expect(result, 'speedId');
    });

    test('matches sensor with speed in title', () {
      final speedSensor = Sensor(id: 'speedId', title: 'speed sensor');
      final senseBox = SenseBox(sensors: [speedSensor]);

      final result = findSpeedSensorId(senseBox);

      expect(result, 'speedId');
    });

    test('returns null when no speed sensor found', () {
      final senseBox = SenseBox(sensors: []);

      final result = findSpeedSensorId(senseBox);

      expect(result, isNull);
    });
  });

  group('addSpeedEntries', () {
    test('adds speed entries for each gps point', () {
      final speedSensorId = 'speedId';
      final gpsPoints = [
        GeolocationData()
          ..latitude = 10.0
          ..longitude = 20.0
          ..speed = 5.0
          ..timestamp = DateTime.utc(2024, 1, 1, 12, 0, 0),
      ];
      final target = <String, dynamic>{};

      addSpeedEntries(
        target: target,
        gpsBuffer: gpsPoints,
        speedSensorId: speedSensorId,
      );

      expect(target.length, 1);
      final entry = target.values.first as Map<String, dynamic>;
      expect(entry['sensor'], speedSensorId);
      expect(entry['value'], '5.00');
      expect(entry['location']['lat'], 10.0);
      expect(entry['location']['lng'], 20.0);
    });
  });

  group('getUiPriorityByUuid', () {
    test('returns correct priority for distance sensor UUID', () {
      expect(getUiPriorityByUuid(DistanceSensor.sensorCharacteristicUuid), 10);
    });

    test('returns correct priority for distance right sensor UUID', () {
      expect(
          getUiPriorityByUuid(DistanceRightSensor.sensorCharacteristicUuid), 20);
    });

    test('returns correct priority for overtaking prediction sensor UUID', () {
      expect(
          getUiPriorityByUuid(
              OvertakingPredictionSensor.sensorCharacteristicUuid),
          30);
    });

    test('returns correct priority for temperature sensor UUID', () {
      expect(
          getUiPriorityByUuid(TemperatureSensor.sensorCharacteristicUuid), 40);
    });

    test('returns correct priority for humidity sensor UUID', () {
      expect(getUiPriorityByUuid(HumiditySensor.sensorCharacteristicUuid), 50);
    });

    test('returns correct priority for acceleration sensor UUID', () {
      expect(
          getUiPriorityByUuid(AccelerationSensor.sensorCharacteristicUuid), 60);
    });

    test('returns correct priority for GPS sensor UUID', () {
      expect(getUiPriorityByUuid(GPSSensor.sensorCharacteristicUuid), 60);
    });

    test('returns correct priority for surface classification sensor UUID', () {
      expect(
          getUiPriorityByUuid(
              SurfaceClassificationSensor.sensorCharacteristicUuid),
          60);
    });

    test('returns correct priority for surface anomaly sensor UUID', () {
      expect(
          getUiPriorityByUuid(SurfaceAnomalySensor.sensorCharacteristicUuid),
          60);
    });

    test('returns correct priority for finedust sensor UUID', () {
      expect(getUiPriorityByUuid(FinedustSensor.sensorCharacteristicUuid), 80);
    });

    test('returns default priority for unknown UUID', () {
      expect(getUiPriorityByUuid('unknown-uuid'), 999999);
    });

    test('returns default priority for empty string', () {
      expect(getUiPriorityByUuid(''), 999999);
    });
  });

  group('getUniqueSortedSensorEntries', () {
    test('deduplicates sensor entries with same title, attribute, and UUID',
        () {
      final sensorData = [
        SensorData()
          ..title = 'temperature'
          ..attribute = null
          ..characteristicUuid = TemperatureSensor.sensorCharacteristicUuid,
        SensorData()
          ..title = 'temperature'
          ..attribute = null
          ..characteristicUuid = TemperatureSensor.sensorCharacteristicUuid,
        SensorData()
          ..title = 'humidity'
          ..attribute = null
          ..characteristicUuid = HumiditySensor.sensorCharacteristicUuid,
      ];

      final entries = getUniqueSortedSensorEntries(sensorData);

      expect(entries.length, 2);
      expect(entries.any((e) => e.title == 'temperature'), isTrue);
      expect(entries.any((e) => e.title == 'humidity'), isTrue);
    });

    test('keeps entries with same title but different attributes', () {
      final sensorData = [
        SensorData()
          ..title = 'finedust'
          ..attribute = 'pm1'
          ..characteristicUuid = FinedustSensor.sensorCharacteristicUuid,
        SensorData()
          ..title = 'finedust'
          ..attribute = 'pm2.5'
          ..characteristicUuid = FinedustSensor.sensorCharacteristicUuid,
      ];

      final entries = getUniqueSortedSensorEntries(sensorData);

      expect(entries.length, 2);
      expect(entries.any((e) => e.attribute == 'pm1'), isTrue);
      expect(entries.any((e) => e.attribute == 'pm2.5'), isTrue);
    });

    test('sorts entries by UUID priority', () {
      final sensorData = [
        SensorData()
          ..title = 'humidity'
          ..attribute = null
          ..characteristicUuid = HumiditySensor.sensorCharacteristicUuid,
        SensorData()
          ..title = 'temperature'
          ..attribute = null
          ..characteristicUuid = TemperatureSensor.sensorCharacteristicUuid,
        SensorData()
          ..title = 'distance'
          ..attribute = null
          ..characteristicUuid = DistanceSensor.sensorCharacteristicUuid,
      ];

      final entries = getUniqueSortedSensorEntries(sensorData);

      expect(entries.length, 3);
      expect(entries[0].title, 'distance');
      expect(entries[1].title, 'temperature');
      expect(entries[2].title, 'humidity');
    });

    test('sorts speed (gps with speed attribute) to the end', () {
      final sensorData = [
        SensorData()
          ..title = 'gps'
          ..attribute = 'speed'
          ..characteristicUuid = GPSSensor.sensorCharacteristicUuid,
        SensorData()
          ..title = 'temperature'
          ..attribute = null
          ..characteristicUuid = TemperatureSensor.sensorCharacteristicUuid,
        SensorData()
          ..title = 'humidity'
          ..attribute = null
          ..characteristicUuid = HumiditySensor.sensorCharacteristicUuid,
        SensorData()
          ..title = 'finedust'
          ..attribute = 'pm1'
          ..characteristicUuid = FinedustSensor.sensorCharacteristicUuid,
      ];

      final entries = getUniqueSortedSensorEntries(sensorData);

      expect(entries.length, 4);
      // Speed should be last regardless of its priority
      expect(entries.last.title, 'gps');
      expect(entries.last.attribute, 'speed');
    });

    test('returns empty list for empty input', () {
      final entries = getUniqueSortedSensorEntries([]);
      expect(entries, isEmpty);
    });
  });

  group('getTranslatedTitleFromSensorKey', () {
    testWidgets('returns correct translation for distance sensor', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) {
              final result = getTranslatedTitleFromSensorKey('distance', null, context);
              expect(result, AppLocalizations.of(context)!.sensorDistance);
              return const SizedBox();
            },
          ),
        ),
      );
    });

    testWidgets('returns correct translation for distance_right sensor', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) {
              final result = getTranslatedTitleFromSensorKey('distance_right', null, context);
              expect(result, AppLocalizations.of(context)!.sensorDistanceRight);
              return const SizedBox();
            },
          ),
        ),
      );
    });
  });
}