import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

enum SenseBoxBikeModel { classic, atrai }

class OpenSenseMapService {
  static const String _baseUrl = 'https://api.opensensemap.org';

  Future<void> register(String name, String email, String password) async {
    final response = await http.post(
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

    final response = await http.post(
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
      throw Exception('Failed to refresh token: ${response.body}');
    }
  }

  Future<void> createSenseBoxBike(String name, double latitude,
      double longitude, SenseBoxBikeModel model) async {
    final accessToken = await getAccessToken();
    if (accessToken == null) throw Exception('Not authenticated');

    final response = await http.post(
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

    final response = await http.get(
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

    final response = await http.post(
      Uri.parse('$_baseUrl/boxes/$senseBoxId/data'),
      body: jsonEncode(data),
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 201) {
      print('Data uploaded');
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
    SenseBoxBikeModel.classic: [
      {
        "id": "0",
        "icon": 'osem-thermometer',
        "title": 'Temperature',
        "unit": '°C',
        "sensorType": 'HDC1080'
      },
      {
        "id": "1",
        "icon": 'osem-humidity',
        "title": 'Rel. Humidity',
        "unit": '%',
        "sensorType": 'HDC1080'
      },
      {
        "id": "2",
        "icon": 'osem-cloud',
        "title": 'Finedust PM1',
        "unit": 'µg/m³',
        "sensorType": 'SPS30'
      },
      {
        "id": "3",
        "icon": 'osem-cloud',
        "title": 'Finedust PM2.5',
        "unit": 'µg/m³',
        "sensorType": 'SPS30'
      },
      {
        "id": "4",
        "icon": 'osem-cloud',
        "title": 'Finedust PM4',
        "unit": 'µg/m³',
        "sensorType": 'SPS30'
      },
      {
        "id": "5",
        "icon": 'osem-cloud',
        "title": 'Finedust PM10',
        "unit": 'µg/m³',
        "sensorType": 'SPS30'
      },
      {
        "id": "6",
        "icon": 'osem-signal',
        "title": 'Overtaking Distance',
        "unit": 'cm',
        "sensorType": 'HC-SR04'
      },
      {
        "id": "7",
        "icon": 'osem-shock',
        "title": 'Acceleration X',
        "unit": 'm/s²',
        "sensorType": 'MPU-6050'
      },
      {
        "id": "8",
        "icon": 'osem-shock',
        "title": 'Acceleration Y',
        "unit": 'm/s²',
        "sensorType": 'MPU-6050'
      },
      {
        "id": "9",
        "icon": 'osem-shock',
        "title": 'Acceleration Z',
        "unit": 'm/s²',
        "sensorType": 'MPU-6050'
      },
      {
        "id": "10",
        "icon": 'osem-dashboard',
        "title": 'Speed',
        "unit": 'km/h',
        "sensorType": 'GPS'
      }
    ],
    SenseBoxBikeModel.atrai: [
      {
        "id": "0",
        "icon": 'osem-thermometer',
        "title": 'Temperature',
        "unit": '°C',
        "sensorType": 'HDC1080'
      },
      {
        "id": "1",
        "icon": 'osem-humidity',
        "title": 'Rel. Humidity',
        "unit": '%',
        "sensorType": 'HDC1080'
      },
      {
        "id": "2",
        "icon": 'osem-cloud',
        "title": 'Finedust PM1',
        "unit": 'µg/m³',
        "sensorType": 'SPS30'
      },
      {
        "id": "3",
        "icon": 'osem-cloud',
        "title": 'Finedust PM2.5',
        "unit": 'µg/m³',
        "sensorType": 'SPS30'
      },
      {
        "id": "4",
        "icon": 'osem-cloud',
        "title": 'Finedust PM4',
        "unit": 'µg/m³',
        "sensorType": 'SPS30'
      },
      {
        "id": "5",
        "icon": 'osem-cloud',
        "title": 'Finedust PM10',
        "unit": 'µg/m³',
        "sensorType": 'SPS30'
      },
      {
        "id": "6",
        "icon": 'osem-shock',
        "title": 'Overtaking Car',
        "unit": '%',
        "sensorType": 'VL53L8CX'
      },
      {
        "id": "7",
        "icon": 'osem-shock',
        "title": 'Overtaking Bike',
        "unit": '%',
        "sensorType": 'VL53L8CX'
      },
      {
        "id": "8",
        "icon": 'osem-shock',
        "title": 'Overtaking Distance',
        "unit": 'cm',
        "sensorType": 'VL53L8CX'
      },
      {
        "id": "9",
        "icon": 'osem-shock',
        "title": 'Surface Asphalt',
        "unit": '%',
        "sensorType": 'MPU-6050'
      },
      {
        "id": "10",
        "icon": 'osem-shock',
        "title": 'Surface Sett',
        "unit": '%',
        "sensorType": 'MPU-6050'
      },
      {
        "id": "11",
        "icon": 'osem-shock',
        "title": 'Surface Compacted',
        "unit": '%',
        "sensorType": 'MPU-6050'
      },
      {
        "id": "12",
        "icon": 'osem-shock',
        "title": 'Surface Paving',
        "unit": '%',
        "sensorType": 'MPU-6050'
      },
      {
        "id": "13",
        "icon": 'osem-shock',
        "title": 'Standing',
        "unit": '%',
        "sensorType": 'MPU-6050'
      },
      {
        "id": "14",
        "icon": 'osem-shock',
        "title": 'Surface Anomaly',
        "unit": 'Δ',
        "sensorType": 'MPU-6050'
      },
      {
        "id": "15",
        "icon": 'osem-dashboard',
        "title": 'Speed',
        "unit": 'm/s',
        "sensorType": 'GPS'
      }
    ],
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
