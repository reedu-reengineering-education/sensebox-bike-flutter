import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:sensebox_bike/blocs/ble_bloc.dart';
import 'package:sensebox_bike/blocs/geolocation_bloc.dart';
import 'package:sensebox_bike/blocs/recording_bloc.dart';
import 'package:sensebox_bike/feature_flags.dart';
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
import 'package:sensebox_bike/services/error_service.dart';

class SensorBloc {
  final BleBloc bleBloc;
  final GeolocationBloc geolocationBloc;
  final RecordingBloc recordingBloc;
  final List<Sensor> _sensors = [];
  late final VoidCallback _characteristicsListener;
  late final VoidCallback _characteristicStreamsVersionListener;
  late final VoidCallback _selectedDeviceListener;
  late final VoidCallback _recordingListener;
  List<String> _lastCharacteristicUuids = [];
  bool _isStartingListening = false;

  SensorBloc(this.bleBloc, this.geolocationBloc, this.recordingBloc) {
    _initializeSensors();

    _selectedDeviceListener = () {
      if (bleBloc.selectedDevice != null &&
          bleBloc.selectedDevice!.isConnected) {
        _startListening();
        if (!geolocationBloc.isListening) {
          geolocationBloc.startListening().catchError((error, stackTrace) {
            ErrorService.handleError(error, stackTrace);
          });
        }
      } else {
        _stopListening();
        geolocationBloc.stopListening();
      }
    };

    _characteristicsListener = () {
      final currentUuids = _availableCharacteristicUuids().toList();
      if (!_listEqualsUnordered(_lastCharacteristicUuids, currentUuids)) {
        _lastCharacteristicUuids = List.from(currentUuids);
        _restartAllSensors();
      }
    };

    _characteristicStreamsVersionListener = () {
      _restartAllSensors();
    };

    _recordingListener = () {
      if (!recordingBloc.isRecording) {
        _emitFinalGeolocationOnRecordingStop();
      }
    };
    recordingBloc.isRecordingNotifier.addListener(_recordingListener);
    recordingBloc.setRecordingCallbacks(
      onRecordingStart: _onRecordingStart,
      onRecordingStop: _onRecordingStop,
    );

    bleBloc.selectedDeviceNotifier.addListener(_selectedDeviceListener);
    bleBloc.availableCharacteristics.addListener(_characteristicsListener);
    bleBloc.characteristicStreamsVersion
        .addListener(_characteristicStreamsVersionListener);
  }

  static bool get _isCsvLoggingEnabled =>
      !kReleaseMode &&
      dotenv.get('ENABLE_SENSOR_CSV_LOGGING', fallback: 'false').toLowerCase() ==
          'true';

  Set<String> _availableCharacteristicUuids() {
    return bleBloc.availableCharacteristics.value
        .map((c) => c.uuid.toString().toLowerCase())
        .toSet();
  }

  Future<void> _onRecordingStart() async {
    _clearAllSensorBuffersForNewRecording();

    if (_isCsvLoggingEnabled) {
      SensorCsvLoggerService().startLogging(_sensors);
    }

    final directUploadService = recordingBloc.directUploadService;
    if (directUploadService != null) {
      for (final sensor in _sensors) {
        sensor.setDirectUploadService(directUploadService);
      }

      directUploadService.enable();
    }

    if (geolocationBloc.isListening) {
      geolocationBloc.stopListening();
    }
    await geolocationBloc.startListening();
    await geolocationBloc.getCurrentLocationAndEmit();
  }

  Future<void> _onRecordingStop() async {
    if (_isCsvLoggingEnabled) {
      await SensorCsvLoggerService().stopLogging();
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
        HumiditySensor(bleBloc, geolocationBloc, recordingBloc, isarService));
    _sensors.add(
        DistanceSensor(bleBloc, geolocationBloc, recordingBloc, isarService));
    _sensors.add(DistanceRightSensor(
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
        FinedustSensor(bleBloc, geolocationBloc, recordingBloc, isarService));
    _sensors.add(
        GPSSensor(bleBloc, geolocationBloc, recordingBloc, isarService));
  }

  Future<void> _startListening() async {
    if (_isStartingListening) {
      return;
    }
    _isStartingListening = true;
    try {
      final availableUuids = _availableCharacteristicUuids();

      for (var sensor in _sensors) {
        final uuid = sensor.characteristicUuid.toLowerCase();
        if (!availableUuids.contains(uuid) ||
            !bleBloc.hasCharacteristicStream(uuid)) {
          continue;
        }
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
    await _stopListening();
    await _startListening();
  }

  Future<void> _emitFinalGeolocationOnRecordingStop() async {
    await geolocationBloc.emitFinalGeolocation();
  }

  void _clearAllSensorBuffersForNewRecording() {
    for (var sensor in _sensors) {
      sensor.clearBuffersForNewRecording();
    }
  }

  List<Widget> getSensorWidgets() {
    final availableUuids = _availableCharacteristicUuids();

    final availableSensors = _sensors.where((sensor) {
      if (FeatureFlags.hideSurfaceAnomalySensor &&
          sensor.title == 'surface_anomaly') {
        return false;
      }
      return availableUuids.contains(sensor.characteristicUuid.toLowerCase());
    }).toList();

    availableSensors.sort((a, b) => a.uiPriority.compareTo(b.uiPriority));
    return availableSensors
        .map<Widget>((sensor) => sensor.buildWidget())
        .toList();
  }

  void dispose() {
    bleBloc.selectedDeviceNotifier.removeListener(_selectedDeviceListener);
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
  }
}
