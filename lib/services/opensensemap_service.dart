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

class RetryException implements Exception {
  final String message;
  final dynamic data;

  RetryException(this.message, this.data);

  @override
  String toString() => message;
}

class OpenSenseMapService {
  static const String _baseUrl = openSenseMapUrl;
  final http.Client client;
  final Future<SharedPreferences> _prefs;

  bool _isRateLimited = false;
  DateTime? _rateLimitUntil;
  bool _isPermanentlyDisabled = false;

  OpenSenseMapService({
    http.Client? client,
    Future<SharedPreferences>? prefs,
  })  : client = client ?? http.Client(),
        _prefs = prefs ?? SharedPreferences.getInstance();

  bool get isAcceptingRequests => !_isRateLimited && !_isPermanentlyDisabled;
  bool get isPermanentlyDisabled => _isPermanentlyDisabled;

  Duration? get remainingRateLimitTime {
    if (!_isRateLimited || _rateLimitUntil == null) return null;
    final remaining = _rateLimitUntil!.difference(DateTime.now());
    return remaining.isNegative ? null : remaining;
  }

  void resetPermanentDisable() {
    _isPermanentlyDisabled = false;
  }




  /// Validates and extracts tokens from response data
  /// Throws Exception if tokens are missing or empty
  Map<String, String> _validateAndExtractTokens(
      Map<String, dynamic> responseData) {
    if (!responseData.containsKey('token') ||
        !responseData.containsKey('refreshToken')) {
      throw Exception('Invalid response format: missing token or refreshToken');
    }

    final String accessToken = responseData['token'] as String;
    final String refreshToken = responseData['refreshToken'] as String;

    if (accessToken.isEmpty || refreshToken.isEmpty) {
      throw Exception('Invalid response format: empty token or refreshToken');
    }

    return {
      'accessToken': accessToken,
      'refreshToken': refreshToken,
    };
  }

  Future<void> setTokens(http.Response response) async {
    final prefs = await _prefs;
    final responseData = jsonDecode(response.body);

    final tokens = _validateAndExtractTokens(responseData);
    final accessToken = tokens['accessToken']!;
    final refreshToken = tokens['refreshToken']!;

    await prefs.setString('accessToken', accessToken);
    await prefs.setString('refreshToken', refreshToken);
  }

  Future<void> removeTokens() async {
    final prefs = await _prefs;

    await prefs.remove('accessToken');
    await prefs.remove('refreshToken');
  }

  Future<String?> getRefreshTokenFromPreferences() async {
    final prefs = await _prefs;
    return prefs.getString('refreshToken');
  }

  Future<String?> getAccessTokenFromPreferences() async {
    final prefs = await _prefs;
    return prefs.getString('accessToken');
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

      resetPermanentDisable();

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
    final cachedUserData = await _getCachedUserData();
    
    // If we have cached data and a valid access token, return cached data immediately
    if (cachedUserData != null) {
      final accessToken = await getAccessToken();
      if (accessToken != null) {
        return cachedUserData;
      }
    }

    try {
      final userData = await _makeAuthenticatedRequest<Map<String, dynamic>?>(
        requestFn: (accessToken) => client.get(
          Uri.parse('$_baseUrl/users/me'),
          headers: {'Authorization': 'Bearer $accessToken'},
        ),
        successHandler: (response) => jsonDecode(response.body),
        errorMessage: 'Failed to load user data',
      );

      if (userData != null) {
        await _saveUserData(userData);
        return userData;
      }

      if (cachedUserData != null) {
        await _clearUserData();
      }
      return null;
    } catch (e) {
      if (e.toString().contains('Not authenticated') ||
          e.toString().contains('Authentication failed') ||
          e.toString().contains('Failed to refresh token')) {
        await _clearUserData();
      }
      return null;
    }
  }

  Future<String?> getAccessToken() async {
    final token = await getAccessTokenFromPreferences();

    if (token != null && _isTokenValid(token)) {
      return token;
    }

    // Token is null or invalid - attempt to refresh automatically
    try {
      final tokens = await refreshToken();
      if (tokens != null) {
        return tokens['accessToken'];
      }
    } catch (e) {
      // Refresh failed - data is already cleared by refreshToken()
      debugPrint(
          '[OpenSenseMapService] Auto-refresh failed in getAccessToken: $e');
    }

    return null;
  }

  bool _isTokenValid(String token) {
    try {
      final jwt = JWT.decode(token);
      final exp = jwt.payload['exp'];
      if (exp == null) {
        return false;
      }
      final expirationTime = DateTime.fromMillisecondsSinceEpoch(exp * 1000);
      final now = DateTime.now();

      return expirationTime.isAfter(now);
    } catch (e) {
      return false;
    }
  }

