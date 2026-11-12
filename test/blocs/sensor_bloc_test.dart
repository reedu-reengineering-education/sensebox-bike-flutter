import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sensebox_bike/ble/ble_characteristic_ref.dart';
import 'package:sensebox_bike/ble/ble_uuids.dart';
import 'package:sensebox_bike/blocs/sensor_bloc.dart';
import 'package:sensebox_bike/models/geolocation_data.dart';
import 'package:sensebox_bike/sensors/temperature_sensor.dart';
import '../ble/ble_test_helpers.dart';
import '../mocks.dart';

class _ConnectableBleBloc extends MockBleBloc {
  bool connected = false;

  @override
  bool get isConnected => connected;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _ConnectableBleBloc bleBloc;
  late MockGeolocationBloc geolocationBloc;
  late SensorBloc sensorBloc;

  final temperature = BleCharacteristicRef(
    deviceId: testDeviceId,
    serviceUuid: senseBoxServiceUuid,
    characteristicUuid: BleUuid(TemperatureSensor.sensorCharacteristicUuid),
  );

  void connect() {
    bleBloc.selectedDevice = testBleDevice;
    bleBloc.availableCharacteristics.value = [temperature];
    bleBloc.connected = true;
    bleBloc.notifyListeners();
  }

  int sensorStarts() =>
      verify(() => geolocationBloc.geolocationStream).callCount;

  setUp(() {
    bleBloc = _ConnectableBleBloc();
    geolocationBloc = MockGeolocationBloc();
    when(() => geolocationBloc.isarService).thenReturn(MockIsarService());
    when(() => geolocationBloc.isListening).thenReturn(true);
    when(() => geolocationBloc.geolocationStream)
        .thenAnswer((_) => const Stream<GeolocationData>.empty());
    sensorBloc = SensorBloc(bleBloc, geolocationBloc, MockRecordingBloc());
  });

  tearDown(() => sensorBloc.dispose());

  test('starts sensors once per connected session', () async {
    connect();
    bleBloc.notifyListeners();
    bleBloc.isBluetoothEnabledNotifier.value = true;
    bleBloc.notifyListeners();
    await pumpEventQueue();

    expect(sensorStarts(), 1);
  });

  test('stops sensors while reconnecting and restarts them once after',
      () async {
    connect();
    await pumpEventQueue();
    expect(sensorStarts(), 1);

    bleBloc.connected = false;
    bleBloc.notifyListeners();
    connect();
    await pumpEventQueue();

    expect(sensorStarts(), 1);
    verifyNever(() => geolocationBloc.stopListening());
  });

  test('stops location updates when the box is disconnected', () async {
    connect();
    await pumpEventQueue();

    bleBloc.connected = false;
    bleBloc.selectedDevice = null;
    bleBloc.notifyListeners();
    await pumpEventQueue();

    verify(() => geolocationBloc.stopListening()).called(1);
  });
}
