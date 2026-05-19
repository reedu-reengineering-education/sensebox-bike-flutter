import 'dart:async';
import 'package:flutter/material.dart';
import 'package:sensebox_bike/l10n/app_localizations.dart';
import 'package:sensebox_bike/models/upload_progress.dart';
import 'package:sensebox_bike/services/batch_upload_service.dart';
import 'package:sensebox_bike/ui/widgets/common/upload_progress_indicator.dart';
import 'package:sensebox_bike/ui/widgets/common/upload_info_widget.dart';
import 'package:sensebox_bike/ui/widgets/common/app_dialog.dart';

class UploadProgressModal extends StatefulWidget {
  final BatchUploadService batchUploadService;
  final VoidCallback? onUploadComplete;
  final VoidCallback? onUploadFailed;
  final VoidCallback? onStartUpload;
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

    _progressSubscription =
        widget.batchUploadService.uploadProgressStream.listen(
      _onProgressUpdate,
      onError: (error) {
        debugPrint('[UploadProgressModal] Stream error: $error');
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

  }

  @override
  void dispose() {
    _progressSubscription.cancel();
    UploadProgressOverlay._resetState();
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

    return AppDialog(
      type: AppDialogType.info,
      title: localizations.uploadProgressTitle,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppDialog.messageContent(context, localizations.uploadConfirmMessage),
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
    return AppDialog(
      type: AppDialogType.info,
      title: AppLocalizations.of(context)!.uploadProgressTitle,
      content: UploadProgressIndicator(
        progress: progress,
        compact: false,
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
  static BuildContext? _lastContext;

  /// Shows the upload progress modal
  static void show(
    BuildContext context, {
    required BatchUploadService batchUploadService,
    bool canUpload = true,
    required bool isAuthenticated,
    required bool hasSelectedBox,
    VoidCallback? onUploadComplete,
    VoidCallback? onUploadFailed,
    VoidCallback? onStartUpload,
    VoidCallback? onDismiss,
  }) {
    if (_isShown) return;
    _isShown = true;
    _lastContext = context;

    if (!canUpload) {
      final localizations = AppLocalizations.of(context)!;
      String message;
      if (!isAuthenticated) {
        message = localizations.uploadBlockNotAuthenticated;
      } else if (!hasSelectedBox) {
        message = localizations.uploadBlockNoBox;
      } else {
        message = localizations.uploadPostRideRequirementsMessage;
      }
      showAppDialog(
        context: context,
        title: localizations.uploadRequirementsTitle,
        message: message,
        type: AppDialogType.info,
        confirmLabel: localizations.generalOk,
      ).then((_) {
        UploadProgressOverlay.hide();
        onDismiss?.call();
      });
      return;
    }
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => UploadProgressModal(
        batchUploadService: batchUploadService,
        onUploadComplete: () {
          UploadProgressOverlay.hide();
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
    if (_isShown) {
      _isShown = false;
      if (_lastContext != null) {
        final navigator = Navigator.maybeOf(_lastContext!);
        if (navigator != null && navigator.canPop()) {
          navigator.pop();
        }
        _lastContext = null;
      }
    }
  }

  /// Resets overlay state without navigating. Safe to call from dispose(),
  /// where the widget tree is locked and Navigator.pop() is forbidden.
  static void _resetState() {
    _isShown = false;
    _lastContext = null;
  }

  /// Whether the modal is currently shown
  static bool get isShown => _isShown;
}
