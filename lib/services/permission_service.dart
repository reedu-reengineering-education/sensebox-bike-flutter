import 'dart:io';

import 'package:app_settings/app_settings.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sensebox_bike/services/custom_exceptions.dart';

bool _isLocationAccessSufficient(LocationPermission permission) =>
  permission == LocationPermission.always ||
  permission == LocationPermission.whileInUse;

class PermissionService {
  @visibleForTesting
  static Future<void> Function()? debugAlwaysLocationPermissionRequest;

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

    if (permission == LocationPermission.whileInUse) {
      return permission;
    }

    return permission;
  }

  static Future<LocationPermission> _resolveLocationPermissionRequiringAlways()
  async {
    var permission = await _resolveLocationPermission();

    if (permission == LocationPermission.deniedForever) {
      return permission;
    }

    if (permission == LocationPermission.whileInUse) {
      await _requestAlwaysLocationPermission();
      permission = await Geolocator.checkPermission();
    }

    return permission;
  }

  static Future<void> _requestAlwaysLocationPermission() async {
    if (debugAlwaysLocationPermissionRequest != null) {
      await debugAlwaysLocationPermissionRequest!();
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

  static Future<void> ensureLocationPermissionsGranted({
    bool requireAlways = false,
  }) async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw LocationPermissionDenied();
    }

    final permission = requireAlways
        ? await _resolveLocationPermissionRequiringAlways()
        : await _resolveLocationPermission();
    if (!requireAlways && !_isLocationAccessSufficient(permission)) {
      throw LocationPermissionDenied();
    }
    if (requireAlways && permission != LocationPermission.always) {
      throw LocationPermissionDenied();
    }
  }

  static Future<bool> isLocationPermissionGranted({
    bool requireAlways = false,
  }) async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    final permission = requireAlways
        ? await _resolveLocationPermissionRequiringAlways()
        : await _resolveLocationPermission();
    if (requireAlways) {
      return permission == LocationPermission.always;
    }
    return _isLocationAccessSufficient(permission);
  }
}
