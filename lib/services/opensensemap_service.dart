import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:sensebox_bike/services/custom_exceptions.dart';
import 'package:sensebox_bike/services/error_service.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:retry/retry.dart';
import 'dart:async';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';

import 'package:sensebox_bike/constants.dart';

enum SenseBoxBikeModel { classic, atrai }

class OpenSenseMapService {
  static const String _baseUrl = openSenseMapUrl;

  // The following class variables and constructor are added to allow testing
  // No refactoring of other parts of the code should be needed
  final http.Client client;
  final Future<SharedPreferences> _prefs;

  // Add rate limiting state
  bool _isRateLimited = false;
  DateTime? _rateLimitUntil;

  // Add permanent authentication failure state
  bool _isPermanentlyDisabled = false;

  // Add token caching fields
  String? _cachedAccessToken;
  DateTime? _tokenExpiration;
  bool _isRefreshingToken = false;

  OpenSenseMapService({
    http.Client? client,
    Future<SharedPreferences>? prefs,
  })  : client = client ?? http.Client(),
        _prefs = prefs ?? SharedPreferences.getInstance();

  // Add method to check if service is accepting requests
  bool get isAcceptingRequests => !_isRateLimited && !_isPermanentlyDisabled;

  // Add method to check if service is permanently disabled
  bool get isPermanentlyDisabled => _isPermanentlyDisabled;

  // Add method to get remaining rate limit time
  Duration? get remainingRateLimitTime {
    if (!_isRateLimited || _rateLimitUntil == null) return null;
    final remaining = _rateLimitUntil!.difference(DateTime.now());
    return remaining.isNegative ? null : remaining;
  }

  // Add method to reset permanent disable state (called after successful re-login)
  void resetPermanentDisable() {
    _isPermanentlyDisabled = false;
  }

  // Add method to check if service is authenticated
  bool get isAuthenticated {
    return _cachedAccessToken != null &&
        _tokenExpiration != null &&
        _isTokenValid(_cachedAccessToken!);
  }

  // Debug getters for troubleshooting
  bool get hasCachedToken => _cachedAccessToken != null;
  DateTime? get tokenExpiration => _tokenExpiration;

  Future<void> setTokens(http.Response response) async {
    final prefs = await _prefs;
    final responseData = jsonDecode(response.body);
    final String accessToken = responseData['token'];
    final String refreshToken = responseData['refreshToken'];

    await prefs.setString('accessToken', accessToken);
    await prefs.setString('refreshToken', refreshToken);

    // Update cached token with actual expiration
    _cachedAccessToken = accessToken;
    _tokenExpiration = _getTokenExpiration(accessToken);
  }

  Future<void> removeTokens() async {
    final prefs = await _prefs;

    await prefs.remove('accessToken');
    await prefs.remove('refreshToken');

    // Clear cached token
    _clearCachedToken();
  }

  Future<String?> getRefreshTokenFromPreferences() async {
    final prefs = await _prefs;

    return prefs.getString('refreshToken');
  }

  Future<void> register(String name, String email, String password) async {
    final response = await client.post(
      Uri.parse('$_baseUrl/users/register'),
      body: jsonEncode({
        'name': name,
        'email': email,
        'password': password,
      }),
      headers: {'Content-Type': 'application/json'},
    );

    if (response.statusCode != 201) {
      final errorResponse = jsonDecode(response.body);
      throw Exception(errorResponse['message']);
    }

    final responseData = jsonDecode(response.body);

    await setTokens(response);

    // Save user data from registration response
    await _saveUserData({
      'data': {
        'me': {
          'name': name,
          'email': email,
        }
      }
    });

    return responseData;
  }

  Future<void> _saveUserData(Map<String, dynamic> userData) async {
    final prefs = await _prefs;
    await prefs.setString('userData', jsonEncode(userData));
  }

  Future<Map<String, dynamic>?> _getCachedUserData() async {
    final prefs = await _prefs;
    final userDataString = prefs.getString('userData');
    if (userDataString != null) {
      try {
        return jsonDecode(userDataString);
      } catch (e) {
        // If cached data is corrupted, remove it
        await prefs.remove('userData');
      }
    }
    return null;
  }

  Future<void> _clearUserData() async {
    final prefs = await _prefs;
    await prefs.remove('userData');
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await client.post(
      Uri.parse('$_baseUrl/users/sign-in'),
      body: jsonEncode({
        'email': email,
        'password': password,
      }),
      headers: {'Content-Type': 'application/json'},
    );

    if (response.statusCode == 200) {
      final responseData = jsonDecode(response.body);

      await setTokens(response);

      // Reset permanent disable state after successful login
      resetPermanentDisable();

      // If the response contains user data, save it
      if (responseData.containsKey('user')) {
        await _saveUserData({
          'data': {'me': responseData['user']}
        });
      }

      return responseData;
    } else {
      throw Exception(json.decode(response.body)['message']);
    }
  }

