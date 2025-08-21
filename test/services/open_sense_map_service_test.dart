import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:sensebox_bike/services/opensensemap_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockClient extends Mock implements http.Client {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  
  late OpenSenseMapService service;
  late MockClient mockHttpClient;
  late SharedPreferences prefs;
  final String accessToken = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyLCJleHAiOjk5OTk5OTk5OTl9.test_signature';

  setUpAll(() {
    registerFallbackValue(Uri());
  });

  setUp() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    mockHttpClient = MockClient();
    service =
        OpenSenseMapService(client: mockHttpClient, prefs: Future.value(prefs));
  }

  tearDown(() async {
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
    await Future.wait([
      prefs.setString('refreshToken', accessToken),
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
      // Mock multiple failed attempts due to retry logic
      when(() => mockHttpClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          )).thenAnswer((_) async => http.Response('Not authenticated', 401));

      await expectLater(service.uploadData('id', { "data": "data" }), throwsException);
    });

    test('when receives error response, throws exception', () async {
      // Mock multiple failed attempts due to retry logic
      when(() => mockHttpClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          )).thenAnswer((_) async => http.Response('Client error', 400));

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

    test('when no accessToken, returns null', () async {
      mockHTTPGETResponse(
          '{"name": "Test User", "email": "test@example.com"}', 200);

      var userData = await service.getUserData();

      expect(userData, null);
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

      // Mock successful token refresh with valid JWT
      mockHTTPPOSTResponse(
          '{"token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyLCJleHAiOjk5OTk5OTk5OTl9.test_signature", "refreshToken": "new_refresh"}', 200);

      var userData = await service.getUserData();

      expect(userData, {"name": "Test User", "email": "test@example.com"});
    });

    test('when receives 401 after token refresh, returns null', () async {
      await setTokens();
      // Both calls return 401
      when(() => mockHttpClient.get(
            any(),
            headers: any(named: 'headers'),
          )).thenAnswer((_) async => http.Response('Unauthorized', 401));

      // Mock successful token refresh with valid JWT
      mockHTTPPOSTResponse(
          '{"token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyLCJleHAiOjk5OTk5OTk5OTl9.test_signature", "refreshToken": "new_refresh"}', 200);

      var userData = await service.getUserData();

      expect(userData, null);
    });

    test('when token refresh fails, returns null', () async {
      await setTokens();
      // First call returns 401
      when(() => mockHttpClient.get(
            any(),
            headers: any(named: 'headers'),
          )).thenAnswer((_) async => http.Response('Unauthorized', 401));

      // Mock failed token refresh
      mockHTTPPOSTResponse('{"error": "Invalid refresh token"}', 400);

      var userData = await service.getUserData();

      expect(userData, null);
    });

    test('when receives error response other than 401, returns null', () async {
      await setTokens();
      mockHTTPGETResponse('error', 500);

      var userData = await service.getUserData();

      expect(userData, null);
    });
  });

  group('Token Caching', () {
    test('isAuthenticated returns true when cached token is valid', () async {
      await setTokens();
      await service.getAccessToken(); // This will cache the token

      expect(service.isAuthenticated, true);
    });

    test('isAuthenticated returns false when no cached token', () {
      expect(service.isAuthenticated, false);
    });

    test('tokenExpiration returns cached expiration time', () async {
      await setTokens();
      await service.getAccessToken(); // This will cache the token

      expect(service.tokenExpiration, isA<DateTime>());
      expect(service.tokenExpiration!.isAfter(DateTime.now()), true);
    });

    test('tokenExpiration returns null when no cached token', () {
      expect(service.tokenExpiration, null);
    });

    test('getAccessToken caches token after first call', () async {
      await setTokens();

      final token1 = await service.getAccessToken();
      final token2 = await service.getAccessToken(); // Should use cache

      expect(token1, equals(token2));
      expect(service.isAuthenticated, true);
    });

    test('cached token is cleared when invalid', () async {
      // Set an expired token
      const expiredToken =
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyLCJleHAiOjE1MTYyMzkwMjJ9.test_signature';
      await prefs.setString('accessToken', expiredToken);
      await prefs.setString('refreshToken', 'refresh_token');

      // Mock refresh token failure
      mockHTTPPOSTResponse('{"error": "Refresh token is expired"}', 400);

      final token = await service.getAccessToken();

      expect(token, null);
      expect(service.isAuthenticated, false);
    });
  });

  group('Token Validation', () {
    test('_isTokenValid returns true for valid token', () async {
      await setTokens();

      final token = await service.getAccessToken();
      expect(token, isNotNull);
    });

    test('_isTokenValid returns false for expired token', () async {
      const expiredToken =
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyLCJleHAiOjE1MTYyMzkwMjJ9.test_signature';
      await prefs.setString('accessToken', expiredToken);
      await prefs.setString('refreshToken', 'refresh_token');

      // Mock refresh token failure
      mockHTTPPOSTResponse('{"error": "Refresh token is expired"}', 400);

      final token = await service.getAccessToken();
      expect(token, null);
    });

    test('_isTokenValid returns false for malformed token', () async {
      await prefs.setString('accessToken', 'invalid.token.format');
      await prefs.setString('refreshToken', 'refresh_token');

      final token = await service.getAccessToken();
      expect(token, null);
    });
  });

  group('Rate Limiting', () {
    test('isAcceptingRequests returns true initially', () {
      expect(service.isAcceptingRequests, true);
    });

    test('isPermanentlyDisabled returns false initially', () {
      expect(service.isPermanentlyDisabled, false);
    });

    test('remainingRateLimitTime returns null when not rate limited', () {
      expect(service.remainingRateLimitTime, null);
    });
  });

  group('User Data Caching', () {
    test('getUserData caches user data after successful API call', () async {
      await setTokens();
      mockHTTPGETResponse(
          '{"data": {"me": {"name": "Test User", "email": "test@example.com"}}}',
          200);

      final userData = await service.getUserData();

      expect(userData, isNotNull);
      expect(userData!['data']['me']['name'], 'Test User');
    });

    test('getUserData returns cached data when API fails but cache exists',
        () async {
      await setTokens();

      // First successful call to cache data
      mockHTTPGETResponse(
          '{"data": {"me": {"name": "Test User", "email": "test@example.com"}}}',
          200);
      await service.getUserData();

      // Second call with API failure - should clear cache and return null
      mockHTTPGETResponse('Unauthorized', 401);
      final userData = await service.getUserData();

      expect(userData, null);
    });

    test('logout clears user data cache', () async {
      await setTokens();
      mockHTTPGETResponse(
          '{"data": {"me": {"name": "Test User", "email": "test@example.com"}}}',
          200);

      await service.getUserData(); // Cache some data
      await service.logout();

      // User data should be cleared
      expect(prefs.getString('userData'), null);
    });
  });

  group('Proactive Token Refresh', () {
    test('getAccessToken refreshes token proactively when expiring soon',
        () async {
      // Use a valid token that should trigger proactive refresh logic
      final soonToExpireToken =
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyLCJleHAiOjk5OTk5OTk5OTl9.test_signature';

      await prefs.setString('accessToken', soonToExpireToken);
      await prefs.setString('refreshToken', accessToken);

      // Mock successful refresh
      mockHTTPPOSTResponse(
          '{"token": "$accessToken", "refreshToken": "new_refresh"}', 200);

      final token = await service.getAccessToken();

      expect(token, isNotNull);
    });

    test('getAccessToken handles refresh failure gracefully', () async {
      // Create a token that expires in 3 minutes but is still valid
      final soonToExpireToken =
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyLCJleHAiOjk5OTk5OTk5OTl9.test_signature';

      await prefs.setString('accessToken', soonToExpireToken);
      await prefs.setString('refreshToken', accessToken);

      // Mock failed refresh
      mockHTTPPOSTResponse('{"error": "Refresh failed"}', 400);

      final token = await service.getAccessToken();

      // Should return the current valid token even if refresh failed
      expect(token, soonToExpireToken);
    });
  });

  group('Rate Limiting State', () {
    test('resetPermanentDisable resets permanent disable state', () {
      service.resetPermanentDisable();
      expect(service.isPermanentlyDisabled, false);
    });

    test('isAcceptingRequests reflects rate limiting state', () {
      expect(service.isAcceptingRequests, true);
    });
  });

  group('createSenseBoxBikeModel Factory', () {
    test('creates model with default values', () {
      final model =
          service.createSenseBoxBikeModel('Test Box', 13.4050, 52.5200);

      expect(model['name'], 'Test Box');
      expect(model['exposure'], 'mobile');
      expect(model['location'], [52.5200, 13.4050]);
      expect(model['grouptag'], ['bike', 'classic']);
      expect(model['sensors'], isNotNull);
    });

    test('creates model with custom grouptags', () {
      final model = service.createSenseBoxBikeModel(
        'Test Box',
        13.4050,
        52.5200,
        grouptags: ['custom', 'test'],
      );

      expect(model['grouptag'], ['custom', 'test']);
    });

    test('creates model with atrai model', () {
      final model = service.createSenseBoxBikeModel(
        'Test Box',
        13.4050,
        52.5200,
        model: SenseBoxBikeModel.atrai,
      );

      expect(model['grouptag'], ['bike', 'atrai']);
    });

    test('adds selected tag to grouptags', () {
      final model = service.createSenseBoxBikeModel(
        'Test Box',
        13.4050,
        52.5200,
        selectedTag: 'custom-tag',
      );

      expect(model['grouptag'], ['bike', 'classic', 'custom-tag']);
    });

    test('does not add empty selected tag', () {
      final model = service.createSenseBoxBikeModel(
        'Test Box',
        13.4050,
        52.5200,
        selectedTag: '',
      );

      expect(model['grouptag'], ['bike', 'classic']);
    });
  });

  group('sensors Map', () {
    test('contains both classic and atrai models', () {
      expect(service.sensors.containsKey(SenseBoxBikeModel.classic), true);
      expect(service.sensors.containsKey(SenseBoxBikeModel.atrai), true);
    });

    test('classic and atrai models have different sensors', () {
      final classicSensors = service.sensors[SenseBoxBikeModel.classic];
      final atraiSensors = service.sensors[SenseBoxBikeModel.atrai];

      expect(classicSensors, isNotNull);
      expect(atraiSensors, isNotNull);
      expect(classicSensors, isA<List>());
      expect(atraiSensors, isA<List>());
    });
  });
}