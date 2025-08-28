import 'dart:async';
import 'package:flutter/material.dart';
import 'package:sensebox_bike/l10n/app_localizations.dart';
import 'package:sensebox_bike/models/upload_progress.dart';
import 'package:sensebox_bike/services/batch_upload_service.dart';
import 'package:sensebox_bike/ui/widgets/common/upload_progress_indicator.dart';
import 'package:sensebox_bike/ui/widgets/common/upload_info_widget.dart';

/// A modal bottom sheet that displays upload progress in real-time.
///
/// This modal slides up from the bottom when an upload starts and shows:
/// - First: Confirmation dialog asking if user wants to upload
/// - Then: Real-time progress updates from BatchUploadService
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

  /// Callback to start the upload (called when user confirms)
  final VoidCallback? onStartUpload;

  /// Callback when modal is dismissed (e.g., user cancels)
  final VoidCallback? onDismiss;

  const UploadProgressModal({
    super.key,
    required this.batchUploadService,
    this.onUploadComplete,
    this.onUploadFailed,
    this.onStartUpload,
    this.onDismiss,
  });

  @override
  State<UploadProgressModal> createState() => _UploadProgressModalState();
}

class _UploadProgressModalState extends State<UploadProgressModal> {
  late StreamSubscription<UploadProgress> _progressSubscription;
  UploadProgress? _currentProgress;
  bool _hasStartedUpload = false;

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
      _hasStartedUpload = true;
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

  void _handleDismiss() {
    widget.onDismiss?.call();
    Navigator.of(context).pop();
    // Note: UploadProgressOverlay.hide() will be called automatically when the dialog is closed
  }

  void _handleStartUpload() {
    setState(() {
      _hasStartedUpload = true;
    });
    widget.onStartUpload?.call();
  }

  @override
  Widget build(BuildContext context) {
    // If upload hasn't started yet, show confirmation dialog
    if (!_hasStartedUpload) {
      return WillPopScope(
        onWillPop: () async {
          // Call onDismiss when modal is closed through back button
          widget.onDismiss?.call();
          return true;
        },
        child: _buildConfirmationDialog(context),
      );
    }

    // If upload has started, show progress
    final progress = _currentProgress;
    if (progress == null) {
      return const SizedBox.shrink();
    }

    return WillPopScope(
      onWillPop: () async {
        // Call onDismiss when modal is closed through back button
        widget.onDismiss?.call();
        return true;
      },
      child: _buildProgressDialog(context, progress),
    );
  }

  Widget _buildConfirmationDialog(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    
    return AlertDialog(
      title: Text(AppLocalizations.of(context)!.uploadProgressTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(localizations.uploadConfirmMessage),
          const SizedBox(height: 16),
          const UploadInfoWidget(),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _handleDismiss,
          child: Text(localizations.generalCancel),
        ),
        FilledButton(
          onPressed: _handleStartUpload,
          child: Text(localizations.generalUpload),
        ),
      ],
    );
  }

  Widget _buildProgressDialog(BuildContext context, UploadProgress progress) {
    return AlertDialog(
      title: Text(AppLocalizations.of(context)!.uploadProgressTitle),
      contentPadding: EdgeInsets.zero,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          UploadProgressIndicator(
            progress: progress,
            compact: false,
          ),
        ],
      ),
      actions: _buildActions(context, progress),
    );
  }

  List<Widget> _buildActions(BuildContext context, UploadProgress progress) {
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
        // Close button for failed uploads
        return [
          TextButton(
            onPressed: _handleDismiss,
            child: Text(AppLocalizations.of(context)!.generalClose),
          ),
        ];
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
    VoidCallback? onStartUpload,
    VoidCallback? onDismiss,
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
        onStartUpload: onStartUpload,
        onDismiss: onDismiss,
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
