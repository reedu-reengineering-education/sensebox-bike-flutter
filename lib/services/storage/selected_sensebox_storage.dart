import 'package:shared_preferences/shared_preferences.dart';

abstract class SelectedSenseBoxStorage {
  Future<String?> loadSelectedSenseBoxJson();
  Future<void> saveSelectedSenseBoxJson(String value);
  Future<void> clearSelectedSenseBox();
}

class SharedPreferencesSelectedSenseBoxStorage
    implements SelectedSenseBoxStorage {
  SharedPreferencesSelectedSenseBoxStorage({Future<SharedPreferences>? prefs})
      : _prefs = prefs ?? SharedPreferences.getInstance();

  final Future<SharedPreferences> _prefs;

  @override
  Future<String?> loadSelectedSenseBoxJson() async {
    final prefs = await _prefs;
    return prefs.getString('selectedSenseBox');
  }

  @override
  Future<void> saveSelectedSenseBoxJson(String value) async {
    final prefs = await _prefs;
    await prefs.setString('selectedSenseBox', value);
  }

  @override
  Future<void> clearSelectedSenseBox() async {
    final prefs = await _prefs;
    await prefs.remove('selectedSenseBox');
  }
}

class InMemorySelectedSenseBoxStorage implements SelectedSenseBoxStorage {
  String? _value;

  @override
  Future<String?> loadSelectedSenseBoxJson() async => _value;

  @override
  Future<void> saveSelectedSenseBoxJson(String value) async {
    _value = value;
  }

  @override
  Future<void> clearSelectedSenseBox() async {
    _value = null;
  }
}
