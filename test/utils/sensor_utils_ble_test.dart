import 'package:flutter_test/flutter_test.dart';
import 'package:sensebox_bike/sensors/temperature_sensor.dart';
import 'package:sensebox_bike/utils/sensor_utils.dart';

void main() {
  test('getSensorDisplayNameByUuid returns readable name for known uuid', () {
    expect(
      getSensorDisplayNameByUuid(TemperatureSensor.sensorCharacteristicUuid),
      'temperature',
    );
  });

  test('getSensorDisplayNameByUuid returns uuid for unknown sensor', () {
    const unknown = '00000000-0000-0000-0000-000000000000';
    expect(getSensorDisplayNameByUuid(unknown), unknown);
  });
}