  /// Public method to check if current access token is valid without triggering refresh
  Future<bool> isCurrentAccessTokenValid() async {
    final token = await getAccessTokenFromPreferences();
    if (token == null) return false;
    return _isTokenValid(token);
  }

  Future<Map<String, String>?> refreshToken() async {
    try {
      // Check if refresh token exists
      final refreshToken = await getRefreshTokenFromPreferences();
      if (refreshToken == null) {
        throw Exception('No refresh token found');
      }

      final response = await retry(
        () async {
          final response = await client.post(
            Uri.parse('$_baseUrl/users/refresh-auth'),
            body: jsonEncode({'token': refreshToken}),
            headers: {'Content-Type': 'application/json'},
          ).timeout(const Duration(seconds: 30));

          if (response.statusCode == 200) {
            return response;
          } else if (response.statusCode == 429) {
            throw RetryException(
                'Rate limited (${response.statusCode})', response);
          } else if (response.statusCode >= 500) {
            throw RetryException(
                'Server error (${response.statusCode})', response);
          } else {
            return response;
          }
        },
        retryIf: (e) => e is RetryException,
        maxAttempts: 3,
        delayFactor: const Duration(seconds: 1),
        maxDelay: const Duration(seconds: 5),
        onRetry: (e) {
          if (e is RetryException) {
            debugPrint(
                '[OpenSenseMapService] Retrying token refresh: ${e.message}');
          }
        },
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final tokens = _validateAndExtractTokens(responseData);

        // Save tokens to SharedPreferences
        await setTokens(response);

        return {
          'accessToken': tokens['accessToken']!,
          'refreshToken': tokens['refreshToken']!,
        };
      } else {
        // Token refresh failed - clear all cached data
        await _clearAllCachedData();
        throw Exception('Token refresh failed: ${response.statusCode}');
      }
    } catch (e) {
      // Any error during refresh - clear all cached data
      await _clearAllCachedData();
      rethrow;
    }
  }


  /// Clears all cached data when authentication fails
  Future<void> _clearAllCachedData() async {
    // Clear tokens from SharedPreferences
    await removeTokens();

    // Clear user data cache
    await _clearUserData();

    debugPrint(
        '[OpenSenseMapService] All cached data cleared due to authentication failure');
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
      // Try to refresh token
      try {
        final tokens = await refreshToken();

        final retryResponse = await requestFn(tokens!['accessToken']!);

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
      double longitude, SenseBoxBikeModel model, String? selectedTag,
      [List<String?>? additionalTags]) async {
    return _makeAuthenticatedRequest<void>(
      requestFn: (accessToken) => client.post(
        Uri.parse('$_baseUrl/boxes'),
        body: jsonEncode(createSenseBoxBikeModel(
          name,
          latitude,
          longitude,
          model: model,
          selectedTag: selectedTag,
          additionalTags: additionalTags,
        )),
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

    // Check if data exceeds 2500 items and trim if needed to stay under the API limit
    const maxItems = 2450;
    if (data.length > maxItems) {
      final int itemsToRemove = data.length - maxItems;
      data = data.skip(itemsToRemove).toList();

      // Log the trimming event
      ErrorService.handleError(
        'Data trimmed before upload: Removed $itemsToRemove oldest items to stay under $maxItems limit (original: ${sensorData.values.length}, final: ${data.length})',
        StackTrace.current,
        sendToSentry: true,
      );
    }

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
        
        if (response.statusCode == 201) {
          debugPrint(
              '[OpenSenseMapService] Data uploaded successfully at ${DateTime.now()}');
          return;
        } else if (response.statusCode == 401 || response.statusCode == 403) {
          ErrorService.handleError(
              'Client error ${response.statusCode}: ${response.body}',
              StackTrace.current,
              sendToSentry: true);

          // Use the same robust token refresh method
          try {
            final tokens = await refreshToken();
            if (tokens != null) {
              throw Exception('Token refreshed, retrying');
            }
            throw Exception('Token refresh failed');
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
            errorString.contains('Token refreshed, retrying') ||
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
    List<String?>? additionalTags = const [],
  }) {
    // Initialize the base grouptags
    final List<String> baseGroupTags = grouptags ??
        ['bike', model == SenseBoxBikeModel.classic ? 'classic' : 'atrai'];
    // Add the selectedTag if it is not null
    if (selectedTag != null && selectedTag.isNotEmpty) {
      baseGroupTags.add(selectedTag);
    }

    final List<String> allTags = {
      ...baseGroupTags,
      ...?additionalTags?.whereType<String>(),
    }.toList();

    final baseProperties = {
      'name': name,
      'exposure': 'mobile',
      'location': [latitude, longitude],
      'grouptag': allTags,
    };

    return {
      ...baseProperties,
      'sensors': sensors[model]!,
    };
  }
}
