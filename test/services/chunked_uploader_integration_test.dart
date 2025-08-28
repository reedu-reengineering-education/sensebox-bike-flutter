import 'package:flutter_test/flutter_test.dart';
import 'package:sensebox_bike/services/chunked_uploader.dart';
import 'package:sensebox_bike/services/opensensemap_service.dart';
import 'package:sensebox_bike/models/sensebox.dart';
import 'package:sensebox_bike/models/geolocation_data.dart';

void main() {
  group('ChunkedUploader Integration', () {
    test('should be instantiable with required dependencies', () {
      final mockService = _MockOpenSenseMapService();
      final testSenseBox = _createTestSenseBox();
      
      expect(
        () => ChunkedUploader(
          openSenseMapService: mockService,
          senseBox: testSenseBox,
        ),
        returnsNormally,
      );
    });

    test('should have all required public methods', () {
      final mockService = _MockOpenSenseMapService();
      final testSenseBox = _createTestSenseBox();
      final uploader = ChunkedUploader(
        openSenseMapService: mockService,
        senseBox: testSenseBox,
      );

      // Verify all required methods exist
      expect(uploader.splitIntoChunks, isA<Function>());
      expect(uploader.uploadChunk, isA<Function>());
      expect(uploader.uploadTrackInChunks, isA<Function>());
    });

    test('should split large datasets correctly', () {
      final mockService = _MockOpenSenseMapService();
      final testSenseBox = _createTestSenseBox();
      final uploader = ChunkedUploader(
        openSenseMapService: mockService,
        senseBox: testSenseBox,
      );

      final largeDataset = _createGeolocationList(10000);
      final chunks = uploader.splitIntoChunks(largeDataset, testSenseBox);

      // Should create multiple chunks based on measurement estimation
      expect(chunks.length, greaterThan(1));
      expect(chunks.length, lessThan(largeDataset.length)); // Should be more efficient than 1 per point
      
      // Verify total count is preserved
      final totalPoints = chunks.fold<int>(0, (sum, chunk) => sum + chunk.length);
      expect(totalPoints, equals(10000));
    });
  });
}

// Simple mock for integration testing
class _MockOpenSenseMapService implements OpenSenseMapService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

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
    ],
  );
}

List<GeolocationData> _createGeolocationList(int count) {
  final List<GeolocationData> geolocations = [];
  final baseTime = DateTime.now();
  
  for (int i = 0; i < count; i++) {
    final geolocation = GeolocationData()
      ..latitude = 52.5200 + (i * 0.0001)
      ..longitude = 13.4050 + (i * 0.0001)
      ..speed = 15.0 + (i % 10)
      ..timestamp = baseTime.add(Duration(seconds: i));
    
    geolocations.add(geolocation);
  }
  
  return geolocations;
}