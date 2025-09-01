import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sensebox_bike/blocs/track_bloc.dart';
import 'package:sensebox_bike/models/track_data.dart';
import 'package:sensebox_bike/models/track_status_info.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sensebox_bike/l10n/app_localizations.dart';

import '../mocks.dart';

class MockAppLocalizations extends Mock implements AppLocalizations {
  @override
  String get trackStatusUploaded => 'Uploaded';

  @override
  String get trackStatusNotUploaded => 'Not uploaded';

  @override
  String get trackStatusUploadFailed => 'Upload failed';

  @override
  String get settingsUploadModeDirect => 'Direct Upload (Beta)';

  @override
  String generalTrackDurationShort(String hours, String minutes) =>
      '${hours}h ${minutes}m';

  @override
  String generalTrackDistance(String distance) => '${distance} km';
}

void main() {
  late TrackBloc trackBloc;
  late MockIsarService mockIsarService;
  late MockAppLocalizations mockLocalizations;
  late ThemeData testTheme;

  setUpAll(() {
    registerFallbackValue(TrackData());
  });

  setUp(() {
    mockIsarService = MockIsarService();
    trackBloc = TrackBloc(mockIsarService);
    mockLocalizations = MockAppLocalizations();
    testTheme = ThemeData.light();
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
      expect(trackBloc.currentTrack!.isDirectUpload, equals(1));
    });

    test('startNewTrack with isDirectUpload = true sets isDirectUpload to true', () async {
      when(() => mockIsarService.mockTrackService.saveTrack(any()))
          .thenAnswer((_) async => 1);

      final trackId = await trackBloc.startNewTrack(isDirectUpload: true);

      expect(trackId, equals(1));
      expect(trackBloc.currentTrack, isNotNull);
      expect(trackBloc.currentTrack!.isDirectUpload, equals(1));
    });

    test('startNewTrack with isDirectUpload = false sets isDirectUpload to false', () async {
      when(() => mockIsarService.mockTrackService.saveTrack(any()))
          .thenAnswer((_) async => 1);

      final trackId = await trackBloc.startNewTrack(isDirectUpload: false);

      expect(trackId, equals(1));
      expect(trackBloc.currentTrack, isNotNull);
      expect(trackBloc.currentTrack!.isDirectUpload, equals(0));
    });

    test('endTrack clears currentTrack', () {
      trackBloc.endTrack();
      expect(trackBloc.currentTrack, isNull);
    });
  });

  group('TrackBloc - Status Calculation', () {
    test(
        'getEstimatedTrackStatusInfo returns correct info for direct upload track',
        () {
      final track = TrackData()..isDirectUpload = 1;

      final statusInfo =
          trackBloc.getEstimatedTrackStatusInfo(
          track, testTheme, mockLocalizations);

      expect(statusInfo.status, equals(TrackStatus.directUpload));
      expect(statusInfo.color, equals(Colors.blue));
      expect(statusInfo.icon, equals(Icons.cloud_sync));
      expect(statusInfo.text, equals('Direct Upload (Beta)'));
    });

    test('getEstimatedTrackStatusInfo returns correct info for uploaded track',
        () {
      final track = TrackData()
        ..isDirectUpload = 0
        ..uploaded = 1;

      final statusInfo =
          trackBloc.getEstimatedTrackStatusInfo(
          track, testTheme, mockLocalizations);

      expect(statusInfo.status, equals(TrackStatus.uploaded));
      expect(statusInfo.color, equals(Colors.green));
      expect(statusInfo.icon, equals(Icons.cloud_done));
      expect(statusInfo.text, equals('Uploaded'));
    });

    test(
        'getEstimatedTrackStatusInfo returns correct info for failed upload track',
        () {
      final track = TrackData()
        ..isDirectUpload = 0
        ..uploaded = 0
        ..uploadAttempts = 1;

      final statusInfo =
          trackBloc.getEstimatedTrackStatusInfo(
          track, testTheme, mockLocalizations);

      expect(statusInfo.status, equals(TrackStatus.uploadFailed));
      expect(statusInfo.color, equals(testTheme.colorScheme.error));
      expect(statusInfo.icon, equals(Icons.cloud_off));
      expect(statusInfo.text, equals('Upload failed'));
    });

    test(
        'getEstimatedTrackStatusInfo returns correct info for not uploaded track',
        () {
      final track = TrackData()
        ..isDirectUpload = 0
        ..uploaded = 0
        ..uploadAttempts = 0;

      final statusInfo =
          trackBloc.getEstimatedTrackStatusInfo(
          track, testTheme, mockLocalizations);

      expect(statusInfo.status, equals(TrackStatus.notUploaded));
      expect(statusInfo.color, equals(testTheme.colorScheme.outline));
      expect(statusInfo.icon, equals(Icons.cloud_upload));
      expect(statusInfo.text, equals('Not uploaded'));
    });
  });

  group('TrackBloc - Formatting Methods', () {
    test('formatTrackDate formats date correctly', () {
      final date = DateTime(2024, 3, 15);
      final formatted = trackBloc.formatTrackDate(date);

      expect(formatted, equals('15.03.2024'));
    });

    test('formatTrackTimeRange formats time range correctly', () {
      final startTime = DateTime(2024, 3, 15, 10, 30);
      final endTime = DateTime(2024, 3, 15, 14, 45);
      final formatted = trackBloc.formatTrackTimeRange(startTime, endTime);

      expect(formatted, equals('10:30 - 14:45'));
    });

    test('formatTrackDuration formats duration correctly', () {
      final duration = Duration(hours: 2, minutes: 30);
      final formatted =
          trackBloc.formatTrackDuration(duration, mockLocalizations);

      expect(formatted, equals('2h 30m'));
    });

    test('formatTrackDistance formats distance correctly', () {
      final distance = 12.5;
      final formatted =
          trackBloc.formatTrackDistance(distance, mockLocalizations);

      expect(formatted, equals('12.50 km'));
    });
  });
}
