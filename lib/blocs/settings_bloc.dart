import 'dart:async';
import 'package:flutter/material.dart';
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

  SettingsBloc() {
    _loadSettings();
  }

  // Getter for the current "Vibrate on disconnect" value
  bool get vibrateOnDisconnect => _vibrateOnDisconnect;

  // Getter for the current privacy zones
  List<String> get privacyZones => _privacyZones;

  // Getter for the current upload mode
  bool get directUploadMode => _directUploadMode;

  // Stream for vibrateOnDisconnect updates
  Stream<bool> get vibrateOnDisconnectStream =>
      _vibrateOnDisconnectController.stream;

  // Stream for privacy zones updates
  Stream<List<String>> get privacyZonesStream => _privacyZonesController.stream;

  // Stream for upload mode updates
  Stream<bool> get directUploadModeStream => _directUploadModeController.stream;

  // Load settings from Shared Preferences
  Future<void> _loadSettings() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    _vibrateOnDisconnect = prefs.getBool('vibrateOnDisconnect') ?? false;
    _privacyZones = prefs.getStringList('privacyZones') ?? [];
    _directUploadMode = prefs.getBool('directUploadMode') ?? false;

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
    await prefs.setBool('vibrateOnDisconnect', value);

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

  // Dispose the StreamController when no longer needed
  @override
  void dispose() {
    _vibrateOnDisconnectController.close();
    _privacyZonesController.close();
    _directUploadModeController.close();
    super.dispose();
  }
}
