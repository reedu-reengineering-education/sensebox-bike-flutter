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
  final ValueNotifier<bool> _isAuthenticatingNotifier =
      ValueNotifier<bool>(false);
  ValueNotifier<bool> get isAuthenticatingNotifier => _isAuthenticatingNotifier;
  bool get isAuthenticating => _isAuthenticatingNotifier.value;
  
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
  
  /// Mark authentication as failed and notify listeners
  /// This allows external services to update the authentication state
  Future<void> markAuthenticationFailed() async {
    _isAuthenticated = false;
    _selectedSenseBox = null;
    _senseBoxController.add(null);
    _senseBoxes.clear();
    await _service.removeTokens();

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('selectedSenseBox');

    notifyListeners();
  }
  
  List<dynamic> get senseBoxes => _senseBoxes.values.expand((e) => e).toList();

  Future<Map<String, dynamic>?> getUserData() async {
    try {
      return await _service.getUserData();
    } catch (e) {
      // Handle authentication exceptions gracefully
      if (e.toString().contains('Not authenticated')) {
        _isAuthenticated = false;
        notifyListeners();
      }
      return null;
    }
  }

  OpenSenseMapBloc() {
    _initializeAuth();
  }

  Future<void> _initializeAuth() async {
    _isAuthenticatingNotifier.value = true;
    try {
      // First check if we have any stored tokens
      final token = await _service.getAccessToken();
      if (token == null) {
        // No tokens stored - definitely not authenticated
        _isAuthenticated = false;
        notifyListeners();
        return;
      }

      // We have a token, but need to validate it with the API
      // Try to get user data to verify the token actually works
      final userData = await _service.getUserData();
      if (userData != null) {
        // Token is valid and API call succeeded
        _isAuthenticated = true;
        notifyListeners();
        await loadSelectedSenseBox();
      } else {
        // Token exists but API call failed - try to refresh
        try {
          await _service.refreshToken();
          // Verify refresh worked by getting user data again
          final refreshedUserData = await _service.getUserData();
          if (refreshedUserData != null) {
            _isAuthenticated = true;
            notifyListeners();
            await loadSelectedSenseBox();
          } else {
            // Refresh failed - not authenticated
            _isAuthenticated = false;
            notifyListeners();
          }
        } catch (refreshError) {
          // Refresh failed - not authenticated
          _isAuthenticated = false;
          notifyListeners();
        }
      }
    } catch (e) {
      // Any other error - not authenticated
      _isAuthenticated = false;
      notifyListeners();
    } finally {
      _isAuthenticatingNotifier.value = false;
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

  /// Explicitly validate current authentication state with API call
  Future<bool> validateAuthenticationState() async {
    try {
      final userData = await _service.getUserData();
      final isValid = userData != null;

      if (_isAuthenticated != isValid) {
        _isAuthenticated = isValid;
        notifyListeners();
      }

      return isValid;
    } catch (e) {
      if (_isAuthenticated) {
        _isAuthenticated = false;
        notifyListeners();
      }
      return false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.resumed) {
      try {
        // Use the same validation logic as _initializeAuth
        final token = await _service.getAccessToken();
        if (token == null) {
          _isAuthenticated = false;
          notifyListeners();
          return;
        }

        // Validate token with API call
        final userData = await _service.getUserData();
        if (userData != null) {
          _isAuthenticated = true;
          if (_selectedSenseBox == null) {
            await loadSelectedSenseBox();
          }
        } else {
          // Token invalid - try refresh
          try {
            await _service.refreshToken();
            final refreshedUserData = await _service.getUserData();
            if (refreshedUserData != null) {
              _isAuthenticated = true;
              if (_selectedSenseBox == null) {
                await loadSelectedSenseBox();
              }
            } else {
              _isAuthenticated = false;
            }
          } catch (refreshError) {
            _isAuthenticated = false;
          }
        }
      } catch (_) {
        _isAuthenticated = false;
      } finally {
        notifyListeners();
      }
    }
  }

  Future<void> register(String name, String email, String password) async {
    _isAuthenticatingNotifier.value = true;
    try {
      await _service.register(name, email, password);
      _isAuthenticated = true;
      _senseBoxes.clear();
      _selectedSenseBox = null;
      _senseBoxController.add(null);
      notifyListeners();
    } catch (e) {
      _isAuthenticated = false;
      rethrow;
    } finally {
      _isAuthenticatingNotifier.value = false;
      notifyListeners();
    }
  }

  Future<void> login(String email, String password) async {
    _isAuthenticatingNotifier.value = true;
    try {
      await _service.login(email, password);
      _isAuthenticated = true;
      notifyListeners();

      final senseBoxes = await fetchSenseBoxes(page: 0);

      if (senseBoxes.isNotEmpty) {
        await setSelectedSenseBox(SenseBox.fromJson(senseBoxes.first));
      }
    } catch (e) {
      _isAuthenticated = false;
      rethrow;
    } finally {
      _isAuthenticatingNotifier.value = false;
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
      // Handle authentication exceptions gracefully
      if (e.toString().contains('Not authenticated')) {
        _isAuthenticated = false;
        notifyListeners();
      } else {
        ErrorService.handleError(e, stack);
      }
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
    } catch (e) {
      // Handle authentication exceptions gracefully
      if (e.toString().contains('Not authenticated')) {
        _isAuthenticated = false;
        notifyListeners();
      }
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
    _senseBoxController.close();
    _isAuthenticatingNotifier.dispose();
    super.dispose();
  }
}
