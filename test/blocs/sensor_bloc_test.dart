import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sensebox_bike/blocs/sensor_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../mocks.dart';

class FakeBluetoothCharacteristic extends Fake implements BluetoothCharacteristic {
  @override
  final Guid uuid;
  FakeBluetoothCharacteristic({required String uuid}) : uuid = Guid(uuid);
}
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockBleBloc bleBloc;
  late MockGeolocationBloc geolocationBloc;
  final uuid = '2cdf2174-35be-fdc4-4ca2-6fd173f8b3a8'; // UUID for temperature sensor

  setUpAll(() {
    dotenv.testLoad(fileInput: 'MAPBOX_ACCESS_TOKEN=dummy_token\n');
    registerFallbackValue(MockSensor());
  });

  setUp(() {
    bleBloc = MockBleBloc();
    geolocationBloc = MockGeolocationBloc();

    // Mock notifiers and values as needed
    when(() => bleBloc.selectedDeviceNotifier).thenReturn(ValueNotifier(null));
    when(() => bleBloc.availableCharacteristics).thenReturn(ValueNotifier([]));
    when(() => bleBloc.characteristicStreamsVersion).thenReturn(ValueNotifier(0));
  });
  test('getSensorWidgets returns only sensors with available characteristics', () {
    final characteristic = FakeBluetoothCharacteristic(uuid: uuid);
    final notifier = ValueNotifier<List<BluetoothCharacteristic>>([characteristic]);
    
    when(() => bleBloc.availableCharacteristics).thenReturn(notifier);
    
    final bloc = SensorBloc(bleBloc, geolocationBloc);
    expect(bloc.getSensorWidgets(), isA<List<Widget>>());
    expect(bloc.getSensorWidgets().length, 1);
  });
}