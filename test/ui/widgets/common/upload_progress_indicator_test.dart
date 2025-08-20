import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sensebox_bike/l10n/app_localizations.dart';
import 'package:sensebox_bike/models/upload_progress.dart';
import 'package:sensebox_bike/ui/widgets/common/upload_progress_indicator.dart';
import 'package:sensebox_bike/ui/widgets/common/loader.dart';

void main() {
  group('UploadProgressIndicator', () {
    Widget createTestWidget(UploadProgress progress, {
      bool compact = false,
    }) {
      return MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: UploadProgressIndicator(
            progress: progress,
            compact: compact,
          ),
        ),
      );
    }

    group('Full Indicator', () {
      testWidgets('displays preparing state correctly', (WidgetTester tester) async {
        const progress = UploadProgress(
          totalChunks: 0,
          completedChunks: 0,
          failedChunks: 0,
          status: UploadStatus.preparing,
          canRetry: false,
        );

        await tester.pumpWidget(createTestWidget(progress));

        // Should show preparing status
        expect(find.text('Preparing upload...'), findsOneWidget);
        
        // Should show loading indicator
        expect(find.byType(Loader), findsOneWidget);
        
        // Should not show progress bar when totalChunks is 0
        expect(find.byType(LinearProgressIndicator), findsNothing);
      });

      testWidgets('displays uploading state with progress', (WidgetTester tester) async {
        const progress = UploadProgress(
          totalChunks: 5,
          completedChunks: 2,
          failedChunks: 0,
          status: UploadStatus.uploading,
          canRetry: false,
        );

        await tester.pumpWidget(createTestWidget(progress));

        // Should show uploading status
        expect(find.text('Uploading track data...'), findsOneWidget);
        
        // Should show progress information
        expect(find.text('2 of 5 chunks uploaded'), findsOneWidget);
        expect(find.text('40% complete'), findsOneWidget);
        
        // Should show progress bar
        expect(find.byType(LinearProgressIndicator), findsOneWidget);
        
        // Should show upload icon
        expect(find.byIcon(Icons.cloud_upload), findsOneWidget);
      });

      testWidgets('displays retrying state correctly', (WidgetTester tester) async {
        const progress = UploadProgress(
          totalChunks: 3,
          completedChunks: 1,
          failedChunks: 1,
          status: UploadStatus.retrying,
          canRetry: true,
        );

        await tester.pumpWidget(createTestWidget(progress));

        // Should show retrying status
        expect(find.text('Retrying upload...'), findsOneWidget);
        
        // Should show progress information
        expect(find.text('1 of 3 chunks uploaded'), findsOneWidget);
        
        // Should show loading indicator
        expect(find.byType(Loader), findsOneWidget);
      });

      testWidgets('displays completed state correctly', (WidgetTester tester) async {
        const progress = UploadProgress(
          totalChunks: 3,
          completedChunks: 3,
          failedChunks: 0,
          status: UploadStatus.completed,
          canRetry: false,
        );

        await tester.pumpWidget(createTestWidget(progress));

        // Should show completed status
        expect(find.text('Upload completed successfully'), findsOneWidget);
        
        // Should show success icon
        expect(find.byIcon(Icons.check_circle), findsOneWidget);
        
        // Should show 100% progress
        expect(find.text('100% complete'), findsOneWidget);
      });

      testWidgets('displays failed state correctly', (WidgetTester tester) async {
        const progress = UploadProgress(
          totalChunks: 3,
          completedChunks: 1,
          failedChunks: 2,
          status: UploadStatus.failed,
          errorMessage: 'Network connection failed',
          canRetry: true,
        );

        await tester.pumpWidget(createTestWidget(progress));

        // Should show failed status
        expect(find.text('Upload failed'), findsOneWidget);
        
        // Should show error icon
        expect(find.byIcon(Icons.error), findsOneWidget);
        
        // Should show error message
        expect(find.text('Network connection failed. Please check your internet connection and try again.'), findsOneWidget);
      });

      testWidgets('displays authentication failure correctly', (WidgetTester tester) async {
        const progress = UploadProgress(
          totalChunks: 3,
          completedChunks: 0,
          failedChunks: 0,
          status: UploadStatus.failed,
          errorMessage: 'Authentication failed - user needs to re-login',
          canRetry: false,
        );

        await tester.pumpWidget(createTestWidget(progress));

        // Should show authentication failed status
        expect(find.text('Authentication required'), findsOneWidget);
        
        // Should show authentication error message
        expect(find.text('Please log in to upload data.'), findsOneWidget);
      });
    });

    group('Compact Indicator', () {
      testWidgets('displays compact preparing state', (WidgetTester tester) async {
        const progress = UploadProgress(
          totalChunks: 0,
          completedChunks: 0,
          failedChunks: 0,
          status: UploadStatus.preparing,
          canRetry: false,
        );

        await tester.pumpWidget(createTestWidget(progress, compact: true));

        // Should show preparing status
        expect(find.text('Preparing upload...'), findsOneWidget);
        
        // Should show loading indicator
        expect(find.byType(Loader), findsOneWidget);
        
        // Should not show progress bar when not in progress
        expect(find.byType(LinearProgressIndicator), findsNothing);
      });

      testWidgets('displays compact uploading state with progress bar', (WidgetTester tester) async {
        const progress = UploadProgress(
          totalChunks: 4,
          completedChunks: 3,
          failedChunks: 0,
          status: UploadStatus.uploading,
          canRetry: false,
        );

        await tester.pumpWidget(createTestWidget(progress, compact: true));

        // Should show uploading status
        expect(find.text('Uploading track data...'), findsOneWidget);
        
        // Should show progress bar in compact mode
        expect(find.byType(LinearProgressIndicator), findsOneWidget);
        
        // Should show upload icon
        expect(find.byIcon(Icons.cloud_upload), findsOneWidget);
      });

      testWidgets('displays compact completed state', (WidgetTester tester) async {
        const progress = UploadProgress(
          totalChunks: 2,
          completedChunks: 2,
          failedChunks: 0,
          status: UploadStatus.completed,
          canRetry: false,
        );

        await tester.pumpWidget(createTestWidget(progress, compact: true));

        // Should show completed status
        expect(find.text('Upload completed successfully'), findsOneWidget);
        
        // Should show success icon
        expect(find.byIcon(Icons.check_circle), findsOneWidget);
        
        // Should not show progress bar when completed
        expect(find.byType(LinearProgressIndicator), findsNothing);
      });

      testWidgets('displays compact failed state correctly', (WidgetTester tester) async {
        const progress = UploadProgress(
          totalChunks: 3,
          completedChunks: 1,
          failedChunks: 2,
          status: UploadStatus.failed,
          errorMessage: 'Upload failed',
          canRetry: true,
        );

        await tester.pumpWidget(createTestWidget(
          progress,
          compact: true,
        ));

        // Should show failed status
        expect(find.text('Upload failed'), findsOneWidget);
        
        // Should show error icon
        expect(find.byIcon(Icons.error), findsOneWidget);
      });
    });

    group('Progress Calculations', () {
      testWidgets('calculates progress percentage correctly', (WidgetTester tester) async {
        const progress = UploadProgress(
          totalChunks: 8,
          completedChunks: 3,
          failedChunks: 1,
          status: UploadStatus.uploading,
          canRetry: false,
        );

        await tester.pumpWidget(createTestWidget(progress));

        // Should show correct percentage (3/8 = 37.5% rounded to 38%)
        expect(find.text('38% complete'), findsOneWidget);
        expect(find.text('3 of 8 chunks uploaded'), findsOneWidget);
      });

      testWidgets('handles zero chunks correctly', (WidgetTester tester) async {
        const progress = UploadProgress(
          totalChunks: 0,
          completedChunks: 0,
          failedChunks: 0,
          status: UploadStatus.preparing,
          canRetry: false,
        );

        await tester.pumpWidget(createTestWidget(progress));

        // Should not show progress information when totalChunks is 0
        expect(find.textContaining('chunks uploaded'), findsNothing);
        expect(find.textContaining('% complete'), findsNothing);
        expect(find.byType(LinearProgressIndicator), findsNothing);
      });
    });

    group('Error Message Handling', () {
      testWidgets('shows network error message for network failures', (WidgetTester tester) async {
        const progress = UploadProgress(
          totalChunks: 3,
          completedChunks: 1,
          failedChunks: 2,
          status: UploadStatus.failed,
          errorMessage: 'network connection timeout',
          canRetry: true,
        );

        await tester.pumpWidget(createTestWidget(progress));

        expect(find.text('Network connection failed. Please check your internet connection and try again.'), findsOneWidget);
      });

      testWidgets('shows authentication error message for auth failures', (WidgetTester tester) async {
        const progress = UploadProgress(
          totalChunks: 3,
          completedChunks: 0,
          failedChunks: 0,
          status: UploadStatus.failed,
          errorMessage: 'Authentication failed - user needs to re-login',
          canRetry: false,
        );

        await tester.pumpWidget(createTestWidget(progress));

        expect(find.text('Please log in to upload data.'), findsOneWidget);
      });

      testWidgets('shows generic error message for other failures', (WidgetTester tester) async {
        const progress = UploadProgress(
          totalChunks: 3,
          completedChunks: 1,
          failedChunks: 2,
          status: UploadStatus.failed,
          errorMessage: 'Some unexpected error occurred',
          canRetry: true,
        );

        await tester.pumpWidget(createTestWidget(progress));

        expect(find.text('Upload failed. Please try again.'), findsOneWidget);
      });
    });

    group('Visual States', () {
      testWidgets('uses correct colors for different states', (WidgetTester tester) async {
        // Test completed state colors
        const completedProgress = UploadProgress(
          totalChunks: 3,
          completedChunks: 3,
          failedChunks: 0,
          status: UploadStatus.completed,
          canRetry: false,
        );

        await tester.pumpWidget(createTestWidget(completedProgress));
        
        // Should show success icon with correct color
        final successIcon = tester.widget<Icon>(find.byIcon(Icons.check_circle));
        expect(successIcon.color, isNotNull);

        // Test failed state colors
        const failedProgress = UploadProgress(
          totalChunks: 3,
          completedChunks: 1,
          failedChunks: 2,
          status: UploadStatus.failed,
          errorMessage: 'Upload failed',
          canRetry: true,
        );

        await tester.pumpWidget(createTestWidget(failedProgress));
        
        // Should show error icon with correct color
        final errorIcon = tester.widget<Icon>(find.byIcon(Icons.error));
        expect(errorIcon.color, isNotNull);
      });

      testWidgets('shows progress bar with correct value', (WidgetTester tester) async {
        const progress = UploadProgress(
          totalChunks: 10,
          completedChunks: 7,
          failedChunks: 1,
          status: UploadStatus.uploading,
          canRetry: false,
        );

        await tester.pumpWidget(createTestWidget(progress));

        final progressBar = tester.widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator));
        expect(progressBar.value, equals(0.7)); // 7/10 = 0.7
      });
    });
  });
}