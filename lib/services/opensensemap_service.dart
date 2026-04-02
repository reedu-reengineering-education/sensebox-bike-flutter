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
import 'package:sensebox_bike/utils/opensensemap_utils.dart';
import 'package:sensebox_bike/blocs/settings_bloc.dart';
import 'package:sensebox_bike/models/sensebox.dart';

enum SenseBoxBikeModel { classic, atrai }

class UploadRetryException implements Exception {
  final String message;
  final String? refreshedBoxToken;

  UploadRetryException(this.message, {this.refreshedBoxToken});

  @override
  String toString() => message;
}

class ServerErrorException implements Exception {
  final int statusCode;

  ServerErrorException(this.statusCode);

  @override
  String toString() => 'Server error $statusCode';
}

class OpenSenseMapService {
  final http.Client client;
  final Future<SharedPreferences> _prefs;
  final SettingsBloc? _settingsBloc;

  bool _isRateLimited = false;
  DateTime? _rateLimitUntil;
  bool _isPermanentlyDisabled = false;

  OpenSenseMapService({
    http.Client? client,
    Future<SharedPreferences>? prefs,
    SettingsBloc? settingsBloc,
  })  : client = client ?? http.Client(),
        _prefs = prefs ?? SharedPreferences.getInstance(),
        _settingsBloc = settingsBloc;

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

  String get _baseUrl {
    final settingsBloc = _settingsBloc;
    if (settingsBloc != null) {
      return settingsBloc.apiUrl;
    }
    return openSenseMapUrl;
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
    try {
      final responseData = safeJsonDecode(response.body);
      final tokens = _validateAndExtractTokens(responseData);
      final accessToken = tokens['accessToken']!;
      final refreshToken = tokens['refreshToken']!;

      await prefs.setString('accessToken', accessToken);
      await prefs.setString('refreshToken', refreshToken);
    } catch (e) {
      throw Exception('Failed to parse token response: $e');
    }
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

  Future<Map<String, dynamic>> register(
      String name, String email, String password) async {
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
      String errorMessage = 'Registration failed';
      try {
        final errorResponse = safeJsonDecode(response.body);
        errorMessage = errorResponse['message'] ?? errorMessage;
      } catch (e) {
        // If JSON parsing fails, use status code
        errorMessage = 'Registration failed: ${response.statusCode}';
      }
      throw RegistrationError(errorMessage);
    }

    try {
      final responseData = safeJsonDecode(response.body);
      await setTokens(response);
      await saveUserData(responseData);
      return responseData;
    } catch (e) {
      if (e is! RegistrationError) {
        throw RegistrationError('Registration failed: $e');
      }
      rethrow;
    }
  }

  Future<bool> saveUserData(Map<String, dynamic> responseData) async {
    // Both registration and login responses have the same structure: { "data": { "user": {...} } }
    if (responseData.containsKey('data') &&
        responseData['data'] is Map<String, dynamic> &&
        responseData['data'].containsKey('user') &&
        responseData['data']['user'] is Map<String, dynamic>) {
      final userData = {
        'data': {'me': responseData['data']['user']}
      };
      await _storeUserDataInPreferences(userData);
      return true;
    }
    return false;
  }

  Future<void> _storeUserDataInPreferences(
      Map<String, dynamic> userData) async {
    final prefs = await _prefs;
    await prefs.setString('userData', jsonEncode(userData));
  }

