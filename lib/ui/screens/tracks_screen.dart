import 'dart:async';

import 'package:provider/provider.dart';
import 'package:sensebox_bike/blocs/track_bloc.dart';
import 'package:sensebox_bike/blocs/recording_bloc.dart';
import 'package:sensebox_bike/blocs/opensensemap_bloc.dart';
import 'package:sensebox_bike/models/track_data.dart';
import 'package:flutter/material.dart';
import 'package:sensebox_bike/services/isar_service.dart';
import 'package:sensebox_bike/services/batch_upload_service.dart';
import 'package:sensebox_bike/ui/widgets/common/no_tracks_message.dart';
import 'package:sensebox_bike/ui/widgets/common/screen_wrapper.dart';
import 'package:sensebox_bike/ui/widgets/common/underlined_text_tabs.dart';
import 'package:sensebox_bike/ui/widgets/track/track_list_item.dart';
import 'package:sensebox_bike/ui/widgets/track/tracks_stats_carousel.dart';
import 'package:sensebox_bike/l10n/app_localizations.dart';
import 'package:sensebox_bike/constants.dart';
import 'package:sensebox_bike/theme.dart';

/// Largest a track card is allowed to get. Sized so phones stay at 2 columns.
const double kTrackTileMaxExtent = 240;

class TracksScreen extends StatefulWidget {
  const TracksScreen({super.key});

  @override
  State<TracksScreen> createState() => TracksScreenState();
}

class TracksScreenState extends State<TracksScreen> {
  late IsarService _isarService;
  late RecordingBloc _recordingBloc;
  late OpenSenseMapBloc _openSenseMapBloc;
  late TrackBloc _trackBloc;
  late BatchUploadService _batchUploadService;
  final ScrollController _scrollController = ScrollController();
  List<TrackData> _displayedTracks = [];
  // Pagination variables
  int _currentPage = 0;
  bool _hasMoreTracks = true;
  bool _isLoading = false;
  bool _isStatsLoading = true;
  VoidCallback? _recordingListener;
  // Filter state
  bool _showOnlyUnuploaded = false;
  double _tabsHeaderHeight = 56;

  int _totalTrackCount = 0;
  Duration _totalDuration = Duration.zero;
  double _totalDistance = 0.0;
  int _ridesThisWeek = 0;
  Duration _durationThisWeek = Duration.zero;
  double _distanceThisWeek = 0.0;
  DateTime? _statsStartDate;

  @override
  void initState() {
    super.initState();

    _isarService = context.read<TrackBloc>().isarService;
    _recordingBloc = context.read<RecordingBloc>();
    _openSenseMapBloc = context.read<OpenSenseMapBloc>();
    _trackBloc = context.read<TrackBloc>();

    // Initialize batch upload service
    _batchUploadService = BatchUploadService(
      openSenseMapService: _openSenseMapBloc.openSenseMapService,
      trackService: _isarService.trackService,
      openSenseMapBloc: _openSenseMapBloc,
    );

    // Listen to recording state changes
    _recordingListener = () {
      if (mounted) {
        _handleRefresh();
      }
    };
    _recordingBloc.isRecordingNotifier.addListener(_recordingListener!);
    _scrollController.addListener(_onScroll);

    _fetchInitialTracks();
    _loadSummaryStats();
  }

