import 'package:csv/csv.dart';
import 'package:sensebox_bike/models/sensor_data.dart';
import 'package:sensebox_bike/services/isar_service/geolocation_service.dart';
import 'package:sensebox_bike/services/isar_service/sensor_service.dart';
import 'package:sensebox_bike/services/storage/selected_sensebox_storage.dart';
import 'package:sensebox_bike/utils/isar_utils.dart';
import 'package:sensebox_bike/utils/sensor_utils.dart';

class TrackExportService {
  const TrackExportService();

  Future<String> buildOpenSenseMapCsvContent({
    required int trackId,
    required GeolocationService geolocationService,
    required SensorService sensorService,
    required SelectedSenseBoxStorage selectedSenseBoxStorage,
  }) async {
    final senseBox = await getSelectedSenseBoxOrThrow(selectedSenseBoxStorage);
    final geolocationDataList =
        await geolocationService.getGeolocationDataByTrackId(trackId);
    final sensorDataLines = <String>[];

    for (final geoData in geolocationDataList) {
      final data = await sensorService.getSensorDataByGeolocationId(geoData.id);
      sensorDataLines.addAll(
        data.map((sensor) {
          final sensorId = findSensorIdByData(sensor, senseBox.sensors ?? []);
          return formatOpenSenseMapCsvLine(sensorId, sensor.value, geoData);
        }),
      );
    }

    return sensorDataLines.join('\n');
  }

  Future<String> buildCsvContent({
    required int trackId,
    required GeolocationService geolocationService,
    required SensorService sensorService,
  }) async {
    final geolocationDataList =
        await geolocationService.getGeolocationDataByTrackId(trackId);
    final sensorDataByGeolocation = <int, List<SensorData>>{};

    for (final geoData in geolocationDataList) {
      final sensorData =
          await sensorService.getSensorDataByGeolocationId(geoData.id);
      sensorDataByGeolocation[geoData.id] = sensorData;
    }

    final sensorTitles = collectAndSortSensorTitles(sensorDataByGeolocation);
    final headers = buildCsvHeaders(sensorTitles);
    final csvData = <List<String>>[
      headers,
      ...buildCsvRows(
        geolocationDataList,
        sensorDataByGeolocation,
        sensorTitles,
      ),
    ];

    return const ListToCsvConverter().convert(csvData);
  }
}
