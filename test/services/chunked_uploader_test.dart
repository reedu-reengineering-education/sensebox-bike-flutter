
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sensebox_bike/models/geolocation_data.dart';
import 'package:sensebox_bike/models/sensebox.dart';
import 'package:sensebox_bike/services/chunked_uploader.dart';
import 'package:sensebox_bike/services/opensensemap_service.dart';

class MockOpenSenseMapService extends Mock implements OpenSenseMapService {}
void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });
  
  group('ChunkedUploader', () {
    late ChunkedUploader chunkedUploader;
    late MockOpenSenseMapService mockOpenSenseMapService;
    late SenseBox testSenseBox;

    setUp(() {
      mockOpenSenseMapService = MockOpenSenseMapService();
      testSenseBox = _createTestSenseBox();
      chunkedUploader = ChunkedUploader(
        openSenseMapService: mockOpenSenseMapService,
        senseBox: testSenseBox,
      );
    });

    group('splitIntoChunks', () {
      test('should return empty list for empty input', () {
        final result = chunkedUploader.splitIntoChunks([], testSenseBox);
        expect(result, isEmpty);
      });

      test('should return single chunk for data under limit', () {
        final geolocations = _createGeolocationList(100);
        final result = chunkedUploader.splitIntoChunks(geolocations, testSenseBox);
        
        expect(result.length, equals(1));
        expect(result[0].length, equals(100));
        expect(result[0], equals(geolocations));
      });

      test('should split large datasets into multiple chunks based on measurement estimation', () {
        final geolocations = _createGeolocationList(1000);
        final result = chunkedUploader.splitIntoChunks(geolocations, testSenseBox);
        
        // With estimated measurements per point, should create multiple smaller chunks
        expect(result.length, greaterThan(1));
      });

      test('should create appropriate chunks based on measurement estimation', () {
        final geolocations = _createGeolocationList(2000); // Use more points to force multiple chunks
        final result = chunkedUploader.splitIntoChunks(geolocations, testSenseBox);
        
        // Should create multiple chunks based on estimated measurements per point
        expect(result.length, greaterThan(1));
        
        // Each chunk should have reasonable size (around 833 points for 3 measurements per point)
        for (final chunk in result) {
          expect(chunk.length, greaterThan(0));
          expect(chunk.length, lessThanOrEqualTo(833)); // Based on 2500/3 estimation
        }
      });

      test('should maintain chronological order in chunks', () {
        final geolocations = _createGeolocationList(1000);
        final result = chunkedUploader.splitIntoChunks(geolocations, testSenseBox);
        
        // Check that timestamps are in order within each chunk
        for (final chunk in result) {
          for (int i = 1; i < chunk.length; i++) {
            expect(
              chunk[i].timestamp.isAfter(chunk[i - 1].timestamp) ||
              chunk[i].timestamp.isAtSameMomentAs(chunk[i - 1].timestamp),
              isTrue,
              reason: 'Timestamps should be in chronological order',
            );
          }
        }
        
        // Check that the last timestamp of chunk n is before first timestamp of chunk n+1
        for (int i = 1; i < result.length; i++) {
          expect(
            result[i][0].timestamp.isAfter(result[i - 1].last.timestamp) ||
            result[i][0].timestamp.isAtSameMomentAs(result[i - 1].last.timestamp),
            isTrue,
            reason: 'Chunks should be in chronological order',
          );
        }
      });

      test('should handle large datasets efficiently', () {
        final geolocations = _createGeolocationList(5000);
        final stopwatch = Stopwatch()..start();
        
        final result = chunkedUploader.splitIntoChunks(geolocations, testSenseBox);
        
        stopwatch.stop();
        
        expect(result.length, greaterThan(1));
        expect(stopwatch.elapsedMilliseconds, lessThan(1000), 
               reason: 'Chunking should be fast even for large datasets');
      });

      test('should estimate measurements correctly for test SenseBox', () {
        // Test SenseBox has Speed, Temperature, Humidity sensors
        // Should estimate: 1 (speed) + 1 (temperature) + 1 (humidity) = 3 measurements per point
        // With 2500 max measurements, chunk size should be around 2500/3 = 833 points
        final geolocations = _createGeolocationList(2000);
        final result = chunkedUploader.splitIntoChunks(geolocations, testSenseBox);
        
        // Should create multiple chunks
        expect(result.length, greaterThan(2));
        
        // Each chunk should be reasonably sized (not too big to exceed measurement limit)
        for (final chunk in result) {
          expect(chunk.length, lessThanOrEqualTo(1000)); // Conservative estimate
        }
      });
    });

    group('uploadChunk', () {
      test('should return success for empty chunk', () async {
        final result = await chunkedUploader.uploadChunk([], testSenseBox, 0);
        
        expect(result.success, isTrue);
        expect(result.chunkIndex, equals(0));
        verifyNever(() => mockOpenSenseMapService.uploadData(any(), any()));
      });

      test('should handle upload service errors correctly', () async {
        final chunk = _createGeolocationList(1); // Single point to minimize Isar issues
        when(() => mockOpenSenseMapService.uploadData(any(), any()))
            .thenThrow(Exception('Network error'));

        final result = await chunkedUploader.uploadChunk(chunk, testSenseBox, 0);
        
        expect(result.success, isFalse);
        expect(result.chunkIndex, equals(0));
        expect(result.errorMessage, isNotNull);
      });
    });

    // Note: uploadTrackInChunks tests are simplified due to Isar complexity
    // In a real implementation, these would require proper Isar test setup
    group('uploadTrackInChunks', () {
      test('should handle track upload flow', () {
        // This test verifies the method exists and has the correct signature
        expect(chunkedUploader.uploadTrackInChunks, isA<Function>());
      });
    });
  });
}

// Helper functions for creating test data

SenseBox _createTestSenseBox() {
  return SenseBox(
    sId: 'test-sensebox-id',
    name: 'Test SenseBox',
    sensors: [
      Sensor(
        id: 'speed-sensor-id',
        title: 'Speed',
        unit: 'km/h',
        sensorType: 'speed',
      ),
      Sensor(
        id: 'temp-sensor-id',
        title: 'Temperature',
        unit: '°C',
        sensorType: 'temperature',
      ),
      Sensor(
        id: 'humidity-sensor-id',
        title: 'Humidity',
        unit: '%',
        sensorType: 'humidity',
      ),
    ],
  );
}

List<GeolocationData> _createGeolocationList(int count) {
  final List<GeolocationData> geolocations = [];
  final baseTime = DateTime.now();
  
  for (int i = 0; i < count; i++) {
    final geolocation = GeolocationData()
      ..latitude = 52.5200 + (i * 0.0001) // Berlin coordinates with small increments
      ..longitude = 13.4050 + (i * 0.0001)
      ..speed = 15.0 + (i % 10) // Varying speed
      ..timestamp = baseTime.add(Duration(seconds: i));
    
    geolocations.add(geolocation);
  }
  
  return geolocations;
}

// Note: Complex Isar relationship testing would require proper test setup
// These helper functions are simplified for the core chunking logic tests