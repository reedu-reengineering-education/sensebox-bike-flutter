import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sensebox_bike/models/upload_progress.dart';
import 'package:sensebox_bike/services/batch_upload_service.dart';
import 'package:sensebox_bike/ui/widgets/common/operation_progress_modal.dart';
import 'package:sensebox_bike/ui/widgets/common/operation_progress_overlay.dart';
import 'package:sensebox_bike/ui/widgets/common/upload_info_widget.dart';
import '../../../test_helpers.dart';

class MockBatchUploadService extends Mock implements BatchUploadService {}

void main() {
  setUpAll(() {
    WidgetsFlutterBinding.ensureInitialized();
  });

  group('OperationProgressModal', () {
    late StreamController<UploadProgress> progressController;

    setUp(() {
      progressController = StreamController<UploadProgress>.broadcast();
    });

    tearDown(() async {
      await progressController.close();
    });

    testWidgets('shows confirmation dialog by default',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        createLocalizedTestApp(
          child: Scaffold(
            body: OperationProgressModal(
              progressStream: progressController.stream,
            ),
          ),
          locale: const Locale('en'),
        ),
      );

      expect(find.text('Would you like to upload your track data now?'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Upload'), findsOneWidget);
      expect(find.byType(UploadInfoWidget), findsOneWidget);
    });

    testWidgets('starts immediately when confirmation disabled',
        (WidgetTester tester) async {
      var started = false;

      await tester.pumpWidget(
        createLocalizedTestApp(
          child: Scaffold(
            body: OperationProgressModal(
              progressStream: progressController.stream,
              showConfirmation: false,
              onStart: () => started = true,
            ),
          ),
          locale: const Locale('en'),
        ),
      );

      await tester.pump();
      expect(started, isTrue);
      expect(find.text('Would you like to upload your track data now?'), findsNothing);

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
      await tester.pumpWidget(
        createLocalizedTestApp(
          child: Scaffold(
            body: OperationProgressModal(
              progressStream: progressController.stream,
            ),
          ),
          locale: const Locale('en'),
        ),
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

      await tester.pumpWidget(
        createLocalizedTestApp(
          child: Scaffold(
            body: OperationProgressModal(
              progressStream: progressController.stream,
              onComplete: () => completed = true,
            ),
          ),
          locale: const Locale('en'),
        ),
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

      await tester.pumpWidget(
        createLocalizedTestApp(
          child: Scaffold(
            body: OperationProgressModal(
              progressStream: progressController.stream,
              onDismiss: () {
                dismissed = true;
              },
            ),
          ),
          locale: const Locale('en'),
        ),
      );

      await tester.tap(find.text('Cancel'));
      await tester.pump();

      expect(dismissed, isTrue);
    });
  });

  group('OperationProgressModal cancel and errors', () {
    late StreamController<UploadProgress> progressController;

    setUp(() {
      progressController = StreamController<UploadProgress>.broadcast();
    });

    tearDown(() async {
      await progressController.close();
    });

    Future<void> pumpRunningModal(
      WidgetTester tester, {
      VoidCallback? onCancel,
      VoidCallback? onDismiss,
    }) async {
      await tester.pumpWidget(
        createLocalizedTestApp(
          child: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () => showDialog(
                  context: context,
                  builder: (_) => OperationProgressModal(
                    progressStream: progressController.stream,
                    showConfirmation: false,
                    onCancel: onCancel,
                    onDismiss: onDismiss,
                  ),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
          locale: const Locale('en'),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pump();
    }

    testWidgets('Cancel is available while preparing and cancels the upload',
        (WidgetTester tester) async {
      var cancelled = 0;
      var dismissed = 0;
      await pumpRunningModal(tester,
          onCancel: () => cancelled++, onDismiss: () => dismissed++);

      progressController.add(const UploadProgress(
        totalChunks: 0,
        completedChunks: 0,
        failedChunks: 0,
        status: UploadStatus.preparing,
        canRetry: false,
      ));
      await tester.pump();

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(cancelled, 1);
      expect(dismissed, 1);
      expect(find.byType(OperationProgressModal), findsNothing);
    });

    testWidgets('Cancel is available while uploading',
        (WidgetTester tester) async {
      var cancelled = 0;
      await pumpRunningModal(tester, onCancel: () => cancelled++);

      progressController.add(const UploadProgress(
        totalChunks: 3,
        completedChunks: 1,
        failedChunks: 0,
        status: UploadStatus.uploading,
        canRetry: false,
      ));
      await tester.pump();

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(cancelled, 1);
    });

    testWidgets('closing after a failure does not cancel',
        (WidgetTester tester) async {
      var cancelled = 0;
      await pumpRunningModal(tester, onCancel: () => cancelled++);

      progressController.add(const UploadProgress(
        totalChunks: 2,
        completedChunks: 0,
        failedChunks: 1,
        status: UploadStatus.failed,
        errorMessage: 'Server error 503',
        errorDetail: 'HTTP 503: Service Unavailable',
        failureKind: UploadFailureKind.apiResponse,
        canRetry: true,
      ));
      await tester.pump();

      expect(find.textContaining('Please try again later'), findsOneWidget);
      expect(find.text('openSenseMap responded: HTTP 503: Service Unavailable'),
          findsOneWidget);
      expect(find.text('Cancel'), findsNothing);

      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();

      expect(cancelled, 0);
    });

    testWidgets('shows a connection problem detail',
        (WidgetTester tester) async {
      await pumpRunningModal(tester, onCancel: () {});

      progressController.add(const UploadProgress(
        totalChunks: 2,
        completedChunks: 0,
        failedChunks: 1,
        status: UploadStatus.failed,
        errorMessage: 'Server error 503',
        errorDetail:
            "Failed host lookup: 'api.opensensemap.org' (No address associated with hostname)",
        failureKind: UploadFailureKind.connection,
        canRetry: true,
      ));
      await tester.pump();

      expect(
          find.text('Could not connect to openSenseMap.\n'
              "Reason: Failed host lookup: 'api.opensensemap.org' (No address associated with hostname)"),
          findsOneWidget);
    });

    testWidgets('shows the current upload step', (WidgetTester tester) async {
      await pumpRunningModal(tester, onCancel: () {});

      Future<void> emit(UploadStage stage, int completed,
          {UploadStatus status = UploadStatus.uploading}) async {
        progressController.add(UploadProgress(
          totalChunks: stage == UploadStage.checkingLogin ||
                  stage == UploadStage.loadingTrack
              ? 0
              : 3,
          completedChunks: completed,
          failedChunks: 0,
          status: status,
          canRetry: false,
          stage: stage,
        ));
        await tester.pump();
      }

      await emit(UploadStage.checkingLogin, 0,
          status: UploadStatus.preparing);
      expect(find.text('Checking openSenseMap login...'), findsOneWidget);

      await emit(UploadStage.loadingTrack, 0, status: UploadStatus.preparing);
      expect(find.text('Loading track data...'), findsOneWidget);

      await emit(UploadStage.preparingChunk, 1);
      expect(find.text('Preparing part 2 of 3...'), findsOneWidget);

      await emit(UploadStage.sendingChunk, 1);
      expect(find.text('Uploading part 2 of 3 to openSenseMap...'),
          findsOneWidget);

      await emit(UploadStage.retryingChunk, 1, status: UploadStatus.retrying);
      expect(
          find.text(
              'No response from openSenseMap, retrying part 2 of 3...'),
          findsOneWidget);
    });

    testWidgets('long status text wraps instead of being cut',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(360 * 3, 800 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await pumpRunningModal(tester, onCancel: () {});

      progressController.add(const UploadProgress(
        totalChunks: 1,
        completedChunks: 0,
        failedChunks: 0,
        status: UploadStatus.uploading,
        canRetry: false,
        stage: UploadStage.sendingChunk,
      ));
      await tester.pumpAndSettle();

      const text = 'Uploading part 1 of 1 to openSenseMap...';
      final status = tester.renderObject<RenderParagraph>(find.text(text));
      expect(status.didExceedMaxLines, isFalse);
      final lineHeight = status.getFullHeightForCaret(
          const TextPosition(offset: 0));
      expect(status.size.height, greaterThan(lineHeight * 1.5),
          reason: 'status should wrap onto several lines');
      expect(tester.takeException(), isNull);
    });

    testWidgets('no Cancel button without onCancel (e.g. export)',
        (WidgetTester tester) async {
      await pumpRunningModal(tester);

      progressController.add(const UploadProgress(
        totalChunks: 0,
        completedChunks: 0,
        failedChunks: 0,
        status: UploadStatus.preparing,
        canRetry: false,
      ));
      await tester.pump();

      expect(find.text('Cancel'), findsNothing);
    });
  });

  group('OperationProgressOverlay', () {
    testWidgets('show/hide works with upload service mode',
        (WidgetTester tester) async {
      late StreamController<UploadProgress> progressController;
      late MockBatchUploadService mockService;

      mockService = MockBatchUploadService();
      progressController = StreamController<UploadProgress>.broadcast();

      when(() => mockService.uploadProgressStream)
          .thenAnswer((_) => progressController.stream);

      await tester.pumpWidget(
        createLocalizedTestApp(
          child: Builder(
            builder: (context) {
              return Scaffold(
                body: ElevatedButton(
                  onPressed: () {
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
                  child: const Text('Show Overlay'),
                ),
              );
            },
          ),
          locale: const Locale('en'),
        ),
      );

      expect(find.text('Would you like to upload your track data now?'), findsNothing);
      expect(OperationProgressOverlay.isVisible, isFalse);

      await tester.tap(find.text('Show Overlay'));
      await tester.pump();

      expect(OperationProgressOverlay.isVisible, isTrue);
      expect(find.text('Would you like to upload your track data now?'), findsOneWidget);

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

      await progressController.close();
    });

    testWidgets('does not call onDismiss when hidden programmatically',
        (WidgetTester tester) async {
      late StreamController<UploadProgress> progressController;
      late MockBatchUploadService mockService;
      bool dismissCalled = false;

      mockService = MockBatchUploadService();
      progressController = StreamController<UploadProgress>.broadcast();

      when(() => mockService.uploadProgressStream)
          .thenAnswer((_) => progressController.stream);

      await tester.pumpWidget(
        createLocalizedTestApp(
          child: Builder(
            builder: (context) {
              return Scaffold(
                body: ElevatedButton(
                  onPressed: () {
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
                  child: const Text('Show Overlay'),
                ),
              );
            },
          ),
          locale: const Locale('en'),
        ),
      );

      await tester.tap(find.text('Show Overlay'));
      await tester.pump();

      expect(OperationProgressOverlay.isVisible, isTrue);
      expect(dismissCalled, isFalse);

      OperationProgressOverlay.hide();
      await tester.pump();

      expect(dismissCalled, isFalse);
      expect(OperationProgressOverlay.isVisible, isFalse);

      await progressController.close();
    });

    testWidgets('shows confirmation dialog when using upload config',
        (WidgetTester tester) async {
      late StreamController<UploadProgress> progressController;
      late MockBatchUploadService mockService;

      mockService = MockBatchUploadService();
      progressController = StreamController<UploadProgress>.broadcast();

      when(() => mockService.uploadProgressStream)
          .thenAnswer((_) => progressController.stream);

      await tester.pumpWidget(
        createLocalizedTestApp(
          child: Builder(
            builder: (context) {
              return Scaffold(
                body: ElevatedButton(
                  onPressed: () {
                    OperationProgressOverlay.show(
                      context,
                      config: OperationProgressOverlayConfig.upload(
                        uploadService: mockService,
                      ),
                    );
                  },
                  child: const Text('Show Overlay'),
                ),
              );
            },
          ),
          locale: const Locale('en'),
        ),
      );

      await tester.tap(find.text('Show Overlay'));
      await tester.pump();

      expect(OperationProgressOverlay.isVisible, isTrue);
      expect(find.text('Would you like to upload your track data now?'), findsOneWidget);

      await progressController.close();
    });

    testWidgets('showWithProgressStream starts and renders progress',
        (WidgetTester tester) async {
      late StreamController<UploadProgress> progressController;
      var started = false;

      OperationProgressOverlay.hide();

      progressController = StreamController<UploadProgress>.broadcast();

      await tester.pumpWidget(
        createLocalizedTestApp(
          child: Builder(
            builder: (context) {
              return Scaffold(
                body: ElevatedButton(
                  onPressed: () {
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
                  child: const Text('Show Overlay'),
                ),
              );
            },
          ),
          locale: const Locale('en'),
        ),
      );

      await tester.tap(find.text('Show Overlay'));
      await tester.pump();
      await tester.pump();

      expect(started, isTrue);
      expect(find.text('Would you like to upload your track data now?'),
          findsNothing);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);

      OperationProgressOverlay.hide();
      await tester.pump();
      expect(OperationProgressOverlay.isVisible, isFalse);

      await progressController.close();
    });
  });
}