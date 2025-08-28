import 'package:flutter_test/flutter_test.dart';
import 'package:sensebox_bike/blocs/track_bloc.dart';
import 'package:sensebox_bike/services/isar_service.dart';
import 'package:sensebox_bike/models/track_data.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter/foundation.dart';

import '../mocks.dart';

void main() {
  late TrackBloc trackBloc;
  late MockIsarService mockIsarService;

  setUpAll(() {
    registerFallbackValue(TrackData());
  });

  setUp(() {
    mockIsarService = MockIsarService();
    trackBloc = TrackBloc(mockIsarService);
  });

  tearDown(() {
    trackBloc.dispose();
  });

  group('TrackBloc', () {
    test('startNewTrack without isDirectUpload parameter sets isDirectUpload to default true', () async {
      when(() => mockIsarService.mockTrackService.saveTrack(any()))
          .thenAnswer((_) async => 1);

      final trackId = await trackBloc.startNewTrack();

      expect(trackId, equals(1));
      expect(trackBloc.currentTrack, isNotNull);
      expect(trackBloc.currentTrack!.isDirectUpload, isTrue);
    });

    test('startNewTrack with isDirectUpload = true sets isDirectUpload to true', () async {
      when(() => mockIsarService.mockTrackService.saveTrack(any()))
          .thenAnswer((_) async => 1);

      final trackId = await trackBloc.startNewTrack(isDirectUpload: true);

      expect(trackId, equals(1));
      expect(trackBloc.currentTrack, isNotNull);
      expect(trackBloc.currentTrack!.isDirectUpload, isTrue);
    });

    test('startNewTrack with isDirectUpload = false sets isDirectUpload to false', () async {
      when(() => mockIsarService.mockTrackService.saveTrack(any()))
          .thenAnswer((_) async => 1);

      final trackId = await trackBloc.startNewTrack(isDirectUpload: false);

      expect(trackId, equals(1));
      expect(trackBloc.currentTrack, isNotNull);
      expect(trackBloc.currentTrack!.isDirectUpload, isFalse);
    });

    test('endTrack clears currentTrack', () {
      trackBloc.endTrack();
      expect(trackBloc.currentTrack, isNull);
    });
  });
}
