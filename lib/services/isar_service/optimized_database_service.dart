import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:isar/isar.dart';
import 'package:sensebox_bike/constants.dart';
import 'package:sensebox_bike/models/geolocation_data.dart';
import 'package:sensebox_bike/models/sensor_data.dart';
import 'package:sensebox_bike/models/track_data.dart';
import 'package:sensebox_bike/services/isar_service/isar_provider.dart';

class OptimizedDatabaseService {
  static const int _defaultBatchSize = uploadBatchSize;
  static bool _isProcessing = false;
  static final Duration _processingTimeout = Duration(seconds: 10);
  static final IsarProvider _isarProvider = IsarProvider();

  static Future<List<Map<String, dynamic>>> processGeolocationDataForUpload(
    int trackId,
    List<int> uploadedIds,
  ) async {
    return await _processDataEfficiently(trackId, uploadedIds);
  }

  static Future<int> getGeolocationCount(int trackId) async {
    return await _getGeolocationCountEfficiently(trackId);
  }

  static Future<List<Map<String, dynamic>>> processDataInBatches(
    int trackId,
    List<int> uploadedIds, {
    int batchSize = _defaultBatchSize,
  }) async {
    return await _processDataEfficiently(trackId, uploadedIds, batchSize: batchSize);
  }

  static Future<Isar> _getIsarInstance() async {
    return await _isarProvider.getDatabase();
  }

  static Future<void> _waitForProcessing() async {
    if (!_isProcessing) return;
    
    final startTime = DateTime.now();
    while (_isProcessing) {
      final elapsed = DateTime.now().difference(startTime);
      if (elapsed > _processingTimeout) {
        debugPrint('Processing timeout reached, proceeding anyway');
        break;
      }
      await Future.delayed(const Duration(milliseconds: 100));
    }
  }

  static Future<int> _getGeolocationCountEfficiently(int trackId) async {
    try {
      await _waitForProcessing();
      _isProcessing = true;
      
      // Use a microtask to avoid blocking the main thread
      return await Future.microtask(() async {
        final isar = await _getIsarInstance();

        try {
          return await isar.geolocationDatas
              .where()
              .filter()
              .track((q) => q.idEqualTo(trackId))
              .count();
        } catch (e) {
          debugPrint('Error counting geolocation data: $e');
          return 0;
        }
      });
    } catch (e) {
      debugPrint('Error getting geolocation count: $e');
      return 0; // Return 0 on error
    } finally {
      _isProcessing = false;
    }
  }

  /// Efficient method to process data without blocking main thread
  static Future<List<Map<String, dynamic>>> _processDataEfficiently(
    int trackId,
    List<int> uploadedIds, {
    int batchSize = _defaultBatchSize,
  }) async {
    try {
      await _waitForProcessing();
      _isProcessing = true;
      
      // Use a microtask to avoid blocking the main thread
      return await Future.microtask(() async {
        final isar = await _getIsarInstance();

        try {
          final totalCount = await isar.geolocationDatas
              .where()
              .filter()
              .track((q) => q.idEqualTo(trackId))
              .count();

          if (totalCount < 2) {
            return [];
          }

          // Get all but the last item (which may be incomplete)
          final geolocationData = await isar.geolocationDatas
              .where()
              .filter()
              .track((q) => q.idEqualTo(trackId))
              .sortByTimestamp()
              .limit(totalCount - 1)
              .findAll();

          // Filter out already uploaded data
          final unuploadedData = geolocationData
              .where((geo) => !uploadedIds.contains(geo.id))
              .toList();

          // Convert to serializable format
          final result = <Map<String, dynamic>>[];
          
          for (final geo in unuploadedData) {
            // Load sensor data for this geolocation
            final sensorData = await isar.sensorDatas
                .where()
                .filter()
                .geolocationData((q) => q.idEqualTo(geo.id))
                .findAll();

            final geoMap = {
              'id': geo.id,
              'latitude': geo.latitude,
              'longitude': geo.longitude,
              'speed': geo.speed,
              'timestamp': geo.timestamp.toIso8601String(),
              'sensorData': sensorData.map((sensor) => {
                'id': sensor.id,
                'characteristicUuid': sensor.characteristicUuid,
                'title': sensor.title,
                'attribute': sensor.attribute,
                'value': sensor.value,
              }).toList(),
            };
            
            result.add(geoMap);
          }

          return result;
        } catch (e) {
          debugPrint('Error processing data efficiently: $e');
          return [];
        }
      });
    } catch (e) {
      debugPrint('Error processing data efficiently: $e');
      return []; // Return empty list on error
    } finally {
      _isProcessing = false;
    }
  }

  static Future<List<Map<String, dynamic>>> processDataInChunks(
    int trackId,
    List<int> uploadedIds, {
    int chunkSize = 25, 
  }) async {
    try {
      await _waitForProcessing();
      _isProcessing = true;
      
      return await Future.microtask(() async {
        final isar = await _getIsarInstance();

        try {
          final totalCount = await isar.geolocationDatas
              .where()
              .filter()
              .track((q) => q.idEqualTo(trackId))
              .count();

          if (totalCount < 2) {
            return [];
          }

          final result = <Map<String, dynamic>>[];
          final effectiveChunkSize = chunkSize.clamp(1, 50);

          // Process in chunks to avoid memory issues
          for (int offset = 0; offset < totalCount - 1; offset += effectiveChunkSize) {
            final actualLimit = (offset + effectiveChunkSize > totalCount - 1) 
                ? (totalCount - 1 - offset) 
                : effectiveChunkSize;

            if (actualLimit <= 0) break;

            final geolocationData = await isar.geolocationDatas
                .where()
                .filter()
                .track((q) => q.idEqualTo(trackId))
                .sortByTimestamp()
                .offset(offset)
                .limit(actualLimit)
                .findAll();

            for (final geo in geolocationData) {
              if (uploadedIds.contains(geo.id)) {
                continue; // Skip already uploaded data
              }

              // Load sensor data for this geolocation
              final sensorData = await isar.sensorDatas
                  .where()
                  .filter()
                  .geolocationData((q) => q.idEqualTo(geo.id))
                  .findAll();

              final geoMap = {
                'id': geo.id,
                'latitude': geo.latitude,
                'longitude': geo.longitude,
                'speed': geo.speed,
                'timestamp': geo.timestamp.toIso8601String(),
                'sensorData': sensorData.map((sensor) => {
                  'id': sensor.id,
                  'characteristicUuid': sensor.characteristicUuid,
                  'title': sensor.title,
                  'attribute': sensor.attribute,
                  'value': sensor.value,
                }).toList(),
              };
              
              result.add(geoMap);
            }

            // Small delay between chunks to prevent blocking
            await Future.delayed(const Duration(milliseconds: 10));
          }

          return result;
        } catch (e) {
          debugPrint('Error processing data in chunks: $e');
          return [];
        }
      });
    } catch (e) {
      debugPrint('Error processing data in chunks: $e');
      return []; // Return empty list on error
    } finally {
      _isProcessing = false;
    }
  }
} 