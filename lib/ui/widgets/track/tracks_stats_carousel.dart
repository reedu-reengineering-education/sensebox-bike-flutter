import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sensebox_bike/l10n/app_localizations.dart';
import 'package:sensebox_bike/theme.dart';

class TracksStatsCarousel extends StatefulWidget {
  final bool isLoading;
  final int totalTrackCount;
  final Duration totalDuration;
  final double totalDistance;
  final int ridesThisWeek;
  final Duration durationThisWeek;
  final double distanceThisWeek;
  final DateTime? statsStartDate;

  const TracksStatsCarousel({
    super.key,
    required this.isLoading,
    required this.totalTrackCount,
    required this.totalDuration,
    required this.totalDistance,
    required this.ridesThisWeek,
    required this.durationThisWeek,
    required this.distanceThisWeek,
    required this.statsStartDate,
  });

  @override
  State<TracksStatsCarousel> createState() => _TracksStatsCarouselState();
}

class _TracksStatsCarouselState extends State<TracksStatsCarousel> {
  late final PageController _pageController;
  int _selectedPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.94);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  String _formatDuration(AppLocalizations localizations, Duration duration) {
    return localizations.generalTrackDurationShort(
      duration.inHours.toString(),
      duration.inMinutes.remainder(60).toString().padLeft(2, '0'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));

    return widget.isLoading
        ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
        : Column(
            mainAxisSize: MainAxisSize.min,
            spacing: 8,
            children: [
              Stack(
                children: [
                  // Invisible card that gives the Stack its natural height
                  Opacity(
                    opacity: 0.0,
                    child: _TracksStatsCard(
                      title: localizations.tracksStatisticsTotalData,
                      subtitle:
                          '${DateFormat('dd.MM.yyyy').format(widget.statsStartDate ?? now)} - ${DateFormat('dd.MM.yyyy').format(now)}',
                      rideValue: widget.totalTrackCount.toString(),
                      distanceValue: localizations.generalTrackDistance(
                          widget.totalDistance.toStringAsFixed(2)),
                      durationValue:
                          _formatDuration(localizations, widget.totalDuration),
                    ),
                  ),
                  Positioned.fill(
                    child: PageView(
                      controller: _pageController,
                      onPageChanged: (index) {
                        setState(() => _selectedPage = index);
                      },
                      children: [
                        _TracksStatsCard(
                          title: localizations.tracksStatisticsTotalData,
                          subtitle:
                              '${DateFormat('dd.MM.yyyy').format(widget.statsStartDate ?? now)} - ${DateFormat('dd.MM.yyyy').format(now)}',
                          rideValue: widget.totalTrackCount.toString(),
                          distanceValue: localizations.generalTrackDistance(
                              widget.totalDistance.toStringAsFixed(2)),
                          durationValue: _formatDuration(
                              localizations, widget.totalDuration),
                        ),
                        _TracksStatsCard(
                          title: localizations.tracksStatisticsThisWeek,
                          subtitle:
                              '${DateFormat('dd.MM.yyyy').format(weekStart)} - ${DateFormat('dd.MM.yyyy').format(now)}',
                          rideValue: widget.ridesThisWeek.toString(),
                          distanceValue: localizations.generalTrackDistance(
                              widget.distanceThisWeek.toStringAsFixed(2)),
                          durationValue: _formatDuration(
                              localizations, widget.durationThisWeek),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(2, (index) {
                  final isActive = index == _selectedPage;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: isActive ? 18 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: isActive
                          ? colorScheme.onSurface
                          : colorScheme.onSurface.withValues(alpha: 0.28),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  );
                }),
              ),
            ],
          );
  }
}

class _TracksStatsCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String rideValue;
  final String distanceValue;
  final String durationValue;

  const _TracksStatsCard({
    required this.title,
    required this.subtitle,
    required this.rideValue,
    required this.distanceValue,
    required this.durationValue,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final localizations = AppLocalizations.of(context)!;

    Widget statRow(IconData icon, String value, String label) {
      return Row(
        children: [
          Icon(icon, size: 16, color: colorScheme.onSurface),
          const SizedBox(width: 6),
          Text(
            value,
            style: theme.textTheme.titleSmall?.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurface.withValues(alpha: 0.82),
            ),
          ),
        ],
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(spacing, 6, spacing, 0),
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(20),
        ),
        padding: const EdgeInsets.all(spacing * 1.5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.78),
              ),
            ),
            const SizedBox(height: spacing * 0.75),
            statRow(
              Icons.directions_bike_outlined,
              rideValue,
              localizations.tracksStatisticsRidesInfo,
            ),
            const SizedBox(height: 5),
            statRow(
              Icons.route_outlined,
              distanceValue,
              localizations.tracksStatisticsDistanceInfo,
            ),
            const SizedBox(height: 5),
            statRow(
              Icons.timer_outlined,
              durationValue,
              localizations.tracksStatisticsTimeInfo,
            ),
          ],
        ),
      ),
    );
  }
}
