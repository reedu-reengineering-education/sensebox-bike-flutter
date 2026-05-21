import 'package:flutter/foundation.dart';

import 'package:flutter/foundation.dart';

const _iosMessage =
    'Location services are disabled or access is denied. To record rides in the background, select "Always" for location access in your phone settings.';

const _androidMessage =
    'Location services are disabled or access is denied. To record tracks, enable location services and allow location access in your phone settings.';

bool get requiresAlwaysLocationPermission =>
    defaultTargetPlatform == TargetPlatform.iOS ||
    defaultTargetPlatform == TargetPlatform.macOS;

String locationPermissionDeniedMessage() {
  if (requiresAlwaysLocationPermission) {
    return _iosMessage;
  }
  return _androidMessage;
}
