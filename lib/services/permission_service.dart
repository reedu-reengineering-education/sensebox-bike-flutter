import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
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

  /// iOS/macOS require "Always" location to keep GPS running with a locked screen.
  static Future<void> ensureLocationPermissionsForRecording() async {
    await ensureLocationPermissionsGranted();

    if (defaultTargetPlatform != TargetPlatform.iOS &&
        defaultTargetPlatform != TargetPlatform.macOS) {
      return;
    }

    await _ensureAlwaysLocationOnApple();
  }

  static Future<bool> allowsBackgroundLocation() async {
    if (defaultTargetPlatform != TargetPlatform.iOS &&
        defaultTargetPlatform != TargetPlatform.macOS) {
      return isLocationPermissionGranted();
    }

    final permission = await Geolocator.checkPermission();
    return permission == LocationPermission.always;
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

  /// Required on Android 14+ to start the GPS foreground service during recording.
  static Future<void> ensureNotificationPermissionGranted() async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return;
    }

    final status = await Permission.notification.status;
    if (status.isGranted) {
      return;
    }

    final result = await Permission.notification.request();
    if (!result.isGranted) {
      throw NotificationPermissionDenied();
    }
  }

  static Future<void> _ensureAlwaysLocationOnApple() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.always) {
      return;
    }

    if (permission == LocationPermission.deniedForever) {
      throw LocationPermissionAlwaysRequired();
    }

    final result = await Permission.locationAlways.request();
    if (result.isGranted) {
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.always) {
      return;
    }

    throw LocationPermissionAlwaysRequired();
  }
}
