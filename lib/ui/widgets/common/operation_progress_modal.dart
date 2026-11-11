import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:sensebox_bike/l10n/app_localizations.dart';
import 'package:sensebox_bike/models/upload_progress.dart';
import 'package:sensebox_bike/ui/widgets/common/upload_progress_indicator.dart';
import 'package:sensebox_bike/ui/widgets/common/upload_info_widget.dart';
import 'package:sensebox_bike/theme.dart';
import 'package:sensebox_bike/ui/widgets/common/app_dialog.dart';

class OperationProgressModal extends StatefulWidget {
  final Stream<UploadProgress> progressStream;
  final VoidCallback? onComplete;
  final VoidCallback? onFailed;
  final VoidCallback? onStart;
  final VoidCallback? onDismiss;

  final VoidCallback? onCancel;
  final bool showConfirmation;
  final String? titleText;
  final String? confirmMessageText;
  final String? exportFilePath;
  final Future<void> Function()? onShare;

  const OperationProgressModal({
    super.key,
    required this.progressStream,
    this.onComplete,
    this.onFailed,
    this.onStart,
    this.onDismiss,
    this.onCancel,
    this.showConfirmation = true,
    this.titleText,
    this.confirmMessageText,
    this.exportFilePath,
    this.onShare,
  });

  @override
  State<OperationProgressModal> createState() => _OperationProgressModalState();
}

class _OperationProgressModalState extends State<OperationProgressModal> {
  late final StreamSubscription<UploadProgress> _progressSubscription;
  UploadProgress? _progress;
  late bool _started = !widget.showConfirmation;

  bool get _isRunning {
    final status = _progress?.status;
    return _started &&
        status != UploadStatus.completed &&
        status != UploadStatus.failed;
  }

  @override
  void initState() {
    super.initState();
    _progressSubscription = widget.progressStream.listen(
      _onProgress,
      onError: (Object error) => setState(() {
        _progress = UploadProgress(
          status: UploadStatus.failed,
          errorMessage: '$error',
        );
      }),
    );

    if (_started) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onStart?.call();
      });
    }
  }

  @override
  void dispose() {
    _progressSubscription.cancel();
    super.dispose();
  }

  void _onProgress(UploadProgress progress) {
    setState(() => _progress = progress);

    if (progress.isCompleted) {
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) widget.onComplete?.call();
      });
    }
    if (progress.hasFailed) {
      widget.onFailed?.call();
    }
  }

  void _start() {
    setState(() => _started = true);
    widget.onStart?.call();
  }

  void _close() => Navigator.of(context).pop();

  void _onPopped() {
    if (_isRunning) widget.onCancel?.call();
    widget.onDismiss?.call();
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final progress = _progress;

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) _onPopped();
      },
      child: AppAlertDialog(
        title: Text(widget.titleText ?? localizations.uploadProgressTitle),
        content: !_started
            ? _buildConfirmation(localizations)
            : progress == null
                ? const SizedBox(
                    height: 72,
                    child: Center(child: CircularProgressIndicator()),
                  )
                : _buildProgress(localizations, progress),
        actions: _buildActions(localizations),
      ),
    );
  }

  Widget _buildConfirmation(AppLocalizations localizations) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.confirmMessageText ?? localizations.uploadConfirmMessage),
        const SizedBox(height: 16),
        const UploadInfoWidget(),
      ],
    );
  }

  Widget _buildProgress(
      AppLocalizations localizations, UploadProgress progress) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        UploadProgressIndicator(progress: progress),
        if (progress.isCompleted && widget.exportFilePath != null)
          Padding(
            padding: const EdgeInsets.only(top: spacing),
            child: UploadInfoWidget(
              text: Platform.isIOS
                  ? localizations.trackDetailsFileSavedApplicationDirectory
                  : localizations.fileSavedDownloadsDirectory,
            ),
          ),
      ],
    );
  }

  List<Widget> _buildActions(AppLocalizations localizations) {
    if (!_started) {
      return [
        TextButton(onPressed: _close, child: Text(localizations.generalCancel)),
        FilledButton(
            onPressed: _start, child: Text(localizations.generalUpload)),
      ];
    }

    if (_isRunning) {
      return [
        if (widget.onCancel != null)
          TextButton(
              onPressed: _close, child: Text(localizations.generalCancel)),
      ];
    }

    final canShare = _progress!.isCompleted &&
        widget.exportFilePath != null &&
        widget.onShare != null;
    final close = Text(localizations.generalClose);
    if (canShare) {
      return [
        TextButton(onPressed: _close, child: close),
        FilledButton(
          onPressed: () async {
            await widget.onShare!();
            if (mounted) _close();
          },
          child: Text(localizations.generalShare),
        ),
      ];
    }
    return [
      if (_progress!.isCompleted)
        FilledButton(onPressed: _close, child: close)
      else
        TextButton(onPressed: _close, child: close),
    ];
  }
}
