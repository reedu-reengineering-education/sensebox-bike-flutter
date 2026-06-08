import 'package:sensebox_bike/feature_flags.dart';
import 'package:sensebox_bike/sensors/sensor.dart';

List<Sensor> filterAvailableSensors(
  Iterable<Sensor> sensors,
  Set<String> characteristicUuids,
) {
  return sensors.where((sensor) {
    if (FeatureFlags.hideSurfaceAnomalySensor &&
        sensor.title == 'surface_anomaly') {
      return false;
    }
    return characteristicUuids.contains(sensor.characteristicUuid);
  }).toList();
}
