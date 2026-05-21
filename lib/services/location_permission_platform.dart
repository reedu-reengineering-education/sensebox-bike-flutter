import 'package:flutter/foundation.dart';

/// Whether the current platform requires [LocationPermission.always] for rides.
///
/// Only iOS needs background "Always" location for ride tracking. Android uses
/// a foreground service with while-in-use permission.
bool get requiresAlwaysLocationPermission =>
    defaultTargetPlatform == TargetPlatform.iOS;
