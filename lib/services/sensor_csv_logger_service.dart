import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sensebox_bike/sensors/sensor.dart';
import 'package:sensebox_bike/models/timestamped_sensor_value.dart';

/// Service that logs sensor data from streams to a single CSV file
/// Logging starts when recording starts and stops when recording stops
class SensorCsvLoggerService {
  static final SensorCsvLoggerService _instance = SensorCsvLoggerService._internal();
  factory SensorCsvLoggerService() => _instance;
  SensorCsvLoggerService._internal();

  final Map<String, StreamSubscription<List<double>>> _subscriptions = {};
  final Map<String, StreamSubscription<TimestampedSensorValue>>
      _timestampedSubscriptions = {};
  final List<String> _buffer = [];
  File? _currentFile;
  Directory? _logDirectory;
  bool _isLogging = false;
  bool _isInitialized = false;
  Timer? _flushTimer;
  
  // Track last logged entry per sensor to prevent duplicates
  // Key: sensor name, Value: tuple of (timestamp in milliseconds, values string)
  final Map<String, MapEntry<int, String>> _lastLoggedEntry = {};

  // Configuration
  static const int _bufferSize = 100; // Flush after 100 entries
  static const Duration _flushInterval = Duration(seconds: 5); // Or every 5 seconds

  /// Initialize the logger service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      Directory? baseDirectory;
      
      if (Platform.isAndroid) {
        // Use Downloads folder on Android - accessible via file manager
        baseDirectory = Directory('/storage/emulated/0/Download');
        if (!await baseDirectory.exists()) {
          // Fallback to external storage if Downloads doesn't exist
          baseDirectory = await getExternalStorageDirectory();
        }
      } else if (Platform.isIOS) {
        // Use Documents directory on iOS - accessible via Files app
        baseDirectory = await getApplicationDocumentsDirectory();
      } else {
        // Fallback for other platforms
        baseDirectory = await getApplicationDocumentsDirectory();
      }

      if (baseDirectory == null) {
        throw Exception('Could not determine storage directory');
      }

      // Create subfolder for sensor logs
      _logDirectory = Directory('${baseDirectory.path}/sensebox_bike_sensor_logs');
      
      if (!await _logDirectory!.exists()) {
        await _logDirectory!.create(recursive: true);
      }

