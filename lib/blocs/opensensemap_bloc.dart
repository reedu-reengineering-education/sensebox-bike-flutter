import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:sensebox_bike/blocs/configuration_bloc.dart';
import 'package:sensebox_bike/models/box_configuration.dart';
import 'package:sensebox_bike/models/sensebox.dart';
import 'package:sensebox_bike/services/error_service.dart';
import 'package:sensebox_bike/services/opensensemap_service.dart';
import 'package:sensebox_bike/utils/opensensemap_utils.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Add for StreamController

class OpenSenseMapBloc with ChangeNotifier, WidgetsBindingObserver {
  final OpenSenseMapService _service;
  final ConfigurationBloc? _configurationBloc;
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
  bool get hasAuthAndSelectedSenseBox =>
      _isAuthenticated && _selectedSenseBox != null;
  
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

  OpenSenseMapBloc({
    ConfigurationBloc? configurationBloc,
    OpenSenseMapService? service,
  })  : _configurationBloc = configurationBloc,
        _service = service ?? OpenSenseMapService() {
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
        _isAuthenticated = true;
        await loadSelectedSenseBox();
        if (_selectedSenseBox == null) {
          await _findAndSetCompatibleReplacement();
        }
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
        if (_selectedSenseBox == null) {
          await _findAndSetCompatibleReplacement();
        }
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
      notifyListeners();
      return;
    }

    final selectedSenseBoxJson = prefs.getString('selectedSenseBox');

    if (selectedSenseBoxJson == null) {
      _senseBoxController.add(null);
      _selectedSenseBox = null;
    } else {
      final savedSenseBox = SenseBox.fromJson(jsonDecode(selectedSenseBoxJson));

      final configurationBloc = _configurationBloc;
      final isCompatible = configurationBloc == null ||
          configurationBloc.isSenseBoxBikeCompatible(savedSenseBox);

      if (isCompatible) {
        if (_selectedSenseBox?.id != savedSenseBox.id) {
          _senseBoxController.add(savedSenseBox);
          _selectedSenseBox = savedSenseBox;
        }
      } else {
        await prefs.remove('selectedSenseBox');
        _senseBoxController.add(null);
        _selectedSenseBox = null;
      }
    }
    notifyListeners();
  }

  Future<void> _findAndSetCompatibleReplacement() async {
    final senseBoxesJson = await fetchSenseBoxes(page: 0);
    if (senseBoxesJson.isNotEmpty) {
      final senseBoxes = _convertJsonToSenseBoxes(senseBoxesJson);
      final compatibleBox = _findFirstCompatibleBox(senseBoxes);
      if (compatibleBox != null) {
        await setSelectedSenseBox(compatibleBox);
      }
    }
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
      _clearSenseBoxes();
      
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

      final boxIds = extractBoxIds(responseData);
      if (boxIds.isNotEmpty) {
        final senseBoxesJson = await fetchSenseBoxes(page: 0);
        if (senseBoxesJson.isNotEmpty) {
          final senseBoxes = _convertJsonToSenseBoxes(senseBoxesJson);
          final compatibleBox = _findFirstCompatibleBox(senseBoxes);
          if (compatibleBox != null) {
            await setSelectedSenseBox(compatibleBox);
          }
        }
      } else {
        _clearSenseBoxes();
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
      _clearSenseBoxes();
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
      double longitude,
      double latitude,
      BoxConfiguration boxConfiguration,
      String? selectedTag,
      List<String?> additionalTags) async {
    try {
      final model = buildSenseBoxBikeModel(
        name,
        longitude,
        latitude,
        boxConfiguration,
        selectedTag,
        additionalTags,
      );
      await _service.createSenseBoxBike(model);
      await fetchSenseBoxes(page: 0);
    } catch (e, stack) {
      if (!_handleAuthenticationError(e)) {
        ErrorService.handleError(e, stack);
      }
    }
  }

  Map<String, dynamic> buildSenseBoxBikeModel(
    String name,
    double longitude,
    double latitude,
    BoxConfiguration boxConfiguration,
    String? selectedTag,
    List<String?> additionalTags,
  ) {
    final sensorsList = boxConfiguration.sensorsAsMap;
    final defaultGrouptag = boxConfiguration.defaultGrouptag;

    final List<String> baseGroupTags = ['bike', defaultGrouptag];

    if (selectedTag != null && selectedTag.isNotEmpty) {
      baseGroupTags.add(selectedTag);
    }

    final List<String> allTags = {
      ...baseGroupTags,
      ...additionalTags.whereType<String>(),
    }.toList();

    final baseProperties = {
      'name': name,
      'exposure': 'mobile',
      'location': [longitude, latitude], // opensensemap expects [lon, lat]: https://docs.opensensemap.org/#api-Boxes-postNewBox
      'grouptag': allTags,
    };

    return {
      ...baseProperties,
      'sensors': sensorsList,
    };
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

  List<SenseBox> _convertJsonToSenseBoxes(List<dynamic> senseBoxesJson) {
    return senseBoxesJson.map((json) => SenseBox.fromJson(json)).toList();
  }

  void _clearSenseBoxes() {
    _senseBoxes.clear();
    _selectedSenseBox = null;
    _senseBoxController.add(null);
  }

  SenseBox? _findFirstCompatibleBox(List<SenseBox> senseBoxes) {
    final configurationBloc = _configurationBloc;
    if (configurationBloc == null) {
      return senseBoxes.isNotEmpty ? senseBoxes.first : null;
    }

    for (final senseBox in senseBoxes) {
      if (configurationBloc.isSenseBoxBikeCompatible(senseBox)) {
        return senseBox;
      }
    }
    return null;
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
