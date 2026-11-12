
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sensebox_bike/blocs/geolocation_map_bloc.dart';
import 'package:sensebox_bike/blocs/recording_bloc.dart';
import 'package:sensebox_bike/models/geolocation_data.dart';
import '../mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  
  group('GeolocationMapBloc', () {
    late GeolocationMapBloc bloc;
    late MockGeolocationBloc mockGeolocationBloc;
    late MockOpenSenseMapBloc mockOpenSenseMapBloc;
    late MockBleBloc mockBleBloc;
    late MockIsarService mockIsarService;
    late MockTrackBloc mockTrackBloc;
    late MockSettingsBloc mockSettingsBloc;
    late RecordingBloc recordingBloc;

    setUp(() {
      mockGeolocationBloc = MockGeolocationBloc();
      mockOpenSenseMapBloc = MockOpenSenseMapBloc();
      mockBleBloc = MockBleBloc();
      mockIsarService = MockIsarService();
      mockTrackBloc = MockTrackBloc();
      mockSettingsBloc = MockSettingsBloc();
      
      // Setup mocks before creating RecordingBloc
      when(() => mockGeolocationBloc.geolocationStream)
          .thenAnswer((_) => Stream.empty());
      
      // Create RecordingBloc with correct parameters
      recordingBloc = RecordingBloc(
        mockIsarService,
        mockBleBloc,
        mockTrackBloc,
        mockOpenSenseMapBloc,
        mockSettingsBloc,
      );

      bloc = GeolocationMapBloc(
        geolocationBloc: mockGeolocationBloc,
        recordingBloc: recordingBloc,
        osemBloc: mockOpenSenseMapBloc,
      );
    });

    tearDown(() {
      bloc.dispose();
    });

    group('Initialization', () {
      test('should initialize with correct initial state', () {
        expect(bloc.isRecording, false);
        expect(bloc.isAuthenticated, false);
        expect(bloc.gpsBuffer, isEmpty);
        expect(bloc.latestLocation, isNull);
        expect(bloc.hasGpsData, false);
      });
    });

    group('State Queries', () {
      test('should return correct shouldShowTrack state', () {
        // Not recording, no data
        expect(bloc.shouldShowTrack, false);
      });

      test('should return correct shouldShowCurrentLocation state', () {
        // No location data
        expect(bloc.shouldShowCurrentLocation, false);
      });

      test('should return correct lastLocationForMap', () {
        // No data
        expect(bloc.lastLocationForMap, isNull);
      });
    });

    group('Public Methods', () {
      test('should clear GPS buffer when clearGpsBuffer is called', () {
        bloc.clearGpsBuffer();
        expect(bloc.gpsBuffer, isEmpty);
      });
    });
  });

  group('GeolocationMapBloc GPS buffer while recording', () {
    late StreamController<GeolocationData> positions;
    late GeolocationMapBloc bloc;

    GeolocationData point(double latitude, int second) => GeolocationData()
      ..latitude = latitude
      ..longitude = 7.6
      ..timestamp = DateTime.utc(2026, 1, 1, 12, 0, second);

    setUp(() {
      positions = StreamController<GeolocationData>.broadcast();
      final geolocationBloc = MockGeolocationBloc();
      when(() => geolocationBloc.geolocationStream)
          .thenAnswer((_) => positions.stream);
      final recordingBloc = MockRecordingBloc()..setRecording(true);
      bloc = GeolocationMapBloc(
        geolocationBloc: geolocationBloc,
        recordingBloc: recordingBloc,
        osemBloc: MockOpenSenseMapBloc(),
      );
    });

    tearDown(() async {
      bloc.dispose();
      await positions.close();
    });

    test('keeps every new point and skips a repeated last point', () async {
      final first = point(51.0, 0);
      positions
        ..add(first)
        ..add(point(51.001, 1))
        ..add(point(51.001, 1))
        ..add(point(51.002, 2));
      await pumpEventQueue();

      expect(bloc.gpsBuffer, hasLength(3));
      expect(bloc.gpsBuffer.first, same(first));
      expect(bloc.lastLocationForMap?.latitude, 51.002);
    });

    test('exposes the buffer read-only', () async {
      positions.add(point(51.0, 0));
      await pumpEventQueue();

      expect(() => bloc.gpsBuffer.add(point(52.0, 1)), throwsUnsupportedError);
    });
  });
} 