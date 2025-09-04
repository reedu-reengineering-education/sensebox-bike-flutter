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
    debugPrint('[OpenSenseMapBloc] Attempting token refresh...');
    try {
      final tokens = await _service.refreshToken();
      if (tokens != null) {
        debugPrint('[OpenSenseMapBloc] Token refresh successful');
        return true;
      } else {
        debugPrint('[OpenSenseMapBloc] Token refresh returned null');
        return false;
      }
    } catch (e) {
      debugPrint('[OpenSenseMapBloc] Token refresh failed: $e');
      return false;
    }
  }

  Future<void> _performAuthentication() async {
    debugPrint('[OpenSenseMapBloc] Starting full authentication flow (fallback method)');
    
    try {
      // Step 1: Check if refresh token exists in SharedPreferences
      debugPrint('[OpenSenseMapBloc] Step 1: Checking for refresh token...');
      final refreshToken = await _service.getRefreshTokenFromPreferences();
      if (refreshToken == null || refreshToken.isEmpty) {
        debugPrint('[OpenSenseMapBloc] No refresh token found, authentication failed');
        _isAuthenticated = false;
        notifyListeners();
        return;
      }
      
      // Step 2: Get and validate access token
      debugPrint('[OpenSenseMapBloc] Step 2: Getting and validating access token...');
      final token = await _service.getAccessToken();
      if (token != null) {
        debugPrint('[OpenSenseMapBloc] Valid access token found, authentication successful');
        _isAuthenticated = true;
        await loadSelectedSenseBox();
        notifyListeners();
        return;
      }
      
      // Step 3: Only attempt token refresh if we have a valid refresh token
      debugPrint('[OpenSenseMapBloc] Step 3: Attempting token refresh...');
      final refreshSuccess = await _attemptTokenRefresh();
      
      // Step 4: Token refresh successful - we're authenticated!
      if (refreshSuccess) {
        debugPrint('[OpenSenseMapBloc] Token refresh successful, authentication successful');
        _isAuthenticated = true;
        await loadSelectedSenseBox();
        notifyListeners();
        return;
      }
      
      // Step 5: All attempts failed
      debugPrint('[OpenSenseMapBloc] All authentication attempts failed');
      _isAuthenticated = false;
    } catch (e) {
      debugPrint('[OpenSenseMapBloc] Authentication error: $e');
      _isAuthenticated = false;
    } finally {
      notifyListeners();
    }
  }

  Future<void> _initializeAuth() async {
    debugPrint('[OpenSenseMapBloc] Starting app initialization authentication');
    _isAuthenticatingNotifier.value = true;
    notifyListeners();

    await _performSmartAuthentication();
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

  /// Smart authentication method that checks tokens first before attempting refresh
  /// This method uses the proven logic from app resume flow
  Future<void> _performSmartAuthentication() async {
          debugPrint('[OpenSenseMapBloc] Starting smart authentication flow');
    
    try {
      // Step 1: Check if we have a valid (non-expired) access token first
      debugPrint('[OpenSenseMapBloc] Checking for valid access token...');
      final accessToken = await _service.getAccessToken();
      if (accessToken != null) {
        // We have a valid, non-expired token, no need to refresh
        debugPrint('[OpenSenseMapBloc] Valid access token found, authentication successful');
        _isAuthenticated = true;
        await loadSelectedSenseBox();
        notifyListeners();
        return;
      }

      // Step 2: No valid access token, check if we have a refresh token to attempt refresh
      debugPrint('[OpenSenseMapBloc] No valid access token, checking for refresh token...');
      final refreshToken = await _service.getRefreshTokenFromPreferences();
      if (refreshToken == null || refreshToken.isEmpty) {
        // No refresh token exists, nothing to refresh
        debugPrint('[OpenSenseMapBloc] No refresh token found, authentication failed');
        _isAuthenticated = false;
        notifyListeners();
        return;
      }


      // Step 4: Attempt token refresh
      debugPrint('[OpenSenseMapBloc] Attempting token refresh...');
      final tokens = await _service.refreshToken();
      final refreshSuccess = tokens != null;

      if (refreshSuccess) {
        debugPrint('[OpenSenseMapBloc] Token refresh successful');
        _isAuthenticated = true;
        if (_service.isPermanentlyDisabled) {
          _service.resetPermanentDisable();
        }
        await loadSelectedSenseBox();
        notifyListeners();
      } else {
        debugPrint('[OpenSenseMapBloc] Token refresh failed, falling back to full authentication');
        await _performAuthentication();
      }
    } catch (e) {
      debugPrint('[OpenSenseMapBloc] Smart authentication failed: $e');
      _handleAuthenticationError(e);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.resumed) {
      debugPrint('[OpenSenseMapBloc] App resumed, starting authentication check');
      _isAuthenticatingNotifier.value = true;
      notifyListeners();
      
      await _performSmartAuthentication();
      
      _isAuthenticatingNotifier.value = false;
      notifyListeners();
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
