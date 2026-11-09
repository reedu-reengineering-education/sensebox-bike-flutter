import 'dart:math';

import 'package:flutter/material.dart';
import 'package:sensebox_bike/l10n/app_localizations.dart';
import 'package:sensebox_bike/models/upload_progress.dart';
import 'package:sensebox_bike/services/export_progress_service.dart';
import 'package:sensebox_bike/theme.dart';
import 'package:sensebox_bike/ui/widgets/common/loader.dart';
import 'package:sensebox_bike/ui/widgets/common/upload_info_widget.dart';

class UploadProgressIndicator extends StatelessWidget {
  final UploadProgress progress;

  const UploadProgressIndicator({super.key, required this.progress});

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final statusColor = _statusColor(colors);
    final errorDetail = _errorDetail(localizations);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      spacing: spacing,
      children: [
        Container(
          padding: const EdgeInsets.all(padding),
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.2),
            borderRadius: BorderRadius.circular(borderRadiusSmall),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: spacing,
            children: [
              _statusIcon(colors),
              Expanded(
                child: Text(
                  _statusText(localizations),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: progress.hasFailed ? colors.error : colors.onSurface,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (progress.isInProgress) const UploadInfoWidget(),
        if (progress.totalChunks > 0)
          LinearProgressIndicator(
            value: progress.progressPercentage,
            backgroundColor: colors.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation<Color>(statusColor),
          ),
        if (progress.hasFailed && progress.errorMessage != null)
          Container(
            padding: const EdgeInsets.all(padding),
            decoration: BoxDecoration(
              color: colors.errorContainer,
              borderRadius: BorderRadius.circular(borderRadiusSmall),
            ),
            child: Row(
              spacing: spacing / 2,
              children: [
                Icon(Icons.error_outline,
                    color: colors.onErrorContainer, size: iconSizeLarge),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    spacing: spacing / 2,
                    children: [
                      Text(
                        _errorMessage(localizations, progress.errorMessage!),
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: colors.onErrorContainer),
                      ),
                      if (errorDetail != null)
                        Text(
                          errorDetail,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.onErrorContainer,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _statusIcon(ColorScheme colors) {
    return switch (progress.status) {
      UploadStatus.preparing || UploadStatus.retrying => const Loader(),
      UploadStatus.uploading =>
        Icon(Icons.cloud_upload, color: colors.primary, size: circleSize),
      UploadStatus.completed =>
        Icon(Icons.check_circle, color: colors.primary, size: circleSize),
      UploadStatus.failed =>
        Icon(Icons.error, color: colors.error, size: circleSize),
    };
  }

  Color _statusColor(ColorScheme colors) {
    return switch (progress.status) {
      UploadStatus.preparing || UploadStatus.uploading => colors.primary,
      UploadStatus.retrying => colors.secondary,
      UploadStatus.completed => colors.success,
      UploadStatus.failed => colors.error,
    };
  }

  String _statusText(AppLocalizations localizations) {
    final total = progress.totalChunks;
    final current = min(progress.completedChunks + 1, max(total, 1));
    final stage = progress.stage;
    return switch (progress.status) {
      UploadStatus.preparing when stage == UploadStage.checkingLogin =>
        localizations.uploadStageCheckingLogin,
      UploadStatus.preparing => localizations.uploadProgressPreparing,
      UploadStatus.uploading when stage == UploadStage.uploadingPart =>
        localizations.uploadStageUploadingPart(current, total),
      UploadStatus.uploading => localizations.uploadProgressUploading,
      UploadStatus.retrying => localizations.uploadProgressRetrying,
      UploadStatus.completed => localizations.uploadProgressCompleted,
      UploadStatus.failed
          when progress.failureKind == UploadFailureKind.authentication =>
        localizations.uploadProgressAuthenticationFailed,
      UploadStatus.failed => localizations.uploadProgressFailed,
    };
  }

  String _errorMessage(AppLocalizations localizations, String errorMessage) {
    return switch (errorMessage) {
      ExportProgressService.exportLoginRequiredErrorToken =>
        localizations.exportRequiresLoginToOpenSenseMap,
      ExportProgressService.exportNoGeolocationsErrorToken =>
        localizations.errorTrackNoGeolocations,
      ExportProgressService.exportDirectoryAccessErrorToken =>
        localizations.errorExportDirectoryAccess,
      ExportProgressService.exportFailedErrorToken =>
        localizations.errorExportFailed,
      _ => switch (progress.failureKind) {
          UploadFailureKind.authentication =>
            localizations.uploadProgressAuthenticationError,
          UploadFailureKind.connection => localizations.errorUploadFailed,
          UploadFailureKind.apiResponse ||
          UploadFailureKind.other =>
            localizations.uploadErrorTryLater,
          null => localizations.uploadProgressGenericError,
        },
    };
  }

  String? _errorDetail(AppLocalizations localizations) {
    final detail = progress.errorDetail;
    if (detail == null ||
        detail.isEmpty ||
        progress.failureKind == UploadFailureKind.authentication) {
      return null;
    }
    return '${localizations.errorReasonPrefix} $detail';
  }
}
