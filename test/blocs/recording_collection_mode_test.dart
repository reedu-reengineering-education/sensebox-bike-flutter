import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:mocktail/mocktail.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:sensebox_bike/blocs/opensensemap_bloc.dart';
import 'package:sensebox_bike/blocs/recording_bloc.dart';
import 'package:sensebox_bike/blocs/track_bloc.dart';
import 'package:sensebox_bike/models/box_configuration.dart';
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
  DataCollectionMode? capturedDataCollectionMode;
  int? capturedCollectionIntervalSeconds;

  @override
  TrackData? get currentTrack => currentTrackValue;

  @override
  Future<int> startNewTrack({
    bool? isDirectUpload,
    DataCollectionMode? dataCollectionMode,
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

  setUpAll(() {
    registerFallbackValue(DataCollectionMode.gpsDriven);
  });

  group('RecordingBloc collection mode resolution', () {
    late MockIsarService mockIsarService;
    late MockBleBloc mockBleBloc;
    late FakeTrackBlocForCollectionMode fakeTrackBloc;
    late FakeOpenSenseMapBlocForRecording fakeOpenSenseMapBloc;
    late MockSettingsBloc mockSettingsBloc;
    late MockConfigurationBloc mockConfigurationBloc;
    late StreamController<SenseBox?> senseBoxController;
    late MockGeolocatorForRecording mockGeolocator;
    late RecordingBloc recordingBloc;

    setUp(() {
      mockIsarService = MockIsarService();
      mockBleBloc = MockBleBloc();
      fakeTrackBloc = FakeTrackBlocForCollectionMode();
      mockSettingsBloc = MockSettingsBloc();
      mockConfigurationBloc = MockConfigurationBloc();
      mockGeolocator = MockGeolocatorForRecording();
      senseBoxController = StreamController<SenseBox?>.broadcast();

      fakeOpenSenseMapBloc = FakeOpenSenseMapBlocForRecording(
        senseBoxStreamValue: senseBoxController.stream,
        openSenseMapServiceValue: MockOpenSenseMapServiceForRecording(),
      );

      geo.GeolocatorPlatform.instance = mockGeolocator;
      setupMockGeolocator(mockGeolocator, testLat1, testLng1);

      when(() => mockSettingsBloc.directUploadMode).thenReturn(false);
      when(() => mockSettingsBloc.lastResolvedDataCollectionMode)
          .thenReturn(DataCollectionMode.gpsDriven);
      when(() => mockSettingsBloc.lastResolvedCollectionIntervalSeconds)
          .thenReturn(defaultCollectionIntervalSeconds);
      when(
        () => mockSettingsBloc.setLastResolvedCollectionMode(
          mode: any(named: 'mode'),
          collectionIntervalSeconds: any(named: 'collectionIntervalSeconds'),
        ),
      ).thenAnswer((_) async {});
      when(() => mockConfigurationBloc.getBoxConfigurationByGrouptag(any()))
          .thenReturn(null);
    });

    tearDown(() async {
      recordingBloc.dispose();
      await senseBoxController.close();
    });

    test('uses gpsDriven from settings by default', () async {
      recordingBloc = RecordingBloc(
        mockIsarService,
        mockBleBloc,
        fakeTrackBloc,
        fakeOpenSenseMapBloc,
        mockSettingsBloc,
        mockConfigurationBloc,
      );

      await recordingBloc.startRecording();

      expect(recordingBloc.activeCollectionMode, DataCollectionMode.gpsDriven);
      expect(recordingBloc.activeCollectionMode.usesPeriodicTimer, isFalse);
      expect(
        fakeTrackBloc.capturedDataCollectionMode,
        DataCollectionMode.gpsDriven,
      );
      expect(fakeTrackBloc.capturedCollectionIntervalSeconds, isNull);
      verify(
        () => mockSettingsBloc.setLastResolvedCollectionMode(
          mode: DataCollectionMode.gpsDriven,
          collectionIntervalSeconds: defaultCollectionIntervalSeconds,
        ),
      ).called(1);
    });

    test('uses periodic mode from settings', () async {
      when(() => mockSettingsBloc.lastResolvedDataCollectionMode)
          .thenReturn(DataCollectionMode.periodic);
      when(() => mockSettingsBloc.lastResolvedCollectionIntervalSeconds)
          .thenReturn(45);

      recordingBloc = RecordingBloc(
        mockIsarService,
        mockBleBloc,
        fakeTrackBloc,
        fakeOpenSenseMapBloc,
        mockSettingsBloc,
        mockConfigurationBloc,
      );

      await recordingBloc.startRecording();

      expect(recordingBloc.activeCollectionMode, DataCollectionMode.periodic);
      expect(recordingBloc.collectionIntervalSeconds, 45);
      expect(fakeTrackBloc.capturedCollectionIntervalSeconds, 45);
      verify(
        () => mockSettingsBloc.setLastResolvedCollectionMode(
          mode: DataCollectionMode.periodic,
          collectionIntervalSeconds: 45,
        ),
      ).called(1);
    });

    test('uses settings mode even when box config differs', () async {
      when(() => mockSettingsBloc.lastResolvedDataCollectionMode)
          .thenReturn(DataCollectionMode.onTap);
      when(() => mockConfigurationBloc.getBoxConfigurationByGrouptag(any()))
          .thenReturn(
        BoxConfiguration(
          id: 'classic',
          displayName: '2022',
          defaultGrouptag: 'classic',
          sensors: const [],
          dataCollectionMode: DataCollectionMode.gpsDriven,
        ),
      );

      recordingBloc = RecordingBloc(
        mockIsarService,
        mockBleBloc,
        fakeTrackBloc,
        fakeOpenSenseMapBloc,
        mockSettingsBloc,
        mockConfigurationBloc,
      );

      senseBoxController.add(
        SenseBox(
          sId: 'classic-box',
          name: 'Classic',
          grouptag: ['bike', 'classic'],
        ),
      );
      await Future.delayed(shortDelay);

      await recordingBloc.startRecording();

      expect(recordingBloc.activeCollectionMode, DataCollectionMode.onTap);
      expect(
        fakeTrackBloc.capturedDataCollectionMode,
        DataCollectionMode.onTap,
      );
      expect(fakeTrackBloc.capturedCollectionIntervalSeconds, isNull);
    });

    test('uses onTap mode from settings', () async {
      when(() => mockSettingsBloc.lastResolvedDataCollectionMode)
          .thenReturn(DataCollectionMode.onTap);

      recordingBloc = RecordingBloc(
        mockIsarService,
        mockBleBloc,
        fakeTrackBloc,
        fakeOpenSenseMapBloc,
        mockSettingsBloc,
        mockConfigurationBloc,
      );

      await recordingBloc.startRecording();

      expect(recordingBloc.activeCollectionMode, DataCollectionMode.onTap);
      expect(
        recordingBloc.activeCollectionMode.showsManualSampleButton,
        isTrue,
      );
      expect(
        fakeTrackBloc.capturedDataCollectionMode,
        DataCollectionMode.onTap,
      );
      expect(fakeTrackBloc.capturedCollectionIntervalSeconds, isNull);
      verify(
        () => mockSettingsBloc.setLastResolvedCollectionMode(
          mode: DataCollectionMode.onTap,
          collectionIntervalSeconds: defaultCollectionIntervalSeconds,
        ),
      ).called(1);
    });
  });
}
