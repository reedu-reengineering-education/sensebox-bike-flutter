import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:sensebox_bike/services/opensensemap_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockClient extends Mock implements http.Client {}

void main() {
  late OpenSenseMapService service;
  late MockClient mockHttpClient;
  late SharedPreferences prefs;
  final String accessToken = 'accessToken';

  setUpAll(() {
    registerFallbackValue(Uri()); // Register fallback Uri
  });

  setUp(() async {
    // Initialize in-memory SharedPreferences
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    mockHttpClient = MockClient();
    service = OpenSenseMapService(client: mockHttpClient,  prefs: SharedPreferences.getInstance());
  });

  tearDown(() async {
    // Clear SharedPreferences after each test
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
    await Future.wait([
      prefs.setString('refreshToken', 'value'),
      prefs.setString('accessToken', accessToken)
    ]);
  }
  group('register()', () {
    test('if gets 201 response, stores tokens in SharedPreferences', () async {
      mockHTTPPOSTResponse('{"token": "test_token", "refreshToken": "test_refresh"}', 201);

      await service.register('test', 'test@example.com', 'password');

      expect(prefs.getString('accessToken'), 'test_token');
      expect(prefs.getString('refreshToken'), 'test_refresh');
    });

    test('if gets error, throws exception and does not store tokens', () async {
      mockHTTPPOSTResponse('Error', 400);
      
      await expectLater(service.register('test', 'test@example.com', 'password'), throwsException);

      expect(prefs.getString('accessToken'), null);
      expect(prefs.getString('refreshToken'), null);
    });
  });

  group('login()', () {
    test('if gets 201 response, stores tokens in SharedPreferences', () async {
      mockHTTPPOSTResponse('{"token": "test_token", "refreshToken": "test_refresh"}', 200);

      await service.login('test@example.com', 'password');

      expect(prefs.getString('accessToken'), 'test_token');
      expect(prefs.getString('refreshToken'), 'test_refresh');
    });

    test('if gets error, throws exception and does not store tokens', () async {
      mockHTTPPOSTResponse('Error', 400);
      
      await expectLater(service.login('test@example.com', 'password'), throwsException);

      expect(prefs.getString('accessToken'), null);
      expect(prefs.getString('refreshToken'), null);
    });
  });

  group('logout()', () {
    test('removes keys', () async {
      await setTokens();

      await service.logout();

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
      await setTokens();

      String? token = await service.getAccessToken();
      
      expect(token, accessToken);
    });

    test('when no token, returns empty string', () async {
      String? token = await service.getAccessToken();
      
      expect(token, null);
    });
  });
  group('refreshToken()', () {
    test('when successful, new access and refresh tokens are stored correctly', () async {
      await setTokens();
      mockHTTPPOSTResponse('{"token": "test_token", "refreshToken": "test_refresh"}', 200);
      
      await service.refreshToken();

      expect(prefs.getString('accessToken'), 'test_token');
      expect(prefs.getString('refreshToken'), 'test_refresh');
    });

    test('when no refresh token, throws exception', () async {
      mockHTTPPOSTResponse('{"token": "test_token", "refreshToken": "test_refresh"}', 200);
      
      await expectLater(service.refreshToken(), throwsException);

      expect(prefs.getString('accessToken'), null);
      expect(prefs.getString('refreshToken'), null);
    });

    test('when no receives error, throws exception', () async {
      mockHTTPPOSTResponse('error', 400);
      
      await expectLater(service.refreshToken(), throwsException);

      expect(prefs.getString('accessToken'), null);
      expect(prefs.getString('refreshToken'), null);
    });
  });

  group('createSenseBoxBike()', () {
    test('when valid params, completes successfully', () async {
      await setTokens();
      mockHTTPPOSTResponse('valid box data', 201);

      await expectLater(
          service.createSenseBoxBike(
              "name", 0, 0, SenseBoxBikeModel.atrai, null),
          completes); 
    });

    test('when no refresh token, throws exception', () async {
      mockHTTPPOSTResponse('valid box data', 201);

      await expectLater(
          service.createSenseBoxBike(
              "name", 0, 0, SenseBoxBikeModel.atrai, null),
          throwsException);
    });

    test('when receives error response, throws exception', () async {
      await setTokens();
      mockHTTPPOSTResponse('valid box data', 400);

      await expectLater(
          service.createSenseBoxBike(
              "name", 0, 0, SenseBoxBikeModel.atrai, null),
          throwsException);
    });
  });

  group('getSenseBoxes()', () {
    test('when success, retrieves list of boxes', () async {
      await setTokens();
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

  group('getUserData()', () {
    test('when success, retrieves user data', () async {
      await setTokens();
      mockHTTPGETResponse(
          '{"name": "Test User", "email": "test@example.com"}', 200);

      var userData = await service.getUserData();

      expect(userData, {"name": "Test User", "email": "test@example.com"});
    });

    test('when no accessToken, throws error', () async {
      mockHTTPGETResponse(
          '{"name": "Test User", "email": "test@example.com"}', 200);

      await expectLater(service.getUserData(), throwsException);
    });

    test('when receives 401, refreshes token and retries once', () async {
      await setTokens();

      int callCount = 0;
      when(() => mockHttpClient.get(
            any(),
            headers: any(named: 'headers'),
          )).thenAnswer((_) async {
        callCount++;
        if (callCount == 1) {
          return http.Response('Unauthorized', 401);
        } else {
          return http.Response(
              '{"name": "Test User", "email": "test@example.com"}', 200);
        }
      });

      // Mock successful token refresh
      mockHTTPPOSTResponse(
          '{"token": "new_token", "refreshToken": "new_refresh"}', 200);

      var userData = await service.getUserData();

      expect(userData, {"name": "Test User", "email": "test@example.com"});
    });

    test('when receives 401 after token refresh, throws exception', () async {
      await setTokens();
      // Both calls return 401
      when(() => mockHttpClient.get(
            any(),
            headers: any(named: 'headers'),
          )).thenAnswer((_) async => http.Response('Unauthorized', 401));

      // Mock successful token refresh
      mockHTTPPOSTResponse(
          '{"token": "new_token", "refreshToken": "new_refresh"}', 200);

      await expectLater(service.getUserData(), throwsException);
    });

    test('when token refresh fails, throws exception', () async {
      await setTokens();
      // First call returns 401
      when(() => mockHttpClient.get(
            any(),
            headers: any(named: 'headers'),
          )).thenAnswer((_) async => http.Response('Unauthorized', 401));

      // Mock failed token refresh
      mockHTTPPOSTResponse('{"error": "Invalid refresh token"}', 400);

      await expectLater(service.getUserData(), throwsException);
    });

    test('when receives error response other than 401, throws error', () async {
      await setTokens();
      mockHTTPGETResponse('error', 500);

      await expectLater(service.getUserData(), throwsException);
    });
  });
}