  Future<Map<String, dynamic>?> _getCachedUserData() async {
    final prefs = await _prefs;
    final userDataString = prefs.getString('userData');
    if (userDataString != null) {
      try {
        return safeJsonDecode(userDataString);
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
      try {
        final responseData = safeJsonDecode(response.body);
        await setTokens(response);
        resetPermanentDisable();
        await saveUserData(responseData);
        return responseData;
      } catch (e) {
        if (e is! LoginError) {
          throw LoginError('Login failed: $e');
        }
        rethrow;
      }
    } else {
      String errorMessage = 'Login failed';
      try {
        final errorData = safeJsonDecode(response.body);
        errorMessage = errorData['message'] ?? errorMessage;
      } catch (e) {
        // If JSON parsing fails, use status code
        errorMessage = 'Login failed: ${response.statusCode}';
      }
      throw LoginError(errorMessage);
    }
  }

  Future<void> logout() async {
    await removeTokens();
    await _clearUserData();
  }

  Future<Map<String, dynamic>?> getUserData() async {
    final cachedUserData = await _getCachedUserData();
    
    // If we have cached data, return it immediately (no need to check token validity)
    if (cachedUserData != null) {
      return cachedUserData;
    }
    
    // Check if we have a valid access token before making API call
    final accessToken = await getAccessToken();
    if (accessToken == null) {
      return null;
    }

    try {
      final userData = await _makeAuthenticatedRequest<Map<String, dynamic>?>(
        requestFn: (accessToken) => client.get(
          Uri.parse('$_baseUrl/users/me'),
          headers: {'Authorization': 'Bearer $accessToken'},
        ),
        successHandler: (response) {
          try {
            return safeJsonDecode(response.body);
          } catch (e) {
            throw Exception('Failed to parse user data: $e');
          }
        },
        errorMessage: 'Failed to load user data',
      );

      if (userData != null) {
        await _storeUserDataInPreferences(userData);
        return userData;
      }

      if (cachedUserData != null) {
        await _clearUserData();
      }
      return null;
    } catch (e) {
      if (e is AuthException) await _clearUserData();
      return null;
    }
  }

  Future<String?> getAccessToken() async {
    final token = await getAccessTokenFromPreferences();

    if (token != null && _isTokenValid(token)) {
      return token;
    }

    try {
      final tokens = await refreshToken();
      return tokens['accessToken'];
    } catch (e) {
      return null;
    }
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

  Future<Map<String, String>> refreshToken() async {
    try {
      final refreshToken = await getRefreshTokenFromPreferences();
      if (refreshToken == null) {
        throw AuthException();
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
            _updateRateLimitFromResponse(response);
          } else if (response.statusCode >= 500) {
            throw ServerErrorException(response.statusCode);
          } else {
            return response;
          }
        },
        retryIf: _isRetryableHttpError,
        maxAttempts: 3,
        delayFactor: const Duration(seconds: 1),
        maxDelay: const Duration(seconds: 5),
        onRetry: (e) async {
          if (e is TooManyRequestsException) {
            await Future.delayed(Duration(seconds: e.retryAfter));
          }
        },
      );

      if (response.statusCode == 200) {
        try {
          final responseData = safeJsonDecode(response.body);
          final tokens = _validateAndExtractTokens(responseData);

          // Save tokens to SharedPreferences
          await setTokens(response);

          return {
            'accessToken': tokens['accessToken']!,
            'refreshToken': tokens['refreshToken']!,
          };
        } catch (e) {
          throw Exception('Failed to parse token refresh response: $e');
        }
      } else {
        await _clearAllCachedData();
        throw AuthException('Token refresh failed: ${response.statusCode}');
      }
    } catch (e) {
      // Any error during refresh - clear all cached data
      await _clearAllCachedData();
      rethrow;
    }
  }

  Future<void> _clearAllCachedData() async {
    await removeTokens();
    await _clearUserData();
  }

  Future<T> _makeAuthenticatedRequest<T>({
    required Future<http.Response> Function(String accessToken) requestFn,
    required T Function(http.Response response) successHandler,
    required String errorMessage,
  }) async {
    final accessToken = await getAccessToken();
    if (accessToken == null) throw AuthException();

    final response = await requestFn(accessToken);

    if (response.statusCode == 200 || response.statusCode == 201) {
      return successHandler(response);
    } else if (response.statusCode == 401 || response.statusCode == 403) {
      final tokens = await refreshToken();
      final retryResponse = await requestFn(tokens['accessToken']!);
      if (retryResponse.statusCode == 200 || retryResponse.statusCode == 201) {
        return successHandler(retryResponse);
      }
      _throwForStatus(retryResponse, errorMessage);
    } else {
      _throwForStatus(response, errorMessage);
    }
  }

  Future<void> createSenseBoxBike(Map<String, dynamic> data) async {
    return _makeAuthenticatedRequest<void>(
      requestFn: (accessToken) => client.post(
        Uri.parse('$_baseUrl/boxes'),
        body: jsonEncode(data),
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
        try {
          dynamic responseData = safeJsonDecode(response.body);
          return responseData['data']['boxes'];
        } catch (e) {
          throw Exception('Failed to parse senseBoxes response: $e');
        }
      },
      errorMessage: 'Failed to load senseBoxes',
    );
  }

  Future<Map<String, dynamic>> _getUserBox(String boxId) async {
    return _makeAuthenticatedRequest<Map<String, dynamic>>(
      requestFn: (accessToken) => client.get(
        Uri.parse('$_baseUrl/users/me/boxes/$boxId'),
        headers: {'Authorization': 'Bearer $accessToken'},
      ),
      successHandler: (response) {
        dynamic responseData;
        try {
          responseData = safeJsonDecode(response.body);
        } catch (e) {
          throw Exception('Failed to parse user box response: $e');
        }
        if (responseData['data'] is Map<String, dynamic>) {
          final data = responseData['data'] as Map<String, dynamic>;
          if (data['box'] is Map<String, dynamic>) {
            return data['box'] as Map<String, dynamic>;
          }
        }
        throw Exception('Unexpected user box response format');
      },
      errorMessage: 'Failed to load user box',
    );
  }

