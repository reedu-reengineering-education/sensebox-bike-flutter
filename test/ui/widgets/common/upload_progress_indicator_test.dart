import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sensebox_bike/l10n/app_localizations.dart';
import 'package:sensebox_bike/models/upload_progress.dart';
import 'package:sensebox_bike/ui/widgets/common/loader.dart';
import 'package:sensebox_bike/ui/widgets/common/upload_progress_indicator.dart';

void main() {
  Future<AppLocalizations> pump(
      WidgetTester tester, UploadProgress progress) async {
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: UploadProgressIndicator(progress: progress)),
    ));
    return AppLocalizations.of(
        tester.element(find.byType(UploadProgressIndicator)))!;
  }

  group('status', () {
    testWidgets('preparing shows a loader and no progress bar', (tester) async {
      final l10n =
          await pump(tester, const UploadProgress(status: UploadStatus.preparing));

      expect(find.text(l10n.uploadProgressPreparing), findsOneWidget);
      expect(find.byType(Loader), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsNothing);
    });

    testWidgets('checking login', (tester) async {
      final l10n = await pump(
          tester,
          const UploadProgress(
              status: UploadStatus.preparing,
              stage: UploadStage.checkingLogin));

      expect(find.text(l10n.uploadStageCheckingLogin), findsOneWidget);
    });

    testWidgets('uploading a part shows which part and the progress bar',
        (tester) async {
      final l10n = await pump(
          tester,
          const UploadProgress(
              status: UploadStatus.uploading,
              stage: UploadStage.uploadingPart,
              totalChunks: 10,
              completedChunks: 7));

      expect(find.text(l10n.uploadStageUploadingPart(8, 10)), findsOneWidget);
      expect(find.byIcon(Icons.cloud_upload), findsOneWidget);
      expect(
          tester
              .widget<LinearProgressIndicator>(
                  find.byType(LinearProgressIndicator))
              .value,
          0.7);
    });

    testWidgets('uploading without a stage', (tester) async {
      final l10n = await pump(
          tester,
          const UploadProgress(
              status: UploadStatus.uploading, totalChunks: 5));

      expect(find.text(l10n.uploadProgressUploading), findsOneWidget);
    });

    testWidgets('retrying', (tester) async {
      final l10n = await pump(
          tester,
          const UploadProgress(
              status: UploadStatus.retrying, totalChunks: 3, completedChunks: 1));

      expect(find.text(l10n.uploadProgressRetrying), findsOneWidget);
      expect(find.byType(Loader), findsOneWidget);
    });

    testWidgets('completed', (tester) async {
      final l10n = await pump(
          tester,
          const UploadProgress(
              status: UploadStatus.completed, totalChunks: 3, completedChunks: 3));

      expect(find.text(l10n.uploadProgressCompleted), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
    });
  });

  group('errors', () {
    testWidgets('connection error shows the reason', (tester) async {
      final l10n = await pump(
          tester,
          const UploadProgress(
            status: UploadStatus.failed,
            errorMessage: 'TimeoutException',
            errorDetail: 'No response within 25 s',
            failureKind: UploadFailureKind.connection,
          ));

      expect(find.text(l10n.uploadProgressFailed), findsOneWidget);
      expect(find.byIcon(Icons.error), findsOneWidget);
      expect(find.text(l10n.errorUploadFailed), findsOneWidget);
      expect(find.text('${l10n.errorReasonPrefix} No response within 25 s'),
          findsOneWidget);
    });

    testWidgets('API error asks to try again later', (tester) async {
      final l10n = await pump(
          tester,
          const UploadProgress(
            status: UploadStatus.failed,
            errorMessage: 'Server error 503',
            errorDetail: 'HTTP 503',
            failureKind: UploadFailureKind.apiResponse,
          ));

      expect(find.text(l10n.uploadErrorTryLater), findsOneWidget);
      expect(find.text('${l10n.errorReasonPrefix} HTTP 503'), findsOneWidget);
    });

    testWidgets('authentication error asks to log in, without a reason',
        (tester) async {
      final l10n = await pump(
          tester,
          const UploadProgress(
            status: UploadStatus.failed,
            errorMessage: 'Not logged in to openSenseMap',
            errorDetail: 'Not logged in to openSenseMap',
            failureKind: UploadFailureKind.authentication,
          ));

      expect(find.text(l10n.uploadProgressAuthenticationFailed), findsOneWidget);
      expect(find.text(l10n.uploadProgressAuthenticationError), findsOneWidget);
      expect(find.textContaining(l10n.errorReasonPrefix), findsNothing);
    });

    testWidgets('unknown error shows the generic message', (tester) async {
      final l10n = await pump(
          tester,
          const UploadProgress(
              status: UploadStatus.failed, errorMessage: 'Something odd'));

      expect(find.text(l10n.uploadProgressGenericError), findsOneWidget);
    });
  });
}
