import 'package:fl_chart/fl_chart.dart';
import 'package:sensebox_bike/blocs/ble_bloc.dart';
import 'package:sensebox_bike/blocs/geolocation_bloc.dart';
import 'package:sensebox_bike/blocs/recording_bloc.dart';
import 'package:sensebox_bike/sensors/sensor.dart';
import 'package:sensebox_bike/services/isar_service.dart';
import 'package:flutter/material.dart';
import 'package:sensebox_bike/ui/widgets/sensor/sensor_card.dart';
import 'package:sensebox_bike/utils/sensor_utils.dart';
import 'package:sensebox_bike/l10n/app_localizations.dart';
import 'package:sensebox_bike/ui/widgets/common/sensor_conditional_rerender.dart';

class SurfaceClassificationSensor extends Sensor {
  double _latestAsphalt = 0.0;
  double _latestCompacted = 0.0;
  double _latestPaving = 0.0;
  double _latestSett = 0.0;
  double _latestStanding = 0.0;

  @override
  get uiPriority => 50;

  static const String sensorCharacteristicUuid =
      'b944af10-f495-4560-968f-2f0d18cab521';

  SurfaceClassificationSensor(
      BleBloc bleBloc, GeolocationBloc geolocationBloc,
      RecordingBloc recordingBloc, IsarService isarService)
      : super(
            sensorCharacteristicUuid,
            "surface_classification",
            ["asphalt", "compacted", "paving", "sett", "standing"],
            bleBloc,
            geolocationBloc,
            recordingBloc,
            isarService);

  @override
  void onDataReceived(List<double> data) {
    super.onDataReceived(data); // Call the parent class to handle buffering
    if (data.length >= 5) {
      _latestAsphalt = data[0];
      _latestCompacted = data[1];
      _latestPaving = data[2];
      _latestSett = data[3];
      _latestStanding = data[4];
    }
  }

  @override
  List<double> aggregateData(List<List<double>> valueBuffer) {
    List<double> sumValues = [0.0, 0.0, 0.0, 0.0, 0.0];
    int count = valueBuffer.length;

    for (var values in valueBuffer) {
      sumValues[0] += values[0];
      sumValues[1] += values[1];
      sumValues[2] += values[2];
      sumValues[3] += values[3];
      sumValues[4] += values[4];
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
          child: Text("${(value * 100).toStringAsFixed(0)}%",
              style: Theme.of(context).textTheme.labelSmall),
        ),
      ),
      const SizedBox(width: 8),
      Text(title)
    ]);
  }

  @override
  Widget buildWidget() {
    return SensorConditionalRerender(
      valueStream: valueStream
          .map((event) => [event[0], event[1], event[2], event[3], event[4]]),
      initialValue: [
        _latestAsphalt,
        _latestCompacted,
        _latestPaving,
        _latestSett,
        _latestStanding
      ],
      latestValue: [
        _latestAsphalt,
        _latestCompacted,
        _latestPaving,
        _latestSett,
        _latestStanding
      ],
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
        return SensorCard(
            title: AppLocalizations.of(context)!.sensorSurface,
            icon: getSensorIcon(title),
            color: getSensorColor(title),
            child: Column(
              children: [
                const SizedBox(
                  height: 2,
                ),
                for (int i = 0; i < value.length; i++)
                  _buildLegendEntry(
                      [
                        AppLocalizations.of(context)!.sensorSurfaceAsphaltShort,
                        AppLocalizations.of(context)!
                            .sensorSurfaceCompactedShort,
                        AppLocalizations.of(context)!.sensorSurfacePavingShort,
                        AppLocalizations.of(context)!.sensorSurfaceSettShort,
                        AppLocalizations.of(context)!.sensorSurfaceStanding
                      ][i],
                      [
                        Colors.blue,
                        Colors.green,
                        Colors.purpleAccent,
                        Colors.orange,
                        Colors.blueGrey
                      ][i],
                      value[i],
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
                                for (int i = 0; i < value.length; i++)
                                  BarChartRodStackItem(
                                    value.take(i).fold(0.0, (a, b) => a + b),
                                    value
                                        .take(i + 1)
                                        .fold(0.0, (a, b) => a + b),
                                    [
                                      Colors.blue,
                                      Colors.green,
                                      Colors.purpleAccent,
                                      Colors.orange,
                                      Colors.blueGrey
                                    ][i],
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
