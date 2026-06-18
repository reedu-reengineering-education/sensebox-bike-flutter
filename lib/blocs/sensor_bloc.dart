import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:sensebox_bike/blocs/ble_bloc.dart';
import 'package:sensebox_bike/blocs/geolocation_bloc.dart';
import 'package:sensebox_bike/blocs/recording_bloc.dart';
import 'package:sensebox_bike/blocs/settings_bloc.dart';
import 'package:sensebox_bike/blocs/sensor_availability.dart';
import 'package:sensebox_bike/sensors/acceleration_sensor.dart';
import 'package:sensebox_bike/sensors/distance_sensor.dart';
import 'package:sensebox_bike/sensors/distance_right_sensor.dart';
import 'package:sensebox_bike/sensors/finedust_sensor.dart';
import 'package:sensebox_bike/sensors/gps_sensor.dart';
import 'package:sensebox_bike/sensors/humidity_sensor.dart';
import 'package:sensebox_bike/sensors/overtaking_prediction_sensor.dart';
import 'package:sensebox_bike/sensors/sensor.dart';
import 'package:sensebox_bike/sensors/surface_anomaly_sensor.dart';
import 'package:sensebox_bike/sensors/surface_classification_sensor.dart';
import 'package:sensebox_bike/sensors/temperature_sensor.dart';
import 'package:sensebox_bike/services/sensor_csv_logger_service.dart';

class SensorBloc with ChangeNotifier {
  final BleBloc bleBloc;
  final GeolocationBloc geolocationBloc;
  final RecordingBloc recordingBloc;
  final SettingsBloc settingsBloc;
  final List<Sensor> _sensors = [];
  late final VoidCallback _characteristicsListener;
  late final VoidCallback _characteristicStreamsVersionListener;
  late final VoidCallback _selectedDeviceListener;
  late final VoidCallback _recordingListener;
  late final VoidCallback _reconnectingListener;
  List<String> _lastCharacteristicUuids = [];
  bool _isStartingListening = false;

  SensorBloc(this.bleBloc, this.geolocationBloc, this.recordingBloc,
      this.settingsBloc) {
    _initializeSensors();

    _selectedDeviceListener = () {
      if (bleBloc.selectedDevice != null && bleBloc.isConnected) {
        _startListening();
        if (!geolocationBloc.isListening) {
          geolocationBloc.startListening();
        }
      } else {
        _stopListening();
        geolocationBloc.stopListening();
      }
      notifyListeners();
    };

    _characteristicsListener = () {
      final currentUuids = _characteristicUuids.toList();
      if (currentUuids.isEmpty) {
        _lastCharacteristicUuids = [];
        unawaited(_stopListening());
        return;
      }
      if (bleBloc.selectedDevice == null) {
        return;
      }
      if (!_listEqualsUnordered(_lastCharacteristicUuids, currentUuids)) {
        _lastCharacteristicUuids = List.from(currentUuids);
        _restartAllSensors();
      }
    };

    _characteristicStreamsVersionListener = () {
      if (bleBloc.selectedDevice == null) {
        return;
      }
      _restartAllSensors();
    };

    _reconnectingListener = () {
      if (bleBloc.isReconnectingNotifier.value) {
        unawaited(_stopListening());
        return;
      }
      if (bleBloc.selectedDevice != null && bleBloc.isConnected) {
        unawaited(_restartAllSensors());
        if (!geolocationBloc.isListening) {
          geolocationBloc.startListening();
        }
      }
    };

    _recordingListener = () {
      if (!recordingBloc.isRecording) {
        _flushAllSensorBuffers();
      }
    };
    recordingBloc.isRecordingNotifier.addListener(_recordingListener);
    recordingBloc.setRecordingCallbacks(
      onRecordingStart: _onRecordingStart,
      onRecordingStop: _onRecordingStop,
    );

    bleBloc.selectedDeviceNotifier.addListener(_selectedDeviceListener);
    bleBloc.isReconnectingNotifier.addListener(_reconnectingListener);
    bleBloc.availableCharacteristics.addListener(_characteristicsListener);
    bleBloc.characteristicStreamsVersion
        .addListener(_characteristicStreamsVersionListener);
  }

  Future<void> _onRecordingStart() async {
    _clearAllSensorBuffersForNewRecording();
    
    if (!kReleaseMode) {
      final envValue =
          dotenv.get('ENABLE_SENSOR_CSV_LOGGING', fallback: 'false');
      final enableLogging = envValue.toLowerCase() == 'true';
      if (enableLogging) {
        final csvLogger = SensorCsvLoggerService();
        csvLogger.startLogging(_sensors);
      }
    }
    
    final directUploadService = recordingBloc.directUploadService;
    if (directUploadService != null) {

      for (final sensor in _sensors) {
        sensor.setDirectUploadService(directUploadService);
      }

      directUploadService.enable();
    }
    
    if (!geolocationBloc.isListening) {
      geolocationBloc.startListening();
    }
    geolocationBloc.getCurrentLocationAndEmit().catchError((e) {
    });
  }

