import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:isar_community/isar.dart';
import 'package:mocktail/mocktail.dart';
import 'package:retry/retry.dart';
import 'package:sensebox_bike/models/geolocation_data.dart';
import 'package:sensebox_bike/models/sensebox.dart';
import 'package:sensebox_bike/models/track_data.dart';
import 'package:sensebox_bike/models/upload_progress.dart';
import 'package:sensebox_bike/services/batch_upload_service.dart';
import 'package:sensebox_bike/services/custom_exceptions.dart';
import 'package:sensebox_bike/services/opensensemap_service.dart';

import '../mocks.dart';
import '../test_helpers.dart';

class _MockOpenSenseMapService extends Mock implements OpenSenseMapService {}

/// Measurements per chunk is capped at 2000 and this box produces one
/// measurement (speed) per point, so this yields exactly 2 chunks.
const _pointsForTwoChunks = 2001;

void main() {
  late Isar isar;
  late _MockOpenSenseMapService osemService;
  late MockTrackService trackService;
  late MockOpenSenseMapBloc osemBloc;
  late SenseBox senseBox;

  setUpAll(() {
    registerFallbackValue(SenseBox());
    registerFallbackValue(<String, dynamic>{});
    registerFallbackValue(TrackData());
    registerFallbackValue(const RetryOptions());
    registerFallbackValue(Duration.zero);
  });

  setUp(() async {
    isar = await initializeInMemoryIsar();
    osemService = _MockOpenSenseMapService();
    trackService = MockTrackService();
    osemBloc = MockOpenSenseMapBloc()..isAuthenticated = true;
    senseBox = SenseBox(
      sId: 'box-id',
      name: 'Test box',
      sensors: [
        Sensor(id: 'speed-id', title: 'Speed', unit: 'm/s', sensorType: 'speed'),
      ],
    );
    when(() => trackService.saveTrack(any())).thenAnswer((_) async => 1);
  });

  tearDown(() async {
    await isar.close(deleteFromDisk: true);
  });

  Future<TrackData> createTrack(int points) async {
    final track = TrackData()..uploaded = 0;
    final base = DateTime.utc(2026, 1, 1);
    await isar.writeTxn(() async {
      await isar.trackDatas.put(track);
      final geos = List.generate(
        points,
        (i) => GeolocationData()
          ..latitude = 52.0 + i * 0.0001
          ..longitude = 13.0 + i * 0.0001
          ..speed = 5.0
          ..timestamp = base.add(Duration(seconds: i)),
      );
      for (final geo in geos) {
        geo.track.value = track;
      }
      await isar.geolocationDatas.putAll(geos);
      for (final geo in geos) {
        await geo.track.save();
      }
    });
    return track;
  }

  BatchUploadService createService({
    // Loading sensor data for 2000 points takes a moment even in tests.
    Duration chunkUploadTimeout = const Duration(seconds: 2),
  }) {
    return BatchUploadService(
      openSenseMapService: osemService,
      trackService: trackService,
      openSenseMapBloc: osemBloc,
      chunkUploadTimeout: chunkUploadTimeout,
    );
  }

  void stubUpload(Future<void> Function() answer) {
    when(() => osemService.uploadData(
          any(),
          any(),
          retryOptions: any(named: 'retryOptions'),
          requestTimeout: any(named: 'requestTimeout'),
          reportErrors: any(named: 'reportErrors'),
          onRetry: any(named: 'onRetry'),
        )).thenAnswer((_) => answer());
  }

  void verifyUploadCalls(int times) {
    if (times == 0) {
      verifyNever(() => osemService.uploadData(
            any(),
            any(),
            retryOptions: any(named: 'retryOptions'),
            requestTimeout: any(named: 'requestTimeout'),
            reportErrors: any(named: 'reportErrors'),
            onRetry: any(named: 'onRetry'),
          ));
      return;
    }
    verify(() => osemService.uploadData(
          any(),
          any(),
          retryOptions: any(named: 'retryOptions'),
          requestTimeout: any(named: 'requestTimeout'),
          reportErrors: false,
          onRetry: any(named: 'onRetry'),
        )).called(times);
  }

  test('uploads all chunks and marks the track as uploaded', () async {
    final track = await createTrack(_pointsForTwoChunks);
    stubUpload(() async {});
    final service = createService();
    final events = <UploadProgress>[];
    service.uploadProgressStream.listen(events.add);

    await service.uploadTrack(track, senseBox);
    await pumpEventQueue();

    verifyUploadCalls(2);
    expect(track.uploaded, 1);
    expect(events.last.status, UploadStatus.completed);
    expect(events.last.completedChunks, 2);
    expect(
      events.map((e) => (e.stage, e.completedChunks)).toList(),
      [
        (UploadStage.checkingLogin, 0),
        (null, 0), // loading track
        (UploadStage.uploadingPart, 0),
        (UploadStage.uploadingPart, 1),
        (null, 2), // completed
      ],
    );
    service.dispose();
  });

  test(
      'stops at the first chunk that does not finish in time and reports a '
      'connection problem', () async {
    final track = await createTrack(_pointsForTwoChunks);
    stubUpload(() => Completer<void>().future); // never completes
    final service = createService();
    final events = <UploadProgress>[];
    service.uploadProgressStream.listen(events.add);

    final stopwatch = Stopwatch()..start();
    await expectLater(service.uploadTrack(track, senseBox),
        throwsA(isA<TimeoutException>()));
    stopwatch.stop();
    await pumpEventQueue();

    // Second chunk is never attempted.
    verifyUploadCalls(1);
    expect(stopwatch.elapsed, lessThan(const Duration(seconds: 5)));
    expect(track.uploaded, isNot(1));
    expect(events.last.status, UploadStatus.failed);
    expect(events.last.canRetry, isTrue);
    expect(events.last.failureKind, UploadFailureKind.connection);
    expect(events.last.errorDetail, 'No response within 2 s');
    service.dispose();
  });

  test('shows the message returned by the API', () async {
    final track = await createTrack(_pointsForTwoChunks);
    stubUpload(() async => throw OpenSenseMapApiException(
        422, 'Upload to box box-id failed', '{"message":"Invalid location"}'));
    final service = createService();
    final events = <UploadProgress>[];
    service.uploadProgressStream.listen(events.add);

    await expectLater(service.uploadTrack(track, senseBox),
        throwsA(isA<OpenSenseMapApiException>()));
    await pumpEventQueue();

    verifyUploadCalls(1);
    expect(events.last.status, UploadStatus.failed);
    expect(events.last.errorDetail, 'HTTP 422: Invalid location');
    expect(events.last.failureKind, UploadFailureKind.apiResponse);
  });

  test('cancelUpload stops a running upload without marking it uploaded',
      () async {
    final track = await createTrack(_pointsForTwoChunks);
    final firstChunkStarted = Completer<void>();
    stubUpload(() {
      if (!firstChunkStarted.isCompleted) firstChunkStarted.complete();
      return Completer<void>().future; // hangs until cancelled
    });
    final service = createService(chunkUploadTimeout: const Duration(minutes: 1));

    final upload = service.uploadTrack(track, senseBox);
    await firstChunkStarted.future;
    expect(service.isUploading, isTrue);

    service.cancelUpload();
    await upload; // completes normally, does not wait for the minute

    expect(service.isUploading, isFalse);
    verifyUploadCalls(1);
    expect(track.uploaded, isNot(1));
    service.dispose();
  });

  test('reports a retry of the current chunk', () async {
    final track = await createTrack(10);
    when(() => osemService.uploadData(
          any(),
          any(),
          retryOptions: any(named: 'retryOptions'),
          requestTimeout: any(named: 'requestTimeout'),
          reportErrors: any(named: 'reportErrors'),
          onRetry: any(named: 'onRetry'),
        )).thenAnswer((invocation) async {
      final onRetry =
          invocation.namedArguments[#onRetry] as void Function(Object)?;
      onRetry?.call(TimeoutException('first attempt'));
    });
    final service = createService();
    final events = <UploadProgress>[];
    service.uploadProgressStream.listen(events.add);

    await service.uploadTrack(track, senseBox);
    await pumpEventQueue();

    final retry =
        events.firstWhere((e) => e.status == UploadStatus.retrying);
    expect(retry.totalChunks, 1);
    service.dispose();
  });

  test('shows the real network error when openSenseMap cannot be reached',
      () async {
    final track = await createTrack(10);
    // Exact error seen on Android without connectivity.
    stubUpload(() async => throw http.ClientException(
          "SocketException: Failed host lookup: 'api.opensensemap.org' "
          '(OS Error: No address associated with hostname, errno = 7)',
          Uri.parse('https://api.opensensemap.org/boxes/box-id/data'),
        ));
    final service = createService();
    final events = <UploadProgress>[];
    service.uploadProgressStream.listen(events.add);

    await expectLater(service.uploadTrack(track, senseBox),
        throwsA(isA<http.ClientException>()));
    await pumpEventQueue();

    expect(events.last.failureKind, UploadFailureKind.connection);
    expect(events.last.errorDetail,
        "Failed host lookup: 'api.opensensemap.org' (No address associated with hostname)");
  });

  test('asks to log in again when the user is not logged in', () async {
    final track = await createTrack(10);
    osemBloc.isAuthenticated = false;
    final service = createService();
    final events = <UploadProgress>[];
    service.uploadProgressStream.listen(events.add);

    await expectLater(service.uploadTrack(track, senseBox),
        throwsA(isA<PermanentAuthenticationError>()));
    await pumpEventQueue();

    verifyUploadCalls(0);
    expect(events.last.status, UploadStatus.failed);
    expect(events.last.failureKind, UploadFailureKind.authentication);
    expect(events.last.canRetry, isFalse);
    service.dispose();
  });
}
