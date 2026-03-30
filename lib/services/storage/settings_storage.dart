import 'package:shared_preferences/shared_preferences.dart';

class AppSettingsData {
  const AppSettingsData({
    required this.vibrateOnDisconnect,
    required this.privacyZones,
    required this.directUploadMode,
  });

  final bool vibrateOnDisconnect;
  final List<String> privacyZones;
  final bool directUploadMode;
}

abstract class SettingsStorage {
  Future<AppSettingsData> load();
  Future<void> setVibrateOnDisconnect(bool value);
  Future<void> setPrivacyZones(List<String> zones);
  Future<void> setDirectUploadMode(bool value);
}

class SharedPreferencesSettingsStorage implements SettingsStorage {
  SharedPreferencesSettingsStorage({Future<SharedPreferences>? prefs})
      : _prefs = prefs ?? SharedPreferences.getInstance();

  final Future<SharedPreferences> _prefs;

  @override
  Future<AppSettingsData> load() async {
    final prefs = await _prefs;
    return AppSettingsData(
      vibrateOnDisconnect: prefs.getBool('vibrateOnDisconnect') ?? false,
      privacyZones: prefs.getStringList('privacyZones') ?? const <String>[],
      directUploadMode: prefs.getBool('directUploadMode') ?? false,
    );
  }

  @override
  Future<void> setVibrateOnDisconnect(bool value) async {
    final prefs = await _prefs;
    await prefs.setBool('vibrateOnDisconnect', value);
  }

  @override
  Future<void> setPrivacyZones(List<String> zones) async {
    final prefs = await _prefs;
    await prefs.setStringList('privacyZones', zones);
  }

  @override
  Future<void> setDirectUploadMode(bool value) async {
    final prefs = await _prefs;
    await prefs.setBool('directUploadMode', value);
  }
}

class InMemorySettingsStorage implements SettingsStorage {
  InMemorySettingsStorage({
    AppSettingsData? initialData,
  }) : _data = initialData ??
            const AppSettingsData(
              vibrateOnDisconnect: false,
              privacyZones: <String>[],
              directUploadMode: false,
            );

  AppSettingsData _data;

  @override
  Future<AppSettingsData> load() async => _data;

  @override
  Future<void> setVibrateOnDisconnect(bool value) async {
    _data = AppSettingsData(
      vibrateOnDisconnect: value,
      privacyZones: _data.privacyZones,
      directUploadMode: _data.directUploadMode,
    );
  }

  @override
  Future<void> setPrivacyZones(List<String> zones) async {
    _data = AppSettingsData(
      vibrateOnDisconnect: _data.vibrateOnDisconnect,
      privacyZones: zones,
      directUploadMode: _data.directUploadMode,
    );
  }

  @override
  Future<void> setDirectUploadMode(bool value) async {
    _data = AppSettingsData(
      vibrateOnDisconnect: _data.vibrateOnDisconnect,
      privacyZones: _data.privacyZones,
      directUploadMode: value,
    );
  }
}
