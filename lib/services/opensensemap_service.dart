import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:sensebox_bike/constants.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

enum SenseBoxBikeModel { classic, atrai }

class OpenSenseMapService {
  static const String _baseUrl = openSenseMapUrl;
  // The following class variables and constructor are added to allow testing
  // No refactoring of other parts of the code should be needed
  final http.Client client;
  final Future<SharedPreferences> prefs;

  OpenSenseMapService({
    http.Client? client,
    Future<SharedPreferences>? prefs,
  })  : client = client ?? http.Client(),
        prefs = prefs ?? SharedPreferences.getInstance();

  Future<void> register(String name, String email, String password) async {
    final response = await client.post(
      Uri.parse('$_baseUrl/users/register'),
      body: jsonEncode({
        'name': name,
        'email': email,
        'password': password,
      }),
      headers: {
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode != 201) {
      final errorResponse = jsonDecode(response.body);
      throw Exception(errorResponse['message']);
    }

    final responseData = jsonDecode(response.body);
    final String accessToken = responseData['token'];
    final String refreshToken = responseData['refreshToken'];

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('accessToken', accessToken);
    await prefs.setString('refreshToken', refreshToken);

    return responseData;
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await client.post(
      Uri.parse('$_baseUrl/users/sign-in'),
      body: jsonEncode({
        'email': email,
        'password': password,
      }),
      headers: {
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final responseData = jsonDecode(response.body);
      final String accessToken = responseData['token'];
      final String refreshToken = responseData['refreshToken'];

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('accessToken', accessToken);
      await prefs.setString('refreshToken', refreshToken);

      return responseData;
    } else {
      throw Exception(json.decode(response.body)['message']);
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('accessToken');
    await prefs.remove('refreshToken');
  }

  Future<String?> getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();

    return prefs.getString('accessToken');
  }

  Future<void> refreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    final refreshToken = prefs.getString('refreshToken');

    if (refreshToken == null) {
      throw Exception('No refresh token found');
    }

    final response = await client.post(
      Uri.parse('$_baseUrl/users/refresh-auth'),
      body: jsonEncode({'token': refreshToken}),
      headers: {
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final responseData = jsonDecode(response.body);
      final String newAccessToken = responseData['token'];
      final String newRefreshToken = responseData['refreshToken'];

      await prefs.setString('accessToken', newAccessToken);
      await prefs.setString('refreshToken', newRefreshToken);
    } else {
      await prefs.remove('accessToken');
      await prefs.remove('refreshToken');
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

    if (accessToken == null) {
      throw Exception('Not authenticated');
    }

    final response = await client.get(
      Uri.parse('$_baseUrl/users/me/boxes?page=$page'),
      headers: {
        'Authorization': 'Bearer $accessToken',
      },
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
