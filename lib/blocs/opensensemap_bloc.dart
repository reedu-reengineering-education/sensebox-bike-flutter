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
    // Register as observer to handle app lifecycle events
    WidgetsBinding.instance.addObserver(this);
    _initializeAuth();
  }

  Future<bool> _attemptTokenRefresh() async {
    try {
      debugPrint('[OpenSenseMapBloc] Attempting token refresh...');
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

  /// Shared authentication logic used by both app start and background resume
  Future<void> _performAuthentication() async {
    try {
      // Step 1: Check if refresh token exists in SharedPreferences
      final hasStoredTokens = await _service.hasStoredTokens();
      if (!hasStoredTokens) {
        debugPrint(
            '[OpenSenseMapBloc] No refresh token found - user needs to login');
        _isAuthenticated = false;
        return;
      }
      debugPrint(
          '[OpenSenseMapBloc] Found refresh token, proceeding with authentication');

      // Step 2: Get and validate access token
      final token = await _service.getAccessToken();
      if (token != null) {
        debugPrint(
            '[OpenSenseMapBloc] Valid access token found - authentication complete');
        _isAuthenticated = true;
        await loadSelectedSenseBox();
        return;
      } else {
        debugPrint(
            '[OpenSenseMapBloc] No valid access token available - will attempt refresh');
      }

      // Step 3: Attempt token refresh
      debugPrint('[OpenSenseMapBloc] Attempting token refresh...');
      final refreshSuccess = await _attemptTokenRefresh();

      if (refreshSuccess) {
        // Step 4: Token refresh successful - we're authenticated!
        debugPrint(
            '[OpenSenseMapBloc] Token refresh successful - authentication complete');
        _isAuthenticated = true;
        await loadSelectedSenseBox();
        return;
      } else {
        debugPrint('[OpenSenseMapBloc] Token refresh failed');
      }

      // Step 5: All attempts failed
      debugPrint('[OpenSenseMapBloc] All authentication attempts failed');
      _isAuthenticated = false;
      
    } catch (e) {
      debugPrint('[OpenSenseMapBloc] Authentication failed: $e');
      _isAuthenticated = false;
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
        // First, try a force refresh if the service was previously disabled
        // This handles cases where the app was backgrounded during auth issues
        if (_service.isPermanentlyDisabled) {
          debugPrint(
              '[OpenSenseMapBloc] Service was disabled, attempting force refresh...');
          final refreshSuccess = await _service.forceTokenRefresh();
          if (refreshSuccess) {
            _service.resetPermanentDisable();
            debugPrint(
                '[OpenSenseMapBloc] Force refresh succeeded, service re-enabled');
          }
        }

        // Use the shared authentication logic
        await _performAuthentication();
        
      } catch (e) {
        debugPrint('[OpenSenseMapBloc] Background auth check failed: $e');
        // Only set to unauthenticated if it's clearly an auth-related error
        if (e.toString().contains('Not authenticated') ||
            e.toString().contains('Authentication failed') ||
            e.toString().contains('No refresh token found') ||
            e.toString().contains('Refresh token is expired')) {
          _isAuthenticated = false;
        }
        // For other errors (network, etc.), keep current state
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
      _senseBoxes.clear(); // Clear cached senseboxes
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