  Future<void> logout() async {
    await removeTokens();
    await _clearUserData();
  }

  Future<Map<String, dynamic>?> getUserData() async {
    // First try to get cached user data
    final cachedUserData = await _getCachedUserData();
    
    // Always try to get fresh data from API to validate authentication
    try {
      final userData = await _makeAuthenticatedRequest<Map<String, dynamic>?>(
        requestFn: (accessToken) => client.get(
          Uri.parse('$_baseUrl/users/me'),
          headers: {'Authorization': 'Bearer $accessToken'},
        ),
        successHandler: (response) => jsonDecode(response.body),
        errorMessage: 'Failed to load user data',
      );

      // Cache the fresh user data
      if (userData != null) {
        await _saveUserData(userData);
        return userData;
      }
      
      // If API call failed but we have cached data, clear it and return null
      if (cachedUserData != null) {
        await _clearUserData();
      }
      return null;
    } catch (e) {
      // Clear cached data on any authentication error
      if (e.toString().contains('Not authenticated') ||
          e.toString().contains('Authentication failed') ||
          e.toString().contains('Failed to refresh token')) {
        await _clearUserData();
      }
      return null;
    }
  }

  Future<String?> getAccessToken() async {
    if (_cachedAccessToken != null && _tokenExpiration != null) {
      final isValid = _isTokenValid(_cachedAccessToken!);
      if (isValid) {
        final now = DateTime.now();
        final timeUntilExpiry = _tokenExpiration!.difference(now);

        if (timeUntilExpiry.inMinutes > 5) {
          return _cachedAccessToken;
        }

        if (timeUntilExpiry.inMinutes > 0 && !_isRefreshingToken) {
          _refreshTokenProactively();
        }
      } else {
        _clearCachedToken();
      }
    }

    final prefs = await _prefs;
    final token = prefs.getString('accessToken');

    if (token != null) {
      final isValid = _isTokenValid(token);
      if (isValid) {
        _cachedAccessToken = token;
        _tokenExpiration = _getTokenExpiration(token);
      } else {
        await prefs.remove('accessToken');
        return null;
      }
    }

    return token;
  }

  /// Decode JWT payload using dart_jsonwebtoken library
  Map<String, dynamic>? _decodeJwtPayload(String token) {
    try {
      final jwt = JWT.decode(token);
      return jwt.payload;
    } catch (e) {
      return null;
    }
  }

  /// Validate JWT token and extract expiration
  bool _isTokenValid(String token) {
    try {
      final jwt = JWT.decode(token);
      final exp = jwt.payload['exp'];
      if (exp == null) {
        return false;
      }
      final expirationTime = DateTime.fromMillisecondsSinceEpoch(exp * 1000);
      final now = DateTime.now();
      // Temporary: Code to test if token is expired
      // final fakeExpiredTime = now.subtract(Duration(hours: 1));
      // return expirationTime.isAfter(fakeExpiredTime);
      return expirationTime.isAfter(now);
    } catch (e) {
      return false;
    }
  }

  /// Extract expiration time from JWT token
  DateTime? _getTokenExpiration(String token) {
    try {
      final jwt = JWT.decode(token);
      final exp = jwt.payload['exp'];
      if (exp == null) return null;

      return DateTime.fromMillisecondsSinceEpoch(exp * 1000);
    } catch (e) {
      return null;
    }
  }

  Future<void> refreshToken() async {
    final refreshToken = await getRefreshTokenFromPreferences();
    if (refreshToken == null) {
      throw Exception('No refresh token found');
    }

    final response = await client.post(
      Uri.parse('$_baseUrl/users/refresh-auth'),
      body: jsonEncode({'token': refreshToken}),
      headers: {'Content-Type': 'application/json'},
    );

    if (response.statusCode == 200) {
      await setTokens(response);
      // Update cached token after successful refresh
      final prefs = await _prefs;
      _cachedAccessToken = prefs.getString('accessToken');
      _tokenExpiration = _getTokenExpiration(_cachedAccessToken!);
    } else {
      await removeTokens();
      _clearCachedToken();

      throw Exception('Token refresh failed - retrying');
    }
  }

  /// Proactively refresh token before it expires
  Future<void> _refreshTokenProactively() async {
    if (_isRefreshingToken) return;

    _isRefreshingToken = true;
    try {
      await refreshToken();
    } catch (e) {
      // If proactive refresh fails, clear cache and let normal flow handle it
      _clearCachedToken();
    } finally {
      _isRefreshingToken = false;
    }
  }

