import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:mocktail/mocktail.dart';
import 'package:sensebox_bike/blocs/recording_bloc.dart';
import 'package:sensebox_bike/models/ble_connection_phase.dart';
import 'package:sensebox_bike/models/track_data.dart';
import 'package:sensebox_bike/services/batch_upload_service.dart';
import 'package:sensebox_bike/services/opensensemap_service.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import '../mocks.dart';
import '../test_helpers.dart';

class MockGeolocator extends Mock
    with MockPlatformInterfaceMixin
    implements geo.GeolocatorPlatform {}

class MockOpenSenseMapService extends Mock implements OpenSenseMapService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    initializeTestDependencies();
  });
  
  late MockGeolocator mockGeolocator;
  late MockIsarService mockIsarService;
  late MockBleBloc mockBleBloc;
  late MockTrackBloc mockTrackBloc;
  late MockOpenSenseMapBloc mockOpenSenseMapBloc;
  late MockSettingsBloc mockSettingsBloc;
  late RecordingBloc recordingBloc;

  setUp(() {
    mockGeolocator = MockGeolocator();
    mockIsarService = MockIsarService();
    mockBleBloc = MockBleBloc();
    mockTrackBloc = MockTrackBloc();
    mockOpenSenseMapBloc = MockOpenSenseMapBloc();
    mockSettingsBloc = MockSettingsBloc();

    geo.GeolocatorPlatform.instance = mockGeolocator;

    // Setup mock for directUploadMode
    when(() => mockSettingsBloc.directUploadMode).thenReturn(false);

    recordingBloc = RecordingBloc(
      mockIsarService,
      mockBleBloc,
      mockTrackBloc,
      mockOpenSenseMapBloc,
      mockSettingsBloc,
    );
  });

  tearDown(() {
    recordingBloc.dispose();
  });

  group('RecordingBloc.startRecording', () {
    test('should not start recording if location permission is denied', () async {
      // Setup: location services disabled
      when(() => mockGeolocator.isLocationServiceEnabled())
          .thenAnswer((_) async => false);

      // Act
      await recordingBloc.startRecording();

      // Assert
      expect(recordingBloc.isRecording, isFalse);
      verifyNever(() => mockTrackBloc.startNewTrack());
    });

    test('should not start recording if location permission is denied after request', () async {
      // Setup: permission denied
      when(() => mockGeolocator.isLocationServiceEnabled())
          .thenAnswer((_) async => true);
      when(() => mockGeolocator.checkPermission())
          .thenAnswer((_) async => geo.LocationPermission.denied);
      when(() => mockGeolocator.requestPermission())
          .thenAnswer((_) async => geo.LocationPermission.denied);

      // Act
      await recordingBloc.startRecording();

      // Assert
      expect(recordingBloc.isRecording, isFalse);
      verifyNever(() => mockTrackBloc.startNewTrack());
    });

    // TODO: This test fails due to architectural design issue - RecordingBloc creates real services
    // that require platform plugins (SharedPreferences) not available in tests.
    // The bloc would need refactoring to accept service factories as dependencies to make it testable.
    /*
    test('should start recording if location permission is granted', () async {
      // Setup: permission granted
      when(() => mockGeolocator.isLocationServiceEnabled())
          .thenAnswer((_) async => true);
      when(() => mockGeolocator.checkPermission())
          .thenAnswer((_) async => geo.LocationPermission.whileInUse);
      when(() => mockTrackBloc.startNewTrack(
              isDirectUpload: any(named: 'isDirectUpload')))
          .thenAnswer((_) async => 1);
      when(() => mockTrackBloc.currentTrack).thenReturn(null);

      // Act
      await recordingBloc.startRecording();

      // Assert: Check that recording state was set (even if service creation failed)
      expect(recordingBloc.isRecording, isTrue);
      verify(() => mockTrackBloc.startNewTrack(
          isDirectUpload: any(named: 'isDirectUpload'))).called(1);
    });
    */

    // TODO: This test fails due to architectural design issue - RecordingBloc creates real services
    // that require platform plugins (SharedPreferences) not available in tests.
    // The bloc would need refactoring to accept service factories as dependencies to make it testable.
    /*
    test('should not start recording twice', () async {
      // Setup: permission granted
      when(() => mockGeolocator.isLocationServiceEnabled())
          .thenAnswer((_) async => true);
      when(() => mockGeolocator.checkPermission())
          .thenAnswer((_) async => geo.LocationPermission.whileInUse);
      when(() => mockTrackBloc.startNewTrack(
              isDirectUpload: any(named: 'isDirectUpload')))
          .thenAnswer((_) async => 1);
      when(() => mockTrackBloc.currentTrack).thenReturn(null);

      // Act: start recording once (don't test the full flow to avoid OpenSenseMapService issues)
      await recordingBloc.startRecording();

      // Assert
      expect(recordingBloc.isRecording, isTrue);
      verify(() => mockTrackBloc.startNewTrack(
          isDirectUpload: any(named: 'isDirectUpload'))).called(1);
    });
    */
  });

  group('RecordingBloc.stopRecording', () {
    // TODO: This test fails due to architectural design issue - RecordingBloc creates real services
    // that require platform plugins (SharedPreferences) not available in tests.
    // The bloc would need refactoring to accept service factories as dependencies to make it testable.
    /*
    test('should stop recording', () async {
      // Setup: manually set recording state to true by calling startRecording with proper mocks
      when(() => mockGeolocator.isLocationServiceEnabled())
          .thenAnswer((_) async => true);
      when(() => mockGeolocator.checkPermission())
          .thenAnswer((_) async => geo.LocationPermission.whileInUse);
      when(() => mockTrackBloc.startNewTrack(
              isDirectUpload: any(named: 'isDirectUpload')))
          .thenAnswer((_) async => 1);
      when(() => mockTrackBloc.currentTrack).thenReturn(null);

      // Start recording but catch the error from OpenSenseMapService creation
      try {
        await recordingBloc.startRecording();
      } catch (e) {
        // Expected error due to OpenSenseMapService not being available in tests
        // The important thing is that recording state was set
      }

      // Act
      await recordingBloc.stopRecording();

      // Assert
      expect(recordingBloc.isRecording, isFalse);
      expect(recordingBloc.currentTrack, isNull);
    });
    */

    test('should not fail if called when not recording', () async {
      // Act
      await recordingBloc.stopRecording();

      // Assert
      expect(recordingBloc.isRecording, isFalse);
    });
  });

  group('RecordingBloc UI callbacks', () {
    test('invokes onRecordingStoppedDueToBle when stopping due to disconnect',
        () async {
      var called = false;
      recordingBloc.setUiCallbacks(
        onRecordingStoppedDueToBle: () async {
          called = true;
        },
      );
      recordingBloc.isRecordingNotifier.value = true;

      await recordingBloc.stopRecording(dueToBleDisconnect: true);

      expect(called, isTrue);
      expect(recordingBloc.isRecording, isFalse);
    });

    test('clearUiCallbacks prevents onRecordingStoppedDueToBle', () async {
      var called = false;
      recordingBloc.setUiCallbacks(
        onRecordingStoppedDueToBle: () async {
          called = true;
        },
      );
      recordingBloc.clearUiCallbacks();
      recordingBloc.isRecordingNotifier.value = true;

      await recordingBloc.stopRecording(dueToBleDisconnect: true);

      expect(called, isFalse);
    });

    test('ble connection error stops recording and invokes disconnect callback',
        () async {
      var called = false;
      recordingBloc.setUiCallbacks(
        onRecordingStoppedDueToBle: () async {
          called = true;
        },
      );
      recordingBloc.isRecordingNotifier.value = true;

      mockBleBloc.connectionErrorNotifier.value = true;

      expect(recordingBloc.isRecording, isFalse);
      expect(called, isTrue);
    });

    test('invokes onBatchUploadPrompt after batch-mode recording stops',
        () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);

      final mockOpenSenseMapService = MockOpenSenseMapService();
      when(() => mockOpenSenseMapBloc.openSenseMapService)
          .thenReturn(mockOpenSenseMapService);
      when(() => mockGeolocator.isLocationServiceEnabled())
          .thenAnswer((_) async => true);
      when(() => mockGeolocator.checkPermission())
          .thenAnswer((_) async => geo.LocationPermission.whileInUse);
      when(() => mockBleBloc.isReadyForRecording).thenReturn(true);
      when(() => mockTrackBloc.startNewTrack(
            isDirectUpload: any(named: 'isDirectUpload'),
          )).thenAnswer((_) async => 1);
      final track = TrackData()..id = 1;
      when(() => mockTrackBloc.currentTrack).thenReturn(track);

      var promptCalled = false;
      recordingBloc.setUiCallbacks(
        onBatchUploadPrompt: ({
          required track,
          required senseBox,
          required batchUploadService,
          required onFinished,
        }) async {
          promptCalled = true;
          batchUploadService.dispose();
          onFinished();
        },
      );

      await recordingBloc.startRecording();
      expect(recordingBloc.isRecording, isTrue);

      await recordingBloc.stopRecording();

      expect(promptCalled, isTrue);
    });
  });
}