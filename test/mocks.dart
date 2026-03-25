import 'package:flutter/material.dart';
import 'dart:async';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:sensebox_bike/blocs/configuration_bloc.dart';
import 'package:sensebox_bike/blocs/opensensemap_bloc.dart';
import 'package:sensebox_bike/blocs/track_bloc.dart';
import 'package:sensebox_bike/blocs/settings_bloc.dart';
import 'package:sensebox_bike/blocs/recording_bloc.dart';
import 'package:sensebox_bike/blocs/sensor_bloc.dart';
import 'package:sensebox_bike/models/sensor_data.dart';
import 'package:sensebox_bike/models/sensebox.dart';
import 'package:sensebox_bike/services/isar_service.dart';
import 'package:sensebox_bike/services/isar_service/geolocation_service.dart';
import 'package:sensebox_bike/services/isar_service/isar_provider.dart';
import 'package:sensebox_bike/services/isar_service/sensor_service.dart';
import 'package:sensebox_bike/services/isar_service/track_service.dart';
import 'package:sensebox_bike/services/remote_data_service.dart';
import 'package:sensebox_bike/services/error_service.dart';
import 'package:sensebox_bike/blocs/ble_bloc.dart';
import 'package:sensebox_bike/blocs/geolocation_bloc.dart';
import 'package:sensebox_bike/sensors/sensor.dart' as sensors;
import 'package:sensebox_bike/models/track_data.dart';
import 'package:sensebox_bike/models/geolocation_data.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockIsarProvider extends Mock implements IsarProvider {}

class MockRemoteDataService extends Mock implements RemoteDataService {}

class MockErrorService extends Mock implements ErrorService {}

class MockIsarService extends Mock implements IsarService {
  final MockTrackService mockTrackService = MockTrackService();

  @override
  TrackService get trackService => mockTrackService;
}

class MockTrackService extends Mock implements TrackService {}

class MockGeolocationService extends Mock implements GeolocationService {}

class MockSensorService extends Mock implements SensorService {}

class MockBleBloc extends Mock implements BleBloc {
  BleState _state = const BleState(
    isConnected: false,
    isBluetoothEnabled: false,
    isScanning: false,
    isConnecting: false,
    isReconnecting: false,
    selectedDevice: null,
    availableCharacteristics: <BluetoothCharacteristic>[],
    characteristicStreamsVersion: 0,
    connectionError: false,
  );
  final StreamController<BleState> _stateController =
      StreamController<BleState>.broadcast();

  @override
  List<BluetoothDevice> get devicesList => [];

  @override
  Stream<List<BluetoothDevice>> get devicesListStream => Stream.value([]);

  @override
  BleState get state => _state;

  @override
  Stream<BleState> get stream => _stateController.stream;

  @override
  bool get isConnected => _state.isConnected;

  @override
  BluetoothDevice? get selectedDevice => _state.selectedDevice;

  @override
  set selectedDevice(BluetoothDevice? device) {
    _state = BleState(
      isConnected: _state.isConnected,
      isBluetoothEnabled: _state.isBluetoothEnabled,
      isScanning: _state.isScanning,
      isConnecting: _state.isConnecting,
      isReconnecting: _state.isReconnecting,
      selectedDevice: device,
      availableCharacteristics: _state.availableCharacteristics,
      characteristicStreamsVersion: _state.characteristicStreamsVersion,
      connectionError: _state.connectionError,
    );
    _stateController.add(_state);
  }

  @override
  Future<void> connectToDevice(
      BluetoothDevice device, BuildContext context) async {}

  @override
  void disconnectDevice() {}

  @override
  Future<void> startScanning() async {}

  @override
  Future<void> scanForNewDevices() async {
    selectedDevice = null;
  }

  @override
  void resetConnectionError() {
    _state = BleState(
      isConnected: _state.isConnected,
      isBluetoothEnabled: _state.isBluetoothEnabled,
      isScanning: _state.isScanning,
      isConnecting: _state.isConnecting,
      isReconnecting: _state.isReconnecting,
      selectedDevice: _state.selectedDevice,
      availableCharacteristics: _state.availableCharacteristics,
      characteristicStreamsVersion: _state.characteristicStreamsVersion,
      connectionError: false,
    );
    _emitState();
  }

  @override
  void updateBluetoothStatus(bool isEnabled) {
    _state = BleState(
      isConnected: _state.isConnected,
      isBluetoothEnabled: isEnabled,
      isScanning: _state.isScanning,
      isConnecting: _state.isConnecting,
      isReconnecting: _state.isReconnecting,
      selectedDevice: _state.selectedDevice,
      availableCharacteristics: _state.availableCharacteristics,
      characteristicStreamsVersion: _state.characteristicStreamsVersion,
      connectionError: _state.connectionError,
    );
    _emitState();
  }

  @override
  Future<void> requestEnableBluetooth() async {}

  @override
  Stream<List<double>> getCharacteristicStream(String characteristicUuid) =>
      Stream.value([]);

  void _emitState() {
    _stateController.add(_state);
  }

  @override
  Future<void> close() async {
    await _stateController.close();
  }

  @override
  void dispose() {
    close();
  }

  ValueNotifier<bool> get permanentConnectionLossNotifier =>
      ValueNotifier<bool>(false);
}

class MockTrackBloc extends Mock with ChangeNotifier implements TrackBloc {}

class MockGeolocationBloc extends Mock implements GeolocationBloc {}

