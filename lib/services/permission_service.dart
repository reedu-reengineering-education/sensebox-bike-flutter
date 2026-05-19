import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sensebox_bike/services/custom_exceptions.dart';

class PermissionService {
  static bool get _isApplePlatform =>
      defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS;

  static Future<void> ensureLocationPermissionsGranted() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw LocationPermissionDenied();
    }

    if (_isApplePlatform) {
      await _ensureAlwaysLocationOnApple();
      return;
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
    await ensureNotificationPermissionGranted();
  }

  /// Called during first app setup (e.g. after accepting the privacy policy).
  /// On iOS this shows "When In Use" first, then immediately prompts for "Always".
  static Future<void> requestInitialLocationPermissions() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return;
    }

    if (_isApplePlatform) {
      await _requestAppleLocationPermissions();
      return;
    }

    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      await Geolocator.requestPermission();
    }
  }

  static Future<bool> allowsBackgroundLocation() async {
    if (!_isApplePlatform) {
      return isLocationPermissionGranted();
    }

    final permission = await Geolocator.checkPermission();
    return permission == LocationPermission.always;
  }

  static Future<bool> isLocationPermissionGranted() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return false;
    }

    if (_isApplePlatform) {
      final permission = await _requestAppleLocationPermissions();
      return permission == LocationPermission.always;
    }

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
    final permission = await _requestAppleLocationPermissions();

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw LocationPermissionDenied();
    }

    if (permission != LocationPermission.always) {
      throw LocationPermissionAlwaysRequired();
    }
  }

  /// Requests "When In Use" if needed, then immediately prompts for "Always".
  static Future<LocationPermission> _requestAppleLocationPermissions() async {
    var permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return permission;
    }

    if (permission != LocationPermission.always) {
      await Permission.locationAlways.request();
      permission = await Geolocator.checkPermission();
    }

    return permission;
  }
}
