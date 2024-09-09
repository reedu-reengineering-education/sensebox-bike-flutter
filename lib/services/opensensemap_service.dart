import 'package:http/http.dart' as http;
import 'package:sensebox_bike/models/sensebox.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class OpenSenseMapService {
  static const String _baseUrl = 'https://api.opensensemap.org';

  Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await http.post(
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

      // Store tokens in SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('accessToken', accessToken);
      await prefs.setString('refreshToken', refreshToken);

      return responseData;
    } else {
      throw Exception('Failed to log in');
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

    final response = await http.post(
      Uri.parse('$_baseUrl/users/refresh-token'),
      body: jsonEncode({'refreshToken': refreshToken}),
      headers: {
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final responseData = jsonDecode(response.body);
      final String newAccessToken = responseData['token'];

      await prefs.setString('accessToken', newAccessToken);
    } else {
      throw Exception('Failed to refresh token');
    }
  }

  Future<List<dynamic>> getSenseBoxes() async {
    final accessToken = await getAccessToken();
    if (accessToken == null) throw Exception('Not authenticated');

    final response = await http.get(
      Uri.parse('$_baseUrl/users/me/boxes'),
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

    final response = await http.post(
      Uri.parse('$_baseUrl/boxes/$senseBoxId/data'),
      body: jsonEncode(data),
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode != 201) {
      throw Exception(
          'Failed to upload data (${response.statusCode}) ${response.body}');
    }
  }
}
