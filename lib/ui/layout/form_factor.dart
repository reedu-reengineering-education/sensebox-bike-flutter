import 'package:flutter/material.dart';

/// Shared breakpoints. Phone behavior must match pre-tablet layouts.
class Breakpoints {
  /// Material/iPad-style tablet threshold on the shortest side.
  static const double tablet = 600;
}

extension FormFactorX on BuildContext {
  bool get isTablet =>
      MediaQuery.sizeOf(this).shortestSide >= Breakpoints.tablet;

  bool get isLandscape =>
      MediaQuery.sizeOf(this).width > MediaQuery.sizeOf(this).height;

  /// Home screen shows the floating side rail only on tablets in landscape.
  /// Tablet portrait keeps the regular stacked phone layout.
  bool get useSideRail => isTablet && isLandscape;

  /// Width of the side rail holding actions and sensor tiles.
  double get sideRailWidth {
    final width = MediaQuery.sizeOf(this).width;
    return (width * 0.32).clamp(320.0, 440.0);
  }
}
