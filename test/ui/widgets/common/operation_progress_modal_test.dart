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
      expect(find.byType(UploadInfoWidget), findsNothing);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);

      OperationProgressOverlay.hide();
      await tester.pump();
      expect(OperationProgressOverlay.isVisible, isFalse);

      await progressController.close();
    });
  });
}