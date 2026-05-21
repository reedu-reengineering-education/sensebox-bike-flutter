import 'package:geolocator/geolocator.dart';
import 'package:sensebox_bike/services/location_permission_messages.dart';
import 'package:sensebox_bike/services/custom_exceptions.dart';

class PermissionService {
  static bool get _requiresAlwaysLocation =>
      requiresAlwaysLocationPermission;

  static bool _isPermissionGranted(LocationPermission permission) {
    if (_requiresAlwaysLocation) {
      return permission == LocationPermission.always;
    }
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  static Future<LocationPermission> _requestAndEscalatePermission() async {
    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (_requiresAlwaysLocation &&
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

    final permission = await _requestAndEscalatePermission();

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever ||
        !_isPermissionGranted(permission)) {
      throw LocationPermissionDenied();
    }
  }

  static Future<bool> isLocationPermissionGranted() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await _requestAndEscalatePermission();
    } else if (_requiresAlwaysLocation &&
        permission == LocationPermission.whileInUse) {
      permission = await Geolocator.requestPermission();
    }

    return _isPermissionGranted(permission);
  }
}
