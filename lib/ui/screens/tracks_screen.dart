import 'package:provider/provider.dart';
import 'package:sensebox_bike/blocs/track_bloc.dart';
import 'package:sensebox_bike/blocs/recording_bloc.dart';
import 'package:sensebox_bike/models/track_data.dart';
import 'package:flutter/material.dart';
import 'package:sensebox_bike/services/isar_service.dart';
import 'package:sensebox_bike/ui/widgets/common/button_with_loader.dart';
import 'package:sensebox_bike/ui/widgets/common/custom_divider.dart';
import 'package:sensebox_bike/ui/widgets/common/screen_wrapper.dart';
import 'package:sensebox_bike/ui/widgets/track/track_list_item.dart';
import 'package:sensebox_bike/l10n/app_localizations.dart';
import 'package:sensebox_bike/constants.dart';

class TracksScreen extends StatefulWidget {
  const TracksScreen({super.key});

  @override
  State<TracksScreen> createState() => TracksScreenState();
}

class TracksScreenState extends State<TracksScreen> {
  late IsarService _isarService;
  late RecordingBloc _recordingBloc;
  final ScrollController _scrollController = ScrollController();
  List<TrackData> _displayedTracks = [];
  // Pagination variables
  int _currentPage = 0;
  bool _hasMoreTracks = true;
  bool _isLoading = false;
  VoidCallback? _recordingListener;

  @override
  void initState() {
    super.initState();

    _isarService = Provider.of<TrackBloc>(context, listen: false).isarService;
    _recordingBloc = Provider.of<RecordingBloc>(context, listen: false);

    // Listen to recording state changes
    _recordingListener = () {
      if (mounted) {
        _handleRefresh();
      }
    };
    _recordingBloc.isRecordingNotifier.addListener(_recordingListener!);

    _fetchInitialTracks();
  }

  @override
  void dispose() {
    if (_recordingListener != null) {
      _recordingBloc.isRecordingNotifier.removeListener(_recordingListener!);
    }
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchInitialTracks() async {
    setState(() => _isLoading = true);

    final tracks = await _isarService.trackService.getTracksPaginated(
      offset: 0,
      limit: tracksPerPage,
      skipLastTrack: _recordingBloc.isRecording,
    );

    setState(() {
      _displayedTracks = tracks;
      _currentPage = 1;
      _hasMoreTracks = tracks.length == tracksPerPage;
      _isLoading = false;
    });
  }

  void refreshTracks() {
    _handleRefresh();
  }

  Future<void> _handleRefresh() async {
    setState(() {
      _currentPage = 0;
      _displayedTracks.clear();
      _hasMoreTracks = true;
      _fetchInitialTracks();
    });
  }

  Future<void> _loadMoreTracks() async {
    if (_isLoading || !_hasMoreTracks) return;
    setState(() => _isLoading = true);
    final tracks = await _isarService.trackService.getTracksPaginated(
      offset: _currentPage * tracksPerPage,
      limit: tracksPerPage,
      skipLastTrack: _recordingBloc.isRecording,
    );

    setState(() {
      _displayedTracks.addAll(tracks);
      _currentPage += 1;
      _hasMoreTracks = tracks.length == tracksPerPage;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

    return ScreenWrapper(
      title: localizations.tracksAppBarTitle,
      child: Column(
        children: [
          Expanded(
            child: RefreshIndicator(
                color: Theme.of(context).colorScheme.primaryFixedDim,
                onRefresh: _handleRefresh,
                child: ScrollbarTheme(
                  data: ScrollbarThemeData(
                    thumbColor:
                        WidgetStateProperty.all(colorScheme.primaryFixedDim),
                  ),
                  child: Scrollbar(
                    controller: _scrollController,
                    thumbVisibility: true,
                    thickness: 2,
                    child: ListView.separated(
                      separatorBuilder: (context, index) => CustomDivider(
                        showDivider: !(index == _displayedTracks.length - 1 &&
                            _hasMoreTracks),
                      ),
                      controller: _scrollController,
                      itemCount: _hasMoreTracks
                          ? _displayedTracks.length + 1 // Add 1 for "Load More"
                          : _displayedTracks.length, // No "Load More" button
                      itemBuilder: (context, index) {
                        if (index < _displayedTracks.length) {
                          TrackData track = _displayedTracks[index];
                          return TrackListItem(
                            track: track,
                            onDismissed: () async {
                              await _isarService.trackService
                                  .deleteTrack(track.id);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content:
                                      Text(localizations.tracksTrackDeleted),
                                ),
                              );
                              _handleRefresh();
                            },
                          );
                        } else {
                          return Center(
                            child: ButtonWithLoader(
                              isLoading: _isLoading,
                              onPressed: _isLoading ? null : _loadMoreTracks,
                              text: AppLocalizations.of(context)!.loadMore,
                              width: 0.6,
                            ),
                          );
                        }
                      },
                    ),
                  ),
                )),
          ),
        ],
      ),
    );
  }
}
