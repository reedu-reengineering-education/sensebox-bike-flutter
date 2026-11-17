import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sensebox_bike/ble/ble_characteristic_ref.dart';
import 'package:sensebox_bike/ble/ble_device.dart';
import 'package:sensebox_bike/blocs/configuration_bloc.dart';
import 'package:sensebox_bike/blocs/opensensemap_bloc.dart';
import 'package:sensebox_bike/blocs/track_bloc.dart';
import 'package:sensebox_bike/blocs/settings_bloc.dart';
import 'package:sensebox_bike/blocs/recording_bloc.dart';
import 'package:sensebox_bike/models/sensor_data.dart';
import 'package:sensebox_bike/models/sensebox.dart';
import 'package:sensebox_bike/services/isar_service.dart';
import 'package:sensebox_bike/services/isar_service/geolocation_service.dart';
import 'package:sensebox_bike/services/isar_service/sensor_service.dart';
import 'package:sensebox_bike/services/isar_service/track_service.dart';
import 'package:sensebox_bike/ble/ble_characteristic_streams.dart';
import 'package:sensebox_bike/blocs/ble_bloc.dart';
import 'ble/mock_ble_platform.dart';
import 'package:sensebox_bike/blocs/geolocation_bloc.dart';
import 'package:sensebox_bike/sensors/sensor.dart' as sensors;
import 'package:sensebox_bike/models/track_data.dart';
import 'package:sensebox_bike/models/geolocation_data.dart';
import 'package:sensebox_bike/models/data_collection_mode.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockIsarService extends Mock implements IsarService {
  final MockTrackService mockTrackService = MockTrackService();

  @override
  TrackService get trackService => mockTrackService;
}

class MockTrackService extends Mock implements TrackService {}

class MockGeolocationService extends Mock implements GeolocationService {}

class MockSensorService extends Mock implements SensorService {}

class _TestBleCharacteristicStreams extends BleCharacteristicStreams {
  _TestBleCharacteristicStreams() : super(platform: MockBlePlatform());

  final Map<String, StreamController<List<double>>> _testStreams = {};

  @override
  Stream<List<double>> characteristicStream(String characteristicUuid) {
    return _testStreams
        .putIfAbsent(
          characteristicUuid,
          () => StreamController<List<double>>.broadcast(),
        )
        .stream;
  }

  @override
  Future<void> clear({
    Iterable<BleCharacteristicRef> characteristics = const [],
  }) async {
    await super.clear();
    final controllers = _testStreams.values.toList();
    _testStreams.clear();
    for (final controller in controllers) {
      await controller.close();
    }
  }
}

class MockBleBloc extends Mock with ChangeNotifier implements BleBloc {
  @override
  final ValueNotifier<bool> isBluetoothEnabledNotifier = ValueNotifier(false);

  @override
  final ValueNotifier<bool> isScanningNotifier = ValueNotifier(false);

  @override
  final ValueNotifier<bool> isConnectingNotifier = ValueNotifier(false);

  @override
  final ValueNotifier<bool> isReconnectingNotifier = ValueNotifier(false);

  @override
  final ValueNotifier<BleDevice?> selectedDeviceNotifier = ValueNotifier(null);

  @override
  final ValueNotifier<List<BleCharacteristicRef>> availableCharacteristics =
      ValueNotifier([]);

  @override
  final ValueNotifier<int> characteristicStreamsVersion = ValueNotifier(0);

  @override
  final ValueNotifier<bool> connectionErrorNotifier = ValueNotifier(false);

  @override
  bool get isConnected => false;

  @override
  List<BleDevice> get devicesList => [];

  @override
  Stream<List<BleDevice>> get devicesListStream => Stream.value([]);

  @override
  BleDevice? get selectedDevice => selectedDeviceNotifier.value;

  @override
  set selectedDevice(BleDevice? device) {
    selectedDeviceNotifier.value = device;
  }

  @override
  Future<void> connectToDevice(BleDevice device) async {}

