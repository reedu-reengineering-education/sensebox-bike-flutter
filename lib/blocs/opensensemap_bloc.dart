import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:sensebox_bike/models/sensebox.dart';
import 'package:sensebox_bike/services/error_service.dart';
import 'package:sensebox_bike/services/opensensemap_service.dart';
import 'package:sensebox_bike/utils/opensensemap_utils.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Add for StreamController

class OpenSenseMapBloc with ChangeNotifier, WidgetsBindingObserver {
  final OpenSenseMapService _service = OpenSenseMapService();
  bool _isAuthenticated = false;
  final ValueNotifier<bool> _isAuthenticatingNotifier =
      ValueNotifier<bool>(false);
  ValueNotifier<bool> get isAuthenticatingNotifier => _isAuthenticatingNotifier;
  bool get isAuthenticating => _isAuthenticatingNotifier.value;

  final Map<int, List<dynamic>> _senseBoxes = {};
  final _senseBoxController =
      StreamController<SenseBox?>.broadcast(); // StreamController
  Stream<SenseBox?> get senseBoxStream =>
      _senseBoxController.stream; // Expose stream

  SenseBox? _selectedSenseBox;
  SenseBox? get selectedSenseBox => _selectedSenseBox;
  bool get isAuthenticated => _isAuthenticated;
  
  Future<Map<String, dynamic>?> get userData => _service.getUserData();

  OpenSenseMapService get openSenseMapService => _service;
  
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
      _handleAuthenticationError(e);
      return null;
    }
  }

  OpenSenseMapBloc() {
    WidgetsBinding.instance.addObserver(this);
  }

  /// Core authentication logic that can be reused
  Future<void> performAuthenticationCheck() async {
    _isAuthenticatingNotifier.value = true;
    notifyListeners();
    
    try {
      // First, check if we have a valid access token
      final isTokenValid = await _service.isCurrentAccessTokenValid();
      if (isTokenValid) {
        // We have a valid token, no need to refresh
        _isAuthenticated = true;
        await loadSelectedSenseBox();
        notifyListeners();
        return;
      }

      // No valid access token, check if we have a refresh token
      final refreshToken = await _service.getRefreshTokenFromPreferences();
      if (refreshToken == null || refreshToken.isEmpty) {
        // No refresh token exists, nothing to refresh
        _isAuthenticated = false;
        notifyListeners();
        return;
      }

      // If service is permanently disabled, don't attempt refresh
      if (_service.isPermanentlyDisabled) {
        _isAuthenticated = false;
        notifyListeners();
        return;
      }

      // Attempt token refresh directly
      final tokens = await _service.refreshToken();
      final refreshSuccess = tokens != null;

      if (refreshSuccess) {
        _isAuthenticated = true;
        if (_service.isPermanentlyDisabled) {
          _service.resetPermanentDisable();
        }
        await loadSelectedSenseBox();
      } else {
        _isAuthenticated = false;
      }
    } catch (e) {
      _handleAuthenticationError(e);
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
      _senseBoxController.add(null);
      _selectedSenseBox = null;
    } else {
      final newSenseBox = SenseBox.fromJson(jsonDecode(selectedSenseBoxJson));

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
      await performAuthenticationCheck();
    }
  }

  Future<void> register(String name, String email, String password) async {
    _isAuthenticatingNotifier.value = true;
    notifyListeners();
    try {
      // Clear any existing tokens before fresh registration
      await _service.removeTokens();
      
      // Get the full response data from registration
      final responseData = await _service.register(name, email, password);
      
      _isAuthenticated = true;
      _senseBoxes.clear();
      _selectedSenseBox = null;
      _senseBoxController.add(null);
      
      // User data is already saved by service.saveUserData()

      // Only fetch boxes if there are box IDs in the response
      final boxIds = extractBoxIds(responseData);
      if (boxIds.isNotEmpty) {
        final senseBoxes = await fetchSenseBoxes(page: 0);
        if (senseBoxes.isNotEmpty) {
          await setSelectedSenseBox(SenseBox.fromJson(senseBoxes.first));
        }
      }

      notifyListeners();
    } catch (e) {
      _isAuthenticated = false;
      notifyListeners();
      rethrow;
    } finally {
      _isAuthenticatingNotifier.value = false;
      notifyListeners();
    }
  }

  Future<void> login(String email, String password) async {
    _isAuthenticatingNotifier.value = true;
    notifyListeners();
    try {
      // Clear any existing tokens before fresh login
      await _service.removeTokens();
      
      // Get the full response data from login
      final responseData = await _service.login(email, password);
      
      _isAuthenticated = true;

      // User data is already saved by service.saveUserData()

      // Only fetch boxes if there are box IDs in the response
      final boxIds = extractBoxIds(responseData);
      if (boxIds.isNotEmpty) {
        final senseBoxes = await fetchSenseBoxes(page: 0);
        if (senseBoxes.isNotEmpty) {
          await setSelectedSenseBox(SenseBox.fromJson(senseBoxes.first));
        }
      } else {
        // No boxes in response, clear existing boxes
        _senseBoxes.clear();
        _selectedSenseBox = null;
        _senseBoxController.add(null);
      }

      // Notify listeners after all data processing is complete
      notifyListeners();
    } catch (e) {
      _isAuthenticated = false;
      notifyListeners();
      rethrow;
    } finally {
      _isAuthenticatingNotifier.value = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    _isAuthenticatingNotifier.value = true;
    notifyListeners();
    try {
      await _service.logout();
      _isAuthenticated = false;
      _senseBoxController.add(null);
      _selectedSenseBox = null;
      _senseBoxes.clear();
      notifyListeners();
    } catch (e, stack) {
      ErrorService.handleError(e, stack);
    } finally {
      _isAuthenticatingNotifier.value = false;
      notifyListeners();
    }
  }

  Future<void> createSenseBoxBike(
      String name,
      double latitude,
      double longitude,
      SenseBoxBikeModel model,
      String? selectedTag,
      List<String?> additionalTags) async {
    try {
      await _service.createSenseBoxBike(
          name, latitude, longitude, model, selectedTag, additionalTags);
    } catch (e, stack) {
      if (!_handleAuthenticationError(e)) {
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
      _handleAuthenticationError(e);
      return [];
    }
  }

  /// Helper method to check if an error is authentication-related and handle it
  bool _handleAuthenticationError(dynamic error) {
    final errorString = error.toString();
    final isAuthError = errorString.contains('Not authenticated') ||
        errorString.contains('Authentication failed') ||
        errorString.contains('No refresh token found') ||
        errorString.contains('Refresh token is expired');

    if (isAuthError) {
      _isAuthenticated = false;
      notifyListeners();
      return true;
    }
    return false;
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

  Future<void> uploadData(String senseBoxId, Map<String, dynamic> data) async {
    try {
      // Let the service handle all authentication logic including token refresh
      await _service.uploadData(senseBoxId, data);

      // If we get here, upload was successful and we're authenticated
      _isAuthenticated = true;
      notifyListeners();
    } catch (e) {
      // Handle authentication failures
      _handleAuthenticationError(e);
      rethrow;
    }
  }

  @override
  void dispose() {
    // Remove observer first to prevent any further lifecycle callbacks
    WidgetsBinding.instance.removeObserver(this);

    // Close stream controller
    _senseBoxController.close();

    // Dispose value notifier
    _isAuthenticatingNotifier.dispose();

    // Clear all data structures
    _senseBoxes.clear();
    _selectedSenseBox = null;

    // Call super dispose last
    super.dispose();
  }
}