  @override
  void dispose() {
    if (_recordingListener != null) {
      _recordingBloc.isRecordingNotifier.removeListener(_recordingListener!);
      _recordingListener = null;
    }
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _batchUploadService.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients || _isLoading || !_hasMoreTracks) return;
    if (_scrollController.position.extentAfter < 360) {
      _loadMoreTracks();
    }
  }

  /// Pagination is driven by [_onScroll], which only fires once the content is
  /// long enough to scroll. A wide grid can fit a full page without
  /// overflowing, which would strand the list at one page, so top it up after
  /// each load until the viewport is covered.
  void _ensureViewportFilled() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _isLoading || !_hasMoreTracks) return;
      if (!_scrollController.hasClients) return;
      final position = _scrollController.position;
      if (!position.hasContentDimensions) return;
      if (position.extentAfter < 360) {
        _loadMoreTracks();
      }
    });
  }

  Future<void> _fetchInitialTracks() async {
    setState(() => _isLoading = true);

    List<TrackData> tracks;
    if (_showOnlyUnuploaded) {
      tracks = await _isarService.trackService.getUnuploadedTracksPaginated(
        offset: 0,
        limit: tracksPerPage,
        skipLastTrack: _recordingBloc.isRecording,
      );
    } else {
      tracks = await _isarService.trackService.getTracksPaginated(
        offset: 0,
        limit: tracksPerPage,
        skipLastTrack: _recordingBloc.isRecording,
      );
    }

    setState(() {
      _displayedTracks = tracks;
      _currentPage = 1;
      _hasMoreTracks = tracks.length == tracksPerPage;
      _isLoading = false;
    });

    _ensureViewportFilled();
  }

  Future<void> _loadSummaryStats() async {
    setState(() => _isStatsLoading = true);

    final tracks = await _isarService.trackService.getAllTracks();
    if (!mounted) return;
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final tracksWithGeo =
        tracks.where((track) => track.geolocations.isNotEmpty).toList();
    final weeklyTracks = tracksWithGeo
        .where((track) =>
            track.geolocations.first.timestamp.isAfter(weekStart) ||
            DateUtils.isSameDay(track.geolocations.first.timestamp, weekStart))
        .toList();

    setState(() {
      _totalTrackCount = tracks.length;
      _totalDuration =
          tracks.fold(Duration.zero, (prev, track) => prev + track.duration);
      _totalDistance = tracks.fold(0.0, (prev, track) => prev + track.distance);
      _statsStartDate = tracksWithGeo.isEmpty
          ? null
          : tracksWithGeo
              .map((track) => track.geolocations.first.timestamp)
              .reduce((a, b) => a.isBefore(b) ? a : b);

      _ridesThisWeek = weeklyTracks.length;
      _durationThisWeek = weeklyTracks.fold(
          Duration.zero, (prev, track) => prev + track.duration);
      _distanceThisWeek =
          weeklyTracks.fold(0.0, (prev, track) => prev + track.distance);
      _isStatsLoading = false;
    });
  }

  void refreshTracks() {
    _handleRefresh();
  }

  void _setFilter(bool showOnlyUnuploaded) {
    if (_showOnlyUnuploaded == showOnlyUnuploaded) return;
    setState(() {
      _showOnlyUnuploaded = showOnlyUnuploaded;
      _currentPage = 0;
      _displayedTracks.clear();
      _hasMoreTracks = true;
    });
    _fetchInitialTracks();
  }

  Future<void> _handleRefresh() async {
    setState(() {
      _currentPage = 0;
      _displayedTracks.clear();
      _hasMoreTracks = true;
    });
    await _fetchInitialTracks();
    await _loadSummaryStats();
  }

  Future<void> _loadMoreTracks() async {
    if (_isLoading || !_hasMoreTracks) return;
    setState(() => _isLoading = true);

    List<TrackData> tracks;
    if (_showOnlyUnuploaded) {
      tracks = await _isarService.trackService.getUnuploadedTracksPaginated(
        offset: _currentPage * tracksPerPage,
        limit: tracksPerPage,
        skipLastTrack: _recordingBloc.isRecording,
      );
    } else {
      tracks = await _isarService.trackService.getTracksPaginated(
        offset: _currentPage * tracksPerPage,
        limit: tracksPerPage,
        skipLastTrack: _recordingBloc.isRecording,
      );
    }

    setState(() {
      _displayedTracks.addAll(tracks);
      _currentPage += 1;
      _hasMoreTracks = tracks.length == tracksPerPage;
      _isLoading = false;
    });

    _ensureViewportFilled();
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final bottomSafeInset = MediaQuery.of(context).padding.bottom;
    final bottomContentInset = 120.0 + bottomSafeInset;

    return ScreenWrapper(
      title: localizations.tracksAppBarTitle,
      child: RefreshIndicator(
        color: Theme.of(context).colorScheme.primaryFixedDim,
        onRefresh: _handleRefresh,
        child: ScrollbarTheme(
          data: ScrollbarThemeData(
            thumbColor: WidgetStateProperty.all(colorScheme.primaryFixedDim),
          ),
          child: Scrollbar(
            controller: _scrollController,
            thumbVisibility: true,
            thickness: 2,
            child: CustomScrollView(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Offstage(
                    offstage: true,
                    child: _MeasureSize(
                      onChange: (size) {
                        if (!mounted || size.height <= 0) return;
                        if ((size.height - _tabsHeaderHeight).abs() < 0.5) {
                          return;
                        }
                        setState(() => _tabsHeaderHeight = size.height);
                      },
                      child: _buildStickyTabs(context, localizations),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: TracksStatsCarousel(
                    isLoading: _isStatsLoading,
                    totalTrackCount: _totalTrackCount,
                    totalDuration: _totalDuration,
                    totalDistance: _totalDistance,
                    ridesThisWeek: _ridesThisWeek,
                    durationThisWeek: _durationThisWeek,
                    distanceThisWeek: _distanceThisWeek,
                    statsStartDate: _statsStartDate,
                  ),
                ),
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _TracksTabsHeaderDelegate(
                    minHeight: _tabsHeaderHeight,
                    maxHeight: _tabsHeaderHeight,
                    child: _buildStickyTabs(context, localizations),
                  ),
                ),
                if (_displayedTracks.isEmpty)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: NoTracksMessage(),
                  )
                else ...[
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                      spacing,
                      spacing,
                      spacing,
                      0,
                    ).copyWith(bottom: bottomContentInset),
                    sliver: SliverGrid(
                      // Column count follows the available width so cards keep
                      // roughly their phone size on tablets instead of
                      // stretching: 2-up on phones, 4-up on an iPad in
                      // portrait, 5-up in landscape.
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: kTrackTileMaxExtent,
                        mainAxisSpacing: spacing,
                        crossAxisSpacing: spacing,
                        // Was 0.74 - too tight for the date/time/chip + two
                        // metric rows below the map preview, overflowing on
                        // narrow phones. Taller cards give that content room.
                        childAspectRatio: 0.62,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final track = _displayedTracks[index];
                          return TrackListItem(
                            track: track,
                            trackBloc: _trackBloc,
                            onDismissed: () async {
                              await _isarService.trackService
                                  .deleteTrack(track.id);
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content:
                                      Text(localizations.tracksTrackDeleted),
                                ),
                              );
                              await _handleRefresh();
                            },
                            onTrackUpdated: _handleRefresh,
                          );
                        },
                        childCount: _displayedTracks.length,
                      ),
                    ),
                  ),
                  if (_isLoading)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: spacing),
                        child: Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: colorScheme.primaryFixedDim,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStickyTabs(
      BuildContext context, AppLocalizations localizations) {
    return ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: UnderlinedTextTabs(
        items: [
          localizations.trackFilterAll,
          localizations.trackFilterUnuploaded,
        ],
        selectedIndex: _showOnlyUnuploaded ? 1 : 0,
        onSelected: (index) => _setFilter(index == 1),
        padding: const EdgeInsets.fromLTRB(12, padding, 12, 0),
      ),
    );
  }
}

class _TracksTabsHeaderDelegate extends SliverPersistentHeaderDelegate {
  final double minHeight;
  final double maxHeight;
  final Widget child;

  const _TracksTabsHeaderDelegate({
    required this.minHeight,
    required this.maxHeight,
    required this.child,
  });

  @override
  double get minExtent => minHeight;

  @override
  double get maxExtent => maxHeight;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return child;
  }

  @override
  bool shouldRebuild(covariant _TracksTabsHeaderDelegate oldDelegate) {
    return minHeight != oldDelegate.minHeight ||
        maxHeight != oldDelegate.maxHeight ||
        child != oldDelegate.child;
  }
}

typedef OnWidgetSizeChange = void Function(Size size);

class _MeasureSize extends StatefulWidget {
  final OnWidgetSizeChange onChange;
  final Widget child;

  const _MeasureSize({
    required this.onChange,
    required this.child,
  });

  @override
  State<_MeasureSize> createState() => _MeasureSizeState();
}

class _MeasureSizeState extends State<_MeasureSize> {
  Size? _oldSize;

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final newSize = context.size;
      if (newSize == null || _oldSize == newSize) return;
      _oldSize = newSize;
      widget.onChange(newSize);
    });

    return widget.child;
  }
}
