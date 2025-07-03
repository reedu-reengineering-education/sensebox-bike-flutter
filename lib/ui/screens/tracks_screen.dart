import 'package:provider/provider.dart';
import 'package:sensebox_bike/blocs/track_bloc.dart';
import 'package:sensebox_bike/models/track_data.dart';
import 'package:sensebox_bike/services/error_service.dart';
import 'package:flutter/material.dart';
import 'package:sensebox_bike/services/isar_service.dart';
import 'package:sensebox_bike/theme.dart';
import 'package:sensebox_bike/ui/widgets/common/button_with_loader.dart';
import 'package:sensebox_bike/ui/widgets/common/screen_wrapper.dart';
import 'package:sensebox_bike/ui/widgets/track/track_list_item.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:sensebox_bike/constants.dart';

class TracksScreen extends StatefulWidget {
  const TracksScreen({super.key});

  @override
  State<TracksScreen> createState() => TracksScreenState();
}

class TracksScreenState extends State<TracksScreen> {
  late Future<List<TrackData>> _allTracksFuture;
  late List<TrackData> _allTracks;
  late IsarService _isarService;
  final ScrollController _scrollController = ScrollController(); 
  List<TrackData> _displayedTracks = [];
  // Pagination variables
  int _currentPage = 0;
  bool _hasMoreTracks = true;
  bool _isLoading = false; 

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

  void refreshTracks() {
    _handleRefresh();
  }

  void _loadTracks() {
    setState(() {
      _isLoading = true;
    });

    _allTracksFuture.then((allTracks) {
      setState(() {
        final startIndex = _currentPage * tracksPerPage;
        final endIndex = startIndex + tracksPerPage;
        _allTracks = allTracks;

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
        _isLoading = false; 
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

  void _loadMore() {
    setState(() {
      final startIndex = _currentPage * tracksPerPage;
      final endIndex = startIndex + tracksPerPage;

      if (startIndex >= _allTracks.length) {
        _hasMoreTracks = false; // No more tracks to load
      } else {
        _displayedTracks.addAll(
          _allTracks.sublist(
            startIndex,
            endIndex > _allTracks.length ? _allTracks.length : endIndex,
          ),
        );
        _currentPage++;
        _hasMoreTracks =
            endIndex < _allTracks.length; // Check if more tracks exist
      }
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
                      separatorBuilder: (context, index) {
                        // Do not show divider after the last track before the "Load More" button
                        if (index == _displayedTracks.length - 1 &&
                            _hasMoreTracks) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(
                              left: spacing * 2, right: spacing * 2),
                          child: Divider(
                            height: 1,
                            color: colorScheme.primaryFixedDim,
                          ),
                        );
                      },
                      controller: _scrollController,
                      itemCount: _hasMoreTracks
                          ? _displayedTracks.length + 1 // Add 1 for "Load More"
                          : _displayedTracks.length, // No "Load More" button
                      itemBuilder: (context, index) {
                        if (index < _displayedTracks.length) {
                          TrackData track = _displayedTracks[index];
                          return TrackListItem(
                            track: track,
                            isFirst: index == 0,
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
                              onPressed: _isLoading ? null : _loadMore,
                              text: AppLocalizations.of(context)!.loadMore,
                              width: 0.6, 
                            ),
                          );
                        }
                      },
                    ),
                  ),
                )
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
