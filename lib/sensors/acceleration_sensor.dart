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

class AccelerationSensor extends Sensor {
  static int get staticUiPriority => 60;

  @override
  int get uiPriority => staticUiPriority;

  static const String sensorCharacteristicUuid =
      'b944af10-f495-4560-968f-2f0d18cab522';

  AccelerationSensor(
    BleBloc bleBloc,
    GeolocationBloc geolocationBloc,
    RecordingBloc recordingBloc,
    IsarService isarService,
  ) : super(
          sensorCharacteristicUuid,
          'acceleration',
          const ['x', 'y', 'z'],
          bleBloc,
          geolocationBloc,
          recordingBloc,
          isarService,
        );

  @override
  List<double> aggregateData(List<List<double>> valueBuffer) {
    final sumValues = [0.0, 0.0, 0.0];
    final count = valueBuffer.length;

    for (final values in valueBuffer) {
      sumValues[0] += values[0];
      sumValues[1] += values[1];
      sumValues[2] += values[2];
    }

    return sumValues.map((value) => value / count).toList();
  }

  @override
  Widget buildWidget() {
    final safeInitial =
        latestValue.length >= 3 ? latestValue : const [0.0, 0.0, 0.0];

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
          icon: getSensorIcon(title),
          color: getSensorColor(title),
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
