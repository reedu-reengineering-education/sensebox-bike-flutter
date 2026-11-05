import 'dart:math';

import 'package:sensebox_bike/constants.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SupportIdService {
  SupportIdService._();

  static Future<String>? _supportId;

  static Future<String> getOrCreate() => _supportId ??= _loadOrCreate();

  static Future<String> _loadOrCreate() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(SharedPreferencesKeys.supportId);
    if (stored != null && stored.isNotEmpty) {
      return stored;
    }
    final created = generateSupportId();
    await prefs.setString(SharedPreferencesKeys.supportId, created);
    return created;
  }

  static String generateSupportId([Random? random]) {
    final rng = random ?? Random.secure();
    String group() => rng.nextInt(0x10000).toRadixString(16).padLeft(4, '0');
    return '${group()}-${group()}-${group()}';
  }

  static void resetCacheForTesting() => _supportId = null;
}
