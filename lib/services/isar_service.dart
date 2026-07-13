// File: lib/services/isar_service.dart
import 'dart:io';

import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sensebox_bike/constants.dart';
import 'package:sensebox_bike/models/geolocation_data.dart';
import 'package:sensebox_bike/models/sensor_data.dart';
import 'package:sensebox_bike/models/track_data.dart';
import 'package:sensebox_bike/services/custom_exceptions.dart';
import 'package:sensebox_bike/services/isar_service/geolocation_service.dart';
import 'package:sensebox_bike/services/isar_service/sensor_service.dart';
import 'package:sensebox_bike/services/isar_service/track_service.dart';
import 'package:sensebox_bike/utils/isar_utils.dart';
import 'package:sensebox_bike/utils/sensor_utils.dart';
import 'package:sensebox_bike/services/isar_service/isar_provider.dart';

class IsarService {
  final IsarProvider isarProvider;
  final TrackService trackService;
  final GeolocationService geolocationService;
  final SensorService sensorService;

  IsarService({required this.isarProvider})
      : trackService = TrackService(isarProvider: isarProvider),
        geolocationService = GeolocationService(isarProvider: isarProvider),
        sensorService = SensorService(isarProvider: isarProvider);

  Future<TrackData> _getTrackOrThrow(int trackId) async {
    final track = await trackService.getTrackById(trackId);
    if (track == null) throw Exception("Track not found");
    return track;
  }

  // Additional high-level methods that require coordination between services
  Future<String> exportTrackToCsvInOpenSenseMapFormat(
    int trackId, {
    void Function(int totalChunks)? onChunkPlan,
    void Function(int completedChunks, int totalChunks)? onChunkProgress,
  }) async {
    final track = await _getTrackOrThrow(trackId);
    final senseBox = await getSelectedSenseBoxOrThrow();
    final geolocationDataList =
        await geolocationService.getGeolocationDataByTrackId(trackId);
    final file = await _createCsvFile(
      track,
      geolocationDataList,
      formatSuffix: 'osem',
    );
    final sensorDataByGeolocation = <int, List<SensorData>>{};

    // Load sensor data once so chunk estimation and writing use identical data.
    for (final geoData in geolocationDataList) {
      sensorDataByGeolocation[geoData.id] =
          await sensorService.getSensorDataByGeolocationId(geoData.id);
    }

    final totalChunks = _estimateOpenSenseMapExportChunks(sensorDataByGeolocation);
    var completedChunks = 0;
    onChunkPlan?.call(totalChunks);

    return _writeCsvFile(file, (sink) async {
      final lineBuffer = <String>[];
      for (final geoData in geolocationDataList) {
        final data = sensorDataByGeolocation[geoData.id] ?? const <SensorData>[];
        lineBuffer.addAll(
          data.map((sensor) {
            final sensorId = findSensorIdByData(sensor, senseBox.sensors ?? []);
            return formatOpenSenseMapCsvLine(sensorId, sensor.value, geoData);
          }),
        );

        final flushedChunks = _flushLineBufferIfNeeded(sink, lineBuffer);
        if (flushedChunks > 0) {
          completedChunks += flushedChunks;
          onChunkProgress?.call(completedChunks, totalChunks);
          // Yield so UI can paint progress updates between flushed chunks.
          await Future<void>.delayed(Duration.zero);
        }
      }

      final finalFlushedChunks = _flushLineBuffer(sink, lineBuffer);
      if (finalFlushedChunks > 0) {
        completedChunks += finalFlushedChunks;
        onChunkProgress?.call(completedChunks, totalChunks);
        await Future<void>.delayed(Duration.zero);
      }
    });
  }

  Future<String> exportTrackToCsv(
    int trackId, {
    void Function(int totalChunks)? onChunkPlan,
    void Function(int completedChunks, int totalChunks)? onChunkProgress,
  }) async {
    final track = await _getTrackOrThrow(trackId);
    final geolocationDataList =
        await geolocationService.getGeolocationDataByTrackId(trackId);
    final file = await _createCsvFile(
      track,
      geolocationDataList,
      formatSuffix: 'standard',
    );
    const converter = ListToCsvConverter();
    final sensorDataByGeolocation = <int, List<SensorData>>{};

    // Load sensor data once and reuse for both header discovery and row writing.
    for (final geoData in geolocationDataList) {
      sensorDataByGeolocation[geoData.id] =
          await sensorService.getSensorDataByGeolocationId(geoData.id);
    }

    final sensorTitles = collectAndSortSensorTitles(sensorDataByGeolocation);
    final totalChunks = _estimateRegularExportChunks(
      geolocationDataList,
      sensorDataByGeolocation,
    );
    var completedChunks = 0;
    onChunkPlan?.call(totalChunks);

    return _writeCsvFile(file, (sink) async {
      final headers = buildCsvHeaders(sensorTitles);
      sink.writeln(converter.convert([headers]));

      final rowBuffer = <List<String>>[];
      for (final geoData in geolocationDataList) {
        final rows = buildCsvRows(
          [geoData],
          {geoData.id: sensorDataByGeolocation[geoData.id] ?? []},
          sensorTitles,
        );

        if (rows.isNotEmpty) {
          rowBuffer.addAll(rows);
        }

        final flushedChunks = _flushRowBufferIfNeeded(sink, converter, rowBuffer);
        if (flushedChunks > 0) {
          completedChunks += flushedChunks;
          onChunkProgress?.call(completedChunks, totalChunks);
          // Yield so UI can paint progress updates between flushed chunks.
          await Future<void>.delayed(Duration.zero);
        }
      }

      final finalFlushedChunks = _flushRowBuffer(sink, converter, rowBuffer);
      if (finalFlushedChunks > 0) {
        completedChunks += finalFlushedChunks;
        onChunkProgress?.call(completedChunks, totalChunks);
        await Future<void>.delayed(Duration.zero);
      }
    });
  }

