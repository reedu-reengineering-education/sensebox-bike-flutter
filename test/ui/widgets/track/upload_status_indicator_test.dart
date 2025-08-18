import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sensebox_bike/models/track_data.dart';
import 'package:sensebox_bike/ui/widgets/track/upload_status_indicator.dart';
import 'package:sensebox_bike/l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

void main() {
  group('UploadStatusIndicator', () {
    Widget createTestWidget(TrackData track, {VoidCallback? onRetryPressed, bool showText = false, bool isCompact = true}) {
      return MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('en'),
          Locale('de'),
          Locale('pt'),
        ],
        home: Scaffold(
          body: UploadStatusIndicator(
            track: track,
            onRetryPressed: onRetryPressed,
            showText: showText,
            isCompact: isCompact,
          ),
        ),
      );
    }

    testWidgets('displays uploaded status correctly', (WidgetTester tester) async {
      final track = TrackData()
        ..uploaded = true
        ..uploadAttempts = 1;

      await tester.pumpWidget(createTestWidget(track));

      // Should show cloud_done icon for uploaded tracks
      expect(find.byIcon(Icons.cloud_done), findsOneWidget);
      
      // Should have green color indication
      final container = tester.widget<Container>(find.byType(Container).first);
      expect(container.decoration, isA<BoxDecoration>());
    });

    testWidgets('displays not uploaded status correctly', (WidgetTester tester) async {
      final track = TrackData()
        ..uploaded = false
        ..uploadAttempts = 0;

      await tester.pumpWidget(createTestWidget(track));

      // Should show cloud_upload icon for not uploaded tracks
      expect(find.byIcon(Icons.cloud_upload), findsOneWidget);
    });

    testWidgets('displays failed upload status correctly', (WidgetTester tester) async {
      final track = TrackData()
        ..uploaded = false
        ..uploadAttempts = 3
        ..lastUploadAttempt = DateTime.now();

      await tester.pumpWidget(createTestWidget(track));

      // Should show cloud_off icon for failed uploads
      expect(find.byIcon(Icons.cloud_off), findsOneWidget);
    });

    testWidgets('shows text when showText is true', (WidgetTester tester) async {
      final track = TrackData()
        ..uploaded = true
        ..uploadAttempts = 1;

      await tester.pumpWidget(createTestWidget(track, showText: true, isCompact: false));

      // Should show status text
      expect(find.text('Uploaded'), findsOneWidget);
    });

    testWidgets('shows retry button when onRetryPressed is provided and track can be retried', (WidgetTester tester) async {
      bool retryPressed = false;
      final track = TrackData()
        ..uploaded = false
        ..uploadAttempts = 1;

      await tester.pumpWidget(createTestWidget(
        track,
        onRetryPressed: () => retryPressed = true,
        showText: true,
        isCompact: false,
      ));

      // Should show retry icon
      expect(find.byIcon(Icons.refresh), findsOneWidget);

      // Tap the retry button
      await tester.tap(find.byIcon(Icons.refresh));
      await tester.pump();

      expect(retryPressed, isTrue);
    });

    testWidgets('does not show retry button for uploaded tracks', (WidgetTester tester) async {
      final track = TrackData()
        ..uploaded = true
        ..uploadAttempts = 1;

      await tester.pumpWidget(createTestWidget(
        track,
        onRetryPressed: () {},
        showText: true,
        isCompact: false,
      ));

      // Should not show retry icon for uploaded tracks
      expect(find.byIcon(Icons.refresh), findsNothing);
    });

    testWidgets('shows tooltip in compact mode', (WidgetTester tester) async {
      final track = TrackData()
        ..uploaded = false
        ..uploadAttempts = 0;

      await tester.pumpWidget(createTestWidget(track, isCompact: true));

      // Should have tooltip
      expect(find.byType(Tooltip), findsOneWidget);
      
      // Long press to show tooltip
      await tester.longPress(find.byType(Tooltip));
      await tester.pumpAndSettle();

      // Should show tooltip text
      expect(find.text('Not uploaded'), findsOneWidget);
    });

    testWidgets('handles different upload statuses correctly', (WidgetTester tester) async {
      // Test uploaded status
      final uploadedTrack = TrackData()
        ..uploaded = true
        ..uploadAttempts = 1;

      await tester.pumpWidget(createTestWidget(uploadedTrack, showText: true, isCompact: false));
      expect(find.text('Uploaded'), findsOneWidget);
      expect(find.byIcon(Icons.cloud_done), findsOneWidget);

      // Test failed status
      final failedTrack = TrackData()
        ..uploaded = false
        ..uploadAttempts = 2;

      await tester.pumpWidget(createTestWidget(failedTrack, showText: true, isCompact: false));
      expect(find.text('Upload failed'), findsOneWidget);
      expect(find.byIcon(Icons.cloud_off), findsOneWidget);

      // Test not uploaded status
      final notUploadedTrack = TrackData()
        ..uploaded = false
        ..uploadAttempts = 0;

      await tester.pumpWidget(createTestWidget(notUploadedTrack, showText: true, isCompact: false));
      expect(find.text('Not uploaded'), findsOneWidget);
      expect(find.byIcon(Icons.cloud_upload), findsOneWidget);
    });
  });
}