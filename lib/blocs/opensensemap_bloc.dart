import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:sensebox_bike/models/sensebox.dart';
import 'package:sensebox_bike/services/opensensemap_service.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Add for StreamController

class OpenSenseMapBloc with ChangeNotifier, WidgetsBindingObserver {
  final OpenSenseMapService _service = OpenSenseMapService();
  bool _isAuthenticated = false;

  // make senseboxes a key value store. key is the page number, value is the list of senseboxes
  final Map<int, List<dynamic>> _senseBoxes = {};

  final _senseBoxController =
      StreamController<SenseBox?>.broadcast(); // StreamController

  Stream<SenseBox?> get senseBoxStream =>
      _senseBoxController.stream; // Expose stream

  // get selected sensebox
  SenseBox? _selectedSenseBox;

  SenseBox? get selectedSenseBox => _selectedSenseBox;

  bool get isAuthenticated => _isAuthenticated;
  List<dynamic> get senseBoxes => _senseBoxes.values.expand((e) => e).toList();

  OpenSenseMapBloc() {
    _initializeAuth();
  }

  Future<void> _initializeAuth() async {
    try {
      await _service.refreshToken();
      _isAuthenticated = true;
    } catch (_) {
      _isAuthenticated = false;
    } finally {
      notifyListeners();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.resumed) {
      try {
        await _service.refreshToken();
        _isAuthenticated = true;
        await loadSelectedSenseBox();
      } catch (_) {
        _isAuthenticated = false;
      } finally {
        notifyListeners();
      }
    }
  }

  Future<void> register(String name, String email, String password) async {
    try {
      await _service.register(name, email, password);
      _isAuthenticated = true;
    } catch (e) {
      _isAuthenticated = false;
      rethrow;
    } finally {
      notifyListeners();
    }
  }

  Future<void> login(String email, String password) async {
    try {
      await _service.login(email, password);
      _isAuthenticated = true;
    } catch (e) {
      _isAuthenticated = false;
      rethrow;
    } finally {
      notifyListeners();
    }
  }

  Future<void> logout() async {
    await _service.logout();
    _isAuthenticated = false;
    _senseBoxController.add(null); // Clear senseBox on logout
    _selectedSenseBox = null;
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

  bool isSenseBoxBikeCompatible(SenseBox sensebox) {
    // check the sensor names if they are compatible with the SenseBoxBike
    final validSensorNames = _service.sensors.values
        .expand((sensorList) => sensorList.map((sensor) => sensor['title']))
        .toSet()
        .toList();

    for (var sensor in sensebox.sensors!) {
      if (!validSensorNames.contains(sensor.title)) {
        return false;
      }
    }
    return true;
  }

  Future<List> fetchSenseBoxes({int page = 0}) async {
    try {
      var myBoxes = await _service.getSenseBoxes(page: page);
      _senseBoxes[page] = myBoxes;
      notifyListeners();
      return myBoxes;
    } catch (e) {
      throw Exception('Failed to fetch senseBoxes');
    }
  }

  Future<void> setSelectedSenseBox(SenseBox senseBox) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      prefs.setString('selectedSenseBox', jsonEncode(senseBox.toJson()));
      _senseBoxController.add(senseBox); // Push selected senseBox to the stream
      _selectedSenseBox = senseBox;
      notifyListeners();
    } catch (_) {
      throw Exception('Failed to set senseBox');
    }
  }

  Future<void> loadSelectedSenseBox() async {
    final prefs = await SharedPreferences.getInstance();

    if (!_isAuthenticated) {
      await prefs.remove('selectedSenseBox');
      _senseBoxController.add(null);
      _selectedSenseBox = null;
      notifyListeners();
      return;
    }

    final selectedSenseBoxJson = prefs.getString('selectedSenseBox');

    if (selectedSenseBoxJson == null) {
      _senseBoxController.add(null); // Push null if no senseBox is selected
      _selectedSenseBox = null;
    } else {
      _senseBoxController.add(SenseBox.fromJson(jsonDecode(
          selectedSenseBoxJson))); // Push selected senseBox to the stream

      _selectedSenseBox = SenseBox.fromJson(jsonDecode(selectedSenseBoxJson));
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _senseBoxController.close(); // Close the stream when done
    super.dispose();
  }
}
