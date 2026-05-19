import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:sensebox_bike/blocs/ble_bloc.dart';
import 'package:sensebox_bike/blocs/geolocation_bloc.dart';
import 'package:sensebox_bike/blocs/recording_bloc.dart';
import 'package:sensebox_bike/feature_flags.dart';
import 'package:sensebox_bike/models/ble_connection_phase.dart';
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
import 'package:sensebox_bike/services/isar_service.dart';
import 'package:sensebox_bike/services/sensor_csv_logger_service.dart';
import 'package:sensebox_bike/services/error_service.dart';

typedef _SensorFactory = Sensor Function(
  BleBloc bleBloc,
  GeolocationBloc geolocationBloc,
  RecordingBloc recordingBloc,
  IsarService isarService,
);

class SensorBloc {
  static const _sensorFactories = <_SensorFactory>[
    TemperatureSensor.new,
    HumiditySensor.new,
    DistanceSensor.new,
    DistanceRightSensor.new,
    SurfaceClassificationSensor.new,
    AccelerationSensor.new,
    OvertakingPredictionSensor.new,
    SurfaceAnomalySensor.new,
    FinedustSensor.new,
    GPSSensor.new,
  ];

  final BleBloc bleBloc;
  final GeolocationBloc geolocationBloc;
  final RecordingBloc recordingBloc;
  final List<Sensor> _sensors = [];

  late final VoidCallback _connectionPhaseListener;
  bool _isStartingListening = false;

  SensorBloc(this.bleBloc, this.geolocationBloc, this.recordingBloc) {
    final isarService = geolocationBloc.isarService;
    for (final factory in _sensorFactories) {
      _sensors.add(factory(bleBloc, geolocationBloc, recordingBloc, isarService));
    }

    _connectionPhaseListener = () {
      unawaited(_applyConnectionPhase(bleBloc.connectionPhaseNotifier.value));
    };

    recordingBloc.setRecordingCallbacks(
      onRecordingStart: _onRecordingStart,
      onRecordingStop: _onRecordingStop,
    );

    bleBloc.connectionPhaseNotifier.addListener(_connectionPhaseListener);
    _connectionPhaseListener();
  }

  Set<String> get _availableCharacteristicUuids =>
      bleBloc.availableCharacteristics.value
          .map((characteristic) => characteristic.uuid.toString().toLowerCase())
          .toSet();

  Future<void> _applyConnectionPhase(BleConnectionPhase phase) async {
    if (phase == BleConnectionPhase.idle) {
      await _stopListening();
      geolocationBloc.stopListening();
      return;
    }

    if (phase != BleConnectionPhase.connected) {
      return;
    }

    if (!geolocationBloc.isListening) {
      geolocationBloc.startListening().catchError(
            (error, stackTrace) =>
                ErrorService.handleError(error, stackTrace),
          );
    }

    await _stopListening();
    await _startListening();
  }

  Future<void> _onRecordingStart() async {
    for (final sensor in _sensors) {
      sensor.clearBuffersForNewRecording();
    }

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

    await geolocationBloc.emitFinalGeolocation();
  }

  bool get _isCsvLoggingEnabled {
    if (kReleaseMode) {
      return false;
    }
    return dotenv
            .get('ENABLE_SENSOR_CSV_LOGGING', fallback: 'false')
            .toLowerCase() ==
        'true';
  }

  Future<void> _startListening() async {
    if (_isStartingListening) {
      return;
    }

    _isStartingListening = true;
    try {
      final availableUuids = _availableCharacteristicUuids;

      for (final sensor in _sensors) {
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
    for (final sensor in _sensors) {
      await sensor.stopListening();
    }
  }

  List<Sensor> get sensors => _sensors;

  List<Widget> getSensorWidgets() {
    final availableUuids = _availableCharacteristicUuids;

    final availableSensors = _sensors.where((sensor) {
      if (FeatureFlags.hideSurfaceAnomalySensor &&
          sensor.title == 'surface_anomaly') {
        return false;
      }
      return availableUuids.contains(sensor.characteristicUuid.toLowerCase());
    }).toList();

    availableSensors.sort((a, b) => a.uiPriority.compareTo(b.uiPriority));
    return availableSensors
        .map((sensor) => sensor.buildWidget())
        .toList();
  }

  void dispose() {
    bleBloc.connectionPhaseNotifier.removeListener(_connectionPhaseListener);

    _stopListening().catchError((error, stackTrace) {
      debugPrint('Error during sensor cleanup: $error');
      debugPrintStack(stackTrace: stackTrace);
    });

    for (final sensor in _sensors) {
      sensor.dispose();
    }
  }
}
