import 'package:flutter/material.dart';
import 'package:sensebox_bike/theme.dart';
import 'package:sensebox_bike/ui/layout/form_factor.dart';

/// Right-side landscape panel styled like the bottom [NavigationBar]:
/// rounded corners toward the content and a soft drop shadow.
class LandscapeSidePanel extends StatelessWidget {
  final Widget child;
  final double? width;

  const LandscapeSidePanel({
    super.key,
    required this.child,
    this.width,
  });

  static const BorderRadius _borderRadius = BorderRadius.only(
    topLeft: Radius.circular(borderRadius),
    bottomLeft: Radius.circular(borderRadius),
  );

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: width ?? context.landscapeSideRailWidth,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: _borderRadius,
        boxShadow: const [
          BoxShadow(
            color: Colors.black38,
            spreadRadius: 0,
            blurRadius: 12,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: _borderRadius,
        child: Material(
          color: colorScheme.surfaceContainer,
          child: child,
        ),
      ),
    );
  }
}
