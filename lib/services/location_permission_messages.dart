import 'package:sensebox_bike/services/location_permission_platform.dart';

const _iosMessage =
    'Location services are disabled or access is denied. To record rides in the background, select "Always" for location access in your device settings.';

const _androidMessage =
    'Location services are disabled or access is denied. To record tracks, enable location services and allow location access in your device settings.';

String locationPermissionDeniedMessage() {
  if (requiresAlwaysLocationPermission) {
    return _iosMessage;
  }
  return _androidMessage;
}
