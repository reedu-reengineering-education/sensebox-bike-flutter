import 'package:fl_chart/fl_chart.dart';
import 'package:sensebox_bike/blocs/ble_bloc.dart';
import 'package:sensebox_bike/blocs/geolocation_bloc.dart';
import 'package:sensebox_bike/sensors/sensor.dart';
import 'package:sensebox_bike/services/isar_service.dart';
import 'package:flutter/material.dart';
import 'package:sensebox_bike/ui/widgets/sensor/sensor_card.dart';
import 'package:sensebox_bike/utils/sensor_utils.dart';
import 'package:sensebox_bike/l10n/app_localizations.dart';

class FinedustSensor extends Sensor {
  double _latestPM1 = 0.0;
  double _latestPM2_5 = 0.0;
  double _latestPM4 = 0.0;
  double _latestPM10 = 0.0;

  @override
  get uiPriority => 80;

  static const String sensorCharacteristicUuid =
      '7e14e070-84ea-489f-b45a-e1317364b979';

  FinedustSensor(
      BleBloc bleBloc, GeolocationBloc geolocationBloc, IsarService isarService)
      : super(
            sensorCharacteristicUuid,
            "finedust",
            ['pm1', 'pm2.5', 'pm4', 'pm10'],
            bleBloc,
            geolocationBloc,
            isarService);

  @override
  void onDataReceived(List<double> data) {
    super.onDataReceived(data); // Call the parent class to handle buffering
    if (data.length >= 4) {
      _latestPM1 = data[0];
      _latestPM2_5 = data[1];
      _latestPM4 = data[2];
      _latestPM10 = data[3];
    }
  }

  @override
  List<double> aggregateData(List<List<double>> valueBuffer) {
    List<double> sumValues = [0.0, 0.0, 0.0, 0.0];
    int count = valueBuffer.length;

    for (var values in valueBuffer) {
      sumValues[0] += values[0];
      sumValues[1] += values[1];
      sumValues[2] += values[2];
      sumValues[3] += values[3];
    }

    // Calculate the mean for pm1, pm2.5, pm4, and pm10
    return sumValues.map((value) => value / count).toList();
  }

  @override
  Widget buildWidget() {
    return StreamBuilder<List<double>>(
      stream:
          valueStream.map((event) => [event[0], event[1], event[2], event[3]]),
      initialData: [_latestPM1, _latestPM2_5, _latestPM4, _latestPM10],
      builder: (context, snapshot) {
        List<double> displayValues = snapshot.data ??
            [_latestPM1, _latestPM2_5, _latestPM4, _latestPM10];
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
                    gridData: const FlGridData(
                      show: false,
                    ),
                    titlesData: FlTitlesData(
                      show: true,
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 30,
                          getTitlesWidget: (value, _) {
                            switch (value.toInt()) {
                              case 0:
                                return const Text(
                                  'PM1',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold, fontSize: 8),
                                );
                              case 1:
                                return const Text(
                                  'PM2.5',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold, fontSize: 8),
                                );
                              case 2:
                                return const Text(
                                  'PM4',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold, fontSize: 8),
                                );
                              case 3:
                                return const Text(
                                  'PM10',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold, fontSize: 8),
                                );
                            }
                            return const Text('');
                          },
                        ),
                      ),
                      // leftTitles: const AxisTitles(
                      //   sideTitles: SideTitles(showTitles: false),
                      // ),
                      rightTitles: AxisTitles(
                        drawBelowEverything: true,
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 20,
                          getTitlesWidget: (value, meta) {
                            return Text(
                              value.toStringAsFixed(1),
                              textAlign: TextAlign.left,
                              style: const TextStyle(
                                fontSize: 8,
                              ),
                            );
                          },
                        ),
                      ),
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      leftTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                    ),
                    barGroups: [
                      BarChartGroupData(
                        x: 0,
                        barRods: [
                          BarChartRodData(
                            toY: displayValues[0],
                            color: Colors.blueGrey,
                          )
                        ],
                      ),
                      BarChartGroupData(
                        x: 1,
                        barRods: [
                          BarChartRodData(
                            toY: displayValues[1],
                            color: Colors.blueGrey,
                          )
                        ],
                      ),
                      BarChartGroupData(
                        x: 2,
                        barRods: [
                          BarChartRodData(
                            toY: displayValues[2],
                            color: Colors.blueGrey,
                          )
                        ],
                      ),
                      BarChartGroupData(
                        x: 3,
                        barRods: [
                          BarChartRodData(
                            toY: displayValues[3],
                            color: Colors.blueGrey,
                          )
                        ],
                      ),
                    ],
                  ),
                  swapAnimationDuration:
                      const Duration(milliseconds: 250), // Optional
                  swapAnimationCurve: Curves.easeOut, // Optional
                )));

        // child: Column(
        //   crossAxisAlignment: CrossAxisAlignment.baseline,
        //   textBaseline: TextBaseline.alphabetic,
        //   children: [
        //     Row(
        //       children: [
        //         const Text(
        //           'PM1',
        //           style: TextStyle(fontWeight: FontWeight.bold),
        //         ),
        //         Text(
        //           displayValues[0].toStringAsFixed(1),
        //         ),
        //       ],
        //     ),
        //     Row(
        //       children: [
        //         const Text(
        //           'PM2.5',
        //           style: TextStyle(fontWeight: FontWeight.bold),
        //         ),
        //         Text(
        //           displayValues[1].toStringAsFixed(1),
        //         ),
        //       ],
        //     ),
        //     Row(
        //       children: [
        //         const Text(
        //           'PM4',
        //           style: TextStyle(fontWeight: FontWeight.bold),
        //         ),
        //         Text(
        //           displayValues[2].toStringAsFixed(1),
        //         ),
        //       ],
        //     ),
        //     Row(
        //       children: [
        //         const Text(
        //           'PM10',
        //           style: TextStyle(fontWeight: FontWeight.bold),
        //         ),
        //         Text(
        //           displayValues[3].toStringAsFixed(1),
        //         ),
        //       ],
        //     ),
        //   ],
        // ));
      },
    );
  }
}
