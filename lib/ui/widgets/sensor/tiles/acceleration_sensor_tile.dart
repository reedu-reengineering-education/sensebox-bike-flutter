import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:sensebox_bike/l10n/app_localizations.dart';
import 'package:sensebox_bike/ui/widgets/common/sensor_conditional_rerender.dart';
import 'package:sensebox_bike/ui/widgets/sensor/sensor_card.dart';
import 'package:sensebox_bike/utils/sensor_utils.dart';

class AccelerationSensorTile extends StatelessWidget {
  const AccelerationSensorTile({
    required this.valueStream,
    required this.initialValue,
    super.key,
  });

  final Stream<List<double>> valueStream;
  final List<double> initialValue;

  @override
  Widget build(BuildContext context) {
    final safeInitial =
        initialValue.length >= 3 ? initialValue : const [0.0, 0.0, 0.0];

    return SensorConditionalRerender(
      valueStream: valueStream.map(
        (event) => [
          _safeAt(event, 0),
          _safeAt(event, 1),
          _safeAt(event, 2),
        ],
      ),
      initialValue: safeInitial,
      latestValue: safeInitial,
      decimalPlaces: 1,
      builder: (context, value) {
        return SensorCard(
          title: AppLocalizations.of(context)!.sensorAcceleration,
          icon: getSensorIcon('acceleration'),
          color: getSensorColor('acceleration'),
          child: AspectRatio(
            aspectRatio: 1.4,
            child: BarChart(
              BarChartData(
                borderData: FlBorderData(show: false),
                barTouchData: BarTouchData(enabled: false),
                gridData: const FlGridData(show: false),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      getTitlesWidget: (axisValue, _) {
                        switch (axisValue.toInt()) {
                          case 0:
                            return const Text('X',
                                style: TextStyle(fontWeight: FontWeight.bold));
                          case 1:
                            return const Text('Y',
                                style: TextStyle(fontWeight: FontWeight.bold));
                          case 2:
                            return const Text('Z',
                                style: TextStyle(fontWeight: FontWeight.bold));
                          default:
                            return const Text('');
                        }
                      },
                    ),
                  ),
                  leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                ),
                barGroups: [
                  _barGroup(0, value[0]),
                  _barGroup(1, value[1]),
                  _barGroup(2, value[2]),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  BarChartGroupData _barGroup(int x, double y) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: y,
          backDrawRodData: BackgroundBarChartRodData(
            show: true,
            toY: 20,
            color: Colors.grey.shade100,
          ),
        ),
      ],
    );
  }

  static double _safeAt(List<double> values, int index) {
    if (index < 0 || index >= values.length) return 0.0;
    return values[index];
  }
}
