import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:sensebox_bike/services/opensensemap_service.dart';
import 'package:sensebox_bike/models/sensebox.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OpenSenseMapBloc with ChangeNotifier {
  final OpenSenseMapService _service = OpenSenseMapService();
  bool _isAuthenticated = false;
  List<dynamic> _senseBoxes = [];

  bool get isAuthenticated => _isAuthenticated;
  List<dynamic> get senseBoxes => _senseBoxes;

  OpenSenseMapBloc() {
    _service.refreshToken().then((_) => _isAuthenticated = true);
  }

  Future<SenseBox>? get selectedSenseBox {
    final prefs = SharedPreferences.getInstance();
    final selectedSenseBoxJson = prefs.then((prefs) =>
        prefs.getString('selectedSenseBox') ?? jsonEncode(<String, dynamic>{}));
    return selectedSenseBoxJson
        .then((json) => SenseBox.fromJson(jsonDecode(json)));
  }

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
  }

  Future<SenseBox?> getSelectedSenseBox() async {
    final prefs = SharedPreferences.getInstance();
    if (!_isAuthenticated) {
      await prefs.then((prefs) => prefs.remove('selectedSenseBox'));
      return null;
    }

    final selectedSenseBoxJson =
        await prefs.then((prefs) => prefs.getString('selectedSenseBox'));

    if (selectedSenseBoxJson == null) {
      return null;
    }

    return SenseBox.fromJson(jsonDecode(selectedSenseBoxJson));
  }
}
