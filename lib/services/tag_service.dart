import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:sensebox_bike/constants.dart';

class TagService {
  final http.Client client;

  TagService({http.Client? client}) : client = client ?? http.Client();

  Future<List<Map<String, String>>> loadTags() async {
    final http.Response response = await client.get(Uri.parse(tagsUrl));

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);

      // Ensure the data is cast to List<Map<String, String>>
      return data.map((item) {
        if (item is Map<String, dynamic>) {
          return item.map((key, value) => MapEntry(key, value.toString()));
        } else {
          throw Exception('Invalid data format: Expected Map<String, dynamic>');
        }
      }).toList();
    } else {
      throw Exception('Failed to load tags from $tagsUrl');
    }
  }
}