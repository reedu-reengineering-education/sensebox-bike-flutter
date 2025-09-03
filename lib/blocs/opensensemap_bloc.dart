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

  final Map<int, List<dynamic>> _senseBoxes = {};
  final _senseBoxController =
      StreamController<SenseBox?>.broadcast(); // StreamController
  Stream<SenseBox?> get senseBoxStream =>
      _senseBoxController.stream; // Expose stream

  SenseBox? _selectedSenseBox;
  SenseBox? get selectedSenseBox => _selectedSenseBox;
  bool get isAuthenticated => _isAuthenticated;

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
    _initializeAuth();
  }

  Future<bool> _attemptTokenRefresh() async {
    try {
      final tokens = await _service.refreshToken();
      if (tokens != null) {
        return true;
      } else {
        return false;
      }
    } catch (e) {
      return false;
    }
  }

  Future<void> _performAuthentication() async {
    try {
      // Step 1: Check if refresh token exists in SharedPreferences
      final refreshToken = await _service.getRefreshTokenFromPreferences();
      if (refreshToken == null || refreshToken.isEmpty) {
        _isAuthenticated = false;
        notifyListeners();
        return;
      }
      // Step 2: Get and validate access token
      final token = await _service.getAccessToken();
      if (token != null) {
        _isAuthenticated = true;
        await loadSelectedSenseBox();
        notifyListeners();
        return;
      }
      // Step 3: Only attempt token refresh if we have a valid refresh token
      final refreshSuccess = await _attemptTokenRefresh();
      // Step 4: Token refresh successful - we're authenticated!
      if (refreshSuccess) {
        _isAuthenticated = true;
        await loadSelectedSenseBox();
        notifyListeners();
        return;
      }
      // Step 5: All attempts failed
      _isAuthenticated = false;
    } catch (e) {
      _isAuthenticated = false;
    } finally {
      notifyListeners();
    }
  }

  Future<void> _initializeAuth() async {
    _isAuthenticatingNotifier.value = true;
    notifyListeners();

    await _performAuthentication();
    _isAuthenticatingNotifier.value = false;
    notifyListeners();
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
      _isAuthenticatingNotifier.value = true;
      notifyListeners();
      
      try {
        if (_service.isPermanentlyDisabled) {
          final tokens = await _service.refreshToken();
          final refreshSuccess = tokens != null;
          if (refreshSuccess) {
            _service.resetPermanentDisable();
          }
        }

        await _performAuthentication();
      } catch (e) {
        _handleAuthenticationError(e);
      } finally {
        _isAuthenticatingNotifier.value = false;
        notifyListeners();
      }
    }
  }

  Future<void> register(String name, String email, String password) async {
    _isAuthenticatingNotifier.value = true;
    notifyListeners();
    try {
      // Clear any existing tokens before fresh registration
      await _service.removeTokens();
      
      await _service.register(name, email, password);
      _isAuthenticated = true;
      _senseBoxes.clear();
      _selectedSenseBox = null;
      _senseBoxController.add(null);
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
      
      await _service.login(email, password);
      _isAuthenticated = true;
      notifyListeners();

      final senseBoxes = await fetchSenseBoxes(page: 0);

      if (senseBoxes.isNotEmpty) {
        await setSelectedSenseBox(SenseBox.fromJson(senseBoxes.first));
      }
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
      // Check if we need to refresh tokens before upload
      if (!_isAuthenticated) {
        final refreshSuccess = await _attemptTokenRefresh();
        if (!refreshSuccess) {
          throw Exception('Not authenticated');
        }
      }

      // Perform the upload through the service
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
