import 'package:flutter/material.dart';
import 'package:sensebox_bike/feature_flags.dart';
import 'package:sensebox_bike/l10n/app_localizations.dart';
import 'package:sensebox_bike/sensors/sensor.dart';
import 'package:sensebox_bike/ui/widgets/common/sensor_conditional_rerender.dart';
import 'package:sensebox_bike/ui/widgets/sensor/sensor_card.dart';
import 'package:sensebox_bike/ui/widgets/sensor/sensor_value_display.dart';
import 'package:sensebox_bike/ui/widgets/sensor/tiles/acceleration_sensor_tile.dart';
import 'package:sensebox_bike/ui/widgets/sensor/tiles/finedust_sensor_tile.dart';
import 'package:sensebox_bike/ui/widgets/sensor/tiles/gps_sensor_tile.dart';
import 'package:sensebox_bike/ui/widgets/sensor/tiles/surface_classification_sensor_tile.dart';
import 'package:sensebox_bike/utils/sensor_utils.dart';

List<Widget> buildAvailableSensorWidgets({
  required List<Sensor> sensors,
  required Set<String> availableCharacteristicUuids,
}) {
  final availableSensors = sensors.where((sensor) {
    if (FeatureFlags.hideSurfaceAnomalySensor &&
        sensor.title == 'surface_anomaly') {
      return false;
    }
    return availableCharacteristicUuids.contains(sensor.characteristicUuid);
  }).toList();

  availableSensors.sort((a, b) => a.uiPriority.compareTo(b.uiPriority));
  return availableSensors.map<Widget>((sensor) => _SensorTile(sensor)).toList();
}

class _SensorTile extends StatelessWidget {
  const _SensorTile(this.sensor);

  final Sensor sensor;

  @override
  Widget build(BuildContext context) {
    final initialValue =
        sensor.latestValue.isEmpty ? const [0.0] : sensor.latestValue;

    if (sensor.title == 'acceleration') {
      return AccelerationSensorTile(
        valueStream: sensor.valueStream,
        initialValue: initialValue,
      );
    }

    if (sensor.title == 'finedust') {
      return FinedustSensorTile(
        valueStream: sensor.valueStream,
        initialValue: initialValue,
      );
    }

    if (sensor.title == 'surface_classification') {
      return SurfaceClassificationSensorTile(
        valueStream: sensor.valueStream,
        initialValue: initialValue,
      );
    }

    if (sensor.title == 'gps') {
      return GpsSensorTile(
        valueStream: sensor.valueStream,
        initialValue: initialValue,
      );
    }

    return SensorConditionalRerender(
      valueStream: sensor.valueStream,
      initialValue: initialValue,
      latestValue: initialValue,
      decimalPlaces: _decimalPlacesFor(sensor.title),
      builder: (context, value) {
        return SensorCard(
          title: _localizedTitle(context, sensor.title),
          icon: getSensorIcon(sensor.title),
          color: getSensorColor(sensor.title),
          child: _buildContent(context, sensor.title, value),
        );
      },
    );
  }

  Widget _buildContent(BuildContext context, String title, List<double> value) {
    switch (title) {
      case 'temperature':
        return SensorValueDisplay(
          value: _safe(value, 0).toStringAsFixed(1),
          unit: '°C',
        );
      case 'humidity':
        return SensorValueDisplay(
          value: _safe(value, 0).toStringAsFixed(1),
          unit: '%',
        );
      case 'distance':
      case 'distance_right':
        final currentValue = _safe(value, 0);
        return SensorValueDisplay(
          value: currentValue.toStringAsFixed(0),
          unit: 'cm',
          isValid: currentValue != 0.0,
        );
      case 'overtaking':
        return SensorValueDisplay(
          value: (_safe(value, 0) * 100).toStringAsFixed(0),
          unit: '%',
        );
      case 'surface_anomaly':
        return SensorValueDisplay(
          value: _safe(value, 0).toStringAsFixed(1),
          unit: '',
        );
      case 'gps':
        return SensorValueDisplay(
          value: _safe(value, 2).toStringAsFixed(2),
          unit: 'm/s',
        );
      case 'acceleration':
        return const SizedBox.shrink();
      case 'finedust':
        return const SizedBox.shrink();
      case 'surface_classification':
        return const SizedBox.shrink();
      default:
        return SensorValueDisplay(
          value: _safe(value, 0).toStringAsFixed(2),
          unit: '',
        );
    }
  }

  String _localizedTitle(BuildContext context, String title) {
    final l10n = AppLocalizations.of(context)!;
    switch (title) {
      case 'temperature':
        return l10n.sensorTemperature;
      case 'humidity':
        return l10n.sensorHumidity;
      case 'distance':
        return l10n.sensorDistance;
      case 'distance_right':
        return l10n.sensorDistanceRight;
      case 'surface_classification':
        return l10n.sensorSurface;
      case 'acceleration':
        return l10n.sensorAcceleration;
      case 'overtaking':
        return l10n.sensorOvertaking;
      case 'surface_anomaly':
        return l10n.sensorSurfaceAnomaly;
      case 'finedust':
        return l10n.sensorFinedust;
      case 'gps':
        return 'GPS';
      default:
        return title;
    }
  }

  int _decimalPlacesFor(String title) {
    switch (title) {
      case 'distance':
      case 'distance_right':
      case 'overtaking':
      case 'surface_classification':
        return 0;
      case 'temperature':
      case 'humidity':
      case 'surface_anomaly':
        return 1;
      default:
        return 2;
    }
  }

  double _safe(List<double> values, int index) {
    if (index < 0 || index >= values.length) {
      return 0.0;
    }
    return values[index];
  }
}
