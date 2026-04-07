import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sensebox_bike/blocs/configuration_bloc.dart';
import 'package:sensebox_bike/models/box_configuration.dart';
import 'package:sensebox_bike/models/sensebox.dart';
import 'package:sensebox_bike/services/error_service.dart';
import 'package:sensebox_bike/services/opensensemap_auth_service.dart';
import 'package:sensebox_bike/services/opensensemap_selection_service.dart';
import 'package:sensebox_bike/services/opensensemap_service.dart';
import 'package:sensebox_bike/services/storage/selected_sensebox_storage.dart';
import 'package:sensebox_bike/utils/opensensemap_utils.dart';

@immutable
class OpenSenseMapState {
  const OpenSenseMapState({
    required this.isAuthenticated,
    required this.isAuthenticating,
    required this.selectedSenseBox,
    required this.senseBoxes,
  });

  final bool isAuthenticated;
  final bool isAuthenticating;
  final SenseBox? selectedSenseBox;
  final List<dynamic> senseBoxes;

  OpenSenseMapState copyWith({
    bool? isAuthenticated,
    bool? isAuthenticating,
    SenseBox? selectedSenseBox,
    List<dynamic>? senseBoxes,
  }) {
    return OpenSenseMapState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      isAuthenticating: isAuthenticating ?? this.isAuthenticating,
      selectedSenseBox: selectedSenseBox ?? this.selectedSenseBox,
      senseBoxes: senseBoxes ?? this.senseBoxes,
    );
  }
}

