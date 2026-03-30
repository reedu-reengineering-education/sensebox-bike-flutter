import 'dart:convert';
import 'package:http/http.dart' as http;

class RemoteDataService {
  final http.Client client;

  RemoteDataService({http.Client? client})
      : client = client ?? http.Client();

  Future<dynamic> fetchJson(String url) async {
    final http.Response response = await client.get(Uri.parse(url));

    if (response.statusCode == 200) {
      try {
        return json.decode(response.body);
      } catch (e) {
        throw Exception('Failed to parse JSON from $url: $e');
      }
    } else {
      throw Exception('Failed to load data from $url: ${response.statusCode}');
    }
  }
}

