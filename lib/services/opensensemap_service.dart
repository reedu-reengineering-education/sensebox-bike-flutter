import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

import 'package:sensebox_bike/constants.dart';

enum SenseBoxBikeModel { classic, atrai }

class OpenSenseMapService {
  static const String _baseUrl = openSenseMapUrl;

  // The following class variables and constructor are added to allow testing
  // No refactoring of other parts of the code should be needed
  final http.Client client;
  final Future<SharedPreferences> _prefs;

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

  Future<String?> getAccessToken() async {
    final prefs = await _prefs;
    return prefs.getString('accessToken');
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
    } else {
      await removeTokens();
      throw Exception('Failed to refresh token: ${response.body}');
    }
  }

  Future<void> createSenseBoxBike(String name, double latitude,
      double longitude, SenseBoxBikeModel model) async {
    final accessToken = await getAccessToken();
    if (accessToken == null) throw Exception('Not authenticated');

    final response = await client.post(
      Uri.parse('$_baseUrl/boxes'),
      body: jsonEncode(
          createSenseBoxBikeModel(name, latitude, longitude, model: model)),
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 201) {
    } else if (response.statusCode == 401) {
      await refreshToken();
      return createSenseBoxBike(name, latitude, longitude, model);
    } else {
      throw Exception('Failed to create senseBox');
    }
  }

  Future<List<dynamic>> getSenseBoxes({int page = 0}) async {
    final accessToken = await getAccessToken();
    if (accessToken == null) throw Exception('Not authenticated');

    final response = await client.get(
      Uri.parse('$_baseUrl/users/me/boxes?page=$page'),
      headers: {'Authorization': 'Bearer $accessToken'},
    );

    if (response.statusCode == 200) {
      dynamic responseData = jsonDecode(response.body);
      return responseData['data']['boxes'];
    } else if (response.statusCode == 401) {
      await refreshToken();
      return getSenseBoxes();
    } else {
      throw Exception('Failed to load senseBoxes');
    }
  }

  Future<void> uploadData(
      String senseBoxId, Map<String, dynamic> sensorData) async {
    final accessToken = await getAccessToken();
    if (accessToken == null) throw Exception('Not authenticated');

    List<dynamic> data = sensorData.values.toList();

    final response = await client.post(
      Uri.parse('$_baseUrl/boxes/$senseBoxId/data'),
      body: jsonEncode(data),
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 201) {
      debugPrint('Data uploaded');
    } else if (response.statusCode == 401) {
      await refreshToken();
      return uploadData(senseBoxId, sensorData);
    } else if (response.statusCode == 429) {
      throw Exception(
          'Failed to upload data (${response.statusCode}) ${response.body}');
    } else {
      throw Exception(
          'Failed to upload data (${response.statusCode}) ${response.body}');
    }
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
  }) {
    final baseProperties = {
      'name': name,
      'exposure': 'mobile',
      'location': [latitude, longitude],
      'grouptag': grouptags ??
          ['bike', model == SenseBoxBikeModel.classic ? 'classic' : 'atrai'],
    };

    return {
      ...baseProperties,
      'sensors': sensors[model]!,
    };
  }
}
