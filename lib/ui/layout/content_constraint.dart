import 'dart:math';

import 'package:flutter/material.dart';
import 'package:sensebox_bike/ui/layout/form_factor.dart';

/// Centers [child] and caps width on tablet. On phone, returns [child] unchanged.
/// Preserves max height from the parent so [Expanded] / scroll views still work.
class ContentConstraint extends StatelessWidget {
  final Widget child;
  final double? maxWidth;

  const ContentConstraint({
    super.key,
    required this.child,
    this.maxWidth,
  });

  @override
  Widget build(BuildContext context) {
    final max = maxWidth ?? context.contentMaxWidth;
    if (!max.isFinite) {
      return child;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = min(constraints.maxWidth, max);
        return Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: width,
            height:
                constraints.hasBoundedHeight ? constraints.maxHeight : null,
            child: child,
          ),
        );
      },
    );
  }
}
