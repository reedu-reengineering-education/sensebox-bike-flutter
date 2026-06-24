import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:mocktail/mocktail.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:sensebox_bike/blocs/opensensemap_bloc.dart';
import 'package:sensebox_bike/blocs/recording_bloc.dart';
import 'package:sensebox_bike/blocs/track_bloc.dart';
import 'package:sensebox_bike/models/data_collection_mode.dart';
import 'package:sensebox_bike/models/sensebox.dart';
import 'package:sensebox_bike/models/track_data.dart';
import 'package:sensebox_bike/services/opensensemap_service.dart';
import '../mocks.dart';
import '../test_helpers.dart';

class MockGeolocatorForRecording extends Mock
    with MockPlatformInterfaceMixin
    implements geo.GeolocatorPlatform {}

class MockOpenSenseMapServiceForRecording extends Mock
    implements OpenSenseMapService {}

class FakeTrackBlocForCollectionMode extends Fake implements TrackBloc {
  TrackData? currentTrackValue = TrackData();
  String? capturedDataCollectionMode;
  int? capturedCollectionIntervalSeconds;

  @override
  TrackData? get currentTrack => currentTrackValue;

  @override
  Future<int> startNewTrack({
    bool? isDirectUpload,
    String? dataCollectionMode,
    int? collectionIntervalSeconds,
  }) async {
    capturedDataCollectionMode = dataCollectionMode;
    capturedCollectionIntervalSeconds = collectionIntervalSeconds;
    return 1;
  }
}

class FakeOpenSenseMapBlocForRecording extends Fake implements OpenSenseMapBloc {
  FakeOpenSenseMapBlocForRecording({
    required this.senseBoxStreamValue,
    required this.openSenseMapServiceValue,
  });

  final Stream<SenseBox?> senseBoxStreamValue;
  final OpenSenseMapService openSenseMapServiceValue;

  @override
  Stream<SenseBox?> get senseBoxStream => senseBoxStreamValue;

  @override
  OpenSenseMapService get openSenseMapService => openSenseMapServiceValue;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RecordingBloc collection mode resolution', () {
    late MockIsarService mockIsarService;
    late MockBleBloc mockBleBloc;
    late FakeTrackBlocForCollectionMode fakeTrackBloc;
    late FakeOpenSenseMapBlocForRecording fakeOpenSenseMapBloc;
    late MockSettingsBloc mockSettingsBloc;
    late StreamController<SenseBox?> senseBoxController;
    late MockGeolocatorForRecording mockGeolocator;
    late RecordingBloc recordingBloc;

    setUp(() {
      mockIsarService = MockIsarService();
      mockBleBloc = MockBleBloc();
      fakeTrackBloc = FakeTrackBlocForCollectionMode();
      mockSettingsBloc = MockSettingsBloc();
      mockGeolocator = MockGeolocatorForRecording();
      senseBoxController = StreamController<SenseBox?>.broadcast();

      fakeOpenSenseMapBloc = FakeOpenSenseMapBlocForRecording(
        senseBoxStreamValue: senseBoxController.stream,
        openSenseMapServiceValue: MockOpenSenseMapServiceForRecording(),
      );

      geo.GeolocatorPlatform.instance = mockGeolocator;
      setupMockGeolocator(mockGeolocator, testLat1, testLng1);

      when(() => mockSettingsBloc.directUploadMode).thenReturn(false);
      when(() => mockSettingsBloc.dataCollectionMode)
          .thenReturn(DataCollectionMode.postRide);
      when(() => mockSettingsBloc.collectionIntervalSeconds).thenReturn(60);
    });

    tearDown(() async {
      recordingBloc.dispose();
      await senseBoxController.close();
    });

    test('uses postRide mode from settings', () async {
      recordingBloc = RecordingBloc(
        mockIsarService,
        mockBleBloc,
        fakeTrackBloc,
        fakeOpenSenseMapBloc,
        mockSettingsBloc,
      );

      await recordingBloc.startRecording();

      expect(recordingBloc.activeCollectionMode, DataCollectionMode.postRide);
      expect(
        recordingBloc.activeCollectionMode.usesPeriodicTimer,
        isFalse,
      );
      expect(fakeTrackBloc.capturedDataCollectionMode, 'postRide');
      expect(fakeTrackBloc.capturedCollectionIntervalSeconds, isNull);
    });

    test('uses periodic mode and interval from settings', () async {
      when(() => mockSettingsBloc.dataCollectionMode)
          .thenReturn(DataCollectionMode.periodic);
      when(() => mockSettingsBloc.collectionIntervalSeconds).thenReturn(45);

      recordingBloc = RecordingBloc(
        mockIsarService,
        mockBleBloc,
        fakeTrackBloc,
        fakeOpenSenseMapBloc,
        mockSettingsBloc,
      );

      await recordingBloc.startRecording();

      expect(recordingBloc.activeCollectionMode, DataCollectionMode.periodic);
      expect(recordingBloc.collectionIntervalSeconds, 45);
      expect(recordingBloc.activeCollectionMode.usesPeriodicTimer, isTrue);
      expect(fakeTrackBloc.capturedDataCollectionMode, 'periodic');
      expect(fakeTrackBloc.capturedCollectionIntervalSeconds, 45);
    });
  });
}
