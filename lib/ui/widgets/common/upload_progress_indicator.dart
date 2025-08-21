import 'package:flutter/material.dart';
import 'package:sensebox_bike/l10n/app_localizations.dart';
import 'package:sensebox_bike/models/upload_progress.dart';
import 'package:sensebox_bike/ui/widgets/common/loader.dart';
import 'package:sensebox_bike/theme.dart';

/// A widget that displays upload progress with status text, progress bar, and action buttons.
///
/// This widget integrates with BatchUploadService progress stream to show real-time
/// upload status including:
/// - Progress bar for upload completion
/// - Status text for current upload state
/// - Loading indicators during upload
/// - Success confirmation messages
/// - Error messages with retry options
/// - Authentication failure handling
class UploadProgressIndicator extends StatelessWidget {
  /// Current upload progress state
  final UploadProgress progress;

  /// Whether to show the progress indicator in a compact form
  final bool compact;

  const UploadProgressIndicator({
    super.key,
    required this.progress,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    if (compact) {
      return _buildCompactIndicator(context, localizations, theme);
    } else {
      return _buildFullIndicator(context, localizations, theme);
    }
  }

  /// Builds a compact version of the progress indicator for use in lists or small spaces
  Widget _buildCompactIndicator(
      BuildContext context, AppLocalizations localizations, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: _getBackgroundColor(theme),
        borderRadius: BorderRadius.circular(borderRadiusSmall),
        border: Border.all(
          color: _getBorderColor(theme),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          _buildStatusIcon(theme),
          const SizedBox(width: spacing),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _getStatusText(localizations),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: _getTextColor(theme),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (progress.isInProgress) ...[
                  const SizedBox(height: 4),
                  LinearProgressIndicator(
                    value: progress.progressPercentage,
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      theme.colorScheme.primary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the full version of the progress indicator with detailed information
  Widget _buildFullIndicator(
      BuildContext context, AppLocalizations localizations, ThemeData theme) {
    return Card(
      margin: const EdgeInsets.all(spacing),
      child: Padding(
        padding: const EdgeInsets.all(spacing * 1.5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Status text with icon
            Row(
              children: [
                _buildStatusIcon(theme),
                const SizedBox(width: spacing),
                Expanded(
                  child: Text(
                    _getStatusText(localizations),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: _getTextColor(theme),
                    ),
                  ),
                ),
              ],
            ),

            // Progress information and bar
            if (progress.totalChunks > 0) ...[
              const SizedBox(height: spacing),

              // Progress text
              Text(
                localizations.uploadProgressChunks(
                  progress.completedChunks,
                  progress.totalChunks,
                ),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),

              const SizedBox(height: spacing / 2),

              // Progress bar
              LinearProgressIndicator(
                value: progress.progressPercentage,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(
                  _getProgressColor(theme),
                ),
              ),

              const SizedBox(height: spacing / 2),

              // Percentage text
              Text(
                localizations
                    .uploadProgressPercentage(progress.progressPercentageInt),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],

            // Error message
            if (progress.hasFailed && progress.errorMessage != null) ...[
              const SizedBox(height: spacing),
              Container(
                padding: const EdgeInsets.all(padding),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(borderRadiusSmall),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.error_outline,
                      color: theme.colorScheme.onErrorContainer,
                      size: iconSizeLarge,
                    ),
                    const SizedBox(width: spacing / 2),
                    Expanded(
                      child: Text(
                        _getErrorMessage(localizations, progress.errorMessage!),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Builds the appropriate status icon based on upload state
  Widget _buildStatusIcon(ThemeData theme) {
    switch (progress.status) {
      case UploadStatus.preparing:
        return const Loader();
      case UploadStatus.uploading:
        return Icon(
          Icons.cloud_upload,
          color: theme.colorScheme.primary,
          size: circleSize,
        );
      case UploadStatus.retrying:
        return const Loader();
      case UploadStatus.completed:
        return Icon(
          Icons.check_circle,
          color: theme.colorScheme.primary,
          size: circleSize,
        );
      case UploadStatus.failed:
        return Icon(
          Icons.error,
          color: theme.colorScheme.error,
          size: circleSize,
        );
    }
  }

  /// Gets the appropriate status text based on upload state
  String _getStatusText(AppLocalizations localizations) {
    switch (progress.status) {
      case UploadStatus.preparing:
        return localizations.uploadProgressPreparing;
      case UploadStatus.uploading:
        return localizations.uploadProgressUploading;
      case UploadStatus.retrying:
        return localizations.uploadProgressRetrying;
      case UploadStatus.completed:
        return localizations.uploadProgressCompleted;
      case UploadStatus.failed:
        if (progress.errorMessage?.contains('Authentication failed') == true ||
            progress.errorMessage?.contains('user needs to re-login') == true) {
          return localizations.uploadProgressAuthenticationFailed;
        }
        return localizations.uploadProgressFailed;
    }
  }

  /// Gets user-friendly error message
  String _getErrorMessage(AppLocalizations localizations, String errorMessage) {
    if (errorMessage.contains('Authentication failed') ||
        errorMessage.contains('user needs to re-login')) {
      return localizations.uploadProgressAuthenticationError;
    } else if (errorMessage.contains('network') ||
        errorMessage.contains('connection')) {
      return localizations.uploadProgressNetworkError;
    } else {
      return localizations.uploadProgressGenericError;
    }
  }

  /// Gets the appropriate text color based on upload state
  Color _getTextColor(ThemeData theme) {
    switch (progress.status) {
      case UploadStatus.preparing:
      case UploadStatus.uploading:
      case UploadStatus.retrying:
      case UploadStatus.completed:
        return theme.colorScheme.onSurface;
      case UploadStatus.failed:
        return theme.colorScheme.error;
    }
  }

  /// Gets the appropriate background color for compact mode
  Color _getBackgroundColor(ThemeData theme) {
    switch (progress.status) {
      case UploadStatus.preparing:
      case UploadStatus.uploading:
      case UploadStatus.retrying:
      case UploadStatus.completed:
        return theme.colorScheme.surfaceContainerLow;
      case UploadStatus.failed:
        return theme.colorScheme.errorContainer;
    }
  }

  /// Gets the appropriate border color for compact mode
  Color _getBorderColor(ThemeData theme) {
    switch (progress.status) {
      case UploadStatus.preparing:
      case UploadStatus.uploading:
      case UploadStatus.retrying:
        return theme.colorScheme.outline;
      case UploadStatus.completed:
        return theme.colorScheme.tertiary;
      case UploadStatus.failed:
        return theme.colorScheme.error;
    }
  }

  /// Gets the appropriate progress bar color
  Color _getProgressColor(ThemeData theme) {
    switch (progress.status) {
      case UploadStatus.preparing:
      case UploadStatus.uploading:
      case UploadStatus.completed:
        return theme.colorScheme.primary;
      case UploadStatus.retrying:
        return theme.colorScheme.secondary;
      case UploadStatus.failed:
        return theme.colorScheme.error;
    }
  }
}
