import 'package:flutter/material.dart';

/// A reusable widget for displaying sensor values with units
/// Handles conditional styling based on validity
class SensorValueDisplay extends StatelessWidget {
  final String value;
  final String unit;
  final double fontSize;
  final bool isValid;
  final Color? invalidColor;

  const SensorValueDisplay({
    super.key,
    required this.value,
    required this.unit,
    this.fontSize = 48,
    this.isValid = true,
    this.invalidColor,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = isValid ? null : (invalidColor ?? Theme.of(context).colorScheme.primaryFixedDim);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: fontSize,
            color: textColor,
          ),
        ),
        Text(
          unit,
          style: TextStyle(
            color: textColor,
          ),
        ),
      ],
    );
  }
}
