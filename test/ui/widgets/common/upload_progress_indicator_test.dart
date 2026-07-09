import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sensebox_bike/l10n/app_localizations.dart';
import 'package:sensebox_bike/models/upload_progress.dart';
import 'package:sensebox_bike/ui/widgets/common/upload_progress_indicator.dart';
import 'package:sensebox_bike/ui/widgets/common/loader.dart';

void main() {
  String t(WidgetTester tester, String Function(AppLocalizations l10n) pick) {
    final context = tester.element(find.byType(UploadProgressIndicator));
    return pick(AppLocalizations.of(context)!);
  }

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
        expect(find.text(t(tester, (l10n) => l10n.uploadProgressPreparing)), findsOneWidget);
        
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
        expect(find.text(t(tester, (l10n) => l10n.uploadProgressUploading)), findsOneWidget);
        
        // Should show progress information
        expect(
          find.text(t(tester, (l10n) => l10n.uploadProgressChunks(2, 5))),
          findsOneWidget,
        );
        expect(
          find.text(t(tester, (l10n) => l10n.uploadProgressPercentage(40))),
          findsOneWidget,
        );
        
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
        expect(find.text(t(tester, (l10n) => l10n.uploadProgressRetrying)), findsOneWidget);
        
        // Should show progress information
        expect(
          find.text(t(tester, (l10n) => l10n.uploadProgressChunks(1, 3))),
          findsOneWidget,
        );
        
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
        expect(find.text(t(tester, (l10n) => l10n.uploadProgressCompleted)), findsOneWidget);
        
        // Should show success icon
        expect(find.byIcon(Icons.check_circle), findsOneWidget);
        
        // Should show 100% progress
        expect(
          find.text(t(tester, (l10n) => l10n.uploadProgressPercentage(100))),
          findsOneWidget,
        );
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
        expect(find.text(t(tester, (l10n) => l10n.uploadProgressFailed)), findsOneWidget);
        
        // Should show error icon
        expect(find.byIcon(Icons.error), findsOneWidget);
        
        // Should show error message
        expect(
          find.text(t(tester, (l10n) => l10n.uploadProgressNetworkError)),
          findsOneWidget,
        );
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
        expect(
          find.text(t(tester, (l10n) => l10n.uploadProgressAuthenticationFailed)),
          findsOneWidget,
        );
        
        // Should show authentication error message
        expect(
          find.text(t(tester, (l10n) => l10n.uploadProgressAuthenticationError)),
          findsOneWidget,
        );
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
        expect(find.text(t(tester, (l10n) => l10n.uploadProgressPreparing)), findsOneWidget);
        
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
        expect(find.text(t(tester, (l10n) => l10n.uploadProgressUploading)), findsOneWidget);
        
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
        expect(find.text(t(tester, (l10n) => l10n.uploadProgressCompleted)), findsOneWidget);
        
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
        expect(find.text(t(tester, (l10n) => l10n.uploadProgressFailed)), findsOneWidget);
        
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
        expect(
          find.text(t(tester, (l10n) => l10n.uploadProgressPercentage(38))),
          findsOneWidget,
        );
        expect(
          find.text(t(tester, (l10n) => l10n.uploadProgressChunks(3, 8))),
          findsOneWidget,
        );
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

        expect(
          find.text(t(tester, (l10n) => l10n.uploadProgressNetworkError)),
          findsOneWidget,
        );
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

        expect(
          find.text(t(tester, (l10n) => l10n.uploadProgressAuthenticationError)),
          findsOneWidget,
        );
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

        expect(
          find.text(t(tester, (l10n) => l10n.uploadProgressGenericError)),
          findsOneWidget,
        );
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