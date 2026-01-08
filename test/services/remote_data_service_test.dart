import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:sensebox_bike/services/remote_data_service.dart';

class MockHttpClient extends Mock implements http.Client {}

void main() {
  group('RemoteDataService', () {
    late MockHttpClient mockHttpClient;
    late RemoteDataService service;
    const testUrl = 'https://example.com/data.json';

    setUp(() {
      mockHttpClient = MockHttpClient();
      service = RemoteDataService(client: mockHttpClient);
    });

    void mockHttpGetResponse(String responseBody, int statusCode) {
      when(() => mockHttpClient.get(Uri.parse(testUrl)))
          .thenAnswer((_) async => http.Response(responseBody, statusCode));
    }

    group('fetchJson()', () {
      test('returns parsed JSON on successful response', () async {
        const responseBody = '''
        [
          {"label": "Campaign 1", "value": "campaign1"}
        ]
        ''';
        mockHttpGetResponse(responseBody, 200);

        final result = await service.fetchJson(testUrl);

        expect(result, isA<List>());
        expect((result as List).length, equals(1));
        expect(result[0]['label'], equals('Campaign 1'));
      });

      test('throws exception on non-200 status code', () async {
        mockHttpGetResponse('Not Found', 404);

        expect(
          () => service.fetchJson(testUrl),
          throwsA(isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Failed to load data from $testUrl: 404'),
          )),
        );
      });

      test('throws exception on invalid JSON', () async {
        mockHttpGetResponse('Invalid JSON', 200);

        expect(
          () => service.fetchJson(testUrl),
          throwsA(isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Failed to parse JSON from $testUrl'),
          )),
        );
      });
    });

    test('uses provided http.Client when injected', () {
      final customClient = MockHttpClient();
      final serviceWithCustomClient = RemoteDataService(client: customClient);
      expect(serviceWithCustomClient, isA<RemoteDataService>());
    });
  });
}

