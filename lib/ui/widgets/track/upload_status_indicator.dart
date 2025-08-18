import 'package:flutter/material.dart';
import 'package:sensebox_bike/l10n/app_localizations.dart';
import 'package:sensebox_bike/models/track_data.dart';
import 'package:sensebox_bike/theme.dart';

/// Widget that displays the upload status of a track with appropriate icon and color
class UploadStatusIndicator extends StatelessWidget {
  final TrackData track;
  final VoidCallback? onRetryPressed;
  final bool showText;
  final bool isCompact;

  const UploadStatusIndicator({
    super.key,
    required this.track,
    this.onRetryPressed,
    this.showText = false,
    this.isCompact = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final localizations = AppLocalizations.of(context)!;
    
    final statusColor = _getStatusColor(theme);
    final statusIcon = _getStatusIcon();
    final statusText = _getStatusText(localizations);

    if (isCompact) {
      return _buildCompactIndicator(theme, statusColor, statusIcon, statusText);
    } else {
      return _buildDetailedIndicator(theme, statusColor, statusIcon, statusText, localizations);
    }
  }

  Widget _buildCompactIndicator(ThemeData theme, Color statusColor, IconData statusIcon, String statusText) {
    return Tooltip(
      message: statusText,
      child: Container(
        padding: const EdgeInsets.all(padding / 2),
        decoration: BoxDecoration(
          color: statusColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(borderRadiusSmall),
          border: Border.all(color: statusColor.withOpacity(0.3), width: 1),
        ),
        child: Icon(
          statusIcon,
          size: iconSizeLarge,
          color: statusColor,
        ),
      ),
    );
  }

  Widget _buildDetailedIndicator(ThemeData theme, Color statusColor, IconData statusIcon, String statusText, AppLocalizations localizations) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: spacing / 2, vertical: padding / 2),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(borderRadiusSmall),
        border: Border.all(color: statusColor.withOpacity(0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            statusIcon,
            size: iconSizeLarge,
            color: statusColor,
          ),
          if (showText) ...[
            const SizedBox(width: spacing / 4),
            Text(
              statusText,
              style: theme.textTheme.bodySmall?.copyWith(
                color: statusColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          if (_canRetry() && onRetryPressed != null) ...[
            const SizedBox(width: spacing / 4),
            GestureDetector(
              onTap: onRetryPressed,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(borderRadiusSmall / 2),
                ),
                child: Icon(
                  Icons.refresh,
                  size: iconSize,
                  color: statusColor,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  UploadStatus _getUploadStatus() {
    if (track.uploaded) {
      return UploadStatus.uploaded;
    } else if (track.uploadAttempts > 0) {
      return UploadStatus.failed;
    } else {
      return UploadStatus.notUploaded;
    }
  }

  Color _getStatusColor(ThemeData theme) {
    switch (_getUploadStatus()) {
      case UploadStatus.uploaded:
        return Colors.green;
      case UploadStatus.failed:
        return theme.colorScheme.error;
      case UploadStatus.notUploaded:
        return theme.colorScheme.outline;
    }
  }

  IconData _getStatusIcon() {
    switch (_getUploadStatus()) {
      case UploadStatus.uploaded:
        return Icons.cloud_done;
      case UploadStatus.failed:
        return Icons.cloud_off;
      case UploadStatus.notUploaded:
        return Icons.cloud_upload;
    }
  }

  String _getStatusText(AppLocalizations localizations) {
    switch (_getUploadStatus()) {
      case UploadStatus.uploaded:
        return localizations.trackStatusUploaded;
      case UploadStatus.failed:
        return localizations.trackStatusUploadFailed;
      case UploadStatus.notUploaded:
        return localizations.trackStatusNotUploaded;
    }
  }

  bool _canRetry() {
    return _getUploadStatus() == UploadStatus.failed || _getUploadStatus() == UploadStatus.notUploaded;
  }
}

enum UploadStatus {
  uploaded,
  failed,
  notUploaded,
}