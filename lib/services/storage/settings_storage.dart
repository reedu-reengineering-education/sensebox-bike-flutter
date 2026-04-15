import 'package:shared_preferences/shared_preferences.dart';

class AppSettingsData {
  const AppSettingsData({
    required this.vibrateOnDisconnect,
    required this.privacyZones,
    required this.directUploadMode,
    required this.apiUrl,
  });

  final bool vibrateOnDisconnect;
  final List<String> privacyZones;
  final bool directUploadMode;
  final String apiUrl;
}

abstract class SettingsStorage {
  Future<AppSettingsData> load();
  Future<void> setVibrateOnDisconnect(bool value);
  Future<void> setPrivacyZones(List<String> zones);
  Future<void> setDirectUploadMode(bool value);
  Future<void> setApiUrl(String value);
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
      apiUrl: prefs.getString('apiUrl') ?? '',
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

  @override
  Future<void> setApiUrl(String value) async {
    final prefs = await _prefs;
    await prefs.setString('apiUrl', value);
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
              apiUrl: '',
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
      apiUrl: _data.apiUrl,
    );
  }

  @override
  Future<void> setPrivacyZones(List<String> zones) async {
    _data = AppSettingsData(
      vibrateOnDisconnect: _data.vibrateOnDisconnect,
      privacyZones: zones,
      directUploadMode: _data.directUploadMode,
      apiUrl: _data.apiUrl,
    );
  }

  @override
  Future<void> setDirectUploadMode(bool value) async {
    _data = AppSettingsData(
      vibrateOnDisconnect: _data.vibrateOnDisconnect,
      privacyZones: _data.privacyZones,
      directUploadMode: value,
      apiUrl: _data.apiUrl,
    );
  }

  @override
  Future<void> setApiUrl(String value) async {
    _data = AppSettingsData(
      vibrateOnDisconnect: _data.vibrateOnDisconnect,
      privacyZones: _data.privacyZones,
      directUploadMode: _data.directUploadMode,
      apiUrl: value,
    );
  }
}
