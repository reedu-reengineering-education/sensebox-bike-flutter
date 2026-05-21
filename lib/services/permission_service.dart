import 'package:geolocator/geolocator.dart';
import 'package:sensebox_bike/services/custom_exceptions.dart';
import 'package:sensebox_bike/services/location_permission_platform.dart';

bool _isLocationAccessSufficient(
  LocationPermission permission, {
  required bool requiresAlways,
}) {
  if (requiresAlways) {
    return permission == LocationPermission.always;
  }
  return permission == LocationPermission.always ||
      permission == LocationPermission.whileInUse;
}

class PermissionService {
  static Future<LocationPermission> _resolveLocationPermission() async {
    var permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.deniedForever) {
      return permission;
    }

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.deniedForever) {
      return permission;
    }

    if (requiresAlwaysLocationPermission &&
        permission == LocationPermission.whileInUse) {
      permission = await Geolocator.requestPermission();
    }

    return permission;
  }

  static Future<void> ensureLocationPermissionsGranted() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw LocationPermissionDenied();
    }

    final permission = await _resolveLocationPermission();
    if (!_isLocationAccessSufficient(
      permission,
      requiresAlways: requiresAlwaysLocationPermission,
    )) {
      throw LocationPermissionDenied();
    }
  }

  static Future<bool> isLocationPermissionGranted() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    final permission = await _resolveLocationPermission();
    return _isLocationAccessSufficient(
      permission,
      requiresAlways: requiresAlwaysLocationPermission,
    );
  }
}
