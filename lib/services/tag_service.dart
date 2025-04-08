import 'dart:convert';
import 'package:http/http.dart' as http;

class TagService {
  final String tagsUrl =
      'https://raw.githubusercontent.com/reedu-reengineering-education/sensebox-bike-flutter/main/assets/locations.json';
  final http.Client client;

  TagService({http.Client? client}) : client = client ?? http.Client();

  Future<List<String>> loadTags() async {
    final http.Response response = await client.get(Uri.parse(tagsUrl));

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.cast<String>();
    } else {
      throw Exception('Failed to load tags from $tagsUrl');
    }
  }
}