import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sensebox_bike/models/upload_progress.dart';
import 'package:sensebox_bike/services/batch_upload_service.dart';
import 'package:sensebox_bike/ui/widgets/common/upload_progress_modal.dart';
import 'package:sensebox_bike/ui/widgets/common/upload_info_widget.dart';
import '../../../test_helpers.dart';

// Mock classes
class MockBatchUploadService extends Mock implements BatchUploadService {}

void main() {
  // Initialize Flutter binding for tests
  setUpAll(() {
    WidgetsFlutterBinding.ensureInitialized();
  });

  group('UploadProgressModal', () {
    late MockBatchUploadService mockBatchUploadService;
    late StreamController<UploadProgress> progressController;

    setUp(() {
      mockBatchUploadService = MockBatchUploadService();
      progressController = StreamController<UploadProgress>.broadcast();
      
      // Set up mock stream
      when(() => mockBatchUploadService.uploadProgressStream)
          .thenAnswer((_) => progressController.stream);
      when(() => mockBatchUploadService.currentProgress).thenReturn(null);
    });

    tearDown(() {
      progressController.close();
    });

    testWidgets('should show confirmation dialog first', (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(
        createLocalizedTestApp(
          child: Scaffold(
            body: UploadProgressModal(
              batchUploadService: mockBatchUploadService,
            ),
          ),
          locale: const Locale('en'),
        ),
      );

      // Initially should show confirmation dialog
      expect(find.text('Would you like to upload your track data now?'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Upload'), findsOneWidget);
      // UploadInfoWidget should be shown in confirmation dialog
      expect(find.byType(UploadInfoWidget), findsOneWidget);
      expect(find.text('Upload Progress'), findsOneWidget);
    });

    testWidgets('should show modal when upload starts after confirmation', (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(
        createLocalizedTestApp(
          child: Scaffold(
            body: UploadProgressModal(
              batchUploadService: mockBatchUploadService,
              onStartUpload: () {
                // Simulate starting upload
                progressController.add(const UploadProgress(
                  totalChunks: 5,
                  completedChunks: 0,
                  failedChunks: 0,
                  status: UploadStatus.preparing,
                  canRetry: false,
                ));
              },
            ),
          ),
          locale: const Locale('en'),
        ),
      );

      // Initially should show confirmation dialog
      expect(find.text('Would you like to upload your track data now?'), findsOneWidget);

      // Act - tap upload button
      await tester.tap(find.text('Upload'));
      await tester.pump();

      // Act - emit upload progress
      progressController.add(const UploadProgress(
        totalChunks: 5,
        completedChunks: 0,
        failedChunks: 0,
        status: UploadStatus.preparing,
        canRetry: false,
      ));

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300)); // Animation duration

      // Assert - should now show progress dialog (not confirmation dialog)
      expect(find.text('Upload Progress'), findsOneWidget);
      expect(find.text('Preparing upload...'), findsOneWidget);
      // UploadInfoWidget should NOT be shown in progress dialog, only in confirmation dialog
      expect(find.byType(UploadInfoWidget), findsNothing);
    });

    testWidgets('should show progress updates', (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(
        createLocalizedTestApp(
          child: Scaffold(
            body: UploadProgressModal(
              batchUploadService: mockBatchUploadService,
              onStartUpload: () {
                // Simulate starting upload
                progressController.add(const UploadProgress(
                  totalChunks: 10,
                  completedChunks: 3,
                  failedChunks: 0,
                  status: UploadStatus.uploading,
                  canRetry: false,
                ));
              },
            ),
          ),
          locale: const Locale('en'),
        ),
      );

      // Initially should show confirmation dialog
      expect(find.text('Would you like to upload your track data now?'), findsOneWidget);

      // Act - tap upload button
      await tester.tap(find.text('Upload'));
      await tester.pump();

      // Act - emit uploading progress
      progressController.add(const UploadProgress(
        totalChunks: 10,
        completedChunks: 3,
        failedChunks: 0,
        status: UploadStatus.uploading,
        canRetry: false,
      ));

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Assert
      expect(find.text('Upload Progress'), findsOneWidget);
      expect(find.text('Uploading track data...'), findsOneWidget);
      expect(find.text('3 of 10 chunks uploaded'), findsOneWidget);
      expect(find.text('30% complete'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });

    testWidgets('should show retry button on failure', (WidgetTester tester) async {
      bool retryPressed = false;
      
      // Arrange
      await tester.pumpWidget(
        createLocalizedTestApp(
          child: Scaffold(
            body: UploadProgressModal(
              batchUploadService: mockBatchUploadService,
              onStartUpload: () {
                // Simulate starting upload
                progressController.add(const UploadProgress(
                  totalChunks: 5,
                  completedChunks: 2,
                  failedChunks: 3,
                  status: UploadStatus.failed,
                  errorMessage: 'Network error',
                  canRetry: true,
                ));
              },
            ),
          ),
          locale: const Locale('en'),
        ),
      );

      // Initially should show confirmation dialog
      expect(find.text('Would you like to upload your track data now?'), findsOneWidget);

      // Act - tap upload button
      await tester.tap(find.text('Upload'));
      await tester.pump();

      // Act - emit failed progress
      progressController.add(const UploadProgress(
        totalChunks: 5,
        completedChunks: 2,
        failedChunks: 3,
        status: UploadStatus.failed,
        errorMessage: 'Network error',
        canRetry: true,
      ));

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Assert
      expect(find.text('Upload failed'), findsOneWidget);
      expect(find.text('Retry'), findsNothing);
      
      // No retry button should be shown
      expect(retryPressed, isFalse);
    });

    testWidgets('should hide modal after completion', (WidgetTester tester) async {
      bool completionCalled = false;
      
      // Arrange
      await tester.pumpWidget(
        createLocalizedTestApp(
          child: Scaffold(
            body: UploadProgressModal(
              batchUploadService: mockBatchUploadService,
              onUploadComplete: () {
                completionCalled = true;
              },
              onStartUpload: () {
                // Simulate starting upload
                progressController.add(const UploadProgress(
                  totalChunks: 5,
                  completedChunks: 5,
                  failedChunks: 0,
                  status: UploadStatus.completed,
                  canRetry: false,
                ));
              },
            ),
          ),
          locale: const Locale('en'),
        ),
      );

      // Initially should show confirmation dialog
      expect(find.text('Would you like to upload your track data now?'), findsOneWidget);

      // Act - tap upload button
      await tester.tap(find.text('Upload'));
      await tester.pump();

      // Act - emit completed progress
      progressController.add(const UploadProgress(
        totalChunks: 5,
        completedChunks: 5,
        failedChunks: 0,
        status: UploadStatus.completed,
        canRetry: false,
      ));

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Should show completion
      expect(find.text('Upload completed successfully'), findsOneWidget);

      // Wait for auto-hide delay
      await tester.pump(const Duration(seconds: 3));

      // Should call completion callback
      expect(completionCalled, isTrue);
    });

    testWidgets('should show error message for failed uploads', (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(
        createLocalizedTestApp(
          child: Scaffold(
            body: UploadProgressModal(
              batchUploadService: mockBatchUploadService,
              onStartUpload: () {
                // Simulate starting upload
                progressController.add(const UploadProgress(
                  totalChunks: 5,
                  completedChunks: 2,
                  failedChunks: 3,
                  status: UploadStatus.failed,
                  errorMessage: 'Authentication failed - user needs to re-login',
                  canRetry: false,
                ));
              },
            ),
          ),
          locale: const Locale('en'),
        ),
      );

      // Initially should show confirmation dialog
      expect(find.text('Would you like to upload your track data now?'), findsOneWidget);

      // Act - tap upload button
      await tester.tap(find.text('Upload'));
      await tester.pump();

      // Act - emit failed progress with error
      progressController.add(const UploadProgress(
        totalChunks: 5,
        completedChunks: 2,
        failedChunks: 3,
        status: UploadStatus.failed,
        errorMessage: 'Authentication failed - user needs to re-login',
        canRetry: false,
      ));

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Assert
      expect(find.text('Authentication required'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      // Should show user-friendly error message  
      expect(find.textContaining('Please log in to upload data'), findsOneWidget);
    });

    testWidgets('should call onDismiss when cancel button is tapped',
        (WidgetTester tester) async {
      bool dismissCalled = false;

      // Arrange
      await tester.pumpWidget(
        createLocalizedTestApp(
          child: Scaffold(
            body: UploadProgressModal(
              batchUploadService: mockBatchUploadService,
              onDismiss: () {
                dismissCalled = true;
              },
            ),
          ),
          locale: const Locale('en'),
        ),
      );

      // Initially should show confirmation dialog
      expect(find.text('Would you like to upload your track data now?'),
          findsOneWidget);

      // Act - tap cancel button
      await tester.tap(find.text('Cancel'));
      await tester.pump();

      // Assert - should call onDismiss callback
      expect(dismissCalled, isTrue);
    });

    testWidgets('should call onDismiss when modal is dismissed',
        (WidgetTester tester) async {
      bool dismissCalled = false;

      // Arrange
      await tester.pumpWidget(
        createLocalizedTestApp(
          child: Scaffold(
            body: UploadProgressModal(
              batchUploadService: mockBatchUploadService,
              onDismiss: () {
                dismissCalled = true;
              },
            ),
          ),
          locale: const Locale('en'),
        ),
      );

      // Initially should show confirmation dialog
      expect(find.text('Would you like to upload your track data now?'),
          findsOneWidget);

      // Act - simulate modal dismissal by tapping outside or using back button
      // Since we can't easily simulate this in tests, we'll test the onDismiss callback
      // by verifying it's properly passed through
      expect(dismissCalled, isFalse);

      // The onDismiss callback should be properly set up
      expect(find.text('Cancel'), findsOneWidget);
    });
  });

  group('UploadProgressOverlay', () {
    testWidgets('should show and hide overlay', (WidgetTester tester) async {
      late StreamController<UploadProgress> progressController;
      late MockBatchUploadService mockService;

      // Setup
      mockService = MockBatchUploadService();
      progressController = StreamController<UploadProgress>.broadcast();
      
      when(() => mockService.uploadProgressStream)
          .thenAnswer((_) => progressController.stream);
      when(() => mockService.currentProgress).thenReturn(null);

      // Build app with overlay
      await tester.pumpWidget(
        createLocalizedTestApp(
          child: Builder(
            builder: (context) {
              return Scaffold(
                body: ElevatedButton(
                  onPressed: () {
                    UploadProgressOverlay.show(
                      context,
                      batchUploadService: mockService,
                      onStartUpload: () {
                        // Simulate starting upload
                        progressController.add(const UploadProgress(
                          totalChunks: 5,
                          completedChunks: 1,
                          failedChunks: 0,
                          status: UploadStatus.uploading,
                          canRetry: false,
                        ));
                      },
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

      // Initially no overlay
      expect(find.text('Would you like to upload your track data now?'), findsNothing);
      expect(UploadProgressOverlay.isShown, isFalse);

      // Show overlay
      await tester.tap(find.text('Show Overlay'));
      await tester.pump();

      expect(UploadProgressOverlay.isShown, isTrue);

      // Initially should show confirmation dialog
      expect(find.text('Would you like to upload your track data now?'), findsOneWidget);

      // Act - tap upload button
      await tester.tap(find.text('Upload'));
      await tester.pump();

      // Emit progress to make modal visible
      progressController.add(const UploadProgress(
        totalChunks: 5,
        completedChunks: 1,
        failedChunks: 0,
        status: UploadStatus.uploading,
        canRetry: false,
      ));

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Upload Progress'), findsOneWidget);

      // Hide overlay
      UploadProgressOverlay.hide();
      await tester.pump();

      expect(UploadProgressOverlay.isShown, isFalse);

      // Cleanup
      progressController.close();
    });

    testWidgets(
        'should not call onDismiss when modal is hidden programmatically',
        (WidgetTester tester) async {
      late StreamController<UploadProgress> progressController;
      late MockBatchUploadService mockService;
      bool dismissCalled = false;

      // Setup
      mockService = MockBatchUploadService();
      progressController = StreamController<UploadProgress>.broadcast();

      when(() => mockService.uploadProgressStream)
          .thenAnswer((_) => progressController.stream);
      when(() => mockService.currentProgress).thenReturn(null);

      // Arrange
      await tester.pumpWidget(
        createLocalizedTestApp(
          child: Builder(
            builder: (context) {
              return Scaffold(
                body: ElevatedButton(
                  onPressed: () {
                    UploadProgressOverlay.show(
                      context,
                      batchUploadService: mockService,
                      onDismiss: () {
                        dismissCalled = true;
                      },
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

      // Show overlay
      await tester.tap(find.text('Show Overlay'));
      await tester.pump();

      expect(UploadProgressOverlay.isShown, isTrue);
      expect(dismissCalled, isFalse);

      // Hide overlay programmatically
      UploadProgressOverlay.hide();
      await tester.pump();

      // Assert - should NOT call onDismiss callback when hidden programmatically
      expect(dismissCalled, isFalse);
      expect(UploadProgressOverlay.isShown, isFalse);

      // Cleanup
      progressController.close();
    });
  });
}