import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:sensebox_bike/l10n/app_localizations.dart';
import 'package:sensebox_bike/ui/widgets/common/sensor_conditional_rerender.dart';
import 'package:sensebox_bike/ui/widgets/sensor/sensor_card.dart';
import 'package:sensebox_bike/utils/sensor_utils.dart';

class SurfaceClassificationSensorTile extends StatelessWidget {
  const SurfaceClassificationSensorTile({
    required this.valueStream,
    required this.initialValue,
    super.key,
  });

  final Stream<List<double>> valueStream;
  final List<double> initialValue;

  @override
  Widget build(BuildContext context) {
    final safeInitial = initialValue.length >= 5
        ? initialValue
        : const [0.0, 0.0, 0.0, 0.0, 0.0];

    return SensorConditionalRerender(
      valueStream: valueStream.map(
        (event) => [
          _safeAt(event, 0),
          _safeAt(event, 1),
          _safeAt(event, 2),
          _safeAt(event, 3),
          _safeAt(event, 4),
        ],
      ),
      initialValue: safeInitial,
      latestValue: safeInitial,
      decimalPlaces: 0,
      shouldRerender: (old, next) {
        if (old.length != next.length) return true;
        for (int i = 0; i < old.length; i++) {
          if (old[i].round() != next[i].round()) {
            return true;
          }
        }
        return false;
      },
      builder: (context, value) {
        final labels = [
          AppLocalizations.of(context)!.sensorSurfaceAsphaltShort,
          AppLocalizations.of(context)!.sensorSurfaceCompactedShort,
          AppLocalizations.of(context)!.sensorSurfacePavingShort,
          AppLocalizations.of(context)!.sensorSurfaceSettShort,
          AppLocalizations.of(context)!.sensorSurfaceStanding,
        ];

        final colors = [
          Colors.blue,
          Colors.green,
          Colors.purpleAccent,
          Colors.orange,
          Colors.blueGrey,
        ];

        return SensorCard(
          title: AppLocalizations.of(context)!.sensorSurface,
          icon: getSensorIcon('surface_classification'),
          color: getSensorColor('surface_classification'),
          child: Column(
            children: [
              const SizedBox(height: 2),
              for (int i = 0; i < value.length; i++)
                _legendEntry(
                  context: context,
                  title: labels[i],
                  color: colors[i],
                  value: value[i],
                ),
              SizedBox(
                width: double.infinity,
                height: 18,
                child: RotatedBox(
                  quarterTurns: 1,
                  child: BarChart(
                    BarChartData(
                      borderData: FlBorderData(show: false),
                      barTouchData: BarTouchData(enabled: false),
                      gridData: const FlGridData(show: false),
                      titlesData: const FlTitlesData(show: false),
                      barGroups: [
                        BarChartGroupData(
                          x: 0,
                          barRods: [
                            BarChartRodData(
                              toY: 1,
                              rodStackItems: [
                                for (int i = 0; i < value.length; i++)
                                  BarChartRodStackItem(
                                    value.take(i).fold(0.0, (a, b) => a + b),
                                    value
                                        .take(i + 1)
                                        .fold(0.0, (a, b) => a + b),
                                    colors[i],
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _legendEntry({
    required BuildContext context,
    required String title,
    required Color color,
    required double value,
  }) {
    return Row(
      children: [
        Container(
          height: 16,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: color,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0.5),
            child: Text(
              '${(value * 100).toStringAsFixed(0)}%',
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(title),
      ],
    );
  }

  static double _safeAt(List<double> values, int index) {
    if (index < 0 || index >= values.length) return 0.0;
    return values[index];
  }
}