  Future<File> _createCsvFile(
    TrackData track,
    List<GeolocationData> geolocationDataList,
    {required String formatSuffix}
  ) async {
    final directory = await _resolveExportDirectory();

    if (geolocationDataList.isEmpty) {
      throw TrackHasNoGeolocationsException(track.id);
    }

    String formattedTimestamp = DateFormat('yyyy-MM-dd_HH-mm')
        .format(geolocationDataList.first.timestamp);

    final baseName = 'senseBox_bike_${formattedTimestamp}_$formatSuffix';
    return _createUniqueCsvFile(directory.path, baseName);
  }

  Future<Directory> _resolveExportDirectory() async {
    if (Platform.isAndroid) {
      final downloadsDirectory = Directory('/storage/emulated/0/Download');
      if (downloadsDirectory.existsSync()) {
        return downloadsDirectory;
      }
    }

    // Fallback for non-Android platforms or when public Downloads is unavailable.
    return getApplicationDocumentsDirectory();
  }

  File _createUniqueCsvFile(String directoryPath, String baseName) {
    var filePath = '$directoryPath/$baseName.csv';
    var file = File(filePath);

    var counter = 1;
    while (file.existsSync()) {
      filePath = '$directoryPath/${baseName}_$counter.csv';
      file = File(filePath);
      counter++;
    }

    return file;
  }

  Future<String> _writeCsvFile(
    File file,
    Future<void> Function(IOSink sink) write,
  ) async {
    final sink = file.openWrite();
    try {
      await write(sink);
    } finally {
      await sink.close();
    }
    return file.path;
  }

  int _flushLineBufferIfNeeded(IOSink sink, List<String> lineBuffer) {
    var flushedChunks = 0;
    while (lineBuffer.length >= exportCsvWriteBatchSize) {
      sink.writeln(lineBuffer.take(exportCsvWriteBatchSize).join('\n'));
      lineBuffer.removeRange(0, exportCsvWriteBatchSize);
      flushedChunks++;
    }
    return flushedChunks;
  }

  int _flushLineBuffer(IOSink sink, List<String> lineBuffer) {
    if (lineBuffer.isEmpty) return 0;
    sink.writeln(lineBuffer.join('\n'));
    lineBuffer.clear();
    return 1;
  }

  int _flushRowBufferIfNeeded(
    IOSink sink,
    ListToCsvConverter converter,
    List<List<String>> rowBuffer,
  ) {
    var flushedChunks = 0;
    while (rowBuffer.length >= exportCsvWriteBatchSize) {
      final chunk = rowBuffer.take(exportCsvWriteBatchSize).toList();
      sink.writeln(converter.convert(chunk));
      rowBuffer.removeRange(0, exportCsvWriteBatchSize);
      flushedChunks++;
    }
    return flushedChunks;
  }

  int _flushRowBuffer(
    IOSink sink,
    ListToCsvConverter converter,
    List<List<String>> rowBuffer,
  ) {
    if (rowBuffer.isEmpty) return 0;
    sink.writeln(converter.convert(rowBuffer));
    rowBuffer.clear();
    return 1;
  }

  int _estimateOpenSenseMapExportChunks(
    Map<int, List<SensorData>> sensorDataByGeolocation,
  ) {
    final totalRows = sensorDataByGeolocation.values
        .fold<int>(0, (sum, sensors) => sum + sensors.length);
    final chunks = (totalRows / exportCsvWriteBatchSize).ceil();
    return chunks <= 0 ? 1 : chunks;
  }

  int _estimateRegularExportChunks(
    List<GeolocationData> geolocationDataList,
    Map<int, List<SensorData>> sensorDataByGeolocation,
  ) {
    var totalRows = 0;
    for (final geoData in geolocationDataList) {
      final sensors = sensorDataByGeolocation[geoData.id] ?? const <SensorData>[];
      if (sensors.isNotEmpty) {
        totalRows++;
      }
    }

    final chunks = (totalRows / exportCsvWriteBatchSize).ceil();
    return chunks <= 0 ? 1 : chunks;
  }

  Future<void> deleteAllData() async {
    try {
      await trackService.deleteAllTracks();
      await geolocationService.deleteAllGeolocations();
      await sensorService.deleteAllSensorData();
    } catch (e) {
      throw Exception("Failed to delete all data.");
    }
  }

  Future<List<TrackData>> getTracksPaginated(
      {required int offset, required int limit}) {
    return trackService.getTracksPaginated(offset: offset, limit: limit);
  }
}
