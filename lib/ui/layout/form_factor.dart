import 'dart:math';

import 'package:flutter/material.dart';

/// Shared breakpoints. Phone behavior must match pre-tablet layouts.
class Breakpoints {
  /// Material/iPad-style tablet threshold on the shortest side.
  static const double tablet = 600;

  /// Comfortable reading/form width on iPad.
  static const double contentMaxWidth = 720;

  /// Centered modal/dialog width on iPad.
  static const double modalMaxWidth = 560;

  /// Cap for home map header height on tablet (avoids % of tall windows).
  static const double homeMapMaxHeight = 420;
}

extension FormFactorX on BuildContext {
  bool get isTablet =>
      MediaQuery.sizeOf(this).shortestSide >= Breakpoints.tablet;

  bool get isLandscape =>
      MediaQuery.orientationOf(this) == Orientation.landscape;

  /// Phone: unbounded (full bleed). Tablet: reading width.
  double get contentMaxWidth =>
      isTablet ? Breakpoints.contentMaxWidth : double.infinity;

  /// Home sensor grid: phone stays at 2 columns.
  int homeSensorCrossAxisCount() {
    if (!isTablet) return 2;
    return isLandscape ? 3 : 4;
  }

  /// Map header heights. Phone keeps existing fractions of screen height.
  double homeMapMinHeight({required bool isConnected}) {
    final screenHeight = MediaQuery.sizeOf(this).height;
    if (!isTablet) {
      return screenHeight * 0.33;
    }
    return min(screenHeight * 0.28, Breakpoints.homeMapMaxHeight * 0.7);
  }

  double homeMapMaxHeight({required bool isConnected}) {
    final screenHeight = MediaQuery.sizeOf(this).height;
    if (!isTablet) {
      return screenHeight * (isConnected ? 0.65 : 0.85);
    }
    final fraction = isConnected ? 0.45 : 0.55;
    return min(screenHeight * fraction, Breakpoints.homeMapMaxHeight);
  }
}