  /// Clear cached token (called on logout or auth failure)
  void _clearCachedToken() {
    _cachedAccessToken = null;
    _tokenExpiration = null;
    _isRefreshingToken = false;
  }

  Map<String, dynamic>? getTokenStatus() {
    if (_cachedAccessToken == null || _tokenExpiration == null) {
      return null;
    }

    final now = DateTime.now();
    final timeUntilExpiry = _tokenExpiration!.difference(now);

    return {
      'hasCachedToken': true,
      'isRefreshing': _isRefreshingToken,
      'expiresInMinutes': timeUntilExpiry.inMinutes,
      'isValid': timeUntilExpiry.inMinutes > 5,
    };
  }

  /// Generic method to handle authenticated requests with automatic token refresh
  ///
  /// [requestFn] is a function that makes the HTTP request and returns the response
  /// [successHandler] is a function that processes the successful response
  /// [errorMessage] is the error message to show if the request fails after token refresh
  Future<T> _makeAuthenticatedRequest<T>({
    required Future<http.Response> Function(String accessToken) requestFn,
    required T Function(http.Response response) successHandler,
    required String errorMessage,
  }) async {
    final accessToken = await getAccessToken();
    if (accessToken == null) throw Exception('Not authenticated');

    final response = await requestFn(accessToken);

    if (response.statusCode == 200 || response.statusCode == 201) {
      return successHandler(response);
    } else if (response.statusCode == 401 || response.statusCode == 403) {
      // Only try to refresh token once, and only if we're not already refreshing
      if (_isRefreshingToken) {
        throw Exception('Token refresh already in progress');
      }

      try {
        await refreshToken();
        final newAccessToken = await getAccessToken();
        if (newAccessToken == null) {
          throw Exception('Not authenticated after token refresh');
        }

        final retryResponse = await requestFn(newAccessToken);

        if (retryResponse.statusCode == 200 ||
            retryResponse.statusCode == 201) {
          return successHandler(retryResponse);
        } else {
          throw Exception(
              '$errorMessage after token refresh (${retryResponse.statusCode})');
        }
      } catch (refreshError) {
        throw Exception('Failed to refresh token: $refreshError');
      }
    } else {
      throw Exception('$errorMessage: ${response.body}');
    }
  }

  Future<void> createSenseBoxBike(String name, double latitude,
      double longitude, SenseBoxBikeModel model, String? selectedTag) async {
    return _makeAuthenticatedRequest<void>(
      requestFn: (accessToken) => client.post(
        Uri.parse('$_baseUrl/boxes'),
        body: jsonEncode(createSenseBoxBikeModel(name, latitude, longitude,
            model: model, selectedTag: selectedTag)),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
      ),
      successHandler: (response) {}, // void return
      errorMessage: 'Failed to create senseBox',
    );
  }

  Future<List<dynamic>> getSenseBoxes({int page = 0}) async {
    return _makeAuthenticatedRequest<List<dynamic>>(
      requestFn: (accessToken) => client.get(
        Uri.parse('$_baseUrl/users/me/boxes?page=$page'),
        headers: {'Authorization': 'Bearer $accessToken'},
      ),
      successHandler: (response) {
        dynamic responseData = jsonDecode(response.body);
        return responseData['data']['boxes'];
      },
      errorMessage: 'Failed to load senseBoxes',
    );
  }

