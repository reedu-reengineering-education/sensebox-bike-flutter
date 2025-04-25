import 'package:sensebox_bike/models/track_data.dart';
import 'package:sensebox_bike/services/isar_service.dart';
import 'package:flutter/material.dart';
import 'package:sensebox_bike/ui/widgets/track/track_list_item.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class TracksScreen extends StatefulWidget {
  const TracksScreen({super.key});

  @override
  State<TracksScreen> createState() => _TracksScreenState();
}

class _TracksScreenState extends State<TracksScreen> {
  late Future<List<TrackData>> _tracksFuture;

  @override
  void initState() {
    super.initState();
    // Initialize the future in initState to avoid re-fetching data unnecessarily
    _tracksFuture = IsarService().trackService.getAllTracks();
  }

  Future<void> _handleRefresh() async {
    setState(() {
      _tracksFuture = IsarService().trackService.getAllTracks();
    });
  }

  Widget buildTrackSummaryRow(
      BuildContext context, String tracks, String duration, String distance) {
    // Helper widget for an icon-text combo
    Widget iconText(IconData icon, String text) {
      return Expanded(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                style: Theme.of(context).textTheme.bodyMedium,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            )
          ],
        ),
      );
    }

    return Row(
      children: [
        iconText(Icons.route, tracks),
        iconText(Icons.timer_outlined, duration),
        iconText(Icons.straighten, distance),
      ],
    );
  }

  @override
Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.tracksAppBarTitle),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(32),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 4.0),
            child: FutureBuilder<List<TrackData>>(
              future: _tracksFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return buildTrackSummaryRow(
                    context,
                    AppLocalizations.of(context)!.generalLoading,
                    AppLocalizations.of(context)!.generalLoading,
                    AppLocalizations.of(context)!.generalLoading,
                  );
                } else if (snapshot.hasError) {
                  return Text(AppLocalizations.of(context)!
                      .generalErrorWithDescription(snapshot.error.toString()));
                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return buildTrackSummaryRow(
                    context,
                    AppLocalizations.of(context)!.tracksAppBarSumTracks(0),
                    AppLocalizations.of(context)!.generalTrackDuration(0, 0),
                    AppLocalizations.of(context)!.generalTrackDistance('0.00'),
                  );
                } else {
                  List<TrackData> tracks = snapshot.data!;
                  const zeroDuration = Duration(milliseconds: 0);
                  Duration totalDuration = tracks.fold(
                      zeroDuration, (prev, track) => prev + track.duration);
                  double totalDistance =
                      tracks.fold(0.0, (prev, track) => prev + track.distance);

                  String formattedDuration = AppLocalizations.of(context)!
                      .generalTrackDuration(totalDuration.inHours,
                          totalDuration.inMinutes.remainder(60));

                  return buildTrackSummaryRow(
                    context,
                    AppLocalizations.of(context)!
                        .tracksAppBarSumTracks(tracks.length),
                    formattedDuration,
                    AppLocalizations.of(context)!
                        .generalTrackDistance(totalDistance.toStringAsFixed(2)),
                  );
                }
              },
            ),
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _handleRefresh,
        child: FutureBuilder<List<TrackData>>(
          future: _tracksFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              // Show a scrollable loading indicator
              return ListView(
                children: const [
                  Center(child: CircularProgressIndicator()),
                ],
              );
            } else if (snapshot.hasError) {
              // Show a scrollable error message
              return ListView(
                children: [
                  Center(
                    child: Text(
                      AppLocalizations.of(context)!.generalErrorWithDescription(
                          snapshot.error.toString()),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              );
            } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
              // Show a scrollable empty state
              return ListView(
                children: [
                  Center(
                    child: Text(
                      AppLocalizations.of(context)!.tracksNoTracks,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              );
            } else {
              // Show the list of tracks
              List<TrackData> tracks = snapshot.data!;

              // Filter tracks without geolocation data
              tracks = tracks
                  .where((track) => track.geolocations.isNotEmpty)
                  .toList()
                  .reversed
                  .toList();

              if (tracks.isEmpty) {
                return ListView(
                  children: [
                    Center(
                      child: Text(
                        AppLocalizations.of(context)!.tracksNoTracks,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ],
                );
              }

              return ListView.separated(
                separatorBuilder: (context, index) => const SizedBox(
                  height: 24,
                ),
                padding: const EdgeInsets.only(top: 24),
                itemCount: tracks.length,
                itemBuilder: (context, index) {
                  TrackData track = tracks[index];
                  return TrackListItem(
                    track: track,
                    onDismissed: () async {
                      await IsarService().trackService.deleteTrack(track.id);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                              AppLocalizations.of(context)!.tracksTrackDeleted),
                        ),
                      );
                      // Refresh the list after deleting a track
                      await _handleRefresh();
                    },
                  );
                },
              );
            }
          },
        ),
      ),
    );
  }
}
