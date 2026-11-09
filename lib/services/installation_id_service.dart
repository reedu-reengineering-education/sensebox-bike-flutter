import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:sensebox_bike/constants.dart';
import 'package:shared_preferences/shared_preferences.dart';

class InstallationIdService {
  InstallationIdService._();

  static String? _id;

  static String get id =>
      _id ?? (throw StateError('InstallationIdService.init() was not called'));

  static Future<String> init() async {
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString(SharedPreferencesKeys.installationId);
    if (id == null || id.isEmpty) {
      id = generateInstallationId();
      await prefs.setString(SharedPreferencesKeys.installationId, id);
    }
    return _id = id;
  }

  static String generateInstallationId() {
    final random = Random.secure();
    String group() => random.nextInt(0x10000).toRadixString(16).padLeft(4, '0');
    return '${group()}-${group()}-${group()}';
  }

  @visibleForTesting
  static void setIdForTesting(String? id) => _id = id;
}
