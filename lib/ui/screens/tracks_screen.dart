import 'package:provider/provider.dart';
import 'package:sensebox_bike/blocs/track_bloc.dart';
import 'package:sensebox_bike/models/track_data.dart';
import 'package:sensebox_bike/services/error_service.dart';
import 'package:flutter/material.dart';
import 'package:sensebox_bike/services/isar_service.dart';
import 'package:sensebox_bike/theme.dart';
import 'package:sensebox_bike/ui/widgets/track/track_list_item.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:sensebox_bike/constants.dart';

class TracksScreen extends StatefulWidget {
  const TracksScreen({super.key});

  @override
  State<TracksScreen> createState() => _TracksScreenState();
}

class _TracksScreenState extends State<TracksScreen> {
  late final IsarService isarService;
  late Future<List<TrackData>> _allTracksFuture;
  late IsarService _isarService;
  List<TrackData> _displayedTracks = [];
  int _currentPage = 0;
  bool _hasMoreTracks = true;

  @override
  void initState() {
    super.initState();

    _isarService = Provider.of<TrackBloc>(context, listen: false).isarService;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _fetchAllTracks();
  }

  void _fetchAllTracks() {
    try {
      _allTracksFuture = _isarService.trackService.getAllTracks();
      _loadTracks();
    } catch (e, stack) {
      ErrorService.handleError(e, stack);
    }
  }

  void _loadTracks() {
    _allTracksFuture.then((allTracks) {
      setState(() {
        final startIndex = _currentPage * tracksPerPage;
        final endIndex = startIndex + tracksPerPage;

        if (startIndex >= allTracks.length) {
          _hasMoreTracks = false; // No more tracks to load
        } else {
          _displayedTracks.addAll(
            allTracks.sublist(
              startIndex,
              endIndex > allTracks.length ? allTracks.length : endIndex,
            ),
          );
          _currentPage++;
          _hasMoreTracks =
              endIndex < allTracks.length; // Check if more tracks exist
        }
      });
    });
  }

  Future<void> _handleRefresh() async {
    setState(() {
      _currentPage = 0;
      _displayedTracks.clear();
      _hasMoreTracks = true;
      _fetchAllTracks();
    });
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(localizations.tracksAppBarTitle),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(spacing * 4),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 4.0),
            child: FutureBuilder<List<TrackData>>(
              future: _allTracksFuture,
              builder: (context, snapshot) {
                return TrackSummaryRow(snapshot: snapshot);
              },
            ),
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _handleRefresh,
        child: FutureBuilder<List<TrackData>>(
          future: _allTracksFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const CenteredMessage(
                child: CircularProgressIndicator(),
              );
            } else if (snapshot.hasError) {
              return CenteredMessage(
                child: Text(
                  localizations
                      .generalErrorWithDescription(snapshot.error.toString()),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              );
            } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return CenteredMessage(
                child: Text(
                  localizations.tracksNoTracks,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              );
            } else {
              return ListView.builder(
                padding: const EdgeInsets.only(top: 24),
                itemCount: _hasMoreTracks
                    ? _displayedTracks.length + 1 // Add 1 for "Load More"
                    : _displayedTracks.length, // No "Load More" button
                itemBuilder: (context, index) {
                  if (index < _displayedTracks.length) {
                    TrackData track = _displayedTracks[index];
                    return TrackListItem(
                      track: track,
                      onDismissed: () async {
                        await _isarService.trackService.deleteTrack(track.id);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(localizations.tracksTrackDeleted),
                          ),
                        );
                        _handleRefresh();
                      },
                    );
                  } else {
                    return Padding(
                      padding:
                          const EdgeInsets.symmetric(vertical: spacing * 2),
                      child: Center(
                        child: FilledButton(
                          onPressed: () {
                            _loadTracks();
                          },
                          child: Text(localizations.loadMore),
                        ),
                      ),
                    );
                  }
                },
              );
            }
          },
        ),
      ),
    );
  }
}
class TrackSummaryRow extends StatelessWidget {
  final AsyncSnapshot<List<TrackData>> snapshot;

  const TrackSummaryRow({required this.snapshot, super.key});

  @override
  Widget build(BuildContext context) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return _buildRow(
        context,
        AppLocalizations.of(context)!.generalLoading,
        AppLocalizations.of(context)!.generalLoading,
        AppLocalizations.of(context)!.generalLoading,
      );
    } else if (snapshot.hasError ||
        !snapshot.hasData ||
        snapshot.data!.isEmpty) {
      return _buildRow(
        context,
        AppLocalizations.of(context)!.tracksAppBarSumTracks(0),
        AppLocalizations.of(context)!.generalTrackDuration(0, 0),
        AppLocalizations.of(context)!.generalTrackDistance('0.00'),
      );
    } else {
      List<TrackData> tracks = snapshot.data!;
      const zeroDuration = Duration(milliseconds: 0);
      Duration totalDuration =
          tracks.fold(zeroDuration, (prev, track) => prev + track.duration);
      double totalDistance =
          tracks.fold(0.0, (prev, track) => prev + track.distance);

      String formattedDuration = AppLocalizations.of(context)!
          .generalTrackDuration(
              totalDuration.inHours, totalDuration.inMinutes.remainder(60));

      return _buildRow(
        context,
        AppLocalizations.of(context)!.tracksAppBarSumTracks(tracks.length),
        formattedDuration,
        AppLocalizations.of(context)!
            .generalTrackDistance(totalDistance.toStringAsFixed(2)),
      );
    }
  }

  Widget _buildRow(
      BuildContext context, String tracks, String duration, String distance) {
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
}

class CenteredMessage extends StatelessWidget {
  final Widget child;

  const CenteredMessage({required this.child, super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        Center(child: child),
      ],
    );
  }
}
