import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:sensebox_bike/models/sensebox.dart';
import 'package:sensebox_bike/services/opensensemap_service.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Add for StreamController

class OpenSenseMapBloc with ChangeNotifier {
  final OpenSenseMapService _service = OpenSenseMapService();
  bool _isAuthenticated = false;
  List<dynamic> _senseBoxes = [];

  final _senseBoxController =
      StreamController<SenseBox?>.broadcast(); // StreamController

  bool get isAuthenticated => _isAuthenticated;
  List<dynamic> get senseBoxes => _senseBoxes;

  OpenSenseMapBloc() {
    _service
        .refreshToken()
        .then((_) => {_isAuthenticated = true, loadSelectedSenseBox()});
  }

  Stream<SenseBox?> get senseBoxStream =>
      _senseBoxController.stream; // Expose stream

  Future<void> register(String name, String email, String password) async {
    try {
      await _service.register(name, email, password);
      _isAuthenticated = true;
      notifyListeners();
    } catch (e) {
      _isAuthenticated = false;
      rethrow;
    }
  }

  Future<void> login(String email, String password) async {
    try {
      await _service.login(email, password);
      _isAuthenticated = true;
      notifyListeners();
    } catch (e) {
      _isAuthenticated = false;
      rethrow;
    }
  }

  Future<void> logout() async {
    await _service.logout();
    _isAuthenticated = false;
    _senseBoxController.add(null); // Clear senseBox on logout
    notifyListeners();
  }

  Future<void> createSenseBoxBike(String name, double latitude,
      double longitude, SenseBoxBikeModel model) async {
    try {
      await _service.createSenseBoxBike(name, latitude, longitude, model);
    } catch (e) {
      rethrow;
    }
  }

  Future<List> fetchAndSelectSenseBox() async {
    try {
      _senseBoxes = await _service.getSenseBoxes();
      notifyListeners();
      return _senseBoxes;
    } catch (e) {
      throw Exception('Failed to fetch senseBoxes');
    }
  }

  void setSelectedSenseBox(SenseBox senseBox) {
    final prefs = SharedPreferences.getInstance();
    prefs.then((prefs) =>
        prefs.setString('selectedSenseBox', jsonEncode(senseBox.toJson())));
    _senseBoxController.add(senseBox); // Push selected senseBox to the stream
  }

  Future<void> loadSelectedSenseBox() async {
    final prefs = SharedPreferences.getInstance();

    if (!_isAuthenticated) {
      await prefs.then((prefs) => prefs.remove('selectedSenseBox'));
      _senseBoxController.add(null);
      return;
    }

    final selectedSenseBoxJson =
        await prefs.then((prefs) => prefs.getString('selectedSenseBox'));

    if (selectedSenseBoxJson == null) {
      _senseBoxController.add(null); // Push null if no senseBox is selected
    } else {
      _senseBoxController.add(SenseBox.fromJson(jsonDecode(
          selectedSenseBoxJson))); // Push selected senseBox to the stream
    }
  }

  void dispose() {
    _senseBoxController.close(); // Close the stream when done
    super.dispose();
  }
}
