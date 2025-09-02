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
  String get trackDirectUploadAuthFailed => 'Direct upload auth failed';

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

  group('TrackBloc - Track Management', () {
    test('startNewTrack without isDirectUpload parameter sets isDirectUpload to default true', () async {
      when(() => mockIsarService.mockTrackService.saveTrack(any()))
          .thenAnswer((_) async => 1);

      final trackId = await trackBloc.startNewTrack();

      expect(trackId, equals(1));
      expect(trackBloc.currentTrack, isNotNull);
      expect(trackBloc.currentTrack!.isDirectUpload, equals(1));
    });

    test('startNewTrack with isDirectUpload = true sets isDirectUpload to 1', () async {
      when(() => mockIsarService.mockTrackService.saveTrack(any()))
          .thenAnswer((_) async => 1);

      final trackId = await trackBloc.startNewTrack(isDirectUpload: true);

      expect(trackId, equals(1));
      expect(trackBloc.currentTrack, isNotNull);
      expect(trackBloc.currentTrack!.isDirectUpload, equals(1));
    });

    test('startNewTrack with isDirectUpload = false sets isDirectUpload to 0', () async {
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

  group('TrackBloc - Stream Functionality', () {
    test('currentTrackStream emits values when track is started', () async {
      when(() => mockIsarService.mockTrackService.saveTrack(any()))
          .thenAnswer((_) async => 1);

      final streamValues = <TrackData?>[];
      final subscription = trackBloc.currentTrackStream.listen(streamValues.add);

      await trackBloc.startNewTrack();

      await Future.delayed(Duration(milliseconds: 100));
      expect(streamValues.length, equals(1));
      expect(streamValues.first, isNotNull);
      expect(streamValues.first!.isDirectUpload, equals(1));

      subscription.cancel();
    });

    test('currentTrackStream emits null when track is ended', () async {
      when(() => mockIsarService.mockTrackService.saveTrack(any()))
          .thenAnswer((_) async => 1);

      final streamValues = <TrackData?>[];
      final subscription = trackBloc.currentTrackStream.listen(streamValues.add);

      await trackBloc.startNewTrack();
      trackBloc.endTrack();

      await Future.delayed(Duration(milliseconds: 100));
      expect(streamValues.length, equals(2));
      expect(streamValues.first, isNotNull);
      expect(streamValues.last, isNull);

      subscription.cancel();
    });
  });

  group('TrackBloc - Status Calculation', () {
    test(
        'getEstimatedTrackStatusInfo returns correct info for direct upload track',
        () {
      final track = TrackData()
        ..isDirectUpload = 1
        ..uploaded = 1;

      final statusInfo =
          trackBloc.getEstimatedTrackStatusInfo(
          track, testTheme, mockLocalizations);

      expect(statusInfo.status, equals(TrackStatus.directUpload));
      expect(statusInfo.color, equals(Colors.blue));
      expect(statusInfo.icon, equals(Icons.cloud_sync));
      expect(statusInfo.text, equals('Direct Upload (Beta)'));
    });

    test(
        'getEstimatedTrackStatusInfo returns correct info for direct upload track not yet uploaded',
        () {
      final track = TrackData()
        ..isDirectUpload = 1
        ..uploaded = 0;

      final statusInfo =
          trackBloc.getEstimatedTrackStatusInfo(
          track, testTheme, mockLocalizations);

      expect(statusInfo.status, equals(TrackStatus.directUpload));
      expect(statusInfo.color, equals(Colors.blue));
      expect(statusInfo.icon, equals(Icons.cloud_sync));
      expect(statusInfo.text, equals('Direct Upload (Beta)'));
    });

    test(
        'getEstimatedTrackStatusInfo returns correct info for direct upload track with auth failure',
        () {
      final track = TrackData()
        ..isDirectUpload = 1
        ..uploaded = 0
        ..uploadAttempts = 1;

      final statusInfo =
          trackBloc.getEstimatedTrackStatusInfo(
          track, testTheme, mockLocalizations);

      expect(statusInfo.status, equals(TrackStatus.directUploadAuthFailed));
      expect(statusInfo.color, equals(testTheme.colorScheme.error));
      expect(statusInfo.icon, equals(Icons.cloud_off));
      expect(statusInfo.text, equals('Direct upload auth failed'));
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

  group('TrackBloc - Status Calculation Logic', () {
    test('calculateTrackStatusFromValues for direct upload + uploaded', () {
      final status = trackBloc.calculateTrackStatusFromValues(true, true, 0);
      expect(status, equals(TrackStatus.directUpload));
    });

    test('calculateTrackStatusFromValues for direct upload + not uploaded + no attempts', () {
      final status = trackBloc.calculateTrackStatusFromValues(true, false, 0);
      expect(status, equals(TrackStatus.directUpload));
    });

    test('calculateTrackStatusFromValues for direct upload + not uploaded + with attempts', () {
      final status = trackBloc.calculateTrackStatusFromValues(true, false, 1);
      expect(status, equals(TrackStatus.directUploadAuthFailed));
    });

    test('calculateTrackStatusFromValues for regular track + uploaded', () {
      final status = trackBloc.calculateTrackStatusFromValues(false, true, 0);
      expect(status, equals(TrackStatus.uploaded));
    });

    test('calculateTrackStatusFromValues for regular track + not uploaded + no attempts', () {
      final status = trackBloc.calculateTrackStatusFromValues(false, false, 0);
      expect(status, equals(TrackStatus.notUploaded));
    });

    test('calculateTrackStatusFromValues for regular track + not uploaded + with attempts', () {
      final status = trackBloc.calculateTrackStatusFromValues(false, false, 1);
      expect(status, equals(TrackStatus.uploadFailed));
    });
  });

  group('TrackBloc - Direct Upload Auth Failure', () {
    test('updateDirectUploadAuthFailure updates track and notifies listeners', () async {
      final track = TrackData()
        ..isDirectUpload = 1
        ..uploaded = 1
        ..uploadAttempts = 0;

      when(() => mockIsarService.mockTrackService.updateTrack(any()))
          .thenAnswer((_) async {});

      await trackBloc.updateDirectUploadAuthFailure(track);

      expect(track.uploadAttempts, equals(1));
      expect(track.uploaded, equals(0));
      expect(track.lastUploadAttempt, isNotNull);

      verify(() => mockIsarService.mockTrackService.updateTrack(track)).called(1);
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

  group('TrackBloc - Mapbox URL Generation', () {
    testWidgets('buildStaticMapboxUrl returns empty string for empty polyline', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(home: Container()));
      
      final url = trackBloc.buildStaticMapboxUrl(tester.element(find.byType(Container)), '');
      
      expect(url, equals(''));
    });

    testWidgets('buildStaticMapboxUrl generates correct URL for light theme', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData.light(),
        home: Container()
      ));
      
      final polyline = 'test_polyline_data';
      final url = trackBloc.buildStaticMapboxUrl(tester.element(find.byType(Container)), polyline);
      
      expect(url, contains('light-v11'));
      expect(url, contains('111'));
      expect(url, contains('140x140'));
      expect(url, contains(Uri.encodeComponent(polyline)));
    });

    testWidgets('buildStaticMapboxUrl generates correct URL for dark theme', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData.dark(),
        home: Container()
      ));
      
      final polyline = 'test_polyline_data';
      final url = trackBloc.buildStaticMapboxUrl(tester.element(find.byType(Container)), polyline);
      
      expect(url, contains('dark-v11'));
      expect(url, contains('fff'));
      expect(url, contains('140x140'));
      expect(url, contains(Uri.encodeComponent(polyline)));
    });
  });

  group('TrackBloc - Disposal', () {
    test('dispose closes stream controller', () {
      final trackBlocToDispose = TrackBloc(mockIsarService);
      
      expect(trackBlocToDispose.currentTrackStream, isNotNull);
      
      trackBlocToDispose.dispose();
      
      // After disposal, the stream should still be accessible but closed
      final subscription = trackBlocToDispose.currentTrackStream.listen((_) {});
      expect(subscription.isPaused, isFalse);
      
      subscription.cancel();
    });
  });
}
