import 'dart:async';
import 'package:flutter/material.dart';
import 'package:sensebox_bike/constants.dart';
import 'package:sensebox_bike/models/data_collection_mode.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsBloc with ChangeNotifier {
  // StreamController to manage settings updates
  final StreamController<bool> _vibrateOnDisconnectController =
      StreamController<bool>.broadcast();
  final StreamController<List<String>> _privacyZonesController =
      StreamController<List<String>>.broadcast();
  final StreamController<bool> _directUploadModeController =
      StreamController<bool>.broadcast();

  bool _vibrateOnDisconnect = false;
  List<String> _privacyZones = [];
  bool _directUploadMode =
      false; // false = post-ride upload, true = direct upload
  String _apiUrl = '';
  DataCollectionMode _lastResolvedDataCollectionMode =
      DataCollectionMode.gpsDriven;
  int _lastResolvedCollectionIntervalSeconds =
      defaultCollectionIntervalSeconds;

  SettingsBloc() {
    _loadSettings();
  }

  // Getter for the current "Vibrate on disconnect" value
  bool get vibrateOnDisconnect => _vibrateOnDisconnect;

  // Getter for the current privacy zones
  List<String> get privacyZones => _privacyZones;

  // Getter for the current upload mode
  bool get directUploadMode => _directUploadMode;

  // Getter for the current API URL
  String get apiUrl =>
      _apiUrl.isEmpty ? 'https://api.opensensemap.org' : _apiUrl;

  DataCollectionMode get lastResolvedDataCollectionMode =>
      _lastResolvedDataCollectionMode;

  int get lastResolvedCollectionIntervalSeconds =>
      _lastResolvedCollectionIntervalSeconds;

  // Stream for vibrateOnDisconnect updates
  Stream<bool> get vibrateOnDisconnectStream =>
      _vibrateOnDisconnectController.stream;

  // Stream for privacy zones updates
  Stream<List<String>> get privacyZonesStream => _privacyZonesController.stream;

  // Stream for upload mode updates
  Stream<bool> get directUploadModeStream => _directUploadModeController.stream;

  static DataCollectionMode _parseStoredCollectionMode(String? value) {
    if (value == null) {
      return DataCollectionMode.gpsDriven;
    }
    try {
      return DataCollectionMode.fromJson(value);
    } catch (_) {
      return DataCollectionMode.gpsDriven;
    }
  }

  static int _parseStoredCollectionIntervalSeconds(int? value) {
    if (value == null) {
      return defaultCollectionIntervalSeconds;
    }
    try {
      return parseCollectionIntervalSeconds(value);
    } catch (_) {
      return defaultCollectionIntervalSeconds;
    }
  }

  // Load settings from Shared Preferences
  Future<void> _loadSettings() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    _vibrateOnDisconnect =
        prefs.getBool(SharedPreferencesKeys.vibrateOnDisconnect) ?? false;
    _privacyZones = prefs.getStringList('privacyZones') ?? [];
    _directUploadMode = prefs.getBool('directUploadMode') ?? false;
    _apiUrl = prefs.getString('apiUrl') ?? '';
    _lastResolvedDataCollectionMode = _parseStoredCollectionMode(
      prefs.getString(SharedPreferencesKeys.lastResolvedDataCollectionMode),
    );
    _lastResolvedCollectionIntervalSeconds =
        _parseStoredCollectionIntervalSeconds(
      prefs.getInt(SharedPreferencesKeys.lastResolvedCollectionIntervalSeconds),
    );

    // Emit the values to the streams
    _vibrateOnDisconnectController.add(_vibrateOnDisconnect);
    _privacyZonesController.add(_privacyZones);
    _directUploadModeController.add(_directUploadMode);

    notifyListeners();
  }

  // Toggle the "Vibrate on disconnect" setting and save it
  Future<void> toggleVibrateOnDisconnect(bool value) async {
    _vibrateOnDisconnect = value;

    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(SharedPreferencesKeys.vibrateOnDisconnect, value);

    // Emit the new value to the stream
    _vibrateOnDisconnectController.add(_vibrateOnDisconnect);

    notifyListeners();
  }

  // Set new privacy zones and save them
  Future<void> setPrivacyZones(List<String> zones) async {
    _privacyZones = zones;

    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('privacyZones', zones);

    // Emit the new privacy zones to the stream
    _privacyZonesController.add(_privacyZones);

    notifyListeners();
  }

  // Toggle the upload mode setting and save it
  Future<void> toggleDirectUploadMode(bool value) async {
    _directUploadMode = value;

    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('directUploadMode', value);

    // Emit the new value to the stream
    _directUploadModeController.add(_directUploadMode);

    notifyListeners();
  }

  Future<void> setApiUrl(String value) async {
    _apiUrl = value;

    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('apiUrl', value);

    notifyListeners();
  }

  Future<void> _writeCollectionPrefsToDisk() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      SharedPreferencesKeys.lastResolvedDataCollectionMode,
      _lastResolvedDataCollectionMode.toJson(),
    );
    await prefs.setInt(
      SharedPreferencesKeys.lastResolvedCollectionIntervalSeconds,
      _lastResolvedCollectionIntervalSeconds,
    );
  }

  Future<void> setDataCollectionMode(DataCollectionMode mode) async {
    _lastResolvedDataCollectionMode = mode;
    await _writeCollectionPrefsToDisk();
    notifyListeners();
  }

  Future<void> setCollectionIntervalSeconds(int seconds) async {
    _lastResolvedCollectionIntervalSeconds =
        parseCollectionIntervalSeconds(seconds);
    await _writeCollectionPrefsToDisk();
    notifyListeners();
  }

  Future<void> setLastResolvedCollectionMode({
    required DataCollectionMode mode,
    required int collectionIntervalSeconds,
  }) async {
    _lastResolvedDataCollectionMode = mode;
    _lastResolvedCollectionIntervalSeconds =
        parseCollectionIntervalSeconds(collectionIntervalSeconds);
    await _writeCollectionPrefsToDisk();
    notifyListeners();
  }

  @override
  void dispose() {
    _vibrateOnDisconnectController.close();
    _privacyZonesController.close();
    _directUploadModeController.close();
    super.dispose();
  }
}
