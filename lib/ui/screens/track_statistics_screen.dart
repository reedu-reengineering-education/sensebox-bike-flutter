import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sensebox_bike/services/isar_service.dart';
import 'package:sensebox_bike/theme.dart';
import 'package:sensebox_bike/ui/widgets/common/custom_divider.dart';
import 'package:sensebox_bike/ui/widgets/common/screen_wrapper.dart';
import 'package:sensebox_bike/l10n/app_localizations.dart';

class TrackStatisticsScreen extends StatefulWidget {
  final IsarService isarService;
  const TrackStatisticsScreen({super.key, required this.isarService});

  @override
  State<TrackStatisticsScreen> createState() => _TrackStatisticsScreenState();
}

class _TrackStatisticsScreenState extends State<TrackStatisticsScreen> {
  int _trackCount = 0;
  Duration _totalDuration = Duration.zero;
  double _totalDistance = 0.0;
  int _ridesThisWeek = 0;
  double _distanceThisWeek = 0.0;
  Duration _timeThisWeek = Duration.zero;
  bool _isLoading = true;
  DateTime? _start;
  late DateTime _now;
  late DateTime _weekStart;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _weekStart = _now.subtract(Duration(days: _now.weekday - 1));
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() {
      _isLoading = true;
    });
    final tracks = await widget.isarService.trackService.getAllTracks();
    _start = tracks.isNotEmpty
        ? tracks.first.geolocations.first.timestamp
        : DateTime.now();
    final tracksThisWeek = tracks
        .where((track) =>
            track.geolocations.isNotEmpty &&
            (track.geolocations.first.timestamp.isAfter(_weekStart) ||
                DateUtils.isSameDay(
                    track.geolocations.first.timestamp, _weekStart)))
        .toList();

    setState(() {
      _trackCount = tracks.length;
      _totalDuration =
          tracks.fold(Duration.zero, (prev, track) => prev + track.duration);
      _totalDistance = tracks.fold(0.0, (prev, track) => prev + track.distance);

      _ridesThisWeek = tracksThisWeek.length;
      _distanceThisWeek =
          tracksThisWeek.fold(0.0, (prev, track) => prev + track.distance);
      _timeThisWeek = tracksThisWeek.fold(
          Duration.zero, (prev, track) => prev + track.duration);
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;
    final totalSubtitle =
        '${DateFormat('dd.MM.yyyy').format(_start ?? _now)} - ${DateFormat('dd.MM.yyyy').format(_now)}';
    final thisWeekSubtitle =
        '${DateFormat('dd.MM.yyyy').format(_weekStart)} - ${DateFormat('dd.MM.yyyy').format(_now)}';
    final stats = [
      // TOTAL DATA CARD
      _StatsCard(
        icon: Icons.bar_chart_outlined,
        title: l10n.tracksStatisticsTotalData,
        subtitle: totalSubtitle,
        stats: [
          _StatRow(
            icon: Icons.directions_bike_outlined,
            value: '$_trackCount',
            label: l10n.tracksStatisticsRidesInfo,
            textTheme: textTheme,
          ),
          _StatRow(
            icon: Icons.route_outlined,
            value: l10n.generalTrackDistance(_totalDistance.toStringAsFixed(2)),
            label: l10n.tracksStatisticsDistanceInfo,
            textTheme: textTheme,
          ),
          _StatRow(
            icon: Icons.timer_outlined,
            value: l10n.generalTrackDurationShort(
                _totalDuration.inHours.toString(),
                _totalDuration.inMinutes
                    .remainder(60)
                    .toString()
                    .padLeft(2, '0')),
            label: l10n.tracksStatisticsTimeInfo,
            textTheme: textTheme,
          ),
        ],
      ),
      // THIS WEEK CARD
      _StatsCard(
        icon: Icons.calendar_today_outlined,
        title: l10n.tracksStatisticsThisWeek,
        subtitle: thisWeekSubtitle,
        stats: [
          _StatRow(
            icon: Icons.event_outlined,
            value: '$_ridesThisWeek',
            label: l10n.tracksStatisticsRidesInfo,
            textTheme: textTheme,
          ),
          _StatRow(
            icon: Icons.route_outlined,
            value:
                l10n.generalTrackDistance(_distanceThisWeek.toStringAsFixed(2)),
            label: l10n.tracksStatisticsDistanceInfo,
            textTheme: textTheme,
          ),
          _StatRow(
            icon: Icons.timer_outlined,
            value: l10n.generalTrackDurationShort(
                _timeThisWeek.inHours.toString(),
                _timeThisWeek.inMinutes
                    .remainder(60)
                    .toString()
                    .padLeft(2, '0')),
            label: l10n.tracksStatisticsTimeInfo,
            textTheme: textTheme,
          ),
        ],
      ),
    ];

    return ScreenWrapper(
      title: l10n.tracksStatisticsTitle,
      padding: spacing,
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.separated(
              itemCount: stats.length,
              separatorBuilder: (context, index) =>
                  CustomDivider(showDivider: true),
              itemBuilder: (context, index) => stats[index],
            ),
    );
  }
}

class _StatsCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final List<Widget> stats;

  const _StatsCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.stats,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: spacing, vertical: spacing * 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 28),
              const SizedBox(width: spacing),
              Text(title, style: textTheme.titleLarge),
            ],
          ),
          const SizedBox(height: spacing / 2),
          Text(
            subtitle,
            style: textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
          ),
          const SizedBox(height: spacing * 2),
          ...stats.map((w) => Padding(
                padding: const EdgeInsets.only(bottom: spacing),
                child: w,
              )),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final TextTheme textTheme;

  const _StatRow({
    required this.icon,
    required this.value,
    required this.label,
    required this.textTheme,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 28),
        const SizedBox(width: spacing),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(value,
                    style: textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(width: spacing / 2),
                Text(label),
              ],
            ),
          ],
        ),
      ],
    );
  }
}
