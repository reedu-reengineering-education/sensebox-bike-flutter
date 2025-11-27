import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sensebox_bike/models/timestamped_sensor_value.dart';
import 'package:sensebox_bike/services/sensor_csv_logger_service.dart';
import '../mocks.dart';
import '../test_helpers.dart';

void main() {
  const MethodChannel pathProviderChannel =
      MethodChannel('plugins.flutter.io/path_provider');
  late Directory tempDirectory;
  late SensorCsvLoggerService csvLogger;
  late MockSensor mockSensor1;
  late MockSensor mockSensor2;
  late StreamController<TimestampedSensorValue> sensor1Controller;
  late StreamController<TimestampedSensorValue> sensor2Controller;

  setUp(() async {
    initializeTestDependencies();

    tempDirectory = Directory.systemTemp.createTempSync();
    mockPathProvider(tempDirectory.path);

    csvLogger = SensorCsvLoggerService();
    await csvLogger.dispose();

    mockSensor1 = MockSensor();
    mockSensor2 = MockSensor();
    sensor1Controller = StreamController<TimestampedSensorValue>.broadcast();
    sensor2Controller = StreamController<TimestampedSensorValue>.broadcast();

    when(() => mockSensor1.title).thenReturn('temperature');
    when(() => mockSensor1.timestampedValueStream)
        .thenAnswer((_) => sensor1Controller.stream);

    when(() => mockSensor2.title).thenReturn('humidity');
    when(() => mockSensor2.timestampedValueStream)
        .thenAnswer((_) => sensor2Controller.stream);
  });

  tearDown(() async {
    await csvLogger.dispose();
    await sensor1Controller.close();
    await sensor2Controller.close();
    pathProviderChannel.setMockMethodCallHandler(null);

    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  Future<String> logValuesAndGetContent({
    required List<MockSensor> sensors,
    required List<
            MapEntry<StreamController<TimestampedSensorValue>,
                List<TimestampedSensorValue>>>
        emissions,
    Duration waitAfterEmit = const Duration(milliseconds: 100),
  }) async {
    await csvLogger.initialize();
    csvLogger.startLogging(sensors);
    await Future.delayed(const Duration(milliseconds: 100));

    for (final entry in emissions) {
      for (final value in entry.value) {
        entry.key.add(value);
      }
    }
    await Future.delayed(waitAfterEmit);

    await csvLogger.stopLogging();

    final file = csvLogger.getCurrentLogFile();
    return file != null ? await file.readAsString() : '';
  }

  group('SensorCsvLoggerService', () {
    group('initialize', () {
      test('creates log directory and allows re-initialization after dispose',
          () async {
        await csvLogger.initialize();

        final logDirectoryPath = csvLogger.getLogDirectoryPath();
        expect(logDirectoryPath, isNotNull);
        expect(logDirectoryPath, contains('sensebox_bike_sensor_logs'));

        final logDirectory = Directory(logDirectoryPath!);
        expect(await logDirectory.exists(), isTrue);

        final firstPath = csvLogger.getLogDirectoryPath();
        await csvLogger.initialize();
        expect(csvLogger.getLogDirectoryPath(), equals(firstPath));
      });
    });

    group('startLogging', () {
      test('does not start logging if not initialized', () {
        csvLogger.startLogging([mockSensor1]);
        expect(csvLogger.getCurrentLogFile(), isNull);
      });

      test('creates CSV file with header and ignores duplicate start calls',
          () async {
        await csvLogger.initialize();
        csvLogger.startLogging([mockSensor1, mockSensor2]);
        await Future.delayed(const Duration(milliseconds: 100));

        final firstFile = csvLogger.getCurrentLogFile();
        expect(firstFile, isNotNull);
        expect(firstFile!.path, contains('sensor_data_'));
        expect(firstFile.path, endsWith('.csv'));

        expect(await firstFile.exists(), isTrue);
        final content = await firstFile.readAsString();
        expect(content, contains('sensor_name,timestamp,value1,value2,value3'));

        csvLogger.startLogging([mockSensor1]);
        expect(csvLogger.getCurrentLogFile(), equals(firstFile));
      });
    });

    group('data logging and flushing', () {
      test('logs single and multiple sensor values to CSV', () async {
        final baseTime = DateTime.now().toUtc();

        final content = await logValuesAndGetContent(
          sensors: [mockSensor1, mockSensor2],
          emissions: [
            MapEntry(sensor1Controller, [
              TimestampedSensorValue(values: [25.5], timestamp: baseTime),
            ]),
            MapEntry(sensor2Controller, [
              TimestampedSensorValue(
                values: [60.0],
                timestamp: baseTime.add(const Duration(milliseconds: 20)),
              ),
            ]),
          ],
        );

        expect(content, contains('temperature'));
        expect(content, contains('humidity'));
        expect(content, contains('25.5'));
        expect(content, contains('60.0'));
      });

      test('logs multi-value arrays from same sensor', () async {
        final content = await logValuesAndGetContent(
          sensors: [mockSensor1],
          emissions: [
            MapEntry(sensor1Controller, [
              TimestampedSensorValue(
                values: [25.5, 26.0, 24.8],
                timestamp: DateTime.now().toUtc(),
              ),
            ]),
          ],
        );

        expect(content, contains('25.5,26.0,24.8'));
      });

      test('does not log data after stopLogging is called', () async {
        await csvLogger.initialize();
        csvLogger.startLogging([mockSensor1]);
        await Future.delayed(const Duration(milliseconds: 100));
        await csvLogger.stopLogging();

        sensor1Controller.add(TimestampedSensorValue(
          values: [25.5],
          timestamp: DateTime.now().toUtc(),
        ));
        await Future.delayed(const Duration(milliseconds: 100));

        final content = await csvLogger.getCurrentLogFile()!.readAsString();
        final lines =
            content.split('\n').where((line) => line.isNotEmpty).toList();
        expect(lines.length, equals(1));
      });

      test('flushes buffer when it reaches buffer size (100)', () async {
        await csvLogger.initialize();
        csvLogger.startLogging([mockSensor1]);
        await Future.delayed(const Duration(milliseconds: 100));

        final baseTime = DateTime.now().toUtc();
        for (int i = 0; i < 101; i++) {
          sensor1Controller.add(TimestampedSensorValue(
            values: [i.toDouble()],
            timestamp: baseTime.add(Duration(milliseconds: i * 20)),
          ));
        }
        await Future.delayed(const Duration(milliseconds: 300));

        final content = await csvLogger.getCurrentLogFile()!.readAsString();
        expect(content.length, greaterThan(150));
      });

      test('filters duplicate values within 10ms window', () async {
        final baseTime = DateTime.now().toUtc();

        final content = await logValuesAndGetContent(
          sensors: [mockSensor1],
          emissions: [
            MapEntry(sensor1Controller, [
              TimestampedSensorValue(values: [25.5], timestamp: baseTime),
              TimestampedSensorValue(
                values: [25.5],
                timestamp: baseTime.add(const Duration(milliseconds: 5)),
              ),
              TimestampedSensorValue(
                values: [25.5],
                timestamp: baseTime.add(const Duration(milliseconds: 15)),
              ),
              TimestampedSensorValue(
                values: [30.0],
                timestamp: baseTime.add(const Duration(milliseconds: 20)),
              ),
            ]),
          ],
        );

        final dataLines = content
            .split('\n')
            .where((line) => line.isNotEmpty && !line.contains('sensor_name'))
            .toList();

        expect(dataLines.length, equals(3));
      });
    });

    group('stopLogging', () {
      test('does nothing if not logging', () async {
        await csvLogger.initialize();
        await csvLogger.stopLogging();
      });

      test('unsubscribes from all sensor streams', () async {
        await csvLogger.initialize();
        csvLogger.startLogging([mockSensor1, mockSensor2]);
        await csvLogger.stopLogging();

        sensor1Controller.add(TimestampedSensorValue(
          values: [25.5],
          timestamp: DateTime.now().toUtc(),
        ));
        await Future.delayed(const Duration(milliseconds: 100));

        final content = await csvLogger.getCurrentLogFile()!.readAsString();
        final dataLines = content
            .split('\n')
            .where((line) => line.isNotEmpty && !line.contains('sensor_name'))
            .toList();
        expect(dataLines.length, equals(0));
      });
    });

    group('getLogFiles', () {
      test('returns empty list when no log files exist', () async {
        await csvLogger.initialize();
        final logFiles = await csvLogger.getLogFiles();
        expect(logFiles, isEmpty);
      });

      test('returns log files sorted by newest first', () async {
        await csvLogger.initialize();

        csvLogger.startLogging([mockSensor1]);
        await Future.delayed(const Duration(milliseconds: 200));
        await csvLogger.stopLogging();

        await Future.delayed(const Duration(seconds: 1));

        csvLogger.startLogging([mockSensor1]);
        await Future.delayed(const Duration(milliseconds: 200));
        await csvLogger.stopLogging();

        final logFiles = await csvLogger.getLogFiles();
        expect(logFiles.length, greaterThanOrEqualTo(2));
        expect(logFiles.first.path, isNot(equals(logFiles.last.path)));
      });
    });

    group('getLogDirectoryPath', () {
      test('returns null when not initialized', () async {
        await csvLogger.dispose();
        expect(csvLogger.getLogDirectoryPath(), isNull);
      });

      test('returns path after initialization', () async {
        await csvLogger.initialize();
        final path = csvLogger.getLogDirectoryPath();
        expect(path, isNotNull);
        expect(path, contains('sensebox_bike_sensor_logs'));
      });
    });

    group('getCurrentLogFile', () {
      test('returns null when not logging, valid when logging', () async {
        await csvLogger.initialize();
        expect(csvLogger.getCurrentLogFile(), isNull);

        csvLogger.startLogging([mockSensor1]);
        await Future.delayed(const Duration(milliseconds: 100));
        expect(csvLogger.getCurrentLogFile(), isNotNull);
      });

      test('returns file reference after stopping', () async {
        await csvLogger.initialize();
        csvLogger.startLogging([mockSensor1]);
        await Future.delayed(const Duration(milliseconds: 100));
        await csvLogger.stopLogging();
        expect(csvLogger.getCurrentLogFile(), isNotNull);
      });
    });

    group('dispose', () {
      test('cleans up resources and allows re-initialization', () async {
        await csvLogger.initialize();
        csvLogger.startLogging([mockSensor1]);

        await csvLogger.dispose();
        expect(csvLogger.getCurrentLogFile(), isNull);

        await csvLogger.initialize();
        expect(csvLogger.getLogDirectoryPath(), isNotNull);
      });

      test('flushes buffer before disposing', () async {
        await csvLogger.initialize();
        csvLogger.startLogging([mockSensor1]);
        await Future.delayed(const Duration(milliseconds: 100));

        sensor1Controller.add(TimestampedSensorValue(
          values: [25.5],
          timestamp: DateTime.now().toUtc(),
        ));
        await Future.delayed(const Duration(milliseconds: 100));

        final file = csvLogger.getCurrentLogFile();

        await csvLogger.dispose();

        final content = await file!.readAsString();
        expect(content, contains('25.5'));
      });
    });

    group('CSV format', () {
      test('writes data with correct format and ISO8601 UTC timestamp',
          () async {
        final content = await logValuesAndGetContent(
          sensors: [mockSensor1],
          emissions: [
            MapEntry(sensor1Controller, [
              TimestampedSensorValue(
                values: [25.5],
                timestamp: DateTime.now().toUtc(),
              ),
            ]),
          ],
        );

        final lines =
            content.split('\n').where((line) => line.isNotEmpty).toList();

        expect(
            lines[0], contains('sensor_name,timestamp,value1,value2,value3'));

        expect(lines.length, greaterThanOrEqualTo(2));
        final dataLine = lines[1];
        expect(dataLine, startsWith('temperature,'));
        expect(dataLine, contains('25.5'));

        expect(
            content, matches(RegExp(r'\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}')));
      });
    });

    group('stream error handling', () {
      test('continues logging after stream error', () async {
        await csvLogger.initialize();
        csvLogger.startLogging([mockSensor1]);
        await Future.delayed(const Duration(milliseconds: 100));

        sensor1Controller.addError(Exception('Test error'));
        await Future.delayed(const Duration(milliseconds: 50));

        sensor1Controller.add(TimestampedSensorValue(
          values: [25.5],
          timestamp: DateTime.now().toUtc(),
        ));
        await Future.delayed(const Duration(milliseconds: 100));

        await csvLogger.stopLogging();

        final content = await csvLogger.getCurrentLogFile()!.readAsString();
        expect(content, contains('25.5'));
      });
    });
  });
}
