import 'dart:io';

import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sensebox_bike/services/custom_exceptions.dart';

class PermissionService {
  /// Requests the Android 12+ runtime Bluetooth permissions
  /// ([Permission.bluetoothScan] / [Permission.bluetoothConnect]). On older
  /// Android versions and on iOS these are not runtime permissions and resolve
  /// as granted automatically, so this is a no-op there.
  ///
  /// Returns `true` when the permissions are usable for BLE.
  static Future<bool> ensureBluetoothPermissionsGranted() async {
    if (!Platform.isAndroid) {
      return true;
    }

    final statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
    ].request();

    return statuses.values.every((status) => status.isGranted);
  }

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