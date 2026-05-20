import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:mocktail/mocktail.dart';
import 'package:sensebox_bike/blocs/recording_bloc.dart';
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

  late MockGeolocator mockGeolocator;
  late MockIsarService mockIsarService;
  late MockBleBloc mockBleBloc;
  late MockTrackBloc mockTrackBloc;
  late MockOpenSenseMapBloc mockOpenSenseMapBloc;
  late MockSettingsBloc mockSettingsBloc;
  late RecordingBloc recordingBloc;
  final defaultTargetPlatformOverride = debugDefaultTargetPlatformOverride;

  setUp(() {
    mockGeolocator = MockGeolocator();
    mockIsarService = MockIsarService();
    mockBleBloc = MockBleBloc();
    mockTrackBloc = MockTrackBloc();
    mockOpenSenseMapBloc = MockOpenSenseMapBloc();
    mockSettingsBloc = MockSettingsBloc();

    geo.GeolocatorPlatform.instance = mockGeolocator;

    when(() => mockSettingsBloc.directUploadMode).thenReturn(false);
    when(() => mockOpenSenseMapBloc.openSenseMapService)
        .thenReturn(MockOpenSenseMapService());

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
    debugDefaultTargetPlatformOverride = defaultTargetPlatformOverride;
  });

  group('RecordingBloc.startRecording', () {
    test('should not start recording if location permission is denied', () async {
      when(() => mockGeolocator.isLocationServiceEnabled())
          .thenAnswer((_) async => false);

      await recordingBloc.startRecording();

      expect(recordingBloc.isRecording, isFalse);
      verifyNever(() => mockTrackBloc.startNewTrack());
    });

    test('should not start recording if location permission is denied after request',
        () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

      when(() => mockGeolocator.isLocationServiceEnabled())
          .thenAnswer((_) async => true);
      when(() => mockGeolocator.checkPermission())
          .thenAnswer((_) async => geo.LocationPermission.denied);
      when(() => mockGeolocator.requestPermission())
          .thenAnswer((_) async => geo.LocationPermission.denied);

      await recordingBloc.startRecording();

      expect(recordingBloc.isRecording, isFalse);
      verifyNever(() => mockTrackBloc.startNewTrack());
    });
  });

  group('RecordingBloc.stopRecording', () {
    test('should not fail if called when not recording', () async {
      await recordingBloc.stopRecording();

      expect(recordingBloc.isRecording, isFalse);
    });

    test('calls trackBloc.endTrack when stopping', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

      when(() => mockGeolocator.isLocationServiceEnabled())
          .thenAnswer((_) async => true);
      when(() => mockGeolocator.checkPermission())
          .thenAnswer((_) async => geo.LocationPermission.always);
      when(() => mockBleBloc.isReadyForRecording).thenReturn(true);
      when(() => mockTrackBloc.startNewTrack(isDirectUpload: any(named: 'isDirectUpload')))
          .thenAnswer((_) async => 1);
      when(() => mockTrackBloc.currentTrack).thenReturn(createMockTrackData());
      when(() => mockTrackBloc.endTrack()).thenReturn(null);

      await recordingBloc.startRecording();
      expect(recordingBloc.isRecording, isTrue);

      await recordingBloc.stopRecording();

      expect(recordingBloc.isRecording, isFalse);
      expect(recordingBloc.currentTrack, isNull);
      verify(() => mockTrackBloc.endTrack()).called(1);
    });
  });
}
