import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:sensebox_bike/blocs/ble_bloc.dart';
import 'package:sensebox_bike/blocs/geolocation_bloc.dart';
import 'package:sensebox_bike/blocs/recording_bloc.dart';
import 'package:sensebox_bike/blocs/settings_bloc.dart';
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

@immutable
class SensorState {
  const SensorState({
    required this.isStartingListening,
    required this.sensorsCount,
  });

  final bool isStartingListening;
  final int sensorsCount;
}

class SensorBloc extends Cubit<SensorState> {
  final BleBloc bleBloc;
  final GeolocationBloc geolocationBloc;
  final RecordingBloc recordingBloc;
  final SettingsBloc settingsBloc;
  final List<Sensor> _sensors = [];
  StreamSubscription<BleState>? _bleSubscription;
  StreamSubscription<RecordingLifecycleEvent>? _recordingLifecycleSubscription;
  List<String> _lastCharacteristicUuids = [];
  int _lastCharacteristicStreamsVersion = 0;
  bool _wasBleDeviceConnected = false;
  bool _isStartingListening = false;

  SensorBloc(
      this.bleBloc, this.geolocationBloc, this.recordingBloc, this.settingsBloc)
      : super(const SensorState(
          isStartingListening: false,
          sensorsCount: 0,
        )) {
    _initializeSensors();

    final initialBleState = bleBloc.state;
    _lastCharacteristicUuids = initialBleState.availableCharacteristics
        .map((e) => e.uuid.toString())
        .toList();
    _lastCharacteristicStreamsVersion =
        initialBleState.characteristicStreamsVersion;
    _wasBleDeviceConnected =
        initialBleState.selectedDevice?.isConnected ?? false;

    _bleSubscription = bleBloc.stream.listen(_handleBleStateChange);

    _recordingLifecycleSubscription = recordingBloc.lifecycleEvents.listen(
      (event) {
        if (event == RecordingLifecycleEvent.started) {
          _onRecordingStart();
        } else if (event == RecordingLifecycleEvent.stopped) {
          _onRecordingStop();
          _flushAllSensorBuffers();
        }
      },
    );

    _emitState();
  }

  void _handleBleStateChange(BleState bleState) {
    final isBleDeviceConnected = bleState.selectedDevice?.isConnected ?? false;
    if (_wasBleDeviceConnected != isBleDeviceConnected) {
      _wasBleDeviceConnected = isBleDeviceConnected;
      if (isBleDeviceConnected) {
        _startListening();
        if (!geolocationBloc.isListening) {
          geolocationBloc.startListening();
        }
      } else {
        _stopListening();
        geolocationBloc.stopListening();
      }
      _emitState();
    }

    final currentUuids = bleState.availableCharacteristics
        .map((e) => e.uuid.toString())
        .toList();
    final streamsVersionChanged = _lastCharacteristicStreamsVersion !=
        bleState.characteristicStreamsVersion;
    final characteristicsChanged =
        !_listEqualsUnordered(_lastCharacteristicUuids, currentUuids);

    if (characteristicsChanged || streamsVersionChanged) {
      _lastCharacteristicUuids = List<String>.from(currentUuids);
      _lastCharacteristicStreamsVersion = bleState.characteristicStreamsVersion;
      _restartAllSensors();
    }
  }

  void _emitState() {
    if (!isClosed) {
      emit(SensorState(
        isStartingListening: _isStartingListening,
        sensorsCount: _sensors.length,
      ));
    }
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
    geolocationBloc.getCurrentLocationAndEmit().catchError((e) {});
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
    _sensors
        .add(GPSSensor(bleBloc, geolocationBloc, recordingBloc, isarService));
  }

  Future<void> _startListening() async {
    if (_isStartingListening) {
      return;
    }
    _isStartingListening = true;
    _emitState();
    try {
      for (var sensor in _sensors) {
        await sensor.startListening();
      }
    } finally {
      _isStartingListening = false;
      _emitState();
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

  Future<void> _flushAllSensorBuffers() async {
    await geolocationBloc.emitFinalGeolocation();
  }

  void _clearAllSensorBuffersForNewRecording() {
    for (var sensor in _sensors) {
      sensor.clearBuffersForNewRecording();
    }
  }

  List<Sensor> get sensors => _sensors;

  @override
  Future<void> close() async {
    await _bleSubscription?.cancel();
    await _recordingLifecycleSubscription?.cancel();

    _stopListening().catchError((e, stackTrace) {
      debugPrint('Error during sensor cleanup: $e');
      debugPrintStack(stackTrace: stackTrace);
    });

    for (final sensor in _sensors) {
      sensor.dispose();
    }

    return super.close();
  }

  void dispose() {
    unawaited(close());
  }
}
