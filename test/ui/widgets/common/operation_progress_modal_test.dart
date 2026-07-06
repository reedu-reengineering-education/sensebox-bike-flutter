import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sensebox_bike/models/upload_progress.dart';
import 'package:sensebox_bike/services/batch_upload_service.dart';
import 'package:sensebox_bike/ui/widgets/common/operation_progress_modal.dart';
import 'package:sensebox_bike/ui/widgets/common/operation_progress_overlay.dart';
import 'package:sensebox_bike/ui/widgets/common/upload_info_widget.dart';
import '../../../test_helpers.dart';

class MockBatchUploadService extends Mock implements BatchUploadService {}

const _enLocale = Locale('en');
const kShowOverlayButtonText = 'Show Overlay';
const kShowOneButtonText = 'Show One';
const kShowTwoButtonText = 'Show Two';
const kUploadPromptText = 'Would you like to upload your track data now?';

Future<void> pumpOperationProgressModal(
  WidgetTester tester, {
  required Stream<UploadProgress> progressStream,
  VoidCallback? onComplete,
  VoidCallback? onFailed,
  VoidCallback? onStart,
  VoidCallback? onDismiss,
  bool showConfirmation = true,
}) async {
  await tester.pumpWidget(
    createLocalizedTestApp(
      child: Scaffold(
        body: OperationProgressModal(
          progressStream: progressStream,
          onComplete: onComplete,
          onFailed: onFailed,
          onStart: onStart,
          onDismiss: onDismiss,
          showConfirmation: showConfirmation,
        ),
      ),
      locale: _enLocale,
    ),
  );
}

Future<void> pumpSingleOverlayLauncher(
  WidgetTester tester, {
  required void Function(BuildContext context) onPressed,
}) async {
  await tester.pumpWidget(
    createLocalizedTestApp(
      child: Builder(
        builder: (context) {
          return Scaffold(
            body: ElevatedButton(
              onPressed: () => onPressed(context),
              child: const Text(kShowOverlayButtonText),
            ),
          );
        },
      ),
      locale: _enLocale,
    ),
  );
}

void _stubUploadStream(
  MockBatchUploadService service,
  Stream<UploadProgress> stream,
) {
  when(() => service.uploadProgressStream).thenAnswer((_) => stream);
}

