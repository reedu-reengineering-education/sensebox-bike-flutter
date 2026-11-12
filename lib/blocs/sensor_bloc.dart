import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:sensebox_bike/ble/ble_characteristic_ref.dart';
import 'package:sensebox_bike/blocs/ble_bloc.dart';
import 'package:sensebox_bike/blocs/geolocation_bloc.dart';
import 'package:sensebox_bike/blocs/recording_bloc.dart';
import 'package:sensebox_bike/blocs/sensor_availability.dart';
import 'package:sensebox_bike/models/data_collection_mode.dart';
import 'package:sensebox_bike/models/sensor_data.dart';
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
  final List<Sensor> _sensors = [];
  late final VoidCallback _recordingListener;
  Future<void> _sensorSync = Future.value();
  List<BleCharacteristicRef>? _listeningTo;

  SensorBloc(this.bleBloc, this.geolocationBloc, this.recordingBloc) {
    _initializeSensors();

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

    bleBloc.addListener(_onConnectionChanged);
    bleBloc.characteristicStreams.livePayloadVersion
        .addListener(notifyListeners);

    geolocationBloc.setCollectInstantSensorData((geo) {
      final rows = <SensorData>[];
      for (final sensor in _sensors) {
        rows.addAll(sensor.latestReadingAsSensorData(geo));
      }
      return rows;
    });
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
    // Periodic: take an immediate first sample. On-tap waits for the user;
    // GPS-driven collection is driven by the position stream.
    if (recordingBloc.activeCollectionMode.usesPeriodicTimer) {
      await geolocationBloc.captureSample();
    }
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

  void _onConnectionChanged() {
    _sensorSync = _sensorSync.then((_) => _syncSensorsWithConnection());
    notifyListeners();
  }

  Future<void> _syncSensorsWithConnection() async {
    final session = bleBloc.selectedDevice != null && bleBloc.isConnected
        ? bleBloc.availableCharacteristics.value
        : null;
    if (identical(session, _listeningTo)) {
      return;
    }
    _listeningTo = session;
    await _stopListening();
    if (session != null) {
      for (final sensor in _discoveredSensors) {
        await sensor.startListening();
      }
      if (!geolocationBloc.isListening) {
        geolocationBloc.startListening();
      }
    } else if (bleBloc.selectedDevice == null) {
      geolocationBloc.stopListening();
    }
  }

  Future<void> _stopListening() async {
    for (final sensor in _sensors) {
      await sensor.stopListening();
    }
  }

  Future<void> _flushAllSensorBuffers() async {
    // Final geo flush is only for GPS-driven deferred aggregation.
    // Relies on RecordingBloc firing isRecordingNotifier before resetting mode.
    if (!recordingBloc.activeCollectionMode.isGpsDriven) {
      return;
    }
    await geolocationBloc.emitFinalGeolocation();
  }


  void _clearAllSensorBuffersForNewRecording() {
    // Keep live BLE readings for periodic / on-tap so the first sample is not
    // GPS-speed-only after Start clears aggregation buffers.
    final clearLatestValues =
        recordingBloc.activeCollectionMode.isGpsDriven;
    for (var sensor in _sensors) {
      sensor.clearBuffersForNewRecording(
        clearLatestValues: clearLatestValues,
      );
    }
  }

  List<Sensor> get sensors => _sensors;

  Set<String> get _characteristicUuids => {
        for (final characteristic in bleBloc.availableCharacteristics.value)
          characteristic.uuidString,
      };

  List<Sensor> get _discoveredSensors => filterDiscoveredSensors(
        _sensors,
        _characteristicUuids,
      );

  List<Sensor> get availableSensors => filterAvailableSensors(
        _sensors,
        _characteristicUuids,
        bleBloc.characteristicStreams.hasLivePayload,
      );

  @override
  void dispose() {
    bleBloc.removeListener(_onConnectionChanged);
    bleBloc.characteristicStreams.livePayloadVersion
        .removeListener(notifyListeners);
    recordingBloc.isRecordingNotifier.removeListener(_recordingListener);
    geolocationBloc.setCollectInstantSensorData(null);

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
