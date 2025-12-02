import 'dart:async';
import 'package:flutter/foundation.dart';
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

    const _asyncWaitDuration = Duration(milliseconds: 10);
    const _uploadWaitDuration = Duration(milliseconds: 100);
    const _maxQueueSize = 1000;

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
          aggregatedData: sensorData ?? {'temperature': [22.5 + i]},
          timestamp: DateTime.now(),
        ));
      }
      return batches;
    }

    DirectUploadService createService({VoidCallback? onUploadFailed}) {
      return DirectUploadService(
        openSenseMapService: mockOpenSenseMapService,
        senseBox: mockSenseBox,
        openSenseMapBloc: mockOpenSenseMapBloc,
        onUploadFailed: onUploadFailed,
      );
    }

    void setupMockToThrow(dynamic error) {
      when(() => mockOpenSenseMapBloc.isAuthenticated).thenReturn(true);
      when(() => mockOpenSenseMapBloc.uploadData(any(), any()))
          .thenThrow(error);
    }

    void setupMockToSucceed() {
      when(() => mockOpenSenseMapBloc.isAuthenticated).thenReturn(true);
      when(() => mockOpenSenseMapBloc.uploadData(any(), any()))
          .thenAnswer((_) async {});
    }

    void disableAutoUpload() {
      when(() => mockOpenSenseMapService.isAcceptingRequests)
          .thenReturn(false);
    }

    void enableAutoUpload() {
      when(() => mockOpenSenseMapService.isAcceptingRequests).thenReturn(true);
    }

    Future<void> queueAndWaitForUpload(DirectUploadService svc) async {
      svc.queueBatchesForUpload(createTestBatches());
      await Future.delayed(_asyncWaitDuration);
    }

    Future<void> queueAndUploadRemaining(DirectUploadService svc) async {
      svc.queueBatchesForUpload(createTestBatches());
      await svc.uploadRemainingBufferedData();
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

      enableAutoUpload();

      service = createService();
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
        disableAutoUpload();

        service.queueBatchesForUpload(createTestBatches());
        expect(service.hasPreservedData, true);

        service.disable();
        expect(service.hasPreservedData, false);
      });
    });

    group('Data Queueing', () {
      test('queues data when enabled', () {
        service.enable();
        disableAutoUpload();

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
        await Future.delayed(_asyncWaitDuration);

        expect(service.isEnabled, false);
        expect(service.hasPreservedData, false);

        service.queueBatchesForUpload(createTestBatches(startId: 2));
        expect(service.hasPreservedData, false);
      });
    });

    group('Upload Behavior', () {
      group('Successful Upload', () {
        test('remains enabled after success', () async {
          service.enable();
          setupMockToSucceed();

          await queueAndUploadRemaining(service);

          expect(service.isEnabled, true);
        });

        test('clears queue after success', () async {
          service.enable();
          setupMockToSucceed();

          await queueAndUploadRemaining(service);

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

            await queueAndUploadRemaining(service);

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
        serviceWithCallback = createService(
          onUploadFailed: () => uploadFailedCalled = true,
        );

        serviceWithCallback.enable();
        setupMockToThrow(Exception('Network error'));

        await queueAndWaitForUpload(serviceWithCallback);

        expect(uploadFailedCalled, true);
      });

      test('calls callback only once for multiple errors', () async {
        serviceWithCallback = createService(
          onUploadFailed: () => uploadFailedCallCount++,
        );

        serviceWithCallback.enable();
        setupMockToThrow(Exception('Network error'));

        for (int i = 0; i < 3; i++) {
          serviceWithCallback
              .queueBatchesForUpload(createTestBatches(startId: i));
          await Future.delayed(_asyncWaitDuration);
        }

        expect(uploadFailedCallCount, 1);
      });

      test('calls callback when final upload fails', () async {
        serviceWithCallback = createService(
          onUploadFailed: () => uploadFailedCalled = true,
        );

        serviceWithCallback.enable();
        disableAutoUpload();

        serviceWithCallback.queueBatchesForUpload(createTestBatches());

        setupMockToThrow(Exception('Network error'));

        await serviceWithCallback.uploadRemainingBufferedData();

        expect(uploadFailedCalled, true);
      });

      test('does not call callback on success', () async {
        serviceWithCallback = createService(
          onUploadFailed: () => uploadFailedCalled = true,
        );

        serviceWithCallback.enable();
        setupMockToSucceed();

        await queueAndUploadRemaining(serviceWithCallback);

        expect(uploadFailedCalled, false);
      });

      test('works without callback (null)', () async {
        serviceWithCallback = createService();
        serviceWithCallback.enable();
        setupMockToThrow(Exception('Network error'));

        await queueAndUploadRemaining(serviceWithCallback);

        expect(serviceWithCallback.hasPreservedData, false);
      });
    });

    group('Queue Limit', () {
      setUp(() {
        disableAutoUpload();
      });

      test('enforces limit of $_maxQueueSize batches', () {
        service.enable();

        service.queueBatchesForUpload(createTestBatches(count: _maxQueueSize));
        expect(service.hasPreservedData, true);

        service.queueBatchesForUpload(
            createTestBatches(count: 10, startId: _maxQueueSize));
        expect(service.hasPreservedData, true);
      });

      test('removes oldest batches when limit is exceeded', () {
        service.enable();

        service.queueBatchesForUpload(createTestBatches(count: 998));
        expect(service.hasPreservedData, true);

        service
            .queueBatchesForUpload(createTestBatches(count: 5, startId: 998));
        expect(service.hasPreservedData, true);
      });

      test('handles adding more batches than limit in one call', () {
        service.enable();

        service.queueBatchesForUpload(createTestBatches(count: 500));

        service
            .queueBatchesForUpload(createTestBatches(count: 600, startId: 500));

        expect(service.hasPreservedData, true);
      });

      test('handles incremental additions up to limit', () {
        service.enable();

        for (int batch = 0; batch < 10; batch++) {
          service.queueBatchesForUpload(
            createTestBatches(count: 100, startId: batch * 100),
          );
        }

        expect(service.hasPreservedData, true);

        service
            .queueBatchesForUpload(createTestBatches(count: 1, startId: 1000));
        expect(service.hasPreservedData, true);
      });

      test('merges batches with same geoId without increasing count', () {
        service.enable();

        service.queueBatchesForUpload(createTestBatches(count: 500));

        service.queueBatchesForUpload(
          createTestBatches(
            count: 500,
            sensorData: {'humidity': [50.0]},
          ),
        );

        expect(service.hasPreservedData, true);

        service
            .queueBatchesForUpload(createTestBatches(count: 600, startId: 500));
        expect(service.hasPreservedData, true);
      });

      test('maintains limit after queue is cleared and refilled', () async {
        enableAutoUpload();
        setupMockToSucceed();

        service.enable();

        service.queueBatchesForUpload(createTestBatches(count: _maxQueueSize));

        await Future.delayed(_uploadWaitDuration);
        expect(service.hasPreservedData, false);

        service.queueBatchesForUpload(createTestBatches(count: _maxQueueSize));
        expect(service.hasPreservedData, true);

        service.queueBatchesForUpload(
            createTestBatches(count: 10, startId: _maxQueueSize));
        expect(service.hasPreservedData, true);
      });
    });

    group('Batch Merging', () {
      test('merges batches with same geoId during queueing', () {
        service.enable();
        disableAutoUpload();

        final geo = GeolocationData()
          ..id = 1
          ..latitude = 10.0
          ..longitude = 20.0
          ..speed = 5.0
          ..timestamp = DateTime.utc(2024, 1, 1, 12, 0, 0);

        service.queueBatchesForUpload([
          SensorBatch(
            geoLocation: geo,
            aggregatedData: {
              'temperature': [22.5]
            },
            timestamp: DateTime.now(),
          )
        ]);

        service.queueBatchesForUpload([
          SensorBatch(
            geoLocation: geo,
            aggregatedData: {
              'humidity': [50.0]
            },
            timestamp: DateTime.now(),
          )
        ]);

        expect(service.hasPreservedData, true);
      });

      test('does not merge batches when service is uploading', () async {
        service.enable();
        setupMockToSucceed();

        final geo1 = GeolocationData()
          ..id = 1
          ..latitude = 10.0
          ..longitude = 20.0
          ..speed = 5.0
          ..timestamp = DateTime.utc(2024, 1, 1, 12, 0, 0);

        final geo2 = GeolocationData()
          ..id = 1
          ..latitude = 10.0
          ..longitude = 20.0
          ..speed = 5.0
          ..timestamp = DateTime.utc(2024, 1, 1, 12, 0, 0);

        service.queueBatchesForUpload([
          SensorBatch(
            geoLocation: geo1,
            aggregatedData: {
              'temperature': [22.5]
            },
            timestamp: DateTime.now(),
          )
        ]);

        await Future.delayed(_asyncWaitDuration);

        service.queueBatchesForUpload([
          SensorBatch(
            geoLocation: geo2,
            aggregatedData: {
              'humidity': [50.0]
            },
            timestamp: DateTime.now(),
          )
        ]);

        await Future.delayed(_asyncWaitDuration);
        expect(service.hasPreservedData, false);
      });

      test('preserves metadata when merging duplicate batches in queue', () {
        service.enable();
        disableAutoUpload();

        final geo = GeolocationData()
          ..id = 1
          ..latitude = 10.0
          ..longitude = 20.0
          ..speed = 5.0
          ..timestamp = DateTime.utc(2024, 1, 1, 12, 0, 0);

        final batch1 = SensorBatch(
          geoLocation: geo,
          aggregatedData: {
            'temperature': [22.5]
          },
          timestamp: DateTime.now(),
        );
        batch1.isUploadPending = true;
        batch1.isSavedToDb = true;

        final batch2 = SensorBatch(
          geoLocation: geo,
          aggregatedData: {
            'humidity': [50.0]
          },
          timestamp: DateTime.now(),
        );
        batch2.isUploadPending = false;
        batch2.isSavedToDb = false;

        service.queueBatchesForUpload([batch1]);
        service.queueBatchesForUpload([batch2]);

        expect(service.hasPreservedData, true);
      });
    });

    group('Upload Readiness', () {
      test('does not start upload when service is disabled', () {
        expect(service.isEnabled, false);
        disableAutoUpload();

        service.queueBatchesForUpload(createTestBatches());
        expect(service.hasPreservedData, false);
      });

      test('does not start upload when queue is empty', () {
        service.enable();
        expect(service.hasPreservedData, false);
      });

      test('does not start upload when already uploading', () async {
        service.enable();
        setupMockToSucceed();

        service.queueBatchesForUpload(createTestBatches());
        await Future.delayed(_asyncWaitDuration);

        expect(service.hasPreservedData, false);
      });

      test('does not start upload when service is not accepting requests', () {
        service.enable();
        disableAutoUpload();

        service.queueBatchesForUpload(createTestBatches());
        expect(service.hasPreservedData, true);
      });
    });

    group('Empty Data Handling', () {
      test('handles batches with empty aggregatedData', () async {
        service.enable();
        setupMockToSucceed();

        final geo = GeolocationData()
          ..id = 1
          ..latitude = 10.0
          ..longitude = 20.0
          ..speed = 5.0
          ..timestamp = DateTime.utc(2024, 1, 1, 12, 0, 0);

        final emptyBatch = SensorBatch(
          geoLocation: geo,
          aggregatedData: {},
          timestamp: DateTime.now(),
        );

        service.queueBatchesForUpload([emptyBatch]);
        await queueAndUploadRemaining(service);

        expect(service.hasPreservedData, false);
        expect(service.isEnabled, true);
      });
    });

    group('Final Upload Failure Handling', () {
      test('handles failure when uploading remaining data', () async {
        service.enable();
        disableAutoUpload();

        service.queueBatchesForUpload(createTestBatches());

        setupMockToThrow(Exception('Network error'));

        await service.uploadRemainingBufferedData();

        expect(service.isEnabled, false);
        expect(service.hasPreservedData, false);
      });

      test('does not report failure twice for final upload', () async {
        bool uploadFailedCalled = false;
        final serviceWithCallback = createService(
          onUploadFailed: () => uploadFailedCalled = true,
        );

        serviceWithCallback.enable();
        disableAutoUpload();

        serviceWithCallback.queueBatchesForUpload(createTestBatches());

        setupMockToThrow(Exception('Network error'));

        await serviceWithCallback.uploadRemainingBufferedData();
        await serviceWithCallback.uploadRemainingBufferedData();

        expect(uploadFailedCalled, true);
        serviceWithCallback.dispose();
      });
    });

    group('Queue State Transitions', () {
      test('clears queue after successful upload', () async {
        service.enable();
        setupMockToSucceed();

        service.queueBatchesForUpload(createTestBatches(count: 5));
        await queueAndUploadRemaining(service);

        expect(service.hasPreservedData, false);
        expect(service.isEnabled, true);
      });

      test('maintains queue state during upload', () async {
        service.enable();
        setupMockToSucceed();

        service.queueBatchesForUpload(createTestBatches(count: 3));
        expect(service.hasPreservedData, true);

        await Future.delayed(_asyncWaitDuration);

        expect(service.hasPreservedData, false);
      });
    });
  });
}
