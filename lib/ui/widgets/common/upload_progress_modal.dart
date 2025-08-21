import 'dart:async';
import 'package:flutter/material.dart';
import 'package:sensebox_bike/l10n/app_localizations.dart';
import 'package:sensebox_bike/models/upload_progress.dart';
import 'package:sensebox_bike/services/batch_upload_service.dart';
import 'package:sensebox_bike/ui/widgets/common/upload_progress_indicator.dart';
import 'package:sensebox_bike/theme.dart';

/// A modal bottom sheet that displays upload progress in real-time.
///
/// This modal slides up from the bottom when an upload starts and shows:
/// - Real-time progress updates from BatchUploadService
/// - Progress bar and percentage
/// - Status messages (preparing, uploading, retrying, completed, failed)
/// - Retry button for failed uploads
/// - Success confirmation
/// - Error handling with user-friendly messages
class UploadProgressModal extends StatefulWidget {
  /// The batch upload service to monitor for progress
  final BatchUploadService batchUploadService;

  /// Callback when upload completes successfully
  final VoidCallback? onUploadComplete;

  /// Callback when upload fails permanently
  final VoidCallback? onUploadFailed;

  /// Callback when user requests retry
  final VoidCallback? onRetryRequested;

  const UploadProgressModal({
    super.key,
    required this.batchUploadService,
    this.onUploadComplete,
    this.onUploadFailed,
    this.onRetryRequested,
  });

  @override
  State<UploadProgressModal> createState() => _UploadProgressModalState();
}

class _UploadProgressModalState extends State<UploadProgressModal> {
  late StreamSubscription<UploadProgress> _progressSubscription;
  UploadProgress? _currentProgress;

  @override
  void initState() {
    super.initState();

    // Listen to upload progress
    _progressSubscription =
        widget.batchUploadService.uploadProgressStream.listen(
      _onProgressUpdate,
      onError: (error) {
        debugPrint('[UploadProgressModal] Stream error: $error');
        // Handle stream errors by showing them in the modal
        setState(() {
          _currentProgress = UploadProgress(
            totalChunks: 0,
            completedChunks: 0,
            failedChunks: 0,
            status: UploadStatus.failed,
            errorMessage: error.toString(),
            canRetry: true,
          );
        });
      },
    );

    // Check if there's already an upload in progress
    final currentProgress = widget.batchUploadService.currentProgress;
    if (currentProgress != null) {
      _onProgressUpdate(currentProgress);
    }
  }

  @override
  void dispose() {
    _progressSubscription.cancel();
    UploadProgressOverlay.hide();
    super.dispose();
  }

  void _onProgressUpdate(UploadProgress progress) {
    setState(() {
      _currentProgress = progress;
    });

    // Handle completion
    if (progress.isCompleted) {
      _handleUploadComplete();
    }

    // Handle permanent failure
    if (progress.hasFailed && !progress.canRetry) {
      _handleUploadFailed();
    }
  }

  void _handleUploadComplete() {
    // Show success for a moment, then hide
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        widget.onUploadComplete?.call();
      }
    });
  }

  void _handleUploadFailed() {
    // Keep modal open for failed uploads so user can retry
    widget.onUploadFailed?.call();
  }

  void _handleRetry() {
    widget.onRetryRequested?.call();
  }

  void _handleDismiss() {
    UploadProgressOverlay.hide();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final progress = _currentProgress;
    if (progress == null) {
      return const SizedBox.shrink();
    }

    return _buildModalContent(context, progress);
  }

  Widget _buildModalContent(BuildContext context, UploadProgress progress) {
    return AlertDialog(
      title: Text(AppLocalizations.of(context)!.uploadProgressTitle),
      contentPadding: EdgeInsets.zero,
      content: UploadProgressIndicator(
        progress: progress,
        compact: false,
      ),
      actions: _buildActions(context, progress),
    );
  }

  List<Widget> _buildActions(BuildContext context, UploadProgress progress) {
    final theme = Theme.of(context);

    switch (progress.status) {
      case UploadStatus.preparing:
      case UploadStatus.uploading:
      case UploadStatus.retrying:
        // No buttons during active upload
        return [];

      case UploadStatus.completed:
        // Success button
        return [
          FilledButton(
            onPressed: _handleDismiss,
            child: Text(AppLocalizations.of(context)!.generalClose),
          ),
        ];

      case UploadStatus.failed:
        if (progress.canRetry) {
          // Retry button
          return [
            FilledButton(
              onPressed: _handleRetry,
              style: FilledButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
              ),
              child: Text(AppLocalizations.of(context)!.generalRetry),
            ),
            TextButton(
              onPressed: _handleDismiss,
              child: Text(AppLocalizations.of(context)!.generalCancel),
            ),
          ];
        } else {
          // Close button for permanent failure
          return [
            TextButton(
              onPressed: _handleDismiss,
              child: Text(AppLocalizations.of(context)!.generalClose),
            ),
          ];
        }
    }
  }
}

/// Shows the upload progress modal as a dialog
///
/// This function shows a dialog that displays the upload progress
/// and manages its lifecycle automatically.
class UploadProgressOverlay {
  static bool _isShown = false;

  /// Shows the upload progress modal
  static void show(
    BuildContext context, {
    required BatchUploadService batchUploadService,
    VoidCallback? onUploadComplete,
    VoidCallback? onUploadFailed,
    VoidCallback? onRetryRequested,
  }) {
    if (_isShown) return;

    _isShown = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => UploadProgressModal(
        batchUploadService: batchUploadService,
        onUploadComplete: () {
          hide();
          onUploadComplete?.call();
        },
        onUploadFailed: onUploadFailed,
        onRetryRequested: onRetryRequested,
      ),
    );
  }

  /// Hides the upload progress modal
  static void hide() {
    _isShown = false;
  }

  /// Whether the modal is currently shown
  static bool get isShown => _isShown;
}
