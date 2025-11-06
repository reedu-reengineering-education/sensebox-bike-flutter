import 'package:flutter/material.dart';
import 'package:sensebox_bike/ui/widgets/sensor/sensor_card.dart';
import 'package:sensebox_bike/ui/widgets/common/sensor_conditional_rerender.dart';

/// A specialized sensor card that handles high-frequency sensor updates
/// with built-in performance optimization
class SensorDisplayCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final Stream<List<double>> valueStream;
  final List<double> initialValue;
  final Widget Function(BuildContext, List<double>) valueBuilder;
  final int decimalPlaces;
  final bool Function(List<double>, List<double>)? shouldRerender;

  const SensorDisplayCard({
    super.key,
    required this.title,
    required this.icon,
    required this.color,
    required this.valueStream,
    required this.initialValue,
    required this.valueBuilder,
    this.decimalPlaces = 1,
    this.shouldRerender,
  });

  @override
  Widget build(BuildContext context) {
    return SensorConditionalRerender(
      valueStream: valueStream,
      initialValue: initialValue,
      latestValue: initialValue,
      decimalPlaces: decimalPlaces,
      shouldRerender: shouldRerender,
      builder: (context, value) {
        return SensorCard(
          title: title,
          icon: icon,
          color: color,
          child: valueBuilder(context, value),
        );
      },
    );
  }
}
