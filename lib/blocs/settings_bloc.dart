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
  DataCollectionMode _dataCollectionMode = DataCollectionMode.gpsDriven;
  int _collectionIntervalSeconds = defaultCollectionIntervalSeconds;
  String? _rememberedDeviceId;
  String? _rememberedDeviceName;

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

  DataCollectionMode get dataCollectionMode => _dataCollectionMode;

  int get collectionIntervalSeconds => _collectionIntervalSeconds;

  // Getters for the remembered auto-connect device (null = none remembered)
  String? get rememberedDeviceId => _rememberedDeviceId;
  String? get rememberedDeviceName => _rememberedDeviceName;

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
    // Prefs keys keep legacy "lastResolved*" names for migration compatibility.
    _dataCollectionMode = _parseStoredCollectionMode(
      prefs.getString(SharedPreferencesKeys.lastResolvedDataCollectionMode),
    );
    _collectionIntervalSeconds = _parseStoredCollectionIntervalSeconds(
      prefs.getInt(SharedPreferencesKeys.lastResolvedCollectionIntervalSeconds),
    );
    _rememberedDeviceId = prefs.getString(SharedPreferencesKeys.rememberedDeviceId);
    _rememberedDeviceName =
        prefs.getString(SharedPreferencesKeys.rememberedDeviceName);

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
      _dataCollectionMode.toJson(),
    );
    await prefs.setInt(
      SharedPreferencesKeys.lastResolvedCollectionIntervalSeconds,
      _collectionIntervalSeconds,
    );
  }

  /// Writes mode and/or interval in a single prefs update.
  Future<void> setCollectionPreferences({
    DataCollectionMode? mode,
    int? intervalSeconds,
  }) async {
    if (mode != null) {
      _dataCollectionMode = mode;
    }
    if (intervalSeconds != null) {
      _collectionIntervalSeconds =
          parseCollectionIntervalSeconds(intervalSeconds);
    }
    await _writeCollectionPrefsToDisk();
    notifyListeners();
  }

  Future<void> setDataCollectionMode(DataCollectionMode mode) =>
      setCollectionPreferences(mode: mode);

  Future<void> setCollectionIntervalSeconds(int seconds) =>
      setCollectionPreferences(intervalSeconds: seconds);

  // Remember a device for auto-connect (id + display name), persisted.
  Future<void> rememberDevice(String id, String name) async {
    _rememberedDeviceId = id;
    _rememberedDeviceName = name;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(SharedPreferencesKeys.rememberedDeviceId, id);
    await prefs.setString(SharedPreferencesKeys.rememberedDeviceName, name);

    notifyListeners();
  }

  // Forget the remembered auto-connect device, if any.
  Future<void> forgetRememberedDevice() async {
    _rememberedDeviceId = null;
    _rememberedDeviceName = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(SharedPreferencesKeys.rememberedDeviceId);
    await prefs.remove(SharedPreferencesKeys.rememberedDeviceName);

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
