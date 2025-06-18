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
    final theme = Theme.of(context);
    final localizations = AppLocalizations.of(context)!;

    return Padding(
        padding: const EdgeInsets.only(top: spacing * 3, bottom: spacing),
        child: SizedBox(
          width: double.infinity,
          height: 90,
          child: Stack(
            children: [
              Positioned.fill(
                child: Container(color: theme.colorScheme.surface),
              ),
              Positioned(
                left: spacing,
                top: spacing,
                child: Container(
                  width: MediaQuery.of(context).size.width - 2 * spacing, 
                  height: 70,
                  decoration: _buildHeaderDecoration(theme),
                  child: Padding(
                    padding: const EdgeInsets.all(spacing),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TracksScreenHeaderItem(
                          icon: Icons.route_outlined,
                          label:
                              localizations.tracksAppBarSumTracks(trackCount),
                        ),
                        TracksScreenHeaderItem(
                          icon: Icons.timer_outlined,
                          hours: localizations
                              .generalTrackDurationHours(totalDuration.inHours),
                          minutes: localizations.generalTrackDurationMins(
                            totalDuration.inMinutes.remainder(60),
                          ),
                        ),
                        TracksScreenHeaderItem(
                          icon: Icons.straighten_outlined,
                          label: localizations.generalTrackDistance(
                            totalDistance.toStringAsFixed(0),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        )
    );
  }

  BoxDecoration _buildHeaderDecoration(ThemeData theme) {
    return BoxDecoration(
      color: theme.colorScheme.surfaceVariant,
      border: Border.all(color: theme.colorScheme.tertiary, width: borderWidth),
      borderRadius: theme.tileBorderRadius,
    );
  }
}