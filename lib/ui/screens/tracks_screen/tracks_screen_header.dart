import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:sensebox_bike/theme.dart';
import 'package:sensebox_bike/ui/screens/tracks_screen/track_screen_header_item.dart';

class TracksScreenHeader extends StatelessWidget {
  final int trackCount;
  final Duration totalDuration;
  final double totalDistance;

  const TracksScreenHeader({
    required this.trackCount,
    required this.totalDuration,
    required this.totalDistance,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final number = localizations.tracksAppBarSumTracks(trackCount);
    final durationHrs =
        localizations.generalTrackDurationHours(totalDuration.inHours);
    final durationMins = localizations
        .generalTrackDurationMins(totalDuration.inMinutes.remainder(60));
    final distance =
        localizations.generalTrackDistance(totalDistance.toStringAsFixed(0));

    return Padding(
        padding: const EdgeInsets.only(top: spacing * 4, bottom: spacing),
        child: SizedBox(
            width: double.infinity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Track statistics",
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: spacing),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TracksScreenHeaderItem(
                        icon: Icons.route_outlined, label: number),
                    TracksScreenHeaderItem(
                      icon: Icons.timer_outlined,
                      hours: durationHrs,
                      minutes: durationMins,
                    ),
                    TracksScreenHeaderItem(
                        icon: Icons.straighten_outlined, label: distance),
                  ],
                ),
              ],
            )
        )
    );
  }
}