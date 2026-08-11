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
}

extension FormFactorX on BuildContext {
  bool get isTablet =>
      MediaQuery.sizeOf(this).shortestSide >= Breakpoints.tablet;

  bool get isLandscape =>
      MediaQuery.sizeOf(this).width > MediaQuery.sizeOf(this).height;

  /// Phone: unbounded (full bleed). Tablet: reading width.
  double get contentMaxWidth =>
      isTablet ? Breakpoints.contentMaxWidth : double.infinity;

  /// Home sensor grid: phone stays at 2 columns.
  /// iPad: up to 4 (portrait) / 8 (landscape), or fewer if fewer tiles.
  int homeSensorCrossAxisCount({required int tileCount}) {
    if (!isTablet) return 2;
    final maxColumns = isLandscape ? 8 : 4;
    if (tileCount <= 0) return maxColumns;
    return min(maxColumns, tileCount);
  }

  /// Track overview sensor tiles: phone unchanged.
  /// iPad: up to 4 (portrait) / 8 (landscape), or fewer if fewer tiles.
  int trackSensorCrossAxisCount({required int tileCount}) {
    if (!isTablet) {
      return MediaQuery.sizeOf(this).width < 400 ? 3 : 4;
    }
    final maxColumns = isLandscape ? 8 : 4;
    if (tileCount <= 0) return maxColumns;
    return min(maxColumns, tileCount);
  }

  /// Two-column layouts (tracks list, settings) on iPad landscape.
  bool get useTwoColumnLandscape => isTablet && isLandscape;

  /// Home + track overview: map left, actions/sensors in a right rail.
  bool get useLandscapeSideRail => useTwoColumnLandscape;

  /// Width of the landscape side rail (actions / sensor tiles).
  double get landscapeSideRailWidth {
    final width = MediaQuery.sizeOf(this).width;
    return (width * 0.28).clamp(240.0, 320.0);
  }

  /// Narrower rail for track overview sensor tiles only.
  double get landscapeTrackSideRailWidth => landscapeSideRailWidth / 2;

  double homeMapMinHeight({required bool isConnected}) {
    return MediaQuery.sizeOf(this).height * 0.33;
  }

  double homeMapMaxHeight({required bool isConnected}) {
    return MediaQuery.sizeOf(this).height * (isConnected ? 0.65 : 0.85);
  }
}
