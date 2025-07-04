import 'package:flutter/material.dart';
import 'package:sensebox_bike/theme.dart';

class TrackDivider extends StatelessWidget {
  final bool showDivider;

  const TrackDivider({super.key, required this.showDivider});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    if (!showDivider) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(left: spacing * 2, right: spacing * 2),
      child: Divider(
        height: 1,
        color: colorScheme.primaryFixedDim,
      ),
    );
  }
}