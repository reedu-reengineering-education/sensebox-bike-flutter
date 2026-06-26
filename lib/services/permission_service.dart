import 'dart:io';

import 'package:app_settings/app_settings.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
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
  @visibleForTesting
  static Future<void> Function()? debugIosAlwaysPermissionRequest;

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
      await _requestIosAlwaysLocationPermission();
      permission = await Geolocator.checkPermission();
    }

    return permission;
  }

  static Future<void> _requestIosAlwaysLocationPermission() async {
    if (debugIosAlwaysPermissionRequest != null) {
      await debugIosAlwaysPermissionRequest!();
      return;
    }
    await Permission.locationAlways.request();
  }

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

  static Future<void> openBluetoothSettings() =>
      AppSettings.openAppSettings(type: AppSettingsType.bluetooth);

  static Future<void> openAppSettings() =>
      AppSettings.openAppSettings(type: AppSettingsType.settings);

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
