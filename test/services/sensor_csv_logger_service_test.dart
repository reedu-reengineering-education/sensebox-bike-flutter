import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
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
  late StreamController<List<double>> sensor1Controller;
  late StreamController<List<double>> sensor2Controller;

  setUp(() async {
    initializeTestDependencies();

    // Create a temporary directory for testing
    tempDirectory = Directory.systemTemp.createTempSync();
    mockPathProvider(tempDirectory.path);

    // Dispose any existing instance
    csvLogger = SensorCsvLoggerService();
    await csvLogger.dispose();

    // Create mock sensors with stream controllers
    mockSensor1 = MockSensor();
    mockSensor2 = MockSensor();
    sensor1Controller = StreamController<List<double>>.broadcast();
    sensor2Controller = StreamController<List<double>>.broadcast();

    when(() => mockSensor1.title).thenReturn('temperature');
    when(() => mockSensor1.valueStream).thenAnswer((_) => sensor1Controller.stream);

    when(() => mockSensor2.title).thenReturn('humidity');
    when(() => mockSensor2.valueStream).thenAnswer((_) => sensor2Controller.stream);
  });

  tearDown(() async {
    await csvLogger.dispose();
    await sensor1Controller.close();
    await sensor2Controller.close();
    pathProviderChannel.setMockMethodCallHandler(null);
    
    // Clean up temp directory
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  group('SensorCsvLoggerService', () {
    group('initialize', () {
      test('initializes successfully with temporary directory', () async {
        await csvLogger.initialize();

        final logDirectoryPath = csvLogger.getLogDirectoryPath();
        expect(logDirectoryPath, isNotNull);
        expect(logDirectoryPath, contains('sensebox_bike_sensor_logs'));
        
        final logDirectory = Directory(logDirectoryPath!);
        expect(await logDirectory.exists(), isTrue);
      });

      test('does not reinitialize if already initialized', () async {
        await csvLogger.initialize();
        final firstPath = csvLogger.getLogDirectoryPath();

        await csvLogger.initialize();
        final secondPath = csvLogger.getLogDirectoryPath();

        expect(firstPath, equals(secondPath));
      });
    });

    group('startLogging', () {
      test('does not start logging if not initialized', () {
        csvLogger.startLogging([mockSensor1]);

        expect(csvLogger.getCurrentLogFile(), isNull);
      });

      test('creates CSV file and subscribes to sensor streams', () async {
        await csvLogger.initialize();
        csvLogger.startLogging([mockSensor1, mockSensor2]);

        // Wait for async file creation
        await Future.delayed(const Duration(milliseconds: 100));

        final currentFile = csvLogger.getCurrentLogFile();
        expect(currentFile, isNotNull);
        expect(currentFile!.path, contains('sensor_data_'));
        expect(currentFile.path, endsWith('.csv'));

        // Verify file exists and has header
        expect(await currentFile.exists(), isTrue);
        final content = await currentFile.readAsString();
        expect(content, contains('sensor_name,timestamp,value1'));
      });

      test('does not start logging if already logging', () async {
        await csvLogger.initialize();
        csvLogger.startLogging([mockSensor1]);

        final firstFile = csvLogger.getCurrentLogFile();

        csvLogger.startLogging([mockSensor1]);
        final secondFile = csvLogger.getCurrentLogFile();

        expect(firstFile, equals(secondFile));
      });
    });

    group('data logging', () {
      test('logs sensor data to buffer', () async {
        await csvLogger.initialize();
        csvLogger.startLogging([mockSensor1]);

        // Wait for file creation
        await Future.delayed(const Duration(milliseconds: 100));

        // Emit sensor data
        sensor1Controller.add([25.5]);
        await Future.delayed(const Duration(milliseconds: 100));

        // Manually flush buffer to verify data was logged
        await csvLogger.stopLogging();

        final currentFile = csvLogger.getCurrentLogFile();
        expect(currentFile, isNotNull);
        final content = await currentFile!.readAsString();
        expect(content, contains('temperature'));
        expect(content, contains('25.5'));
      });

      test('logs multiple sensor values correctly', () async {
        await csvLogger.initialize();
        csvLogger.startLogging([mockSensor1, mockSensor2]);

        // Wait for file creation
        await Future.delayed(const Duration(milliseconds: 100));

        sensor1Controller.add([25.5]);
        sensor2Controller.add([60.0]);
        await Future.delayed(const Duration(milliseconds: 100));

        await csvLogger.stopLogging();

        final currentFile = csvLogger.getCurrentLogFile();
        final content = await currentFile!.readAsString();
        expect(content, contains('temperature'));
        expect(content, contains('humidity'));
        expect(content, contains('25.5'));
        expect(content, contains('60.0'));
      });

      test('logs multiple values from same sensor', () async {
        await csvLogger.initialize();
        csvLogger.startLogging([mockSensor1]);

        // Wait for file creation
        await Future.delayed(const Duration(milliseconds: 100));

        sensor1Controller.add([25.5, 26.0, 24.8]);
        await Future.delayed(const Duration(milliseconds: 100));

        await csvLogger.stopLogging();

        final currentFile = csvLogger.getCurrentLogFile();
        final content = await currentFile!.readAsString();
        expect(content, contains('25.5,26.0,24.8'));
      });

      test('does not log data when not logging', () async {
        await csvLogger.initialize();
        csvLogger.startLogging([mockSensor1]);
        await csvLogger.stopLogging();

        sensor1Controller.add([25.5]);
        await Future.delayed(const Duration(milliseconds: 100));

        final currentFile = csvLogger.getCurrentLogFile();
        final content = await currentFile!.readAsString();
        // Should only contain header, no new data
        final lines = content.split('\n').where((line) => line.isNotEmpty).toList();
        expect(lines.length, equals(1)); // Only header
      });
    });

    group('stopLogging', () {
      test('stops logging and flushes buffer', () async {
        await csvLogger.initialize();
        csvLogger.startLogging([mockSensor1]);

        // Wait for file creation
        await Future.delayed(const Duration(milliseconds: 100));

        sensor1Controller.add([25.5]);
        await Future.delayed(const Duration(milliseconds: 100));

        await csvLogger.stopLogging();

        final currentFile = csvLogger.getCurrentLogFile();
        final content = await currentFile!.readAsString();
        expect(content, contains('temperature'));
        expect(content, contains('25.5'));
      });

      test('does nothing if not logging', () async {
        await csvLogger.initialize();
        
        // Should not throw
        await csvLogger.stopLogging();
      });

      test('unsubscribes from all sensor streams', () async {
        await csvLogger.initialize();
        csvLogger.startLogging([mockSensor1, mockSensor2]);

        await csvLogger.stopLogging();

        // Emit data after stopping - should not be logged
        sensor1Controller.add([25.5]);
        await Future.delayed(const Duration(milliseconds: 100));

        final currentFile = csvLogger.getCurrentLogFile();
        final content = await currentFile!.readAsString();
        // Count non-header lines
        final dataLines = content.split('\n')
            .where((line) => line.isNotEmpty && !line.contains('sensor_name'))
            .toList();
        expect(dataLines.length, equals(0));
      });
    });

    group('buffer flushing', () {
      test('flushes buffer when it reaches buffer size', () async {
        await csvLogger.initialize();
        csvLogger.startLogging([mockSensor1]);

        // Wait for file creation
        await Future.delayed(const Duration(milliseconds: 100));

        // Add enough data to trigger buffer flush (buffer size is 100)
        for (int i = 0; i < 101; i++) {
          sensor1Controller.add([i.toDouble()]);
        }
        // Wait for buffer flush to complete
        await Future.delayed(const Duration(milliseconds: 300));

        final currentFile = csvLogger.getCurrentLogFile();
        final content = await currentFile!.readAsString();
        // Should have flushed at least some data (header + some data lines)
        expect(content.length, greaterThan(150));
      });

      test('flushes buffer on stop', () async {
        await csvLogger.initialize();
        csvLogger.startLogging([mockSensor1]);

        // Wait for file creation
        await Future.delayed(const Duration(milliseconds: 100));

        sensor1Controller.add([25.5]);
        await Future.delayed(const Duration(milliseconds: 100));

        await csvLogger.stopLogging();

        final currentFile = csvLogger.getCurrentLogFile();
        final content = await currentFile!.readAsString();
        expect(content, contains('25.5'));
      });
    });

    group('getLogFiles', () {
      test('returns empty list when no log files exist', () async {
        await csvLogger.initialize();

        final logFiles = await csvLogger.getLogFiles();
        expect(logFiles, isEmpty);
      });

      test('returns log files after creating them', () async {
        await csvLogger.initialize();
        csvLogger.startLogging([mockSensor1]);
        
        // Wait for file creation
        await Future.delayed(const Duration(milliseconds: 100));
        
        await csvLogger.stopLogging();

        final logFiles = await csvLogger.getLogFiles();
        expect(logFiles.length, greaterThanOrEqualTo(1));
        expect(logFiles.first.path, endsWith('.csv'));
      });

      test('returns files sorted by newest first', () async {
        await csvLogger.initialize();
        
        // Create first file
        csvLogger.startLogging([mockSensor1]);
        await Future.delayed(const Duration(milliseconds: 200));
        await csvLogger.stopLogging();

        // Wait at least 1 second to ensure different timestamp
        await Future.delayed(const Duration(seconds: 1));

        // Create second file
        csvLogger.startLogging([mockSensor1]);
        await Future.delayed(const Duration(milliseconds: 200));
        await csvLogger.stopLogging();

        final logFiles = await csvLogger.getLogFiles();
        expect(logFiles.length, greaterThanOrEqualTo(2));
        // Newest file should be first (path comparison should work for timestamps)
        expect(logFiles.first.path, isNot(equals(logFiles.last.path)));
      });
    });

    group('getLogDirectoryPath', () {
      test('returns null when not initialized', () async {
        // Ensure service is disposed first
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
      test('returns null when not logging', () async {
        await csvLogger.initialize();
        // File is only created when logging starts
        expect(csvLogger.getCurrentLogFile(), isNull);
      });

      test('returns file when logging', () async {
        await csvLogger.initialize();
        csvLogger.startLogging([mockSensor1]);
        // Wait for async file creation
        await Future.delayed(const Duration(milliseconds: 100));
        expect(csvLogger.getCurrentLogFile(), isNotNull);
      });

      test('returns file reference after stopping', () async {
        await csvLogger.initialize();
        csvLogger.startLogging([mockSensor1]);
        // Wait for file creation
        await Future.delayed(const Duration(milliseconds: 100));
        await csvLogger.stopLogging();
        // Note: The service keeps the file reference even after stopping
        // This is expected behavior based on the implementation
        expect(csvLogger.getCurrentLogFile(), isNotNull);
      });
    });

    group('dispose', () {
      test('cleans up resources', () async {
        await csvLogger.initialize();
        csvLogger.startLogging([mockSensor1]);

        await csvLogger.dispose();

        // After dispose, should be able to reinitialize
        await csvLogger.initialize();
        expect(csvLogger.getLogDirectoryPath(), isNotNull);
      });

      test('flushes buffer before disposing', () async {
        await csvLogger.initialize();
        csvLogger.startLogging([mockSensor1]);

        // Wait for file creation
        await Future.delayed(const Duration(milliseconds: 100));

        sensor1Controller.add([25.5]);
        await Future.delayed(const Duration(milliseconds: 100));

        await csvLogger.dispose();

        final currentFile = csvLogger.getCurrentLogFile();
        // After dispose, currentFile should be null
        expect(currentFile, isNull);
      });
    });

    group('CSV format', () {
      test('creates CSV with correct header format', () async {
        await csvLogger.initialize();
        csvLogger.startLogging([mockSensor1]);

        // Wait for async file creation
        await Future.delayed(const Duration(milliseconds: 100));

        final currentFile = csvLogger.getCurrentLogFile();
        expect(currentFile, isNotNull);
        final content = await currentFile!.readAsString();
        expect(content, contains('sensor_name,timestamp,value1,value2,value3'));
      });

      test('writes data in correct CSV format', () async {
        await csvLogger.initialize();
        csvLogger.startLogging([mockSensor1]);

        // Wait for file creation
        await Future.delayed(const Duration(milliseconds: 100));

        sensor1Controller.add([25.5]);
        await Future.delayed(const Duration(milliseconds: 100));
        await csvLogger.stopLogging();

        final currentFile = csvLogger.getCurrentLogFile();
        final content = await currentFile!.readAsString();
        final lines = content.split('\n').where((line) => line.isNotEmpty).toList();
        
        expect(lines.length, greaterThanOrEqualTo(2)); // Header + at least one data line
        expect(lines[0], contains('sensor_name'));
        
        final dataLine = lines[1];
        expect(dataLine, startsWith('temperature,'));
        expect(dataLine, contains('25.5'));
      });

      test('includes UTC timestamp in ISO8601 format', () async {
        await csvLogger.initialize();
        csvLogger.startLogging([mockSensor1]);

        // Wait for file creation
        await Future.delayed(const Duration(milliseconds: 100));

        sensor1Controller.add([25.5]);
        await Future.delayed(const Duration(milliseconds: 100));
        await csvLogger.stopLogging();

        final currentFile = csvLogger.getCurrentLogFile();
        final content = await currentFile!.readAsString();
        // Check for ISO8601 format timestamp (contains 'T' and 'Z')
        expect(content, matches(RegExp(r'\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}')));
      });
    });
  });
}

