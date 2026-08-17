import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:sensebox_bike/blocs/ble_bloc.dart';
import 'package:sensebox_bike/blocs/geolocation_bloc.dart';
import 'package:sensebox_bike/blocs/recording_bloc.dart';
import 'package:sensebox_bike/l10n/app_localizations.dart';
import 'package:sensebox_bike/sensors/sensor.dart';
import 'package:sensebox_bike/services/isar_service.dart';
import 'package:sensebox_bike/ui/widgets/common/sensor_conditional_rerender.dart';
import 'package:sensebox_bike/ui/widgets/sensor/sensor_card.dart';
import 'package:sensebox_bike/utils/sensor_utils.dart';

class FinedustSensor extends Sensor {
  static int get staticUiPriority => 80;

  @override
  int get uiPriority => staticUiPriority;

  @override
  Duration get lookbackWindow => const Duration(milliseconds: 1000);

  static const String sensorCharacteristicUuid =
      '7e14e070-84ea-489f-b45a-e1317364b979';

  FinedustSensor(
    BleBloc bleBloc,
    GeolocationBloc geolocationBloc,
    RecordingBloc recordingBloc,
    IsarService isarService,
  ) : super(
          sensorCharacteristicUuid,
          'finedust',
          const ['pm1', 'pm2.5', 'pm4', 'pm10'],
          bleBloc,
          geolocationBloc,
          recordingBloc,
          isarService,
        );

  @override
  List<double> aggregateData(List<List<double>> valueBuffer) {
    final sumValues = [0.0, 0.0, 0.0, 0.0];
    final count = valueBuffer.length;

    for (final values in valueBuffer) {
      sumValues[0] += values[0];
      sumValues[1] += values[1];
      sumValues[2] += values[2];
      sumValues[3] += values[3];
    }

    return sumValues.map((value) => value / count).toList();
  }

  @override
  Widget buildWidget() {
    final safeInitial =
        latestValue.length >= 4 ? latestValue : const [0.0, 0.0, 0.0, 0.0];

    return SensorConditionalRerender(
      valueStream: valueStream.map(
        (event) => [
          _safeAt(event, 0),
          _safeAt(event, 1),
          _safeAt(event, 2),
          _safeAt(event, 3),
        ],
      ),
      initialValue: safeInitial,
      latestValue: safeInitial,
      decimalPlaces: 2,
      shouldRerender: (old, next) {
        if (old.length != next.length) return true;
        for (int i = 0; i < old.length; i++) {
          if (old[i].toStringAsFixed(1) != next[i].toStringAsFixed(1)) {
            return true;
          }
        }
        return false;
      },
      builder: (context, value) {
        return SensorCard(
          title: AppLocalizations.of(context)!.sensorFinedust,
          icon: getSensorIcon(title),
          color: getSensorColor(title),
          child: AspectRatio(
            aspectRatio: 1.3,
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
                            return const Text('PM1',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 8));
                          case 1:
                            return const Text('PM2.5',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 8));
                          case 2:
                            return const Text('PM4',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 8));
                          case 3:
                            return const Text('PM10',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 8));
                          default:
                            return const Text('');
                        }
                      },
                    ),
                  ),
                  rightTitles: AxisTitles(
                    drawBelowEverything: true,
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 20,
                      getTitlesWidget: (axisValue, _) {
                        return Text(
                          axisValue.toStringAsFixed(1),
                          textAlign: TextAlign.left,
                          style: const TextStyle(fontSize: 8),
                        );
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                ),
                barGroups: [
                  _barGroup(0, value[0]),
                  _barGroup(1, value[1]),
                  _barGroup(2, value[2]),
                  _barGroup(3, value[3]),
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
      barRods: [BarChartRodData(toY: y, color: Colors.blueGrey)],
    );
  }

  static double _safeAt(List<double> values, int index) {
    if (index < 0 || index >= values.length) return 0.0;
    return values[index];
  }
}