void main() {
  setUpAll(() {
    WidgetsFlutterBinding.ensureInitialized();
  });

  group('OperationProgressModal', () {
    late StreamController<UploadProgress> progressController;

    setUp(() {
      progressController = createBroadcastController<UploadProgress>();
    });

    tearDown(() async {
      await progressController.close();
    });

    testWidgets('shows confirmation dialog by default',
        (WidgetTester tester) async {
      await pumpOperationProgressModal(
        tester,
        progressStream: progressController.stream,
      );

      expect(find.text(kUploadPromptText), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Upload'), findsOneWidget);
      expect(find.byType(UploadInfoWidget), findsOneWidget);
    });

    testWidgets('starts immediately when confirmation disabled',
        (WidgetTester tester) async {
      var started = false;

      await pumpOperationProgressModal(
        tester,
        progressStream: progressController.stream,
        showConfirmation: false,
        onStart: () => started = true,
      );

      await tester.pump();
      expect(started, isTrue);
      expect(find.text(kUploadPromptText), findsNothing);

      progressController.add(const UploadProgress(
        totalChunks: 5,
        completedChunks: 0,
        failedChunks: 0,
        status: UploadStatus.preparing,
        canRetry: false,
      ));
      await tester.pump();

      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.byType(UploadInfoWidget), findsNothing);
    });

    testWidgets('shows progress after confirmation and start',
        (WidgetTester tester) async {
      await pumpOperationProgressModal(
        tester,
        progressStream: progressController.stream,
      );

      await tester.tap(find.text('Upload'));
      await tester.pump();

      progressController.add(const UploadProgress(
        totalChunks: 10,
        completedChunks: 3,
        failedChunks: 0,
        status: UploadStatus.uploading,
        canRetry: false,
      ));

      await tester.pump();

      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });

    testWidgets('invokes completion callback on completed state',
        (WidgetTester tester) async {
      var completed = false;

      await pumpOperationProgressModal(
        tester,
        progressStream: progressController.stream,
        onComplete: () => completed = true,
      );

      await tester.tap(find.text('Upload'));
      await tester.pump();

      progressController.add(const UploadProgress(
        totalChunks: 5,
        completedChunks: 5,
        failedChunks: 0,
        status: UploadStatus.completed,
        canRetry: false,
      ));

      await tester.pump(const Duration(seconds: 3));
      expect(completed, isTrue);
    });

    testWidgets('calls onDismiss when cancel is tapped',
        (WidgetTester tester) async {
      var dismissed = false;

      await pumpOperationProgressModal(
        tester,
        progressStream: progressController.stream,
        onDismiss: () {
          dismissed = true;
        },
      );

      await tester.tap(find.text('Cancel'));
      await tester.pump();

      expect(dismissed, isTrue);
    });

    testWidgets('calls onStart when upload is tapped',
        (WidgetTester tester) async {
      var started = false;

      await pumpOperationProgressModal(
        tester,
        progressStream: progressController.stream,
        onStart: () => started = true,
      );

      await tester.tap(find.text('Upload'));
      await tester.pump();

      expect(started, isTrue);
    });

    testWidgets('shows failed state when progress stream emits error',
        (WidgetTester tester) async {
      await pumpOperationProgressModal(
        tester,
        progressStream: progressController.stream,
        showConfirmation: false,
      );

      progressController.addError(Exception('broken export stream'));
      await tester.pump();

      expect(find.text('Close'), findsOneWidget);
    });

    testWidgets('invokes onFailed for terminal failure state',
        (WidgetTester tester) async {
      var failed = false;

      await pumpOperationProgressModal(
        tester,
        progressStream: progressController.stream,
        showConfirmation: false,
        onFailed: () => failed = true,
      );

      progressController.add(const UploadProgress(
        totalChunks: 5,
        completedChunks: 2,
        failedChunks: 1,
        status: UploadStatus.failed,
        canRetry: false,
      ));
      await tester.pump();

      expect(failed, isTrue);
      expect(find.text('Close'), findsOneWidget);
    });
  });

  group('OperationProgressOverlay', () {
    late StreamController<UploadProgress> progressController;
    late MockBatchUploadService mockService;

    setUp(() {
      OperationProgressOverlay.hide();
      mockService = MockBatchUploadService();
      progressController = createBroadcastController<UploadProgress>();
      _stubUploadStream(mockService, progressController.stream);
    });

    tearDown(() async {
      OperationProgressOverlay.hide();
      await progressController.close();
    });

    testWidgets('show/hide works with upload service mode',
        (WidgetTester tester) async {
      await pumpSingleOverlayLauncher(
        tester,
        onPressed: (context) {
          OperationProgressOverlay.show(
            context,
            config: OperationProgressOverlayConfig.upload(
              uploadService: mockService,
              onStart: () {
                progressController.add(const UploadProgress(
                  totalChunks: 5,
                  completedChunks: 1,
                  failedChunks: 0,
                  status: UploadStatus.uploading,
                  canRetry: false,
                ));
              },
            ),
          );
        },
      );

      expect(find.text(kUploadPromptText), findsNothing);
      expect(OperationProgressOverlay.isVisible, isFalse);

      await tester.tap(find.text(kShowOverlayButtonText));
      await tester.pump();

      expect(OperationProgressOverlay.isVisible, isTrue);
      expect(find.text(kUploadPromptText), findsOneWidget);

      await tester.tap(find.text('Upload'));
      await tester.pump();

      progressController.add(const UploadProgress(
        totalChunks: 5,
        completedChunks: 1,
        failedChunks: 0,
        status: UploadStatus.uploading,
        canRetry: false,
      ));

      await tester.pump();
      expect(find.byType(LinearProgressIndicator), findsOneWidget);

      OperationProgressOverlay.hide();
      await tester.pump();

      expect(OperationProgressOverlay.isVisible, isFalse);
    });

    testWidgets('does not call onDismiss when hidden programmatically',
        (WidgetTester tester) async {
      bool dismissCalled = false;

      await pumpSingleOverlayLauncher(
        tester,
        onPressed: (context) {
          OperationProgressOverlay.show(
            context,
            config: OperationProgressOverlayConfig.upload(
              uploadService: mockService,
              onDismiss: () {
                dismissCalled = true;
              },
            ),
          );
        },
      );

      await tester.tap(find.text(kShowOverlayButtonText));
      await tester.pump();

      expect(OperationProgressOverlay.isVisible, isTrue);
      expect(dismissCalled, isFalse);

      OperationProgressOverlay.hide();
      await tester.pump();

      expect(dismissCalled, isFalse);
      expect(OperationProgressOverlay.isVisible, isFalse);
    });

    testWidgets('shows confirmation dialog when using upload config',
        (WidgetTester tester) async {
      await pumpSingleOverlayLauncher(
        tester,
        onPressed: (context) {
          OperationProgressOverlay.show(
            context,
            config: OperationProgressOverlayConfig.upload(
              uploadService: mockService,
            ),
          );
        },
      );

      await tester.tap(find.text(kShowOverlayButtonText));
      await tester.pump();

      expect(OperationProgressOverlay.isVisible, isTrue);
      expect(find.text(kUploadPromptText), findsOneWidget);
    });

    testWidgets('showWithProgressStream starts and renders progress',
        (WidgetTester tester) async {
      var started = false;

      await pumpSingleOverlayLauncher(
        tester,
        onPressed: (context) {
          OperationProgressOverlay.show(
            context,
            config: OperationProgressOverlayConfig.stream(
              progressStream: progressController.stream,
              showConfirmation: false,
              onStart: () {
                started = true;
                progressController.add(const UploadProgress(
                  totalChunks: 1,
                  completedChunks: 0,
                  failedChunks: 0,
                  status: UploadStatus.uploading,
                  canRetry: false,
                ));
              },
            ),
          );
        },
      );

      await tester.tap(find.text(kShowOverlayButtonText));
      await tester.pump();
      await tester.pump();

      expect(started, isTrue);
      expect(find.byType(UploadInfoWidget), findsNothing);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);

      OperationProgressOverlay.hide();
      await tester.pump();
      expect(OperationProgressOverlay.isVisible, isFalse);
    });

    testWidgets('calls onDismiss when user cancels overlay dialog',
        (WidgetTester tester) async {
      bool dismissCalled = false;

      await pumpSingleOverlayLauncher(
        tester,
        onPressed: (context) {
          OperationProgressOverlay.show(
            context,
            config: OperationProgressOverlayConfig.upload(
              uploadService: mockService,
              onDismiss: () {
                dismissCalled = true;
              },
            ),
          );
        },
      );

      await tester.tap(find.text(kShowOverlayButtonText));
      await tester.pump();
      await tester.tap(find.text('Cancel'));
      await tester.pump();

      expect(dismissCalled, isTrue);
      expect(OperationProgressOverlay.isVisible, isFalse);
    });

    testWidgets('ignores show call while overlay is already visible',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        createLocalizedTestApp(
          child: Builder(
            builder: (context) {
              return Scaffold(
                body: Column(
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        OperationProgressOverlay.show(
                          context,
                          config: OperationProgressOverlayConfig.upload(
                            uploadService: mockService,
                          ),
                        );
                      },
                      child: const Text(kShowOneButtonText),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        OperationProgressOverlay.show(
                          context,
                          config: OperationProgressOverlayConfig.stream(
                            progressStream: progressController.stream,
                            showConfirmation: false,
                          ),
                        );
                      },
                      child: const Text(kShowTwoButtonText),
                    ),
                  ],
                ),
              );
            },
          ),
          locale: _enLocale,
        ),
      );

      await tester.tap(find.text(kShowOneButtonText));
      await tester.pump();
      expect(find.text(kUploadPromptText), findsOneWidget);

      await tester.tap(find.text(kShowTwoButtonText));
      await tester.pump();

      expect(find.text(kUploadPromptText), findsOneWidget);
      expect(OperationProgressOverlay.isVisible, isTrue);

      OperationProgressOverlay.hide();
      await tester.pump();
    });

    testWidgets('calls onComplete and hides overlay on completed progress',
        (WidgetTester tester) async {
      bool completedCalled = false;

      await pumpSingleOverlayLauncher(
        tester,
        onPressed: (context) {
          OperationProgressOverlay.show(
            context,
            config: OperationProgressOverlayConfig.stream(
              progressStream: progressController.stream,
              showConfirmation: false,
              onComplete: () {
                completedCalled = true;
              },
            ),
          );
        },
      );

      await tester.tap(find.text(kShowOverlayButtonText));
      await tester.pump();

      progressController.add(const UploadProgress(
        totalChunks: 1,
        completedChunks: 1,
        failedChunks: 0,
        status: UploadStatus.completed,
        canRetry: false,
      ));

      await tester.pump(const Duration(seconds: 3));

      expect(completedCalled, isTrue);
      expect(OperationProgressOverlay.isVisible, isFalse);
    });
  });
}