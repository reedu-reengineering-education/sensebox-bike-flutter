import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:sensebox_bike/l10n/app_localizations.dart';
import 'package:intl/intl.dart';
import 'package:sensebox_bike/models/track_data.dart';
import 'package:sensebox_bike/secrets.dart';
import 'package:sensebox_bike/theme.dart';
import 'package:sensebox_bike/ui/screens/track_detail_screen.dart';
import 'package:sensebox_bike/ui/widgets/common/clickable_tile.dart';

const double kMapPreviewWidth = 140;
const double kMapPreviewHeight = 140;

class TrackListItem extends StatelessWidget {
  final TrackData track;
  final Function onDismissed;

  const TrackListItem({
    required this.track,
    required this.onDismissed,
    super.key,
  });

  String buildStaticMapboxUrl(BuildContext context) {
    bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    String style = isDarkMode ? 'dark-v11' : 'light-v11';
    String lineColor = isDarkMode ? 'fff' : '111';
    String polyline = Uri.encodeComponent(track.encodedPolyline);

    if (polyline.isEmpty) {
      return '';
    }

    return 'https://api.mapbox.com/styles/v1/mapbox/$style/static/path-1+$lineColor-0.8($polyline)/auto/${kMapPreviewWidth.toInt()}x${kMapPreviewHeight.toInt()}?access_token=$mapboxAccessToken';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final localizations = AppLocalizations.of(context)!;
    final hasGeolocations = track.geolocations.isNotEmpty;

    return Padding(
        padding: EdgeInsets.only(bottom: spacing, top: spacing),
        child: Dismissible(
            key: Key(track.id.toString()),
            background: _buildDismissBackground(theme),
            confirmDismiss: (direction) =>
                _confirmDismiss(context, localizations, theme),
            onDismissed: (direction) => onDismissed(),
            child: ClickableTile(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => TrackDetailScreen(track: track),
                ),
              ),
              child: hasGeolocations
                  ? _buildTrackContent(context, localizations, theme, track)
                  : _buildNoGeolocationsContent(context, localizations, theme),
            )));
  }

  Widget _buildDismissBackground(ThemeData theme) {
    return Container(
      color: theme.colorScheme.error,
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: spacing),
      child: const Icon(Icons.delete_outline),
    );
  }

  Future<bool?> _confirmDismiss(
      BuildContext context, AppLocalizations localizations, ThemeData theme) {
    return showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(localizations.trackDelete),
          content: Text(localizations.trackDeleteConfirmation),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(localizations.generalCancel),
            ),
            FilledButton(
              style: ButtonStyle(
                backgroundColor: WidgetStateProperty.all(
                  theme.colorScheme.error,
                ),
              ),
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(localizations.generalDelete),
            ),
          ],
        );
      },
    );
  }

  Widget _buildNoGeolocationsContent(
      BuildContext context, AppLocalizations localizations, ThemeData theme) {
    return Row(
      children: [
        Expanded(
          child: Center(
            child: Text(
              localizations.trackNoGeolocations,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.error),
            ),
          ),
        ),
        _buildStatusIcon(context, localizations, theme),
      ],
    );
  }

  Widget _buildTrackContent(BuildContext context,
      AppLocalizations localizations, ThemeData theme, TrackData track) {
    final date =
        DateFormat('dd.MM.yyyy').format(track.geolocations.first.timestamp);
    final trackStart =
        DateFormat('HH:mm').format(track.geolocations.first.timestamp);
    final trackEnd =
        DateFormat('HH:mm').format(track.geolocations.last.timestamp);
    final times = '$trackStart - $trackEnd';
    final duration = localizations.generalTrackDurationShort(
        track.duration.inHours.toString(),
        track.duration.inMinutes.remainder(60).toString().padLeft(2, '0'));
    final distance =
        localizations.generalTrackDistance(track.distance.toStringAsFixed(2));
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Map Section
        SizedBox(
            width: kMapPreviewWidth,
            height: kMapPreviewHeight,
            child: CachedNetworkImage(
                imageUrl: buildStaticMapboxUrl(context),
                fit: BoxFit.cover,
                progressIndicatorBuilder: (context, url, downloadProgress) =>
                    Center(
                        child: CircularProgressIndicator(
                            value: downloadProgress.progress)),
                errorWidget: (context, url, error) => Container(
                      width: kMapPreviewWidth,
                      height: kMapPreviewHeight,
                      color: colorScheme.errorContainer,
                      child: Icon(Icons.error_outline, size: iconSizeLarge),
                    ))),
        // Track Info Section
        const SizedBox(width: spacing),
        Expanded(
          child: SizedBox(
            height: kMapPreviewHeight,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(date, style: theme.textTheme.titleSmall),
                        Text(times, style: theme.textTheme.titleSmall),
                      ],
                    ),
                    _buildStatusIcon(context, localizations, theme),
                  ],
                ),
                Column(
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.timer_outlined, size: iconSizeLarge),
                        const SizedBox(width: spacing / 4),
                        Text(duration, style: theme.textTheme.headlineLarge),
                      ],
                    ),
                    Row(
                      children: [
                        const Icon(Icons.straighten_outlined,
                            size: iconSizeLarge),
                        const SizedBox(width: spacing / 4),
                        Text(distance, style: theme.textTheme.headlineLarge),
                      ],
                    ),
                  ],
                )
              ],
            ),
          ),
        )
      ],
    );
  }

  Widget _buildStatusIcon(
      BuildContext context, AppLocalizations localizations, ThemeData theme) {
    final statusColor = _getStatusColor(theme);
    final statusIcon = _getStatusIcon();
    final statusText = _getStatusText(localizations);

    return Tooltip(
      message: statusText,
      child: Container(
        padding: const EdgeInsets.all(padding),
        decoration: BoxDecoration(
          color: statusColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(borderRadiusSmall),
        ),
        child: Icon(
          statusIcon,
          size: iconSizeLarge,
          color: statusColor,
        ),
      ),
    );
  }

  Color _getStatusColor(ThemeData theme) {
    if (track.uploaded) {
      return theme.colorScheme.success;
    } else if (track.uploadAttempts > 0) {
      return theme.colorScheme.error;
    } else {
      return theme.colorScheme.outline;
    }
  }

  IconData _getStatusIcon() {
    if (track.uploaded) {
      return Icons.cloud_done;
    } else if (track.uploadAttempts > 0) {
      return Icons.cloud_off;
    } else {
      return Icons.cloud_upload;
    }
  }

  String _getStatusText(AppLocalizations localizations) {
    if (track.uploaded) {
      return localizations.trackStatusUploaded;
    } else if (track.uploadAttempts > 0) {
      return localizations.trackStatusUploadFailed;
    } else {
      return localizations.trackStatusNotUploaded;
    }
  }
}
