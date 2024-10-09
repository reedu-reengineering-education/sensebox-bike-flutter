import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsBloc with ChangeNotifier {
  // StreamController to manage settings updates
  final StreamController<bool> _vibrateOnDisconnectController =
      StreamController<bool>.broadcast();

  bool _vibrateOnDisconnect = false;

  SettingsBloc() {
    _loadSettings();
  }

  // Getter for the current "Vibrate on disconnect" value
  bool get vibrateOnDisconnect => _vibrateOnDisconnect;

  // Stream for vibrateOnDisconnect updates
  Stream<bool> get vibrateOnDisconnectStream =>
      _vibrateOnDisconnectController.stream;

  // Load settings from Shared Preferences
  Future<void> _loadSettings() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    _vibrateOnDisconnect = prefs.getBool('vibrateOnDisconnect') ?? false;

    // Emit the value to the stream
    _vibrateOnDisconnectController.add(_vibrateOnDisconnect);

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

  // Dispose the StreamController when no longer needed
  @override
  void dispose() {
    _vibrateOnDisconnectController.close();
    super.dispose();
  }
}