  Future<String?> _getBoxAccessToken(String senseBoxId) async {
    final box = await _getUserBox(senseBoxId);
    return box['access_token']?.toString();
  }

  Future<String> _requireBoxToken(
      String senseBoxId, String? currentToken) async {
    if (currentToken?.isNotEmpty == true) {
      return currentToken!;
    }
    final fetchedToken = await _getBoxAccessToken(senseBoxId);
    if (fetchedToken == null || fetchedToken.isEmpty) {
      throw Exception('Box authentication token not found');
    }
    return fetchedToken;
  }

  Future<String> _refreshUploadAuthorization(String senseBoxId) async {
    try {
      final refreshedBoxToken = await _getBoxAccessToken(senseBoxId);
      if (refreshedBoxToken == null || refreshedBoxToken.isEmpty) {
        throw AuthException();
      }
      return refreshedBoxToken;
    } catch (e) {
      if (e is AuthException) {
        _isPermanentlyDisabled = true;
      }
      rethrow;
    }
  }

  void _throwIfRateLimited() {
    if (!_isRateLimited) return;
    final remaining = _rateLimitUntil?.difference(DateTime.now());
    if (remaining != null && !remaining.isNegative) {
      throw TooManyRequestsException(remaining.inSeconds);
    }
    _isRateLimited = false;
    _rateLimitUntil = null;
  }

  Never _updateRateLimitFromResponse(http.Response response) {
    final retryAfter = response.headers['retry-after'];
    final waitTime = retryAfter != null
        ? int.tryParse(retryAfter) ?? defaultTimeout
        : defaultTimeout * 2;
    _isRateLimited = true;
    _rateLimitUntil = DateTime.now().add(Duration(seconds: waitTime));
    throw TooManyRequestsException(waitTime);
  }

  bool _isRetryableHttpError(Object e) =>
      e is TooManyRequestsException ||
      e is ServerErrorException ||
      e is SocketException ||
      e is HttpException ||
      e is TimeoutException;

  bool _isRetryableUploadError(Object e) =>
      _isRetryableHttpError(e) || e is UploadRetryException;

  Never _throwForStatus(http.Response response, String context) {
    if (response.statusCode == 429) _updateRateLimitFromResponse(response);
    if (response.statusCode >= 500) {
      throw ServerErrorException(response.statusCode);
    }
    throw Exception('$context (${response.statusCode}): ${response.body}');
  }

  Future<void> _attemptUploadOnce({
    required String senseBoxId,
    required List<dynamic> data,
    required String tokenForRequest,
  }) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Authorization': tokenForRequest,
    };

    final response = await client
        .post(
          Uri.parse('$_baseUrl/boxes/$senseBoxId/data'),
          body: jsonEncode(data),
          headers: headers,
        )
        .timeout(const Duration(seconds: defaultTimeout));

    if (response.statusCode == 201) {
      return;
    }

    if (response.statusCode == 401 || response.statusCode == 403) {
      final refreshedToken = await _refreshUploadAuthorization(senseBoxId);
      throw UploadRetryException(
        'Box token refreshed, retrying',
        refreshedBoxToken: refreshedToken,
      );
    }

    _throwForStatus(response, 'Upload to box $senseBoxId failed');
  }

  Future<void> uploadData(
    SenseBox senseBox,
    Map<String, dynamic> sensorData,
  ) async {
    final senseBoxId = senseBox.id?.toString();
    if (senseBoxId == null || senseBoxId.isEmpty) {
      throw Exception('SenseBox id is missing');
    }

    List<dynamic> data = sensorData.values.toList();
    String? boxToken = senseBox.accessToken;

    _throwIfRateLimited();

    // API allows up to 6 requests per minute, so set maxAttempts and delays accordingly
    final r = RetryOptions(
      maxAttempts: 6, // 6 attempts per minute
      delayFactor: const Duration(seconds: 10), // 10s between attempts
      maxDelay: const Duration(seconds: 15),
    );

    try {
      await r.retry(
        () async {
          try {
            boxToken = await _requireBoxToken(senseBoxId, boxToken);
            await _attemptUploadOnce(
                senseBoxId: senseBoxId,
                data: data,
                tokenForRequest: boxToken!);
          } on UploadRetryException catch (e) {
            if (e.refreshedBoxToken?.isNotEmpty == true) {
              boxToken = e.refreshedBoxToken;
            }
            rethrow;
          }
        },
        retryIf: _isRetryableUploadError,
        onRetry: (e) async {
          if (e is TooManyRequestsException) {
            await Future.delayed(Duration(seconds: e.retryAfter));
          }
        },
      );
    } catch (e, stackTrace) {
      ErrorService.handleError(
        'Upload failed after retries for box $senseBoxId: $e',
        stackTrace,
        sendToSentry: true,
      );
      rethrow;
    }
  }

}
