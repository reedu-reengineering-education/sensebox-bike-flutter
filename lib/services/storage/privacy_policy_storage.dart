import 'package:shared_preferences/shared_preferences.dart';
import 'package:sensebox_bike/constants.dart';

abstract class PrivacyPolicyStorage {
  Future<String?> loadAcceptedAt();
  Future<void> saveAcceptedAt(String acceptedAtIsoTimestamp);
}

class SharedPreferencesPrivacyPolicyStorage implements PrivacyPolicyStorage {
  SharedPreferencesPrivacyPolicyStorage({Future<SharedPreferences>? prefs})
      : _prefs = prefs ?? SharedPreferences.getInstance();

  final Future<SharedPreferences> _prefs;

  @override
  Future<String?> loadAcceptedAt() async {
    final prefs = await _prefs;
    return prefs.getString(SharedPreferencesKeys.privacyPolicyAcceptedAt);
  }

  @override
  Future<void> saveAcceptedAt(String acceptedAtIsoTimestamp) async {
    final prefs = await _prefs;
    await prefs.setString(
      SharedPreferencesKeys.privacyPolicyAcceptedAt,
      acceptedAtIsoTimestamp,
    );
  }
}