class OpenSenseMapBloc extends Cubit<OpenSenseMapState>
    with WidgetsBindingObserver {
  final OpenSenseMapService _service;
  final OpenSenseMapAuthService _authService;
  final OpenSenseMapSelectionService _selectionService;
  final ConfigurationBloc? _configurationBloc;
  bool _isAuthenticated = false;
  bool _isAuthenticating = false;
  bool get isAuthenticating => _isAuthenticating;

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
    await _selectionService.clearSelectedSenseBox();

    _emitState();
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
    required OpenSenseMapService service,
    required SelectedSenseBoxStorage selectedSenseBoxStorage,
  })  : _configurationBloc = configurationBloc,
        _service = service,
        _authService = OpenSenseMapAuthService(service: service),
        _selectionService = OpenSenseMapSelectionService(
          selectedSenseBoxStorage: selectedSenseBoxStorage,
        ),
        super(
          const OpenSenseMapState(
            isAuthenticated: false,
            isAuthenticating: false,
            selectedSenseBox: null,
            senseBoxes: <dynamic>[],
          ),
        ) {
    WidgetsBinding.instance.addObserver(this);
    _emitState();
  }

  OpenSenseMapState _buildState() => OpenSenseMapState(
        isAuthenticated: _isAuthenticated,
        isAuthenticating: _isAuthenticating,
        selectedSenseBox: _selectedSenseBox,
        senseBoxes: senseBoxes,
      );

  void _emitState() {
    if (!isClosed) {
      emit(_buildState());
    }
  }

  /// Core authentication logic that can be reused
  Future<void> performAuthenticationCheck() async {
    _isAuthenticating = true;
    _emitState();

    try {
      _isAuthenticated = await _authService.authenticateFromStoredTokens();
      if (_isAuthenticated) {
        await loadSelectedSenseBox();
        if (_selectedSenseBox == null) {
          await _findAndSetCompatibleReplacement();
        }
      }
    } catch (e) {
      _handleAuthenticationError(e);
    } finally {
      _isAuthenticating = false;
      _emitState();
    }
  }

  Future<void> loadSelectedSenseBox() async {
    final savedSenseBox = await _selectionService.loadSelectedSenseBox(
      isAuthenticated: _isAuthenticated,
      isCompatible: _isSenseBoxCompatible,
    );

    if (savedSenseBox == null) {
      _senseBoxController.add(null);
      _selectedSenseBox = null;
    } else {
      if (_selectedSenseBox?.id != savedSenseBox.id) {
        _senseBoxController.add(savedSenseBox);
        _selectedSenseBox = savedSenseBox;
      }
    }
    _emitState();
  }

  Future<void> _findAndSetCompatibleReplacement() async {
    final senseBoxesJson = await fetchSenseBoxes(page: 0);
    if (senseBoxesJson.isNotEmpty) {
      final senseBoxes =
          _selectionService.convertJsonToSenseBoxes(senseBoxesJson);
      final compatibleBox = _selectionService.findFirstCompatibleBox(
        senseBoxes,
        isCompatible: _isSenseBoxCompatible,
      );
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
    _isAuthenticating = true;
    _emitState();
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

      _emitState();
    } catch (e) {
      _isAuthenticated = false;
      _emitState();
      rethrow;
    } finally {
      _isAuthenticating = false;
      _emitState();
    }
  }

  Future<void> login(String email, String password) async {
    _isAuthenticating = true;
    _emitState();
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
          final senseBoxes =
              _selectionService.convertJsonToSenseBoxes(senseBoxesJson);
          final compatibleBox = _selectionService.findFirstCompatibleBox(
            senseBoxes,
            isCompatible: _isSenseBoxCompatible,
          );
          if (compatibleBox != null) {
            await setSelectedSenseBox(compatibleBox);
          }
        }
      } else {
        _clearSenseBoxes();
      }

      // Notify listeners after all data processing is complete
      _emitState();
    } catch (e) {
      _isAuthenticated = false;
      _emitState();
      rethrow;
    } finally {
      _isAuthenticating = false;
      _emitState();
    }
  }

  Future<void> logout() async {
    _isAuthenticating = true;
    _emitState();
    try {
      await _service.logout();
      _isAuthenticated = false;
      _clearSenseBoxes();
      _emitState();
    } catch (e, stack) {
      ErrorService.handleError(e, stack);
    } finally {
      _isAuthenticating = false;
      _emitState();
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
      'location': [
        longitude,
        latitude
      ], // opensensemap expects [lon, lat]: https://docs.opensensemap.org/#api-Boxes-postNewBox
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
      _emitState();
      return myBoxes;
    } catch (e) {
      // Handle authentication exceptions gracefully
      _handleAuthenticationError(e);
      return [];
    }
  }

  void _clearSenseBoxes() {
    _senseBoxes.clear();
    _selectedSenseBox = null;
    _senseBoxController.add(null);
  }

  bool _isSenseBoxCompatible(SenseBox senseBox) {
    final configurationBloc = _configurationBloc;
    if (configurationBloc == null) {
      return true;
    }
    return configurationBloc.isSenseBoxBikeCompatible(senseBox);
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
      _emitState();
      return true;
    }
    return false;
  }

  Future<void> setSelectedSenseBox(SenseBox? senseBox) async {
    // Clear previous data before adding new senseBox
    _senseBoxController.add(null);
    if (senseBox == null) {
      await _selectionService.clearSelectedSenseBox();
      _selectedSenseBox = null;
      _emitState();
      return;
    }

    await _selectionService.saveSelectedSenseBox(senseBox);
    _senseBoxController.add(senseBox); // Push selected senseBox to the stream
    _selectedSenseBox = senseBox;
    _emitState();
  }

  Future<void> uploadData(String senseBoxId, Map<String, dynamic> data) async {
    try {
      // Let the service handle all authentication logic including token refresh
      await _service.uploadData(senseBoxId, data);

      // If we get here, upload was successful and we're authenticated
      _isAuthenticated = true;
      _emitState();
    } catch (e) {
      // Handle authentication failures
      _handleAuthenticationError(e);
      rethrow;
    }
  }

  @override
  Future<void> close() async {
    // Remove observer first to prevent any further lifecycle callbacks
    WidgetsBinding.instance.removeObserver(this);

    // Close stream controller
    await _senseBoxController.close();

    // Clear all data structures
    _senseBoxes.clear();
    _selectedSenseBox = null;

    return super.close();
  }

  void dispose() {
    unawaited(close());
  }
}
