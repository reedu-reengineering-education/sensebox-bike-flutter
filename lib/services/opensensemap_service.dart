import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:sensebox_bike/services/custom_exceptions.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:retry/retry.dart';
import 'dart:async';

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

  Future<void> setTokens(http.Response response) async {
    final prefs = await _prefs;
    final responseData = jsonDecode(response.body);
    final String accessToken = responseData['token'];
    final String refreshToken = responseData['refreshToken'];

    await prefs.setString('accessToken', accessToken);
    await prefs.setString('refreshToken', refreshToken);
    
    // Update cached token
    _cachedAccessToken = accessToken;
    _tokenExpiration = DateTime.now().add(Duration(hours: 1));
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

    return responseData;
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

      return responseData;
    } else {
      throw Exception(json.decode(response.body)['message']);
    }
  }

  Future<void> logout() async {
    await removeTokens();
  }

  Future<Map<String, dynamic>?> getUserData() async {
    return _makeAuthenticatedRequest<Map<String, dynamic>?>(
      requestFn: (accessToken) => client.get(
        Uri.parse('$_baseUrl/users/me'),
        headers: {'Authorization': 'Bearer $accessToken'},
      ),
      successHandler: (response) => jsonDecode(response.body),
      errorMessage: 'Failed to load user data',
    );
  }

  /// Get access token with caching and automatic refresh
  Future<String?> getAccessToken() async {
    // Check if we have a valid cached token
    if (_cachedAccessToken != null && _tokenExpiration != null) {
      final now = DateTime.now();
      final timeUntilExpiry = _tokenExpiration!.difference(now);
      
      // If token expires in more than 5 minutes, use cached token
      if (timeUntilExpiry.inMinutes > 5) {
        return _cachedAccessToken;
      }
      
      // If token expires soon, refresh it proactively
      if (timeUntilExpiry.inMinutes > 0 && !_isRefreshingToken) {
        _refreshTokenProactively();
      }
    }
    
    // Get token from preferences and cache it
    final prefs = await _prefs;
    final token = prefs.getString('accessToken');
    
    if (token != null) {
      _cachedAccessToken = token;
      // Set expiration to 1 hour from now (typical JWT lifetime)
      _tokenExpiration = DateTime.now().add(Duration(hours: 1));
    }
    
    return token;
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
      _tokenExpiration = DateTime.now().add(Duration(hours: 1));
    } else {
      await removeTokens();
      _clearCachedToken();
      throw Exception('Failed to refresh token: ${response.body}');
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

  /// Get token status for debugging (returns null if no cached token)
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
    } else if (response.statusCode == 401) {
      // Try to refresh token and retry once
      try {
        await refreshToken();
        final newAccessToken = await getAccessToken();
        if (newAccessToken == null) {
          throw Exception('Not authenticated after token refresh');
        }
        
        final retryResponse = await requestFn(newAccessToken);
        
        if (retryResponse.statusCode == 200 || retryResponse.statusCode == 201) {
          return successHandler(retryResponse);
        } else {
          throw Exception('$errorMessage after token refresh');
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

        if (response.statusCode == 201) {
          debugPrint('Data uploaded');
          return;
        } else if (response.statusCode == 401) {
          await refreshToken();
          throw Exception('Token refreshed, retrying');
        } else if (response.statusCode == 429) {
          final retryAfter = response.headers['retry-after'];
          final waitTime = retryAfter != null
              ? int.tryParse(retryAfter) ?? defaultTimeout
              : defaultTimeout * 2;
          throw TooManyRequestsException(waitTime);
        } else {
          throw Exception(
              'Failed to upload data (${response.statusCode}) ${response.body}');
        }
      },
      retryIf: (e) =>
          e is TooManyRequestsException ||
          e.toString().contains('Token refreshed') ||
          e is TimeoutException,
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
