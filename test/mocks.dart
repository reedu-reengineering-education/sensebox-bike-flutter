import 'package:mocktail/mocktail.dart';
import 'package:sensebox_bike/blocs/opensensemap_bloc.dart';
import 'package:sensebox_bike/models/sensor_data.dart';
import 'package:sensebox_bike/services/isar_service.dart';
import 'package:sensebox_bike/services/isar_service/geolocation_service.dart';
import 'package:sensebox_bike/services/isar_service/isar_provider.dart';
import 'package:sensebox_bike/services/isar_service/sensor_service.dart';
import 'package:sensebox_bike/services/isar_service/track_service.dart';
import 'package:sensebox_bike/services/tag_service.dart';
import 'package:sensebox_bike/blocs/ble_bloc.dart';
import 'package:sensebox_bike/blocs/geolocation_bloc.dart';
import 'package:sensebox_bike/sensors/sensor.dart';

class MockBleBloc extends Mock implements BleBloc {}

class MockGeolocationBloc extends Mock implements GeolocationBloc {}

class MockSensor extends Mock implements Sensor {}
class MockTagService extends Mock implements TagService {}
class MockIsarService extends Mock implements IsarService {}
class MockTrackService extends Mock implements TrackService {}
class MockGeolocationService extends Mock implements GeolocationService {}
class MockSensorService extends Mock implements SensorService {}
class MockIsarProvider extends Mock implements IsarProvider {}
class MockOpenSenseMapBloc extends OpenSenseMapBloc {
  @override
  bool isAuthenticated = false;

  @override
  Future<void> logout() async {
    isAuthenticated = false;
  }
}

class FakeSensorData extends Fake implements SensorData {}