  Future<void> _onRecordingStop() async {
    // Stop CSV logging (only in debug mode if enabled in .env)
    if (!kReleaseMode) {
      final enableLogging = dotenv
              .get('ENABLE_SENSOR_CSV_LOGGING', fallback: 'false')
              .toLowerCase() ==
          'true';
      if (enableLogging) {
        final csvLogger = SensorCsvLoggerService();
        await csvLogger.stopLogging();
      }
    }
    
    final directUploadService = recordingBloc.directUploadService;
    if (directUploadService != null) {
      await directUploadService.uploadRemainingBufferedData();
      directUploadService.disable();
    }
  }

  bool _listEqualsUnordered(List<String> a, List<String> b) {
    final aSorted = List<String>.from(a)..sort();
    final bSorted = List<String>.from(b)..sort();
    return aSorted.length == bSorted.length &&
        aSorted.every((element) => bSorted.contains(element));
  }

  void _initializeSensors() {
    final isarService = geolocationBloc.isarService;

    _sensors.add(TemperatureSensor(
        bleBloc, geolocationBloc, recordingBloc, isarService));
    _sensors.add(
        HumiditySensor(
        bleBloc, geolocationBloc, recordingBloc, isarService));
    _sensors.add(
        DistanceSensor(
        bleBloc, geolocationBloc, recordingBloc, isarService));
    _sensors.add(
        DistanceRightSensor(
        bleBloc, geolocationBloc, recordingBloc, isarService));
    _sensors.add(SurfaceClassificationSensor(
        bleBloc, geolocationBloc, recordingBloc, isarService));
    _sensors.add(AccelerationSensor(
        bleBloc, geolocationBloc, recordingBloc, isarService));
    _sensors.add(OvertakingPredictionSensor(
        bleBloc, geolocationBloc, recordingBloc, isarService));
    _sensors.add(SurfaceAnomalySensor(
        bleBloc, geolocationBloc, recordingBloc, isarService));
    _sensors.add(
        FinedustSensor(
        bleBloc, geolocationBloc, recordingBloc, isarService));
    _sensors
        .add(GPSSensor(
        bleBloc, geolocationBloc, recordingBloc, isarService));
  }

  Future<void> _startListening() async {
    if (_isStartingListening) {
      return;
    }
    _isStartingListening = true;
    try {
      for (final sensor in availableSensors) {
        await sensor.startListening();
      }
    } finally {
      _isStartingListening = false;
    }
  }

  Future<void> _stopListening() async {
    for (var sensor in _sensors) {
      await sensor.stopListening();
    }
  }

  Future<void> _restartAllSensors() async {
    if (bleBloc.selectedDevice == null) {
      await _stopListening();
      return;
    }
    // During reconnect, characteristics may be republished before phase flips
    // to connected; wait for onReconnectSucceeded before re-subscribing.
    if (!bleBloc.isConnected) {
      if (!bleBloc.isReconnectingNotifier.value) {
        await _stopListening();
      }
      return;
    }
    await _stopListening();
    await _startListening();
  }

  Future<void> _flushAllSensorBuffers() async {
    await geolocationBloc.emitFinalGeolocation();
  }


  void _clearAllSensorBuffersForNewRecording() {
    for (var sensor in _sensors) {
      sensor.clearBuffersForNewRecording();
    }
  }

  List<Sensor> get sensors => _sensors;

  Set<String> get _characteristicUuids => {
        for (final characteristic in bleBloc.availableCharacteristics.value)
          characteristic.uuidString,
      };

  List<Sensor> get availableSensors => filterAvailableSensors(
        _sensors,
        _characteristicUuids,
      );

  @override
  void dispose() {
    bleBloc.selectedDeviceNotifier.removeListener(_selectedDeviceListener);
    bleBloc.isReconnectingNotifier.removeListener(_reconnectingListener);
    bleBloc.availableCharacteristics.removeListener(_characteristicsListener);
    bleBloc.characteristicStreamsVersion
        .removeListener(_characteristicStreamsVersionListener);
    recordingBloc.isRecordingNotifier.removeListener(_recordingListener);
    
    _stopListening().catchError((e, stackTrace) {
      debugPrint('Error during sensor cleanup: $e');
      debugPrintStack(stackTrace: stackTrace);
    });
    
    for (final sensor in _sensors) {
      sensor.dispose();
    }
    
    super.dispose();
  }
}
