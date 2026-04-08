import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sensebox_bike/app/app_router.dart';
import 'package:sensebox_bike/l10n/app_localizations.dart';
import 'package:sensebox_bike/models/track_data.dart';
import 'package:sensebox_bike/secrets.dart';
import 'package:sensebox_bike/theme.dart';
import 'package:sensebox_bike/blocs/track_bloc.dart';
import 'package:sensebox_bike/ui/widgets/common/app_dialog.dart';

const double kMapPreviewHeight = 116;
const double _cardRadius = 20;

class TrackListItem extends StatelessWidget {
  final TrackData track;
  final FutureOr<void> Function() onDismissed;
  final VoidCallback? onTrackUpdated;
  final TrackBloc trackBloc;

  const TrackListItem({
    required this.track,
    required this.onDismissed,
    required this.trackBloc,
    this.onTrackUpdated,
    super.key,
  });

  String buildStaticMapboxUrl(BuildContext context) {
    String baseUrl =
        trackBloc.buildStaticMapboxUrl(context, track.encodedPolyline);
    if (baseUrl.isEmpty) return '';
    return '$baseUrl?access_token=$mapboxAccessToken';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final localizations = AppLocalizations.of(context)!;
    final hasGeolocations = track.geolocations.isNotEmpty;
    final colorScheme = theme.colorScheme;
    final statusInfo =
        trackBloc.getEstimatedTrackStatusInfo(track, theme, localizations);
    final date = hasGeolocations
        ? trackBloc.formatTrackDate(track.geolocations.first.timestamp)
        : '-';
    final times = hasGeolocations
        ? trackBloc.formatTrackTimeRange(
            track.geolocations.first.timestamp,
            track.geolocations.last.timestamp,
          )
        : localizations.trackNoGeolocations;
    final duration =
        trackBloc.formatTrackDuration(track.duration, localizations);
    final distance =
        trackBloc.formatTrackDistance(track.distance, localizations);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(_cardRadius),
        onTap: () async {
          await context.push(
            AppRoutes.trackDetail,
            extra: TrackDetailRouteData(
              track: track,
              onTrackUploaded: onTrackUpdated,
            ),
          );
          onTrackUpdated?.call();
        },
        onLongPress: () async {
          final shouldDelete =
              await _confirmDismiss(context, localizations, theme) ?? false;
          if (!shouldDelete) return;
          await onDismissed();
        },
        child: Container(
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(_cardRadius),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 5,
                child: Padding(
                  padding: const EdgeInsets.all(spacing * 0.6),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(_cardRadius - 4),
                          child: hasGeolocations
                              ? CachedNetworkImage(
                                  imageUrl: buildStaticMapboxUrl(context),
                                  fit: BoxFit.cover,
                                  progressIndicatorBuilder:
                                      (context, url, downloadProgress) =>
                                          Center(
                                    child: SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        value: downloadProgress.progress,
                                      ),
                                    ),
                                  ),
                                  errorWidget: (context, url, error) =>
                                      Container(
                                    color: colorScheme.errorContainer,
                                    alignment: Alignment.center,
                                    child: Icon(Icons.error_outline,
                                        size: iconSizeLarge),
                                  ),
                                )
                              : Container(
                                  color: colorScheme.surfaceContainerHighest,
                                  alignment: Alignment.center,
                                  child: Icon(
                                    Icons.map_outlined,
                                    size: 22,
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                        ),
                      ),
                      Positioned(
                        top: 0,
                        right: 0,
                        child: Container(
                          width: spacing * 3,
                          height: spacing * 3,
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerHigh,
                            borderRadius: BorderRadius.only(
                              bottomLeft: Radius.circular(spacing),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: spacing * 0.125,
                        right: spacing * 0.125,
                        child: Tooltip(
                          message: statusInfo.text,
                          child: Container(
                            padding: const EdgeInsets.all(padding),
                            decoration: BoxDecoration(
                              color: statusInfo.color.withValues(alpha: 0.3),
                              borderRadius:
                                  BorderRadius.circular(borderRadiusSmall),
                            ),
                            child: Icon(
                              statusInfo.icon,
                              size: iconSize,
                              color: statusInfo.color,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                flex: 4,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                      spacing * 0.8, 0, spacing * 0.8, spacing * 0.7),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        date,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: colorScheme.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        times,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurface.withValues(alpha: 0.82),
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const Spacer(),
                      _buildMetricRow(
                        theme,
                        icon: Icons.timer_outlined,
                        value: duration,
                      ),
                      const SizedBox(height: spacing * 0.35),
                      _buildMetricRow(
                        theme,
                        icon: Icons.straighten_outlined,
                        value: distance,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<bool?> _confirmDismiss(
      BuildContext context, AppLocalizations localizations, ThemeData theme) {
    return showAppDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AppAlertDialog(
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

  Widget _buildMetricRow(
    ThemeData theme, {
    required IconData icon,
    required String value,
  }) {
    final colorScheme = theme.colorScheme;
    return Row(
      children: [
        Icon(
          icon,
          size: iconSizeLarge,
          color: colorScheme.onSurface.withValues(alpha: 0.92),
        ),
        const SizedBox(width: spacing * 0.35),
        Expanded(
          child: Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w700,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
