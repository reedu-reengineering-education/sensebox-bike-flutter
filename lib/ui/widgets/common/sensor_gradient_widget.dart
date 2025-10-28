import 'package:flutter/material.dart';
import 'package:sensebox_bike/models/geolocation_data.dart';
import 'package:sensebox_bike/models/sensebox.dart';
import 'package:sensebox_bike/utils/track_utils.dart';
import 'package:sensebox_bike/utils/sensor_utils.dart';

class SensorGradientWidget extends StatelessWidget {
  final String sensorType;
  final List<GeolocationData> geolocations;
  final SenseBox? senseBox;
  final double height;
  final EdgeInsets padding;

  const SensorGradientWidget({
    super.key,
    required this.sensorType,
    required this.geolocations,
    this.senseBox,
    this.height = 12.0,
    this.padding = const EdgeInsets.symmetric(horizontal: 12),
  });

  @override
  Widget build(BuildContext context) {
    double minValue = getMinSensorValue(geolocations, sensorType);
    double maxValue = getMaxSensorValue(geolocations, sensorType);
    final unit = _getSensorUnitFromSenseBox(sensorType, senseBox);

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

/// Helper function to get sensor unit from SenseBox data with fallback to constants
String? _getSensorUnitFromSenseBox(String sensorType, SenseBox? senseBox) {
  // Try to get unit from SenseBox API data first
  if (senseBox?.sensors != null) {
    // Find matching sensor using existing utility
    final sensorTitle = getTitleFromSensorKey(sensorType, null);
    if (sensorTitle != null) {
      for (final sensor in senseBox!.sensors!) {
        if (sensor.title == sensorTitle) {
          return sensor.unit;
        }
      }
    }
  }
  
  // Fallback to constants
  return '';
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
SensorValueRange getSensorValueRange(String sensorType, List<GeolocationData> geolocations, {SenseBox? senseBox}) {
  double minValue = getMinSensorValue(geolocations, sensorType);
  double maxValue = getMaxSensorValue(geolocations, sensorType);
  final unit = _getSensorUnitFromSenseBox(sensorType, senseBox);

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
