import 'package:flutter/material.dart';
import 'package:sensebox_bike/models/geolocation_data.dart';
import 'package:sensebox_bike/utils/track_utils.dart';

class SensorGradientWidget extends StatelessWidget {
  final String sensorType;
  final List<GeolocationData> geolocations;
  final double height;
  final EdgeInsets padding;

  const SensorGradientWidget({
    super.key,
    required this.sensorType,
    required this.geolocations,
    this.height = 12.0,
    this.padding = const EdgeInsets.symmetric(horizontal: 12),
  });

  @override
  Widget build(BuildContext context) {
    double minValue = getMinSensorValue(geolocations, sensorType);
    double maxValue = getMaxSensorValue(geolocations, sensorType);
    final unit = getSensorUnit(sensorType);

    // Convert overtaking manoeuvre and surface classification values to percentages
    if (sensorType == 'overtaking' || 
        sensorType.startsWith('surface_classification_') ||
        sensorType == 'surface_classification') {
      minValue *= 100;
      maxValue *= 100;
    }

    return Padding(
      padding: padding,
      child: Column(
        children: [
          Container(
            height: height,
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.all(Radius.circular(20)),
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: getSensorGradientColors(sensorType),
                tileMode: TileMode.mirror,
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${minValue.toStringAsFixed(1)}${unit ?? ''}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const Spacer(),
              Text(
                '${maxValue.toStringAsFixed(1)}${unit ?? ''}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Helper function to get sensor unit based on sensor type
String? getSensorUnit(String sensorType) {
  switch (sensorType) {
    case 'temperature':
      return '°C';
    case 'humidity':
      return '%';
    case 'distance':
      return 'cm';
    case 'overtaking':
      return '%';
    case 'surface_classification_asphalt':
    case 'surface_classification_sett':
    case 'surface_classification_compacted':
    case 'surface_classification_paving':
    case 'surface_classification_standing':
      return '%';
    case 'surface_anomaly':
      return 'Δ';
    case 'acceleration_x':
    case 'acceleration_y':
    case 'acceleration_z':
      return 'm/s²';
    case 'finedust_pm1':
    case 'finedust_pm2.5':
    case 'finedust_pm4':
    case 'finedust_pm10':
      return 'µg/m³';
    case 'gps_speed':
      return 'm/s';
    case 'gps_latitude':
    case 'gps_longitude':
      return '°';
    default:
      return null;
  }
}

/// Helper function to get gradient colors based on sensor type
List<Color> getSensorGradientColors(String sensorType) {
  if (sensorType == 'distance') {
    // Distance sensor: red (close) -> orange (moderate) -> green (far)
    return [Colors.red, Colors.orange, Colors.green];
  } else {
    // Other sensors: green (low) -> orange (medium) -> red (high)
    return [Colors.green, Colors.orange, Colors.red];
  }
}

/// Helper function to get min and max sensor values with units
SensorValueRange getSensorValueRange(String sensorType, List<GeolocationData> geolocations) {
  double minValue = getMinSensorValue(geolocations, sensorType);
  double maxValue = getMaxSensorValue(geolocations, sensorType);
  final unit = getSensorUnit(sensorType);

  // Convert overtaking manoeuvre and surface classification values to percentages
  if (sensorType == 'overtaking' || 
      sensorType.startsWith('surface_classification_') ||
      sensorType == 'surface_classification') {
    minValue *= 100;
    maxValue *= 100;
  }

  return SensorValueRange(
    minValue: minValue,
    maxValue: maxValue,
    unit: unit,
  );
}

/// Data class to hold sensor value range information
class SensorValueRange {
  final double minValue;
  final double maxValue;
  final String? unit;

  const SensorValueRange({
    required this.minValue,
    required this.maxValue,
    this.unit,
  });

  String get formattedMinValue => '${minValue.toStringAsFixed(1)} ${unit ?? ''}';
  String get formattedMaxValue => '${maxValue.toStringAsFixed(1)} ${unit ?? ''}';
}
