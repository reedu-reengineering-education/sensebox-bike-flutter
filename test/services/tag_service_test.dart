import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:sensebox_bike/constants.dart';
import 'package:sensebox_bike/services/tag_service.dart';

class MockHttpClient extends Mock implements http.Client {}

void main() {
  group('TagService', () {
    late MockHttpClient mockHttpClient;
    late TagService tagService;

    setUp(() {
      mockHttpClient = MockHttpClient();
      tagService = TagService(client: mockHttpClient); 
    });

    test('should return a list of tags when the response is successful', () async {
      // Arrange
      const mockResponseBody = '''
      [
        {"label": "Tag 1", "value": "value1"},
        {"label": "Tag 2", "value": "value2"},
        {"label": "Tag 3", "value": "value3"}
      ]
      ''';
      when(() => mockHttpClient.get(Uri.parse(tagsUrl)))
          .thenAnswer((_) async => http.Response(mockResponseBody, 200));

      // Act
      final tags = await tagService.loadTags();

      // Assert
      expect(
          tags,
          equals([
            {"label": "Tag 1", "value": "value1"},
            {"label": "Tag 2", "value": "value2"},
            {"label": "Tag 3", "value": "value3"}
          ]));
    });

    test('should throw an exception when the response status code is not 200', () async {
      // Arrange
      when(() => mockHttpClient.get(Uri.parse(tagsUrl)))
          .thenAnswer((_) async => http.Response('Not Found', 404));

      // Act & Assert
      expect(
        () async => await tagService.loadTags(),
        throwsA(isA<Exception>()),
      );
    });

    test('should throw an exception when the response body is invalid JSON', () async {
      // Arrange
      const invalidData = '''
      [
        {"label": "Tag 1", "value": "value1"},
        "Invalid Item"
      ]
      ''';
      when(() => mockHttpClient.get(Uri.parse(tagsUrl)))
          .thenAnswer((_) async => http.Response(invalidData, 200));

      // Act & Assert
      expect(
        () async => await tagService.loadTags(),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Invalid data format'),
        )),
      );
    });
  });
}