import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:sensebox_bike/constants.dart';
import 'package:sensebox_bike/models/box_configuration.dart';
import 'package:sensebox_bike/models/sensebox.dart';
import 'package:sensebox_bike/services/error_service.dart';
import 'package:sensebox_bike/services/opensensemap_service.dart';
import 'package:sensebox_bike/utils/opensensemap_utils.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sensebox_bike/blocs/settings_bloc.dart';

class OpenSenseMapBloc with ChangeNotifier, WidgetsBindingObserver {
  final OpenSenseMapService _service;
  StreamSubscription<String>? _apiUrlChangedSubscription;
  bool _isAuthenticated = false;
  final ValueNotifier<bool> _isAuthenticatingNotifier =
      ValueNotifier<bool>(false);
  ValueNotifier<bool> get isAuthenticatingNotifier => _isAuthenticatingNotifier;
  bool get isAuthenticating => _isAuthenticatingNotifier.value;

  final Map<int, List<dynamic>> _senseBoxes = {};
  final _senseBoxController = StreamController<SenseBox?>.broadcast();
  Stream<SenseBox?> get senseBoxStream => _senseBoxController.stream;

  SenseBox? _selectedSenseBox;
  SenseBox? get selectedSenseBox => _selectedSenseBox;
  bool get isAuthenticated => _isAuthenticated;
  bool get hasAuthAndSelectedSenseBox =>
      _isAuthenticated && _selectedSenseBox != null;

  Future<Map<String, dynamic>?> get userData => _service.getUserData();

  OpenSenseMapService get openSenseMapService => _service;

  List<dynamic> get senseBoxes => _senseBoxes.values.expand((e) => e).toList();

  OpenSenseMapBloc({
    SettingsBloc? settingsBloc,
    OpenSenseMapService? service,
  }) : _service = service ?? OpenSenseMapService(settingsBloc: settingsBloc) {
    WidgetsBinding.instance.addObserver(this);
    _apiUrlChangedSubscription =
        settingsBloc?.apiUrlChangedStream.listen((_) => logout());
  }

  Future<void> _whileAuthenticating(Future<void> Function() action) async {
    _isAuthenticatingNotifier.value = true;
    notifyListeners();
    try {
      await action();
    } finally {
      _isAuthenticatingNotifier.value = false;
      notifyListeners();
    }
  }

  Future<void> performAuthenticationCheck() => _whileAuthenticating(() async {
        try {
          if (!await _service.isCurrentAccessTokenValid()) {
            final refreshToken =
                await _service.getRefreshTokenFromPreferences();
            if (refreshToken == null ||
                refreshToken.isEmpty ||
                _service.isPermanentlyDisabled) {
              _isAuthenticated = false;
              return;
            }
            await _service.refreshToken();
          }
          _isAuthenticated = true;
          await _restoreSelectedSenseBox();
        } catch (e) {
          _handleAuthenticationError(e);
        }
      });

  Future<void> _restoreSelectedSenseBox() async {
    final prefs = await SharedPreferences.getInstance();
    final savedJson = prefs.getString(SharedPreferencesKeys.selectedSenseBox);
    if (savedJson == null) {
      return _selectFirstBox();
    }
    final savedSenseBox = SenseBox.fromJson(jsonDecode(savedJson));
    if (savedSenseBox.id != _selectedSenseBox?.id) {
      _selectedSenseBox = savedSenseBox;
      _senseBoxController.add(savedSenseBox);
    }
  }

  Future<void> _selectFirstBox() async {
    final boxes = await fetchSenseBoxes(page: 0);
    if (boxes.isNotEmpty) {
      await setSelectedSenseBox(SenseBox.fromJson(boxes.first));
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      performAuthenticationCheck();
    }
  }

  Future<void> register(String name, String email, String password) =>
      _authenticate(() => _service.register(name, email, password));

  Future<void> login(String email, String password) =>
      _authenticate(() => _service.login(email, password));

  Future<void> _authenticate(
          Future<Map<String, dynamic>> Function() request) =>
      _whileAuthenticating(() async {
        try {
          await _service.removeTokens();
          final responseData = await request();
          _isAuthenticated = true;
          await _clearSenseBoxes();
          if (extractBoxIds(responseData).isNotEmpty) {
            await _selectFirstBox();
          }
        } catch (e) {
          _isAuthenticated = false;
          rethrow;
        }
      });

  Future<void> logout() => _whileAuthenticating(() async {
        try {
          await _service.logout();
          _isAuthenticated = false;
          await _clearSenseBoxes();
        } catch (e, stack) {
          ErrorService.handleError(e, stack);
        }
      });

  Future<void> createSenseBoxBike(
      String name,
      double longitude,
      double latitude,
      BoxConfiguration boxConfiguration,
      String? selectedTag,
      List<String?> additionalTags) async {
    try {
      await _service.createSenseBoxBike(buildSenseBoxBikeModel(name, longitude,
          latitude, boxConfiguration, selectedTag, additionalTags));
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
    final grouptags = {
      'bike',
      boxConfiguration.defaultGrouptag,
      if (selectedTag != null && selectedTag.isNotEmpty) selectedTag,
      ...additionalTags.whereType<String>(),
    }.toList();

    return {
      'name': name,
      'exposure': 'mobile',
      'location': [longitude, latitude], // opensensemap expects [lon, lat]: https://docs.opensensemap.org/#api-Boxes-postNewBox
      'grouptag': grouptags,
      'sensors': boxConfiguration.sensorsAsMap,
    };
  }

  Future<List> fetchSenseBoxes({int page = 0}) async {
    try {
      final myBoxes = await _service.getSenseBoxes(page: page);
      _senseBoxes[page] = myBoxes;
      notifyListeners();
      return myBoxes;
    } catch (e) {
      _handleAuthenticationError(e);
      return [];
    }
  }

  Future<void> _clearSenseBoxes() async {
    _senseBoxes.clear();
    await setSelectedSenseBox(null);
  }

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

    _senseBoxController.add(null);
    if (senseBox == null) {
      await prefs.remove(SharedPreferencesKeys.selectedSenseBox);
    } else {
      await prefs.setString(
          SharedPreferencesKeys.selectedSenseBox, jsonEncode(senseBox.toJson()));
      _senseBoxController.add(senseBox);
    }
    _selectedSenseBox = senseBox;
    notifyListeners();
  }

  Future<void> uploadData(
    SenseBox senseBox,
    Map<String, dynamic> data,
  ) async {
    try {
      await _service.uploadData(senseBox, data);
      _isAuthenticated = true;
      notifyListeners();
    } catch (e) {
      _handleAuthenticationError(e);
      rethrow;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _apiUrlChangedSubscription?.cancel();
    _senseBoxController.close();
    _isAuthenticatingNotifier.dispose();
    super.dispose();
  }
}