      _startFlushTimer();
      _isInitialized = true;
      debugPrint('SensorCsvLoggerService initialized - Logs stored at: ${_logDirectory!.path}');
    } catch (e) {
      debugPrint('Error initializing SensorCsvLoggerService: $e');
      // Fallback to app documents directory
      try {
        final directory = await getApplicationDocumentsDirectory();
        _logDirectory = Directory('${directory.path}/sensor_logs');
        if (!await _logDirectory!.exists()) {
          await _logDirectory!.create(recursive: true);
        }
        _startFlushTimer();
        _isInitialized = true;
        debugPrint('SensorCsvLoggerService initialized (fallback) - Logs stored at: ${_logDirectory!.path}');
      } catch (fallbackError) {
        debugPrint('Error in fallback initialization: $fallbackError');
      }
    }
  }

  /// Start logging - creates a new CSV file and subscribes to sensor streams
  void startLogging(List<Sensor> sensors) {
    if (!_isInitialized || _isLogging) return;

    _isLogging = true;
    _buffer.clear();
    _lastLoggedEntry
        .clear(); // Clear duplicate tracking when starting new session
    _createCsvFile();

    // Subscribe to all sensor streams
    for (final sensor in sensors) {
      _subscribeToSensor(sensor);
    }

    debugPrint('Started logging sensor data to CSV');
  }

  /// Stop logging - flushes buffer and unsubscribes from streams
  Future<void> stopLogging() async {
    if (!_isLogging) return;

    _isLogging = false;

    // Unsubscribe from all streams
    for (final subscription in _subscriptions.values) {
      await subscription.cancel();
    }
    _subscriptions.clear();
    for (final subscription in _timestampedSubscriptions.values) {
      await subscription.cancel();
    }
    _timestampedSubscriptions.clear();

    // Flush remaining data
    await _flushBuffer();

    debugPrint('Stopped logging sensor data to CSV');
  }

  /// Subscribe to a sensor's stream
  void _subscribeToSensor(Sensor sensor) {
    final sensorName = sensor.title;
    
    // Cancel existing subscriptions if any
    _subscriptions[sensorName]?.cancel();
    _timestampedSubscriptions[sensorName]?.cancel();

    // Subscribe to the sensor's timestamped value stream (uses same timestamp as aggregation)
    final timestampedSubscription = sensor.timestampedValueStream.listen(
      (timestampedValue) {
        if (_isLogging) {
          _logDataWithTimestamp(
              sensorName, timestampedValue.values, timestampedValue.timestamp);
        }
      },
      onError: (error) {
        debugPrint(
            'Error in timestamped sensor stream for $sensorName: $error');
      },
    );

    _timestampedSubscriptions[sensorName] = timestampedSubscription;
  }

  /// Log data to buffer with provided timestamp (from aggregation)
  void _logDataWithTimestamp(
      String sensorName, List<double> data, DateTime timestamp) {
    if (!_isLogging || _currentFile == null) return;

    final timestampUtc = timestamp.isUtc ? timestamp : timestamp.toUtc();
    final timestampStr = timestampUtc.toIso8601String();
    final timestampMs = timestampUtc.millisecondsSinceEpoch;
    final values = data.map((v) => v.toString()).join(',');
    final csvLine = '$sensorName,$timestampStr,$values';

    // Prevent duplicate entries: same sensor + same values within 10ms window
    final lastEntry = _lastLoggedEntry[sensorName];
    if (lastEntry != null) {
      final timeDiff = (timestampMs - lastEntry.key).abs();
      final sameValues = lastEntry.value == values;

      // Skip if same values arrived within 10ms (likely duplicate)
      if (sameValues && timeDiff < 10) {
        return;
      }
    }

    _lastLoggedEntry[sensorName] = MapEntry(timestampMs, values);
    _buffer.add(csvLine);

    // Flush if buffer is full
    if (_buffer.length >= _bufferSize) {
      _flushBuffer();
    }
  }

  /// Create a new CSV file for the current recording session
  Future<void> _createCsvFile() async {
    if (_logDirectory == null) return;

    try {
      final timestamp = DateFormat('yyyy-MM-dd_HH-mm-ss').format(DateTime.now());
      final fileName = 'sensor_data_$timestamp.csv';
      final filePath = '${_logDirectory!.path}/$fileName';
      final file = File(filePath);

      // Write CSV header
      // Format: sensor_name, timestamp, value1, value2, value3, ...
      // Note: We use a flexible number of value columns since different sensors have different value counts
      final header = 'sensor_name,timestamp,value1,value2,value3,value4,value5,value6,value7,value8,value9,value10';
      await file.writeAsString('$header\n');

      _currentFile = file;
      debugPrint('Created CSV file: $fileName');
    } catch (e) {
      debugPrint('Error creating CSV file: $e');
    }
  }

  /// Flush buffer to file
  Future<void> _flushBuffer() async {
    if (_buffer.isEmpty || _currentFile == null) {
      return;
    }

    try {
      final content = '${_buffer.join('\n')}\n';
      await _currentFile!.writeAsString(content, mode: FileMode.append);
      final count = _buffer.length;
      _buffer.clear();
      debugPrint('Flushed $count entries to CSV file');
    } catch (e) {
      debugPrint('Error flushing buffer: $e');
    }
  }

  /// Start periodic flush timer
  void _startFlushTimer() {
    _flushTimer?.cancel();
    _flushTimer = Timer.periodic(_flushInterval, (timer) {
      if (_isLogging) {
        _flushBuffer();
      }
    });
  }

  /// Get all log files
  Future<List<File>> getLogFiles() async {
    if (_logDirectory == null || !await _logDirectory!.exists()) {
      return [];
    }

    try {
      final files = await _logDirectory!.list().toList();
      return files.whereType<File>().where((f) => f.path.endsWith('.csv')).toList()
        ..sort((a, b) => b.path.compareTo(a.path)); // Newest first
    } catch (e) {
      debugPrint('Error getting log files: $e');
      return [];
    }
  }

  /// Get log directory path
  String? getLogDirectoryPath() {
    return _logDirectory?.path;
  }

  /// Get the current log file
  File? getCurrentLogFile() {
    return _currentFile;
  }

  /// Export a specific log file to Downloads (Android) or share (iOS)
  Future<void> exportLogFile(File file, BuildContext context) async {
    try {
      if (Platform.isAndroid) {
        // Copy to Downloads folder on Android
        final directory = Directory('/storage/emulated/0/Download');
        if (!await directory.exists()) {
          await directory.create(recursive: true);
        }
        
        final fileName = file.path.split('/').last;
        final newPath = '${directory.path}/$fileName';
        await file.copy(newPath);
        
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('File saved to Downloads: $fileName'),
            ),
          );
        }
      } else if (Platform.isIOS) {
        // Share on iOS
        await Share.shareXFiles([XFile(file.path)],
            text: 'Sensor log file');
      }
    } catch (e) {
      debugPrint('Error exporting log file: $e');
      // Fallback to share dialog
      if (context.mounted) {
        await Share.shareXFiles([XFile(file.path)],
            text: 'Sensor log file');
      }
    }
  }

  /// Export all log files
  Future<void> exportAllLogFiles(BuildContext context) async {
    final files = await getLogFiles();
    if (files.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No log files found')),
        );
      }
      return;
    }

    for (final file in files) {
      await exportLogFile(file, context);
      // Small delay between exports
      await Future.delayed(const Duration(milliseconds: 500));
    }
  }

  /// Flush all buffers and close subscriptions
  Future<void> dispose() async {
    _isLogging = false;
    _flushTimer?.cancel();
    
    // Flush buffer
    await _flushBuffer();
    
    // Cancel all subscriptions
    for (final subscription in _subscriptions.values) {
      await subscription.cancel();
    }
    _subscriptions.clear();
    for (final subscription in _timestampedSubscriptions.values) {
      await subscription.cancel();
    }
    _timestampedSubscriptions.clear();
    
    _buffer.clear();
    _lastLoggedEntry.clear();
    _currentFile = null;
    _logDirectory = null;
    _isInitialized = false;
    
    debugPrint('SensorCsvLoggerService disposed');
  }
}