  @override
  Future<void> disconnectDevice({
    BleDevice? device,
    BleDisconnectReason reason = BleDisconnectReason.userRequested,
  }) async {
    if (reason != BleDisconnectReason.retryRelease) {
      selectedDevice = null;
    }
  }

  @override
  Future<void> startScanning() async {}

  @override
  Future<void> scanForNewDevices() async {
    await disconnectDevice(reason: BleDisconnectReason.userRequested);
    await startScanning();
  }

  @override
  void resetConnectionError() {
    connectionErrorNotifier.value = false;
  }

  @override
  void updateBluetoothStatus(bool isEnabled) {
    isBluetoothEnabledNotifier.value = isEnabled;
    notifyListeners();
  }

  @override
  Future<void> requestEnableBluetooth() async {}

  @override
  final BleCharacteristicStreams characteristicStreams =
      _TestBleCharacteristicStreams();
}

class MockTrackBloc extends Mock with ChangeNotifier implements TrackBloc {}

class MockGeolocationBloc extends Mock implements GeolocationBloc {}

class MockOpenSenseMapBloc extends Mock
    with ChangeNotifier
    implements OpenSenseMapBloc {
  @override
  bool isAuthenticated = false;

  @override
  bool get isAuthenticating => false;

  @override
  SenseBox? get selectedSenseBox => null;

  @override
  Stream<SenseBox?> get senseBoxStream => Stream.value(null);

  @override
  List<dynamic> get senseBoxes => [];

  @override
  Future<void> logout() async {
    isAuthenticated = false;
  }

  @override
  Future<Map<String, dynamic>?> get userData => Future.value(null);

  @override
  Future<List> fetchSenseBoxes({int page = 0}) async => [];
}

class MockConfigurationBloc extends Mock implements ConfigurationBloc {}

class MockSettingsBloc extends Mock
    with ChangeNotifier
    implements SettingsBloc {}

class MockRecordingBloc extends Mock implements RecordingBloc {
  @override
  final ValueNotifier<bool> isRecordingNotifier = ValueNotifier(false);

  @override
  final ValueNotifier<DataCollectionMode> activeCollectionModeNotifier =
      ValueNotifier(DataCollectionMode.gpsDriven);

  @override
  int collectionIntervalSeconds = defaultCollectionIntervalSeconds;

  @override
  bool get isRecording => isRecordingNotifier.value;

  void setRecording(bool value) => isRecordingNotifier.value = value;

  @override
  DataCollectionMode get activeCollectionMode =>
      activeCollectionModeNotifier.value;

  void setActiveCollectionMode(DataCollectionMode mode) =>
      activeCollectionModeNotifier.value = mode;
}

class MockGeolocator extends Mock
    with MockPlatformInterfaceMixin
    implements geo.GeolocatorPlatform {}

class MockSensor extends Mock implements sensors.Sensor {}

class FakeSensorData extends Fake implements SensorData {}

class TestTrackBuilder {
  static TrackData createTrack({
    int id = 1,
    int isDirectUpload = 1,
    int uploaded = 0,
    int uploadAttempts = 0,
    DateTime? lastUploadAttempt,
    String? dataCollectionMode,
    int? collectionIntervalSeconds,
    List<GeolocationData> geolocations = const [],
  }) =>
      TrackData()
        ..id = id
        ..isDirectUpload = isDirectUpload
        ..uploaded = uploaded
        ..uploadAttempts = uploadAttempts
        ..lastUploadAttempt = lastUploadAttempt
        ..dataCollectionMode = dataCollectionMode
        ..collectionIntervalSeconds = collectionIntervalSeconds
        ..geolocations.addAll(geolocations);

  static GeolocationData createGeolocation({
    int id = 1,
    double latitude = 52.5200,
    double longitude = 13.4050,
    DateTime? timestamp,
    double speed = 0.0,
  }) =>
      GeolocationData()
        ..id = id
        ..latitude = latitude
        ..longitude = longitude
        ..timestamp = timestamp ?? DateTime.now()
        ..speed = speed;
}
