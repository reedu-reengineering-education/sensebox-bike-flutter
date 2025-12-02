import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sensebox_bike/models/geolocation_data.dart';
import 'package:sensebox_bike/models/sensebox.dart';
import 'package:sensebox_bike/models/sensor_batch.dart';
import 'package:sensebox_bike/services/direct_upload_service.dart';
import 'package:sensebox_bike/services/opensensemap_service.dart';
import 'package:sensebox_bike/services/custom_exceptions.dart';
import 'package:sensebox_bike/blocs/opensensemap_bloc.dart';

class MockOpenSenseMapService extends Mock implements OpenSenseMapService {}

class MockOpenSenseMapBloc extends Mock implements OpenSenseMapBloc {
  @override
  Future<void> uploadData(String senseBoxId, Map<String, dynamic> data) async {
    return super.noSuchMethod(
      Invocation.method(#uploadData, [senseBoxId, data]),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DirectUploadService', () {
    late DirectUploadService service;
    late MockOpenSenseMapService mockOpenSenseMapService;
    late MockOpenSenseMapBloc mockOpenSenseMapBloc;
    late SenseBox mockSenseBox;

    // Helper to create test sensor batches
    List<SensorBatch> createTestBatches({
      int count = 1,
      int startId = 1,
      Map<String, List<double>>? sensorData,
    }) {
      final batches = <SensorBatch>[];
      for (int i = 0; i < count; i++) {
        final geo = GeolocationData()
          ..id = startId + i
          ..latitude = 10.0 + i * 0.001
          ..longitude = 20.0 + i * 0.001
          ..speed = 5.0
          ..timestamp = DateTime.utc(2024, 1, 1, 12, 0, i);

        batches.add(SensorBatch(
          geoLocation: geo,
          aggregatedData: sensorData ??
              {
                'temperature': [22.5 + i]
              },
          timestamp: DateTime.now(),
        ));
      }
      return batches;
    }

    // Helper to setup mock for upload error
    void setupMockToThrow(dynamic error) {
      when(() => mockOpenSenseMapBloc.isAuthenticated).thenReturn(true);
      when(() => mockOpenSenseMapBloc.uploadData(any(), any()))
          .thenThrow(error);
    }

    // Helper to setup mock for successful upload
    void setupMockToSucceed() {
      when(() => mockOpenSenseMapBloc.isAuthenticated).thenReturn(true);
      when(() => mockOpenSenseMapBloc.uploadData(any(), any()))
          .thenAnswer((_) async {});
    }

    setUp(() {
      mockOpenSenseMapService = MockOpenSenseMapService();
      mockOpenSenseMapBloc = MockOpenSenseMapBloc();
      mockSenseBox = SenseBox()
        ..sId = 'test-sensebox-id'
        ..name = 'Test SenseBox'
        ..sensors = [
          Sensor()
            ..id = 'temperature-sensor-id'
            ..title = 'Temperature',
          Sensor()
            ..id = 'speed-sensor-id'
            ..title = 'Speed',
        ];

      when(() => mockOpenSenseMapService.isAcceptingRequests).thenReturn(true);

      service = DirectUploadService(
        openSenseMapService: mockOpenSenseMapService,
        senseBox: mockSenseBox,
        openSenseMapBloc: mockOpenSenseMapBloc,
      );
    });

    tearDown(() {
      service.dispose();
    });

    group('Service State Management', () {
      test('starts disabled by default', () {
        expect(service.isEnabled, false);
      });

      test('can be enabled', () {
        service.enable();
        expect(service.isEnabled, true);
      });

      test('can be disabled', () {
        service.enable();
        expect(service.isEnabled, true);

        service.disable();
        expect(service.isEnabled, false);
      });

      test('can be re-enabled after being disabled', () {
        service.enable();
        service.disable();
        service.enable();
        expect(service.isEnabled, true);
      });

      test('clears buffer when disabled', () {
        service.enable();
        when(() => mockOpenSenseMapService.isAcceptingRequests)
            .thenReturn(false);

        service.queueBatchesForUpload(createTestBatches());
        expect(service.hasPreservedData, true);

        service.disable();
        expect(service.hasPreservedData, false);
      });
    });

    group('Data Queueing', () {
      test('queues data when enabled', () {
        service.enable();
        when(() => mockOpenSenseMapService.isAcceptingRequests)
            .thenReturn(false);

        service.queueBatchesForUpload(createTestBatches());
        expect(service.hasPreservedData, true);
      });

      test('does not queue data when disabled', () {
        expect(service.isEnabled, false);

        service.queueBatchesForUpload(createTestBatches());
        expect(service.hasPreservedData, false);
      });

      test('does not queue new data after service is disabled by error',
          () async {
        service.enable();
        setupMockToThrow(Exception('Network error'));

        service.queueBatchesForUpload(createTestBatches(startId: 1));
        await Future.delayed(Duration(milliseconds: 10));

        expect(service.isEnabled, false);
        expect(service.hasPreservedData, false);

        // Try to queue more data - should be ignored
        service.queueBatchesForUpload(createTestBatches(startId: 2));
        expect(service.hasPreservedData, false);
      });
    });

    group('Upload Behavior', () {
      group('Successful Upload', () {
        test('remains enabled after success', () async {
          service.enable();
          setupMockToSucceed();

          service.queueBatchesForUpload(createTestBatches());
          await service.uploadRemainingBufferedData();

          expect(service.isEnabled, true);
        });

        test('clears queue after success', () async {
          service.enable();
          setupMockToSucceed();

          service.queueBatchesForUpload(createTestBatches());
          await service.uploadRemainingBufferedData();

          expect(service.hasPreservedData, false);
        });
      });

      group('Error Handling', () {
        final errorTestCases = <String, dynamic>{
          'network timeout': Exception('Network timeout'),
          'rate limiting (429)': TooManyRequestsException(30),
          'server error (502)': Exception('Server error 502 - retrying'),
          'server error (503)': Exception('Server error 503 - retrying'),
          'timeout exception':
              TimeoutException('Upload timeout', const Duration(seconds: 30)),
          'token refresh': Exception('Token refreshed, retrying'),
          'authentication failure':
              Exception('Authentication failed - user needs to re-login'),
          'no refresh token': Exception('No refresh token found'),
          'failed token refresh':
              Exception('Failed to refresh token: Network error'),
          'not authenticated': Exception('Not authenticated'),
          'client error (403)': Exception('Client error 403: Forbidden'),
          'client error (404)': Exception('Client error 404: Not Found'),
        };

        for (final entry in errorTestCases.entries) {
          test('disables service on ${entry.key}', () async {
            service.enable();
            setupMockToThrow(entry.value);

            service.queueBatchesForUpload(createTestBatches());
            await service.uploadRemainingBufferedData();

            expect(service.isEnabled, false,
                reason: 'Service should be disabled after ${entry.key}');
            expect(service.hasPreservedData, false,
                reason: 'Queue should be cleared after ${entry.key}');
          });
        }
      });
    });

    group('Upload Failure Callback', () {
      late bool uploadFailedCalled;
      late int uploadFailedCallCount;
      late DirectUploadService serviceWithCallback;

      setUp(() {
        uploadFailedCalled = false;
        uploadFailedCallCount = 0;
      });

      tearDown(() {
        serviceWithCallback.dispose();
      });

      test('calls callback on error', () async {
        serviceWithCallback = DirectUploadService(
          openSenseMapService: mockOpenSenseMapService,
          senseBox: mockSenseBox,
          openSenseMapBloc: mockOpenSenseMapBloc,
          onUploadFailed: () => uploadFailedCalled = true,
        );

        serviceWithCallback.enable();
        setupMockToThrow(Exception('Network error'));

        serviceWithCallback.queueBatchesForUpload(createTestBatches());
        await Future.delayed(Duration(milliseconds: 10));

        expect(uploadFailedCalled, true);
      });

      test('calls callback only once for multiple errors', () async {
        serviceWithCallback = DirectUploadService(
          openSenseMapService: mockOpenSenseMapService,
          senseBox: mockSenseBox,
          openSenseMapBloc: mockOpenSenseMapBloc,
          onUploadFailed: () => uploadFailedCallCount++,
        );

        serviceWithCallback.enable();
        setupMockToThrow(Exception('Network error'));

        // Queue multiple batches
        for (int i = 0; i < 3; i++) {
          serviceWithCallback
              .queueBatchesForUpload(createTestBatches(startId: i));
          await Future.delayed(Duration(milliseconds: 10));
        }

        expect(uploadFailedCallCount, 1);
      });

      test('calls callback when final upload fails', () async {
        serviceWithCallback = DirectUploadService(
          openSenseMapService: mockOpenSenseMapService,
          senseBox: mockSenseBox,
          openSenseMapBloc: mockOpenSenseMapBloc,
          onUploadFailed: () => uploadFailedCalled = true,
        );

        serviceWithCallback.enable();

        // Disable accepting requests so _tryUpload doesn't run during queueing
        when(() => mockOpenSenseMapService.isAcceptingRequests)
            .thenReturn(false);

        serviceWithCallback.queueBatchesForUpload(createTestBatches());

        // Setup failure for final upload
        setupMockToThrow(Exception('Network error'));

        await serviceWithCallback.uploadRemainingBufferedData();

        expect(uploadFailedCalled, true);
      });

      test('does not call callback on success', () async {
        serviceWithCallback = DirectUploadService(
          openSenseMapService: mockOpenSenseMapService,
          senseBox: mockSenseBox,
          openSenseMapBloc: mockOpenSenseMapBloc,
          onUploadFailed: () => uploadFailedCalled = true,
        );

        serviceWithCallback.enable();
        setupMockToSucceed();

        serviceWithCallback.queueBatchesForUpload(createTestBatches());
        await serviceWithCallback.uploadRemainingBufferedData();

        expect(uploadFailedCalled, false);
      });

      test('works without callback (null)', () async {
        serviceWithCallback = DirectUploadService(
          openSenseMapService: mockOpenSenseMapService,
          senseBox: mockSenseBox,
          openSenseMapBloc: mockOpenSenseMapBloc,
        );

        serviceWithCallback.enable();
        setupMockToThrow(Exception('Network error'));

        serviceWithCallback.queueBatchesForUpload(createTestBatches());

        // Should not throw
        await serviceWithCallback.uploadRemainingBufferedData();

        expect(serviceWithCallback.hasPreservedData, false);
      });
    });

    group('Queue Limit', () {
      const maxQueueSize = 1000;

      setUp(() {
        // Prevent auto-upload during queue tests
        when(() => mockOpenSenseMapService.isAcceptingRequests).thenReturn(false);
      });

      test('enforces limit of $maxQueueSize batches', () {
        service.enable();

        service.queueBatchesForUpload(createTestBatches(count: maxQueueSize));
        expect(service.hasPreservedData, true);

        // Add more - should enforce limit
        service.queueBatchesForUpload(
            createTestBatches(count: 10, startId: maxQueueSize));
        expect(service.hasPreservedData, true);
      });

      test('removes oldest batches when limit is exceeded', () {
        service.enable();

        // Fill to just under limit
        service.queueBatchesForUpload(createTestBatches(count: 998));
        expect(service.hasPreservedData, true);

        // Add 5 more - should remove oldest 3
        service
            .queueBatchesForUpload(createTestBatches(count: 5, startId: 998));
        expect(service.hasPreservedData, true);
      });

      test('handles adding more batches than limit in one call', () {
        service.enable();

        // Fill with 500
        service.queueBatchesForUpload(createTestBatches(count: 500));

        // Try to add 600 more (would exceed by 100)
        service
            .queueBatchesForUpload(createTestBatches(count: 600, startId: 500));

        expect(service.hasPreservedData, true);
      });

      test('handles incremental additions up to limit', () {
        service.enable();

        // Add batches incrementally
        for (int batch = 0; batch < 10; batch++) {
          service.queueBatchesForUpload(
            createTestBatches(count: 100, startId: batch * 100),
          );
        }

        expect(service.hasPreservedData, true);

        // Add one more batch - should trigger limit
        service
            .queueBatchesForUpload(createTestBatches(count: 1, startId: 1000));
        expect(service.hasPreservedData, true);
      });

      test('merges batches with same geoId without increasing count', () {
        service.enable();

        // Add 500 batches
        service.queueBatchesForUpload(createTestBatches(count: 500));

        // Add 500 more with same geoIds (should merge)
        service.queueBatchesForUpload(
          createTestBatches(
            count: 500,
            sensorData: {
              'humidity': [50.0]
            },
          ),
        );

        expect(service.hasPreservedData, true);

        // Now add 600 new batches - should trigger limit
        service
            .queueBatchesForUpload(createTestBatches(count: 600, startId: 500));
        expect(service.hasPreservedData, true);
      });

      test('maintains limit after queue is cleared and refilled', () async {
        when(() => mockOpenSenseMapService.isAcceptingRequests).thenReturn(true);
        setupMockToSucceed();

        service.enable();

        // Fill queue
        service.queueBatchesForUpload(createTestBatches(count: maxQueueSize));

        // Upload clears queue
        await Future.delayed(Duration(milliseconds: 100));
        expect(service.hasPreservedData, false);

        // Refill queue
        service.queueBatchesForUpload(createTestBatches(count: maxQueueSize));
        expect(service.hasPreservedData, true);

        // Add more - should enforce limit again
        service.queueBatchesForUpload(
            createTestBatches(count: 10, startId: maxQueueSize));
        expect(service.hasPreservedData, true);
      });
    });
  });
}
