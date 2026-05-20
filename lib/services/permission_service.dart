import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sensebox_bike/constants.dart';
import 'package:sensebox_bike/services/custom_exceptions.dart';
import 'package:sensebox_bike/services/error_service.dart';

class PermissionService {
  static bool get _isApplePlatform =>
      defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS;

  /// Foreground map/GPS usage: While In Use or Always is sufficient.
  static Future<void> ensureForegroundLocationPermissionsGranted() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw LocationPermissionDenied();
    }

    if (_isApplePlatform) {
      await _ensureForegroundLocationOnApple();
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

  /// Backwards-compatible alias for foreground location checks.
  static Future<void> ensureLocationPermissionsGranted() async {
    await ensureForegroundLocationPermissionsGranted();
  }

  /// Recording/background tracking: Always on iOS, notification on Android 14+.
  static Future<void> ensureLocationPermissionsForRecording() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw LocationPermissionDenied();
    }

    if (_isApplePlatform) {
      await _ensureAlwaysLocationOnApple();
    } else {
      await ensureForegroundLocationPermissionsGranted();
    }

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

  /// Requests initial iOS location permissions once per install.
  static Future<void> requestInitialLocationPermissionsIfNeeded() async {
    if (!_isApplePlatform) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    if (prefs.containsKey(
        SharedPreferencesKeys.initialLocationPermissionsRequestedAt)) {
      return;
    }

    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return;
      }

      await requestInitialLocationPermissions();

      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        // User dismissed the prompt; offer again on a future launch.
        return;
      }

      await prefs.setString(
        SharedPreferencesKeys.initialLocationPermissionsRequestedAt,
        DateTime.now().toIso8601String(),
      );
    } catch (e, stack) {
      ErrorService.logToConsole(e, stack);
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

    final permission = await Geolocator.checkPermission();
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

  static Future<void> _ensureForegroundLocationOnApple() async {
    var permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw LocationPermissionDenied();
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
