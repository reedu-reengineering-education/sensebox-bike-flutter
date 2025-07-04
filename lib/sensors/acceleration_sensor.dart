import 'package:fl_chart/fl_chart.dart';
import 'package:sensebox_bike/blocs/ble_bloc.dart';
import 'package:sensebox_bike/blocs/geolocation_bloc.dart';
import 'package:sensebox_bike/sensors/sensor.dart';
import 'package:sensebox_bike/services/isar_service.dart';
import 'package:flutter/material.dart';
import 'package:sensebox_bike/ui/widgets/sensor/sensor_card.dart';
import 'package:sensebox_bike/utils/sensor_utils.dart';
import 'package:sensebox_bike/l10n/app_localizations.dart';

class AccelerationSensor extends Sensor {
  double _latestX = 0.0;
  double _latestY = 0.0;
  double _latestZ = 0.0;

  @override
  get uiPriority => 25;

  static const String sensorCharacteristicUuid =
      'b944af10-f495-4560-968f-2f0d18cab522';

  AccelerationSensor(
      BleBloc bleBloc, GeolocationBloc geolocationBloc, IsarService isarService)
      : super(sensorCharacteristicUuid, "acceleration", ["x", "y", "z"],
            bleBloc, geolocationBloc, isarService);

  @override
  void onDataReceived(List<double> data) {
    super.onDataReceived(data); // Call the parent class to handle buffering
    if (data.length >= 3) {
      _latestX = data[0];
      _latestY = data[1];
      _latestZ = data[2];
    }
  }

  @override
  List<double> aggregateData(List<List<double>> valueBuffer) {
    List<double> sumValues = [0.0, 0.0, 0.0];
    int count = valueBuffer.length;

    for (var values in valueBuffer) {
      sumValues[0] += values[0];
      sumValues[1] += values[1];
      sumValues[2] += values[2];
    }

    // Calculate the mean for x, y, and z
    return sumValues.map((value) => value / count).toList();
  }

  @override
  Widget buildWidget() {
    return StreamBuilder<List<double>>(
      stream: valueStream.map((event) => [event[0], event[1], event[2]]),
      initialData: [_latestX, _latestY, _latestZ],
      builder: (context, snapshot) {
        List<double> displayValues =
            snapshot.data ?? [_latestX, _latestY, _latestZ];

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
                            getTitlesWidget: (value, _) {
                              switch (value.toInt()) {
                                case 0:
                                  return const Text(
                                    'X',
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold),
                                  );
                                case 1:
                                  return const Text(
                                    'Y',
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold),
                                  );
                                case 2:
                                  return const Text(
                                    'Z',
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold),
                                  );
                              }
                              return const Text('');
                            },
                          ),
                        ),
                        leftTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                      ),
                      barGroups: [
                        BarChartGroupData(
                          x: 0,
                          barRods: [
                            BarChartRodData(
                              toY: displayValues[0],
                              backDrawRodData: BackgroundBarChartRodData(
                                show: true,
                                toY: 20,
                                color: Colors.grey.shade100,
                              ),
                            )
                          ],
                        ),
                        BarChartGroupData(
                          x: 1,
                          barRods: [
                            BarChartRodData(
                              toY: displayValues[1],
                              backDrawRodData: BackgroundBarChartRodData(
                                show: true,
                                toY: 20,
                                color: Colors.grey.shade100,
                              ),
                            )
                          ],
                        ),
                        BarChartGroupData(
                          x: 2,
                          barRods: [
                            BarChartRodData(
                              toY: displayValues[2],
                              backDrawRodData: BackgroundBarChartRodData(
                                show: true,
                                toY: 20,
                                color: Colors.grey.shade100,
                              ),
                            )
                          ],
                        ),
                      ]),
                  swapAnimationDuration:
                      const Duration(milliseconds: 250), // Optional
                  swapAnimationCurve: Curves.easeOut, // Optional
                )));
      },
    );
  }
}