class MockOpenSenseMapBloc extends Mock
    with ChangeNotifier
    implements OpenSenseMapBloc {
  OpenSenseMapState _state = const OpenSenseMapState(
    isAuthenticated: false,
    isAuthenticating: false,
    selectedSenseBox: null,
    senseBoxes: <dynamic>[],
  );
  final StreamController<OpenSenseMapState> _stateController =
      StreamController<OpenSenseMapState>.broadcast();
  final StreamController<SenseBox?> _senseBoxController =
      StreamController<SenseBox?>.broadcast();

  @override
  bool isAuthenticated = false;

  @override
  bool get isAuthenticating => false;

  @override
  SenseBox? get selectedSenseBox => null;

  @override
  Stream<SenseBox?> get senseBoxStream => _senseBoxController.stream;

  @override
  List<dynamic> get senseBoxes => [];

  @override
  OpenSenseMapState get state => _state;

  @override
  Stream<OpenSenseMapState> get stream => _stateController.stream;

  @override
  Future<void> logout() async {
    isAuthenticated = false;
    _emitState();
  }

  @override
  Future<void> markAuthenticationFailed() async {
    isAuthenticated = false;
    _emitState();
  }

  @override
  Future<Map<String, dynamic>?> getUserData() async {
    if (!isAuthenticated) {
      return null;
    }
    return {
      'data': {
        'me': {
          'email': 'test@example.com',
          'name': 'Test User',
        }
      }
    };
  }

  @override
  Future<Map<String, dynamic>?> get userData => Future.value(null);

  @override
  Future<List> fetchSenseBoxes({int page = 0}) async => [];

  void _emitState() {
    _state = OpenSenseMapState(
      isAuthenticated: isAuthenticated,
      isAuthenticating: isAuthenticating,
      selectedSenseBox: selectedSenseBox,
      senseBoxes: senseBoxes,
    );
    _stateController.add(_state);
  }

  @override
  Future<void> close() async {
    await _senseBoxController.close();
    await _stateController.close();
  }

  void emitSenseBox(SenseBox? senseBox) {
    _senseBoxController.add(senseBox);
  }
}

class TestableMockOpenSenseMapBloc extends MockOpenSenseMapBloc {
  Future<List<dynamic>>? _fetchSenseBoxesFuture;
  Exception? _fetchSenseBoxesError;
  List<dynamic>? _fetchSenseBoxesResult;
  List<dynamic> _senseBoxes = [];

  void setFetchSenseBoxesFuture(Future<List<dynamic>> future) {
    _fetchSenseBoxesFuture = future;
  }

  void setFetchSenseBoxesError(Exception error) {
    _fetchSenseBoxesError = error;
  }

  void setFetchSenseBoxesResult(List<dynamic> result) {
    _fetchSenseBoxesResult = result;
  }

  void setSenseBoxes(List<dynamic> boxes) {
    _senseBoxes = boxes;
  }

  @override
  List<dynamic> get senseBoxes => _senseBoxes;

  @override
  Future<List> fetchSenseBoxes({int page = 0}) async {
    if (_fetchSenseBoxesError != null) {
      throw _fetchSenseBoxesError!;
    }
    if (_fetchSenseBoxesFuture != null) {
      return await _fetchSenseBoxesFuture!;
    }
    if (_fetchSenseBoxesResult != null) {
      _senseBoxes = _fetchSenseBoxesResult!;
      _emitState();
      return _fetchSenseBoxesResult!;
    }
    return [];
  }
}

class MockConfigurationBloc extends Mock implements ConfigurationBloc {}

class MockSettingsBloc extends Mock implements SettingsBloc {}

class MockRecordingBloc extends Mock implements RecordingBloc {
  bool _isRecording = false;
  final StreamController<bool> _isRecordingController =
      StreamController<bool>.broadcast();
  final StreamController<RecordingLifecycleEvent> _lifecycleController =
      StreamController<RecordingLifecycleEvent>.broadcast();

  MockRecordingBloc();

  @override
  bool get isRecording => _isRecording;

  void setRecording(bool value) {
    _isRecording = value;
    _isRecordingController.add(value);
    _lifecycleController.add(
      value ? RecordingLifecycleEvent.started : RecordingLifecycleEvent.stopped,
    );
  }

  @override
  Stream<bool> get isRecordingStream => _isRecordingController.stream;

  @override
  Stream<RecordingLifecycleEvent> get lifecycleEvents =>
      _lifecycleController.stream;

  Future<void> closeRecordingStream() async {
    await _isRecordingController.close();
    await _lifecycleController.close();
  }
}

class MockSensorBloc extends Mock implements SensorBloc {
  Map<String, List<SensorData>> get sensorData => {};
}

class MockGeolocator extends Mock
    with MockPlatformInterfaceMixin
    implements geo.GeolocatorPlatform {}

class MockSensor extends Mock implements sensors.Sensor {}

class FakeSensorData extends Fake implements SensorData {}

// Track creation helpers for tests
class TestTrackBuilder {
  static TrackData createTrack({
    int? id,
    int? isDirectUpload,
    int? uploaded,
    int? uploadAttempts,
    DateTime? lastUploadAttempt,
    List<GeolocationData>? geolocations,
  }) {
    final track = TrackData()
      ..id = id ?? 1
      ..isDirectUpload = isDirectUpload ?? 1
      ..uploaded = uploaded ?? 0
      ..uploadAttempts = uploadAttempts ?? 0
      ..lastUploadAttempt = lastUploadAttempt;

    if (geolocations != null) {
      track.geolocations.addAll(geolocations);
    }

    return track;
  }

  static GeolocationData createGeolocation({
    int? id,
    double? latitude,
    double? longitude,
    DateTime? timestamp,
    double? speed,
  }) {
    return GeolocationData()
      ..id = id ?? 1
      ..latitude = latitude ?? 52.5200
      ..longitude = longitude ?? 13.4050
      ..timestamp = timestamp ?? DateTime.now()
      ..speed = speed ?? 0.0;
  }
}
