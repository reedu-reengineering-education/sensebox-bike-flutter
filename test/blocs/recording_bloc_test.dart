import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:mocktail/mocktail.dart';
import 'package:sensebox_bike/blocs/recording_bloc.dart';
import 'package:sensebox_bike/blocs/opensensemap_bloc.dart';
import 'package:sensebox_bike/blocs/settings_bloc.dart';
import 'package:sensebox_bike/blocs/track_bloc.dart';
import 'package:sensebox_bike/services/isar_service.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import '../mocks.dart';

class MockGeolocator extends Mock
    with MockPlatformInterfaceMixin
    implements geo.GeolocatorPlatform {}

class MockIsarService extends Mock implements IsarService {}

class MockTrackBloc extends Mock with ChangeNotifier implements TrackBloc {}

class MockOpenSenseMapBloc extends Mock
    with ChangeNotifier
    implements OpenSenseMapBloc {}

class MockSettingsBloc extends Mock
    with ChangeNotifier
    implements SettingsBloc {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  
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

    // Setup mock for senseBoxStream
    when(() => mockOpenSenseMapBloc.senseBoxStream).thenAnswer(
      (_) => Stream.value(null),
    );

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

    test('should start recording if location permission is granted', () async {
      // Setup: permission granted
      when(() => mockGeolocator.isLocationServiceEnabled())
          .thenAnswer((_) async => true);
      when(() => mockGeolocator.checkPermission())
          .thenAnswer((_) async => geo.LocationPermission.whileInUse);
      when(() => mockTrackBloc.startNewTrack()).thenAnswer((_) async => 1);
      when(() => mockTrackBloc.currentTrack).thenReturn(null);

      // Act
      await recordingBloc.startRecording();

      // Assert
      expect(recordingBloc.isRecording, isTrue);
      verify(() => mockTrackBloc.startNewTrack()).called(1);
    });

    test('should not start recording twice', () async {
      // Setup: permission granted
      when(() => mockGeolocator.isLocationServiceEnabled())
          .thenAnswer((_) async => true);
      when(() => mockGeolocator.checkPermission())
          .thenAnswer((_) async => geo.LocationPermission.whileInUse);
      when(() => mockTrackBloc.startNewTrack()).thenAnswer((_) async => 1);
      when(() => mockTrackBloc.currentTrack).thenReturn(null);

      // Act: start recording twice
      await recordingBloc.startRecording();
      await recordingBloc.startRecording();

      // Assert
      expect(recordingBloc.isRecording, isTrue);
      verify(() => mockTrackBloc.startNewTrack()).called(1); // Only called once
    });
  });

  group('RecordingBloc.stopRecording', () {
    test('should stop recording', () async {
      // Setup: manually set recording state to true by calling startRecording with proper mocks
      when(() => mockGeolocator.isLocationServiceEnabled())
          .thenAnswer((_) async => true);
      when(() => mockGeolocator.checkPermission())
          .thenAnswer((_) async => geo.LocationPermission.whileInUse);
      when(() => mockTrackBloc.startNewTrack()).thenAnswer((_) async => 1);
      when(() => mockTrackBloc.currentTrack).thenReturn(null);

      await recordingBloc.startRecording();

      // Act
      await recordingBloc.stopRecording();

      // Assert
      expect(recordingBloc.isRecording, isFalse);
      expect(recordingBloc.currentTrack, isNull);
    });

    test('should not fail if called when not recording', () async {
      // Act
      await recordingBloc.stopRecording();

      // Assert
      expect(recordingBloc.isRecording, isFalse);
    });
  });
}