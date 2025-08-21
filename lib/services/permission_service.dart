import 'package:geolocator/geolocator.dart';
import 'package:sensebox_bike/services/custom_exceptions.dart';

class PermissionService {
  static Future<void> ensureLocationPermissionsGranted() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw LocationPermissionDenied();
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw LocationPermissionDenied();
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw LocationPermissionDenied();
    }
  }

  static Future<bool> isLocationPermissionGranted() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }
}