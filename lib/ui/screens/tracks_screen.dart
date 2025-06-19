import 'package:provider/provider.dart';
import 'package:sensebox_bike/blocs/track_bloc.dart';
import 'package:sensebox_bike/models/track_data.dart';
import 'package:sensebox_bike/services/error_service.dart';
import 'package:flutter/material.dart';
import 'package:sensebox_bike/services/isar_service.dart';
import 'package:sensebox_bike/theme.dart';
import 'package:sensebox_bike/ui/screens/tracks_screen/tracks_screen_header.dart';
import 'package:sensebox_bike/ui/widgets/common/custom_filled_button.dart';
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
      body: Column(
        children: [
          FutureBuilder<List<TrackData>>(
          future: _allTracksFuture,
          builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting ||
                  snapshot.hasError ||
                  !snapshot.hasData) {
                return const TracksScreenHeader(
                  trackCount: 0,
                  totalDuration: Duration.zero,
                  totalDistance: 0.0,
                );
              } else {
                final tracks = snapshot.data!;
                final totalDuration = tracks.fold(
                    Duration.zero, (prev, track) => prev + track.duration);
                final totalDistance =
                    tracks.fold(0.0, (prev, track) => prev + track.distance);

                return TracksScreenHeader(
                  trackCount: tracks.length,
                  totalDuration: totalDuration,
                  totalDistance: totalDistance,
              );
              }
            },
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _handleRefresh,
              
              child: ListView.builder(
                padding: const EdgeInsets.all(spacing),
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
                        child: CustomFilledButton(
                          label: localizations.loadMore,
                          onPressed: () {
                            _loadTracks();
                          },
                        ),
                      ),
                    );
                  }
                },
              ),
            ),
          ),
        ],
      ),
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
