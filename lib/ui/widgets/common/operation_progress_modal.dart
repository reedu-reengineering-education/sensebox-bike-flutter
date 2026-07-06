import 'dart:async';
import 'package:flutter/material.dart';
import 'package:sensebox_bike/l10n/app_localizations.dart';
import 'package:sensebox_bike/models/upload_progress.dart';
import 'package:sensebox_bike/ui/widgets/common/upload_progress_indicator.dart';
import 'package:sensebox_bike/ui/widgets/common/upload_info_widget.dart';

class OperationProgressModal extends StatefulWidget {
  final Stream<UploadProgress> progressStream;
  final VoidCallback? onComplete;
  final VoidCallback? onFailed;
  final VoidCallback? onStart;
  final VoidCallback? onDismiss;
  final bool showConfirmation;
  final String? titleText;
  final String? confirmMessageText;

  const OperationProgressModal({
    super.key,
    required this.progressStream,
    this.onComplete,
    this.onFailed,
    this.onStart,
    this.onDismiss,
    this.showConfirmation = true,
    this.titleText,
    this.confirmMessageText,
  });

  @override
  State<OperationProgressModal> createState() => _OperationProgressModalState();
}

class _OperationProgressModalState extends State<OperationProgressModal> {
  late StreamSubscription<UploadProgress> _progressSubscription;
  UploadProgress? _currentProgress;
  bool _hasStartedOperation = false;
  bool _dismissCallbackHandled = false;

  @override
  void initState() {
    super.initState();

    _progressSubscription =
        widget.progressStream.listen(
      _onProgressUpdate,
      onError: (error) {
        debugPrint('[OperationProgressModal] Stream error: $error');
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

    if (!widget.showConfirmation) {
      _hasStartedOperation = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          widget.onStart?.call();
        }
      });
    }

  }

  @override
  void dispose() {
    _progressSubscription.cancel();
    super.dispose();
  }

  void _onProgressUpdate(UploadProgress progress) {
    setState(() {
      _currentProgress = progress;
    });

    if (progress.isCompleted) {
      _handleOperationComplete();
    }

    if (progress.hasFailed && !progress.canRetry) {
      _handleOperationFailed();
    }
  }

  void _handleOperationComplete() {
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        widget.onComplete?.call();
      }
    });
  }

  void _handleOperationFailed() {
    widget.onFailed?.call();
  }

  void _handleDismiss() {
    if (!_dismissCallbackHandled) {
      _dismissCallbackHandled = true;
      widget.onDismiss?.call();
    }
    Navigator.of(context).pop();
  }

  void _handleStartOperation() {
    setState(() {
      _hasStartedOperation = true;
    });
    widget.onStart?.call();
  }

  void _handlePopInvoked(bool didPop) {
    if (didPop && !_dismissCallbackHandled) {
      _dismissCallbackHandled = true;
      widget.onDismiss?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.showConfirmation && !_hasStartedOperation) {
      return PopScope(
        canPop: true,
        onPopInvokedWithResult: (didPop, result) => _handlePopInvoked(didPop),
        child: _buildConfirmationDialog(context),
      );
    }

    final progress = _currentProgress;
    if (progress == null) {
      return AlertDialog(
        title: Text(widget.titleText ?? AppLocalizations.of(context)!.uploadProgressTitle),
        content: const SizedBox(
          height: 72,
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) => _handlePopInvoked(didPop),
      child: _buildProgressDialog(context, progress),
    );
  }

  Widget _buildConfirmationDialog(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final titleText = widget.titleText ?? localizations.uploadProgressTitle;
    final confirmText = widget.confirmMessageText ?? localizations.uploadConfirmMessage;
    
    return AlertDialog(
      title: Text(titleText),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(confirmText),
          const SizedBox(height: 16),
          if (widget.showConfirmation) const UploadInfoWidget(),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _handleDismiss,
          child: Text(localizations.generalCancel),
        ),
        FilledButton(
          onPressed: _handleStartOperation,
          child: Text(localizations.generalUpload),
        ),
      ],
    );
  }

  Widget _buildProgressDialog(BuildContext context, UploadProgress progress) {
    return AlertDialog(
      title: Text(widget.titleText ?? AppLocalizations.of(context)!.uploadProgressTitle),
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
        return [];

      case UploadStatus.completed:
        return [
          FilledButton(
            onPressed: _handleDismiss,
            child: Text(AppLocalizations.of(context)!.generalClose),
          ),
        ];

      case UploadStatus.failed:
        return [
          TextButton(
            onPressed: _handleDismiss,
            child: Text(AppLocalizations.of(context)!.generalClose),
          ),
        ];
    }
  }
}
