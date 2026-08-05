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
      MediaQuery.orientationOf(this) == Orientation.landscape;

  /// Phone: unbounded (full bleed). Tablet: reading width.
  double get contentMaxWidth =>
      isTablet ? Breakpoints.contentMaxWidth : double.infinity;

  /// Home sensor grid: phone stays at 2 columns.
  int homeSensorCrossAxisCount() {
    if (!isTablet) return 2;
    return isLandscape ? 3 : 4;
  }

  /// Phone map header heights (fractions of screen). Tablet portrait uses
  /// available viewport height via [LayoutBuilder] instead.
  double homeMapMinHeight({required bool isConnected}) {
    return MediaQuery.sizeOf(this).height * 0.33;
  }

  double homeMapMaxHeight({required bool isConnected}) {
    return MediaQuery.sizeOf(this).height * (isConnected ? 0.65 : 0.85);
  }
}
