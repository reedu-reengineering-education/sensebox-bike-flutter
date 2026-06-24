import 'package:sensebox_bike/feature_flags.dart';
import 'package:sensebox_bike/sensors/sensor.dart';

List<Sensor> filterDiscoveredSensors(
  Iterable<Sensor> sensors,
  Set<String> characteristicUuids,
) {
  return filterAvailableSensors(
    sensors,
    characteristicUuids,
    (_) => true,
  );
}

List<Sensor> filterAvailableSensors(
  Iterable<Sensor> sensors,
  Set<String> characteristicUuids,
  bool Function(String uuid) hasLivePayload,
) {
  return sensors.where((sensor) {
    if (FeatureFlags.hideSurfaceAnomalySensor &&
        sensor.title == 'surface_anomaly') {
      return false;
    }
    return characteristicUuids.contains(sensor.characteristicUuid) &&
        hasLivePayload(sensor.characteristicUuid);
  }).toList();
}

List<Sensor> sortSensorsByUiPriority(Iterable<Sensor> sensors) {
  final sorted = List<Sensor>.from(sensors);
  sorted.sort((a, b) => a.uiPriority.compareTo(b.uiPriority));
  return sorted;
}
