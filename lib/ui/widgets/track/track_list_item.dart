import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:sensebox_bike/l10n/app_localizations.dart';
import 'package:sensebox_bike/models/track_data.dart';
import 'package:sensebox_bike/secrets.dart';
import 'package:sensebox_bike/theme.dart';
import 'package:sensebox_bike/ui/screens/track_detail_screen.dart';
import 'package:sensebox_bike/ui/widgets/common/clickable_tile.dart';
import 'package:sensebox_bike/blocs/track_bloc.dart';

const double kMapPreviewWidth = 140;
const double kMapPreviewHeight = 140;

class TrackListItem extends StatelessWidget {
  final TrackData track;
  final Function onDismissed;
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

    return Padding(
        padding: EdgeInsets.only(bottom: spacing, top: spacing),
        child: Dismissible(
            key: Key(track.id.toString()),
            background: _buildDismissBackground(theme),
            confirmDismiss: (direction) =>
                _confirmDismiss(context, localizations, theme),
            onDismissed: (direction) => onDismissed(),
            child: hasGeolocations
                ? ClickableTile(
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => TrackDetailScreen(
                            track: track,
                            onTrackUploaded: onTrackUpdated,
                          ),
                        ),
                      );
                      onTrackUpdated?.call();
                    },
                    child: _buildTrackContent(
                        context, localizations, theme, track),
                  )
                : Container(
                    padding: const EdgeInsets.all(spacing * 2),
                    child: Row(
                      children: [
                        Expanded(
                            child: _buildNoGeolocationsContent(
                                context, localizations, theme))
                      ],
                    ),
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
    return Container(
      width: double.infinity,
      child: Text(
        localizations.trackNoGeolocations,
        style: theme.textTheme.bodyMedium
            ?.copyWith(color: theme.colorScheme.error),
      ),
    );
  }

  Widget _buildTrackContent(BuildContext context,
      AppLocalizations localizations, ThemeData theme, TrackData track) {
    final date = trackBloc.formatTrackDate(track.geolocations.first.timestamp);
    final times = trackBloc.formatTrackTimeRange(
      track.geolocations.first.timestamp,
      track.geolocations.last.timestamp,
    );
    final duration =
        trackBloc.formatTrackDuration(track.duration, localizations);
    final distance =
        trackBloc.formatTrackDistance(track.distance, localizations);
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
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
    final statusInfo =
        trackBloc.getTrackStatusInfo(track, theme, localizations);

    return Tooltip(
      message: statusInfo.text,
      child: Container(
        padding: const EdgeInsets.all(padding),
        decoration: BoxDecoration(
          color: statusInfo.color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(borderRadiusSmall),
        ),
        child: Icon(
          statusInfo.icon,
          size: iconSizeLarge,
          color: statusInfo.color,
        ),
      ),
    );
  }
}
