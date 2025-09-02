import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sensebox_bike/models/track_data.dart';
import 'package:sensebox_bike/blocs/track_bloc.dart';
import 'package:sensebox_bike/models/track_status_info.dart';
import 'package:sensebox_bike/l10n/app_localizations.dart';

import '../../../mocks.dart';

void main() {
  group('Track Status Icon Logic', () {
    late TrackBloc testTrackBloc;
    late ThemeData testTheme;
    late AppLocalizations testLocalizations;

    setUpAll(() {
      registerFallbackValue(TrackData());
    });

    setUp(() async {
      final mockIsarService = MockIsarService();
      // Set up the mock to return a Future<void> for updateTrack
      when(() => mockIsarService.trackService.updateTrack(any()))
          .thenAnswer((_) async {});
      testTrackBloc = TrackBloc(mockIsarService);
      testTheme = ThemeData();
      testLocalizations = await AppLocalizations.delegate.load(const Locale('en'));
    });

    tearDown(() {
      testTrackBloc.dispose();
    });

    test('new track with null values shows direct upload status', () {
      final newTrack = TrackData();
      
      final statusInfo = testTrackBloc.getEstimatedTrackStatusInfo(
          newTrack, testTheme, testLocalizations);

      expect(statusInfo.status, equals(TrackStatus.directUpload));
      expect(statusInfo.icon, equals(Icons.cloud_sync));
      expect(statusInfo.color, equals(Colors.blue));
      expect(
          statusInfo.text, equals(testLocalizations.settingsUploadModeDirect));
    });

    test('regular track (not direct upload) shows not uploaded status', () {
      final regularTrack = TestTrackBuilder.createTrack(
        isDirectUpload: 0,
        uploaded: 0,
        uploadAttempts: 0,
      );
      
      final statusInfo = testTrackBloc.getEstimatedTrackStatusInfo(
          regularTrack, testTheme, testLocalizations);

      expect(statusInfo.status, equals(TrackStatus.notUploaded));
      expect(statusInfo.icon, equals(Icons.cloud_upload));
      expect(statusInfo.color, equals(testTheme.colorScheme.outline));
      expect(statusInfo.text, equals(testLocalizations.trackStatusNotUploaded));
    });

    test('uploaded track shows uploaded status', () {
      final uploadedTrack = TestTrackBuilder.createTrack(
        isDirectUpload: 0,
        uploaded: 1,
        uploadAttempts: 0,
      );
      
      final statusInfo = testTrackBloc.getEstimatedTrackStatusInfo(
          uploadedTrack, testTheme, testLocalizations);

      expect(statusInfo.status, equals(TrackStatus.uploaded));
      expect(statusInfo.icon, equals(Icons.cloud_done));
      expect(statusInfo.color, equals(Colors.green));
      expect(statusInfo.text, equals(testLocalizations.trackStatusUploaded));
    });

    test('track with upload attempts shows upload failed status', () {
      final failedTrack = TestTrackBuilder.createTrack(
        isDirectUpload: 0,
        uploaded: 0,
        uploadAttempts: 2,
        lastUploadAttempt: DateTime.now(),
      );
      
      final statusInfo = testTrackBloc.getEstimatedTrackStatusInfo(
          failedTrack, testTheme, testLocalizations);

      expect(statusInfo.status, equals(TrackStatus.uploadFailed));
      expect(statusInfo.icon, equals(Icons.cloud_off));
      expect(statusInfo.color, equals(testTheme.colorScheme.error));
      expect(statusInfo.text, equals(testLocalizations.trackStatusUploadFailed));
    });

    test('direct upload track with null values shows direct upload status', () {
      final directUploadTrack = TestTrackBuilder.createTrack(
        isDirectUpload: 1,
        uploaded: null,
        uploadAttempts: null,
      );
      
      final statusInfo = testTrackBloc.getEstimatedTrackStatusInfo(
          directUploadTrack, testTheme, testLocalizations);

      expect(statusInfo.status, equals(TrackStatus.directUpload));
      expect(statusInfo.icon, equals(Icons.cloud_sync));
      expect(statusInfo.color, equals(Colors.blue));
      expect(
          statusInfo.text, equals(testLocalizations.settingsUploadModeDirect));
    });

    test(
        'direct upload track with authentication failure shows auth failed status',
        () {
      final authFailedTrack = TestTrackBuilder.createTrack(
        isDirectUpload: 1,
        uploaded: 0,
        uploadAttempts: 1, // Has upload attempts, indicating failure
        lastUploadAttempt: DateTime.now(),
      );

      final statusInfo = testTrackBloc.getEstimatedTrackStatusInfo(
          authFailedTrack, testTheme, testLocalizations);

      expect(statusInfo.status, equals(TrackStatus.directUploadAuthFailed));
      expect(statusInfo.icon, equals(Icons.cloud_off));
      expect(statusInfo.color, equals(testTheme.colorScheme.error));
      expect(statusInfo.text,
          equals(testLocalizations.trackDirectUploadAuthFailed));
    });

    test('direct upload track that was uploaded still shows direct upload status', () {
      final uploadedDirectTrack = TestTrackBuilder.createTrack(
        isDirectUpload: 1,
        uploaded: 1,
        uploadAttempts: 0,
      );
      
      final statusInfo = testTrackBloc.getEstimatedTrackStatusInfo(
          uploadedDirectTrack, testTheme, testLocalizations);

      // Direct upload tracks always show direct upload status, regardless of upload state
      expect(statusInfo.status, equals(TrackStatus.directUpload));
      expect(statusInfo.icon, equals(Icons.cloud_sync));
      expect(statusInfo.color, equals(Colors.blue));
      expect(statusInfo.text, equals(testLocalizations.settingsUploadModeDirect));
    });

    test('direct upload track with failed uploads shows auth failed status',
        () {
      // Create a direct upload track with failed uploads
      final failedDirectTrack = TestTrackBuilder.createTrack(
        isDirectUpload: 1,
        uploaded: 0,
        uploadAttempts: 3,
        lastUploadAttempt: DateTime.now(),
      );
      
      final statusInfo = testTrackBloc.getEstimatedTrackStatusInfo(
          failedDirectTrack, testTheme, testLocalizations);

      // Direct upload tracks with upload attempts show auth failed status
      expect(statusInfo.status, equals(TrackStatus.directUploadAuthFailed));
      expect(statusInfo.icon, equals(Icons.cloud_off));
      expect(statusInfo.color, equals(testTheme.colorScheme.error));
      expect(statusInfo.text,
          equals(testLocalizations.trackDirectUploadAuthFailed));
    });

    test('computed getters work correctly with null values', () {
      final track = TrackData();
      
      // Test computed getters with null values
      expect(track.isDirectUploadTrack, isTrue); // null != 0, so true
      expect(track.isUploaded, isFalse); // null != 1, so false
      expect(track.uploadAttemptsCount, equals(0)); // null ?? 0, so 0
    });

    test('computed getters work correctly with integer values', () {
      final track = TrackData()
        ..isDirectUpload = 0
        ..uploaded = 1
        ..uploadAttempts = 5;
      
      // Test computed getters with integer values
      expect(track.isDirectUploadTrack, isFalse); // 0 != 0, so false
      expect(track.isUploaded, isTrue); // 1 == 1, so true
      expect(track.uploadAttemptsCount, equals(5)); // 5 ?? 0, so 5
    });

    test('track with corrupted data shows not uploaded status', () {
      // Create a track with error state (e.g., corrupted data)
      final errorTrack = TrackData()
        ..isDirectUpload = 0
        ..uploaded = 0
        ..uploadAttempts = -9223372036854775808; // Corrupted negative value
      
      final statusInfo = testTrackBloc.getEstimatedTrackStatusInfo(
          errorTrack, testTheme, testLocalizations);

      // Should handle corrupted data gracefully and show not uploaded status
      expect(statusInfo.status, equals(TrackStatus.notUploaded));
      expect(statusInfo.icon, equals(Icons.cloud_upload));
      expect(statusInfo.color, equals(testTheme.colorScheme.outline));
      expect(statusInfo.text, equals(testLocalizations.trackStatusNotUploaded));
    });

    test('calculateTrackStatusFromValues method works correctly', () {
      // Test the actual calculateTrackStatusFromValues method directly

      // Direct upload tracks with no upload attempts return directUpload
      expect(testTrackBloc.calculateTrackStatusFromValues(true, false, 0), equals(TrackStatus.directUpload));
      expect(testTrackBloc.calculateTrackStatusFromValues(true, true, 0),
          equals(TrackStatus.directUpload));

      // Direct upload tracks with upload attempts return directUploadAuthFailed (only when not uploaded)
      expect(testTrackBloc.calculateTrackStatusFromValues(true, false, 1),
          equals(TrackStatus.directUploadAuthFailed));
      // Direct upload tracks that are uploaded return directUpload regardless of attempts
      expect(testTrackBloc.calculateTrackStatusFromValues(true, true, 5),
          equals(TrackStatus.directUpload));

      // Batch upload tracks with uploaded = true
      expect(testTrackBloc.calculateTrackStatusFromValues(false, true, 0), equals(TrackStatus.uploaded));
      expect(testTrackBloc.calculateTrackStatusFromValues(false, true, 3), equals(TrackStatus.uploaded));

      // Batch upload tracks with uploadAttempts > 0
      expect(testTrackBloc.calculateTrackStatusFromValues(false, false, 1), equals(TrackStatus.uploadFailed));
      expect(testTrackBloc.calculateTrackStatusFromValues(false, false, 5), equals(TrackStatus.uploadFailed));

      // Batch upload tracks with no upload attempts
      expect(testTrackBloc.calculateTrackStatusFromValues(false, false, 0), equals(TrackStatus.notUploaded));
    });

    test('updateDirectUploadAuthFailure method updates track correctly',
        () async {
      final track = TrackData()
        ..isDirectUpload = 1
        ..uploaded = null
        ..uploadAttempts = null
        ..lastUploadAttempt = null;

      // Verify initial state
      expect(track.uploadAttempts, isNull);
      expect(track.uploaded, isNull);
      expect(track.lastUploadAttempt, isNull);

      // Call the method
      await testTrackBloc.updateDirectUploadAuthFailure(track);

      // Verify the track was updated correctly
      expect(track.uploadAttempts, equals(1));
      expect(track.uploaded, equals(0));
      expect(track.lastUploadAttempt, isNotNull);
      expect(
          track.lastUploadAttempt!
              .isAfter(DateTime.now().subtract(const Duration(seconds: 1))),
          isTrue);
    });
  });
}
