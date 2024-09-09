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

  Future<SenseBox>? get selectedSenseBox {
    final prefs = SharedPreferences.getInstance();
    final selectedSenseBoxJson = prefs.then((prefs) =>
        prefs.getString('selectedSenseBox') ?? jsonEncode(<String, dynamic>{}));
    return selectedSenseBoxJson
        .then((json) => SenseBox.fromJson(jsonDecode(json)));
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

  Future<void> fetchAndSelectSenseBox() async {
    try {
      _senseBoxes = await _service.getSenseBoxes();
      notifyListeners();
    } catch (e) {
      throw Exception('Failed to fetch senseBoxes');
    }
  }

  void setSelectedSenseBox(SenseBox senseBox) {
    final prefs = SharedPreferences.getInstance();
    prefs.then((prefs) =>
        prefs.setString('selectedSenseBox', jsonEncode(senseBox.toJson())));
  }

  Future<SenseBox> getSelectedSenseBox() async {
    final prefs = SharedPreferences.getInstance();
    final selectedSenseBoxJson = prefs.then((prefs) =>
        prefs.getString('selectedSenseBox') ?? jsonEncode(<String, dynamic>{}));
    return selectedSenseBoxJson
        .then((json) => SenseBox.fromJson(jsonDecode(json)));
  }

  Future<void> uploadLiveData(Map<String, dynamic> data) async {
    final senseBox = await getSelectedSenseBox();
    if (senseBox.id == null) {
      throw Exception('No senseBox selected');
    }
    await _service.uploadData(senseBox.id, data);
  }
}