  Future<void> uploadData(
      String senseBoxId, Map<String, dynamic> sensorData) async {
    List<dynamic> data = sensorData.values.toList();

    // Check if currently rate limited
    if (_isRateLimited) {
      final remaining = _rateLimitUntil?.difference(DateTime.now());
      if (remaining != null && !remaining.isNegative) {
        throw TooManyRequestsException(remaining.inSeconds);
      } else {
        // Rate limit expired, reset state
        _isRateLimited = false;
        _rateLimitUntil = null;
      }
    }

    // API allows up to 6 requests per minute, so set maxAttempts and delays accordingly
    final r = RetryOptions(
      maxAttempts: 6, // 6 attempts per minute
      delayFactor: const Duration(seconds: 10), // 10s between attempts
      maxDelay: const Duration(seconds: 15),
    );

    await r.retry(
      () async {
        final accessToken = await getAccessToken();
        if (accessToken == null) throw Exception('Not authenticated');

        final response = await client.post(
          Uri.parse('$_baseUrl/boxes/$senseBoxId/data'),
          body: jsonEncode(data),
          headers: {
            'Authorization': 'Bearer $accessToken',
            'Content-Type': 'application/json',
          },
        ).timeout(const Duration(seconds: defaultTimeout));
        // TEMPORARY: Simulate 401/403 for testing authentication failure during upload
        // throw Exception('Authentication failed - user needs to re-login');
        if (response.statusCode == 201) {
          debugPrint(
              '[OpenSenseMapService] Data uploaded successfully at ${DateTime.now()}');
          return;
        } else if (response.statusCode == 401 || response.statusCode == 403) {
          ErrorService.handleError(
              'Client error ${response.statusCode}: ${response.body}',
              StackTrace.current,
              sendToSentry: true);
          try {
            await refreshToken();
            // Get the new access token and retry the request
            final newAccessToken = await getAccessToken();
            if (newAccessToken == null) {
              throw Exception('Not authenticated after token refresh');
            }
            
            final retryResponse = await client.post(
              Uri.parse('$_baseUrl/boxes/$senseBoxId/data'),
              body: jsonEncode(data),
              headers: {
                'Authorization': 'Bearer $newAccessToken',
                'Content-Type': 'application/json',
              },
            ).timeout(const Duration(seconds: defaultTimeout));
            
            if (retryResponse.statusCode == 201) {
              debugPrint(
                  '[OpenSenseMapService] Data uploaded successfully after token refresh at ${DateTime.now()}');
              return;
            } else {
              // If retry still fails, throw permanent auth error
              _isPermanentlyDisabled = true;
              debugPrint(
                  '[OpenSenseMapService] Authentication failed after token refresh - service permanently disabled until re-login');
              throw Exception('Authentication failed - user needs to re-login');
            }
          } catch (e) {
            // If refresh token fails, set permanent disable state - user needs to re-login
            _isPermanentlyDisabled = true;
            debugPrint(
                '[OpenSenseMapService] Authentication failed - service permanently disabled until re-login');
            throw Exception('Authentication failed - user needs to re-login');
          }
        } else if (response.statusCode == 429) {
          ErrorService.handleError(
              'Client error ${response.statusCode}: ${response.body}',
              StackTrace.current,
              sendToSentry: true);
          final retryAfter = response.headers['retry-after'];
          final waitTime = retryAfter != null
              ? int.tryParse(retryAfter) ?? defaultTimeout
              : defaultTimeout * 2;

          // Set rate limiting state
          _isRateLimited = true;
          _rateLimitUntil = DateTime.now().add(Duration(seconds: waitTime));

          throw TooManyRequestsException(waitTime);
        } else {
          // All other errors (4xx and 5xx)
          if (response.statusCode >= 500) {
            // 5xx server errors - retry these
            ErrorService.handleError(
                'Server error ${response.statusCode}: ${response.body}',
                StackTrace.current,
                sendToSentry: true);
            throw Exception('Server error ${response.statusCode} - retrying');
          } else {
            // 4xx client errors - don't retry these
            ErrorService.handleError(
                'Client error ${response.statusCode}: ${response.body}',
                StackTrace.current,
                sendToSentry: true);
            throw Exception(
                'Client error ${response.statusCode}: ${response.body}');
          }
        }
      },
      retryIf: (e) {
        final errorString = e.toString();
        return e is TooManyRequestsException ||
            errorString.contains('Server error') ||
            e is SocketException || // Network connectivity issues
            e is HttpException || // HTTP protocol errors
            e is TimeoutException;
      },
      onRetry: (e) async {
        if (e is TooManyRequestsException) {
          await Future.delayed(Duration(seconds: e.retryAfter));
        }
      },
    );
  }

// Define the available sensors for each model
  final Map<SenseBoxBikeModel, List<dynamic>> sensors = {
    SenseBoxBikeModel.classic: classicModelSensors,
    SenseBoxBikeModel.atrai: atraiModelSensors,
  };

// Factory function
  Map<String, dynamic> createSenseBoxBikeModel(
    String name,
    double longitude,
    double latitude, {
    List<String>? grouptags,
    SenseBoxBikeModel model = SenseBoxBikeModel.classic,
    String? selectedTag,
  }) {
    // Initialize the base grouptags
    final List<String> baseGroupTags = grouptags ??
        ['bike', model == SenseBoxBikeModel.classic ? 'classic' : 'atrai'];
    // Add the selectedTag if it is not null
    if (selectedTag != null && selectedTag.isNotEmpty) {
      baseGroupTags.add(selectedTag);
    }

    final baseProperties = {
      'name': name,
      'exposure': 'mobile',
      'location': [latitude, longitude],
      'grouptag': baseGroupTags,
    };

    return {
      ...baseProperties,
      'sensors': sensors[model]!,
    };
  }
}
