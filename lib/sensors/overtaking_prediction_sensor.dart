import 'package:fl_chart/fl_chart.dart';
import 'package:sensebox_bike/blocs/ble_bloc.dart';
import 'package:sensebox_bike/blocs/geolocation_bloc.dart';
import 'package:sensebox_bike/sensors/sensor.dart';
import 'package:sensebox_bike/services/isar_service.dart';
import 'package:flutter/material.dart';
import 'package:sensebox_bike/ui/widgets/sensor/sensor_card.dart';
import 'package:sensebox_bike/utils/sensor_utils.dart';

class OvertakingPredictionSensor extends Sensor {
  double _latestCarPrediction = 0.0;
  double _latestBikePrediction = 0.0;

  @override
  get uiPriority => 40;

  static const String sensorCharacteristicUuid =
      'fc01c688-2c44-4965-ae18-373af9fed18d';

  OvertakingPredictionSensor(
      BleBloc bleBloc, GeolocationBloc geolocationBloc, IsarService isarService)
      : super(sensorCharacteristicUuid, "overtaking", [], bleBloc,
            geolocationBloc, isarService);

  @override
  void onDataReceived(List<double> data) {
    super.onDataReceived(data); // Call the parent class to handle buffering
    if (data.isNotEmpty) {
      _latestCarPrediction = data[0];
      _latestBikePrediction = data[1];
    }
  }

  @override
  List<double> aggregateData(List<List<double>> valueBuffer) {
    List<double> sumValues = [0.0, 0.0, 0.0];
    int count = valueBuffer.length;

    for (var values in valueBuffer) {
      sumValues[0] += values[0];
      sumValues[1] += values[1];
      sumValues[1] += 1.0 - values[0] - values[1];
    }

    // Calculate the mean for asphalt, compacted, paving, sett, and standing
    return sumValues.map((value) => value / count).toList();
  }

  Widget _buildLegendEntry(
      String title, Color color, double value, BuildContext context) {
    return Row(children: [
      Container(
        height: 16,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: color,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 0.5),
          child: Text(value.toStringAsFixed(1),
              style: Theme.of(context).textTheme.labelSmall),
        ),
      ),
      const SizedBox(width: 8),
      Text(title)
    ]);
  }

  @override
  Widget buildWidget() {
    return StreamBuilder<List<double>>(
      stream: valueStream
          .map((event) => [event[0], event[1], event[2], event[3], event[4]]),
      initialData: [
        _latestCarPrediction,
        _latestBikePrediction,
      ],
      builder: (context, snapshot) {
        List<double> displayValues = snapshot.data ??
            [
              _latestCarPrediction,
              _latestBikePrediction,
            ];
        return SensorCard(
            title: "Overtaking",
            icon: getSensorIcon(title),
            color: getSensorColor(title),
            child: Column(
              children: [
                const SizedBox(
                  height: 2,
                ),
                for (int i = 0; i < displayValues.length; i++)
                  _buildLegendEntry(
                      ["Car", "Bike"][i],
                      [
                        Colors.red,
                        Colors.blue,
                      ][i],
                      displayValues[i],
                      context),
                SizedBox(
                  width: double.infinity,
                  height: 18,
                  child: RotatedBox(
                    quarterTurns: 1,
                    child: BarChart(BarChartData(
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
                                for (int i = 0; i < displayValues.length; i++)
                                  BarChartRodStackItem(
                                    displayValues
                                        .take(i)
                                        .fold(0.0, (a, b) => a + b),
                                    displayValues
                                        .take(i + 1)
                                        .fold(0.0, (a, b) => a + b),
                                    [
                                      Colors.red,
                                      Colors.blue,
                                    ][i],
                                  ),
                                BarChartRodStackItem(
                                  displayValues
                                      .take(displayValues.length)
                                      .fold(0.0, (a, b) => a + b),
                                  1.0,
                                  Colors.white,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    )),
                  ),
                ),
              ],
            ));
      },
    );
  }
}
