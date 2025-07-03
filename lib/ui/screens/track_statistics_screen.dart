import 'package:flutter/material.dart';
import 'package:sensebox_bike/services/isar_service.dart';
import 'package:sensebox_bike/theme.dart';
import 'package:sensebox_bike/ui/widgets/common/screen_wrapper.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

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

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() {
      _isLoading = true;
    });
    final tracks = await widget.isarService.trackService.getAllTracks();

    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final tracksThisWeek = tracks.where((track) =>
      track.geolocations.isNotEmpty && track.geolocations.first.timestamp.isAfter(weekStart)
    ).toList();

    setState(() {
      _trackCount = tracks.length;
      _totalDuration = tracks.fold(Duration.zero, (prev, track) => prev + track.duration);
      _totalDistance = tracks.fold(0.0, (prev, track) => prev + track.distance);

      _ridesThisWeek = tracksThisWeek.length;
      _distanceThisWeek = tracksThisWeek.fold(0.0, (prev, track) => prev + track.distance);
      _timeThisWeek = tracksThisWeek.fold(Duration.zero, (prev, track) => prev + track.duration);
      _isLoading = false;
    });
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    if (hours > 0) {
      return '$hours h ${minutes} m';
    } else if (minutes > 0) {
      return '$minutes m ${seconds}s';
    } else {
      return '${seconds}s';
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;

    return ScreenWrapper(
      title: l10n.tracksStatisticsTitle,
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // TOTAL DATA CARD
                _StatsCard(
                  icon: Icons.bar_chart_outlined,
                  title: l10n.tracksStatisticsTotalData,
                  subtitle: l10n.tracksStatisticsTotalDataInfo,
                  stats: [
                    _StatRow(
                      icon: Icons.directions_bike_outlined,
                      value: '$_trackCount',
                      label: l10n.tracksStatisticsRidesInfo,
                      textTheme: textTheme,
                    ),
                    _StatRow(
                      icon: Icons.route_outlined,
                      value: '${_totalDistance.toStringAsFixed(1)} km',
                      label: l10n.tracksStatisticsDistanceInfo,
                      textTheme: textTheme,
                    ),
                    _StatRow(
                      icon: Icons.timer_off_outlined,
                      value: _formatDuration(_totalDuration),
                      label: l10n.tracksStatisticsTimeInfo,
                      textTheme: textTheme,
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // THIS WEEK CARD
                _StatsCard(
                  icon: Icons.calendar_today_outlined,
                  title: l10n.tracksStatisticsThisWeek,
                  subtitle: l10n.tracksStatisticsThisWeekInfo,
                  stats: [
                    _StatRow(
                      icon: Icons.event_outlined,
                      value: '$_ridesThisWeek',
                      label: l10n.tracksStatisticsRidesInfo,
                      textTheme: textTheme,
                    ),
                    _StatRow(
                      icon: Icons.route_outlined,
                      value: '${_distanceThisWeek.toStringAsFixed(1)} km',
                      label: l10n.tracksStatisticsDistanceInfo,
                      textTheme: textTheme,
                    ),
                    _StatRow(
                      icon: Icons.timer_outlined,
                      value: _formatDuration(_timeThisWeek),
                      label: l10n.tracksStatisticsTimeInfo,
                      textTheme: textTheme,
                    ),
                  ],
                ),
              ],
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

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(borderRadius/2)),
      color: Theme.of(context).cardColor,
      child: Padding(
        padding: const EdgeInsets.all(spacing),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 28),
                const SizedBox(width: spacing),
                Text( title, style: textTheme.titleLarge),
              ],
            ),
            const SizedBox(height: spacing/2),
            Text(
              subtitle,
              style: textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
            ),
            const SizedBox(height: spacing *2),
            ...stats.map((w) => Padding(
                  padding: const EdgeInsets.only(bottom: spacing),
                  child: w,
                )),
          ],
        ),
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
                Text(
                  value,
                  style: textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold)
                ),
                const SizedBox(width: spacing/2),
                Text(label ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}