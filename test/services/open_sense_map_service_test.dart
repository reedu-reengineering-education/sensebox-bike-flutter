import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:sensebox_bike/services/opensensemap_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockClient extends Mock implements http.Client {}

void main() {
  late OpenSenseMapService service;
  late MockClient mockHttpClient;

  setUpAll(() {
    registerFallbackValue(Uri()); // Register fallback Uri
    //registerFallbackValue(<String, String>{}); // For headers if needed
  });

  setUp(() {
    // Initialize in-memory SharedPreferences
    SharedPreferences.setMockInitialValues({});
    mockHttpClient = MockClient();
    service = OpenSenseMapService(client: mockHttpClient,  prefs: SharedPreferences.getInstance());
  });

  tearDown(() async {
    // Clear SharedPreferences after each test
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  });

  void mockHTTPPOSTResponse(String response, int code) {
    when(() => mockHttpClient.post(
      any(),
      headers: any(named: 'headers'),
      body: any(named: 'body'),
    )).thenAnswer((_) async => http.Response(response, code));
  }

  void mockHTTPGETResponse(String response, int code) {
    when(() => mockHttpClient.get(
      any(),
      headers: any(named: 'headers'),
    )).thenAnswer((_) async => http.Response(response, code));
  }

  Future<void> setTokens() async {
    // Set refreshToken
      final prefs = await SharedPreferences.getInstance();
      await Future.wait([
        prefs.setString('refreshToken', 'value'),
        prefs.setString('accessToken', 'value')
      ]);
  }
  group('register()', () {
    test('if gets 201 response, stores tokens in SharedPreferences', () async {
      // Mock HTTP response
      mockHTTPPOSTResponse('{"token": "test_token", "refreshToken": "test_refresh"}', 201);

      await service.register('test', 'test@example.com', 'password');

      // Verify SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('accessToken'), 'test_token');
      expect(prefs.getString('refreshToken'), 'test_refresh');
    });

    test('if gets error, throws exception and does not store tokens', () async {
      // Mock HTTP response
      mockHTTPPOSTResponse('Error', 400);
      
      // Function throws an error
      await expectLater(service.register('test', 'test@example.com', 'password'), throwsException);

      // Verify SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('accessToken'), null);
      expect(prefs.getString('refreshToken'), null);
    });
  });

  group('login()', () {
    test('if gets 201 response, stores tokens in SharedPreferences', () async {
      // Mock HTTP response
      mockHTTPPOSTResponse('{"token": "test_token", "refreshToken": "test_refresh"}', 200);

      await service.login('test@example.com', 'password');

      // Verify SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('accessToken'), 'test_token');
      expect(prefs.getString('refreshToken'), 'test_refresh');
    });

    test('if gets error, throws exception and does not store tokens', () async {
      // Mock HTTP response
      mockHTTPPOSTResponse('Error', 400);
      
      // Function throws an error
      await expectLater(service.login('test@example.com', 'password'), throwsException);

      // Verify SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('accessToken'), null);
      expect(prefs.getString('refreshToken'), null);
    });
  });

  group('logout()', () {
    test('removes keys', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('accessToken', 'value');
      await prefs.setString('refreshToken', 'value');

      await service.logout();

      // Verify SharedPreferences
      expect(prefs.getString('accessToken'), null);
      expect(prefs.getString('refreshToken'), null);
    });
    test('when no keys stored, does not throw error', () async {
      // Verifies completion without errors
      await expectLater(service.logout(), completes); 
    });
  });

  group('getAccessToken()', () {
    test('when token exists, returns it', () async {
      const value = 'token';
      // Set accessToken
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('accessToken', value);

      String? accessToken = await service.getAccessToken();
      
      expect(accessToken, value);
    });

    test('when no token, returns empty string', () async {
      String? accessToken = await service.getAccessToken();
      
      expect(accessToken, null);
    });
  });
  group('refreshToken()', () {
    test('when successful, new access and refresh tokens are stored correctly', () async {
      // Set refreshToken
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('refreshToken', 'value');
      // Mock HTTP response
      mockHTTPPOSTResponse('{"token": "test_token", "refreshToken": "test_refresh"}', 200);
      
      await service.refreshToken();

      // Verify SharedPreferences
      expect(prefs.getString('accessToken'), 'test_token');
      expect(prefs.getString('refreshToken'), 'test_refresh');
    });

    test('when no refresh token, throws exception', () async {
      // Mock HTTP response
      mockHTTPPOSTResponse('{"token": "test_token", "refreshToken": "test_refresh"}', 200);
      
      await expectLater(service.refreshToken(), throwsException);
      // Verify SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('accessToken'), null);
      expect(prefs.getString('refreshToken'), null);
    });

    test('when no receives error, throws exception', () async {
      // Mock HTTP response
      mockHTTPPOSTResponse('error', 400);
      
      await expectLater(service.refreshToken(), throwsException);
      // Verify SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('accessToken'), null);
      expect(prefs.getString('refreshToken'), null);
    });
  });

  group('createSenseBoxBike()', () {
    test('when valid params, completes successfully', () async {
      await setTokens();
      mockHTTPPOSTResponse('valid box data', 201);

      // Verifies completion without errors
      await expectLater(service.createSenseBoxBike("name", 0, 0,SenseBoxBikeModel.atrai), completes); 
    });

    test('when no refresh token, throws exception', () async {
      mockHTTPPOSTResponse('valid box data', 201);

      await expectLater(service.createSenseBoxBike("name", 0, 0,SenseBoxBikeModel.atrai), throwsException);
    });

    test('when receives error response, throws exception', () async {
      await setTokens();
      mockHTTPPOSTResponse('valid box data', 400);

      await expectLater(service.createSenseBoxBike("name", 0, 0,SenseBoxBikeModel.atrai), throwsException);
    });
  });

  group('getSenseBoxes()', () {
    test('when success, retrieves list of boxes', () async {
      await setTokens();
      // Mock HTTP response
      mockHTTPGETResponse('{"data": {"boxes": []}}', 200);
      var boxes = await service.getSenseBoxes();

      expect(boxes, []);
    });

    test('when no accessToken, throws error', () async {
      mockHTTPGETResponse('{"data": {"boxes": []}}', 200);

      await expectLater(service.getSenseBoxes(), throwsException);
    });

    test('when recieves error response, throws error', () async {
      mockHTTPGETResponse('error', 400);

      await expectLater(service.getSenseBoxes(), throwsException);
    });
  });
  group('uploadData()', () {
    test('when valid params, finishes successfully', () async {
      await setTokens();
      mockHTTPPOSTResponse('valid data', 201);

      // Verifies completion without errors
      await expectLater(service.uploadData('id', { "data": "data" }), completes); 
    });

    test('when no valid accessToken, throws exception', () async {
      mockHTTPPOSTResponse('valid data', 201);

      await expectLater(service.uploadData('id', { "data": "data" }), throwsException);
    });

    test('when receives error response, throws exception', () async {
      mockHTTPPOSTResponse('valid data', 400);

      await expectLater(service.uploadData('id', { "data": "data" }), throwsException);
    });
  });
}
