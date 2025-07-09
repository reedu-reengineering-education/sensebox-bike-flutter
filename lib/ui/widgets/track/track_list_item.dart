import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:sensebox_bike/models/track_data.dart';
import 'package:flutter/material.dart';
import 'package:sensebox_bike/secrets.dart';
import 'package:sensebox_bike/ui/screens/track_detail_screen.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class TrackListItem extends StatelessWidget {
  final TrackData track;
  final Function onDismissed;

  const TrackListItem(
      {required this.track, required this.onDismissed, super.key});

  String buildStaticMapboxUrl(BuildContext context) {
    bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    String style = isDarkMode ? 'dark-v11' : 'light-v11';
    String lineColor = isDarkMode ? 'fff' : '111';
    String polyline = Uri.encodeComponent(track.encodedPolyline);

    if (polyline == '') {
      return '';
    }

    return 'https://api.mapbox.com/styles/v1/mapbox/$style/static/path-12+$lineColor-0.8($polyline)/auto/800x500?access_token=$mapboxAccessToken';
  }

  @override
  Widget build(BuildContext context) {
    return Dismissible(
        key: Key(track.id.toString()),
        background: Container(
          color: Colors.red,
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20.0),
          child: const Icon(Icons.delete, color: Colors.white),
        ),
        confirmDismiss: (DismissDirection direction) async {
          return await showDialog(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: Text(AppLocalizations.of(context)!.trackDelete),
                content:
                    Text(AppLocalizations.of(context)!.trackDeleteConfirmation),
                actions: <Widget>[
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: Text(AppLocalizations.of(context)!.generalCancel),
                  ),
                  FilledButton(
                      style: const ButtonStyle(
                          backgroundColor:
                              WidgetStatePropertyAll(Colors.redAccent)),
                      onPressed: () => Navigator.of(context).pop(true),
                      child: Text(AppLocalizations.of(context)!.generalDelete)),
                ],
              );
            },
          );
        },
        onDismissed: (direction) => onDismissed(),
        child: InkWell(
            onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => TrackDetailScreen(track: track)),
                ),
            child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DateFormat('yyyy-MM-dd HH:mm')
                          .format(track.geolocations.first.timestamp),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.timer_outlined),
                        const SizedBox(width: 8),
                        Text(
                            AppLocalizations.of(context)!.generalTrackDuration(
                                track.duration.inHours,
                                track.duration.inMinutes.remainder(60)),
                            style: Theme.of(context).textTheme.bodyMedium),
                        const SizedBox(width: 24),
                        const Icon(Icons.straighten),
                        const SizedBox(width: 8),
                        Text(
                            AppLocalizations.of(context)!.generalTrackDistance(
                                track.distance.toStringAsFixed(2)),
                            style: Theme.of(context).textTheme.bodyMedium),
                      ],
                    ),
                    Card.filled(
                      clipBehavior: Clip.antiAlias,
                      child: CachedNetworkImage(
                        imageUrl: buildStaticMapboxUrl(context),
                        progressIndicatorBuilder:
                            (context, url, downloadProgress) =>
                                CircularProgressIndicator(
                                    value: downloadProgress.progress),
                        errorWidget: (context, url, error) =>
                            const Icon(Icons.error),
                      ),
                      // expanded
                    )
                  ],
                ))));
  }
}
