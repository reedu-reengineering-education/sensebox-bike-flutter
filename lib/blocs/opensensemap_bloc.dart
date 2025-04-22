import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:sensebox_bike/models/sensebox.dart';
import 'package:sensebox_bike/services/error_service.dart';
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
      notifyListeners();
      await loadSelectedSenseBox();
    } catch (_) {
      _isAuthenticated = false;
      notifyListeners();
    }
  }

  Future<void> loadSelectedSenseBox() async {
    final prefs = await SharedPreferences.getInstance();

    if (!_isAuthenticated) {
      await prefs.remove('selectedSenseBox');
      _senseBoxController.add(null);
      _selectedSenseBox = null;

      return;
    }

    final selectedSenseBoxJson = prefs.getString('selectedSenseBox');

    if (selectedSenseBoxJson == null) {
      _senseBoxController.add(null); // Push null if no senseBox is selected
      _selectedSenseBox = null;
    } else {
      final newSenseBox = SenseBox.fromJson(jsonDecode(selectedSenseBoxJson));

      // Avoid creating duplicate instances
      if (_selectedSenseBox?.id != newSenseBox.id) {
        _senseBoxController.add(newSenseBox);
        _selectedSenseBox = newSenseBox;
      }
    }
    notifyListeners();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.resumed) {
      try {
        await _service.refreshToken();
        _isAuthenticated = true;
        
        // Avoid creating duplicate SenseBoxes by checking current state
        if (_selectedSenseBox == null) {
          await loadSelectedSenseBox();
        }
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
      notifyListeners();
    } catch (e, stack) {
      _isAuthenticated = false;
      ErrorService.handleError(e, stack);
    } finally {
      notifyListeners();
    }
  }

  Future<void> login(String email, String password) async {
    try {
      await _service.login(email, password);
      _isAuthenticated = true;
      notifyListeners();

      // Fetch the first page of sense boxes
      final senseBoxes = await fetchSenseBoxes(page: 0);

      // If there are sense boxes, set the first one as the selected box
      if (senseBoxes.isNotEmpty) {
        await setSelectedSenseBox(SenseBox.fromJson(senseBoxes.first));
      }
    } catch (e, stack) {
      _isAuthenticated = false;
      ErrorService.handleError(e, stack);
    } finally {
      notifyListeners();
    }
  }

  Future<void> logout() async {
    try {
      await _service.logout();
      _isAuthenticated = false;
      _senseBoxController.add(null); // Clear senseBox on logout
      _selectedSenseBox = null;
      notifyListeners();
    } catch (e, stack) {
      ErrorService.handleError(e, stack);
    }
  }

  Future<void> createSenseBoxBike(String name, double latitude,
      double longitude, SenseBoxBikeModel model, String? selectedTag) async {
    try {
      await _service.createSenseBoxBike(
          name, latitude, longitude, model, selectedTag);
    } catch (e, stack) {
      ErrorService.handleError(e, stack);
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
      final myBoxes = await _service.getSenseBoxes(page: page);
      _senseBoxes[page] = myBoxes;
      notifyListeners();
      return myBoxes;
    } catch (_) {
      return [];
    }
  }

  Future<void> setSelectedSenseBox(SenseBox? senseBox) async {
    final prefs = await SharedPreferences.getInstance();

    // Clear previous data before adding new senseBox
    _senseBoxController.add(null);
    if (senseBox == null) {
      await prefs.remove('selectedSenseBox');
      _selectedSenseBox = null;
      notifyListeners();
      return;
    } 

    await prefs.setString('selectedSenseBox', jsonEncode(senseBox.toJson()));
    _senseBoxController.add(senseBox); // Push selected senseBox to the stream
    _selectedSenseBox = senseBox;
    notifyListeners();
  }

  @override
  void dispose() {
    _senseBoxController.close(); // Close the stream when done
    super.dispose();
  }
}
