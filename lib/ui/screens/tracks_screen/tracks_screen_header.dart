import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:sensebox_bike/theme.dart';

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
                  height: 71,
                  decoration: _buildHeaderDecoration(theme),
                  child: Padding(
                    padding: const EdgeInsets.all(spacing),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildIconWithText(
                          context,
                          Icons.route,
                          localizations.tracksAppBarSumTracks(trackCount),
                        ),
                        _buildIconWithText(
                          context,
                          Icons.timer_outlined,
                          localizations.generalTrackDuration(
                            totalDuration.inHours,
                            totalDuration.inMinutes.remainder(60),
                          ),
                        ),
                        _buildIconWithText(
                          context,
                          Icons.straighten,
                          localizations.generalTrackDistance(
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
      borderRadius: BorderRadius.circular(borderRadius),
    );
  }

  Widget _buildIconWithText(BuildContext context, IconData icon, String text) {
    final theme = Theme.of(context).textTheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, size: iconSizeLarge), 
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              text.split(' ')[0], 
              style: theme.bodyLarge?.copyWith(
                height: 1.0, // Remove extra line height
              ),
            ),
            const SizedBox(width: spacing / 4), 
            Text(
              text.split(' ').sublist(1).join(' '), 
              style: theme.bodySmall
            ),
          ],
        ),
      ],
    );
  }
}