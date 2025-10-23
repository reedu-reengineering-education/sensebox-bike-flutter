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
  final String expiredToken =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyLCJleHAiOjE1MTYyMzkwMjJ9.test_signature';

  setUpAll(() {
    registerFallbackValue(Uri());
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    mockHttpClient = MockClient();
    service =
        OpenSenseMapService(client: mockHttpClient, prefs: Future.value(prefs));
  });

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

  Future<void> setValidTokens() async {
    await Future.wait([
      prefs.setString('refreshToken', accessToken),
      prefs.setString('accessToken', accessToken)
    ]);
  }

  Future<void> setExpiredTokens() async {
    await Future.wait([
      prefs.setString('refreshToken', accessToken),
      prefs.setString('accessToken', expiredToken)
    ]);
  }

  group('Authentication', () {
    group('register()', () {
      test('stores tokens on successful registration', () async {
        mockHTTPPOSTResponse(
            '{"token": "test_token", "refreshToken": "test_refresh"}', 201);

        await service.register('test', 'test@example.com', 'password');

        expect(prefs.getString('accessToken'), 'test_token');
        expect(prefs.getString('refreshToken'), 'test_refresh');
      });

      test('throws exception on registration error', () async {
        mockHTTPPOSTResponse('{"message": "Email already exists"}', 400);
        
        await expectLater(
            service.register('test', 'test@example.com', 'password'),
            throwsException);

        expect(prefs.getString('accessToken'), null);
        expect(prefs.getString('refreshToken'), null);
      });
    });

    group('login()', () {
      test('stores tokens on successful login', () async {
        mockHTTPPOSTResponse(
            '{"token": "test_token", "refreshToken": "test_refresh"}', 200);

        await service.login('test@example.com', 'password');

        expect(prefs.getString('accessToken'), 'test_token');
        expect(prefs.getString('refreshToken'), 'test_refresh');
      });

      test('throws exception on login error', () async {
        mockHTTPPOSTResponse('{"message": "Invalid credentials"}', 400);
        
        await expectLater(
            service.login('test@example.com', 'password'), throwsException);

        expect(prefs.getString('accessToken'), null);
        expect(prefs.getString('refreshToken'), null);
      });
    });

    group('logout()', () {
      test('removes stored tokens', () async {
        await setValidTokens();

        await service.logout();

        expect(prefs.getString('accessToken'), null);
        expect(prefs.getString('refreshToken'), null);
      });
      
      test('completes successfully when no tokens stored', () async {
        await expectLater(service.logout(), completes);
      });
    });
  });

  group('Token Management', () {
    group('getAccessToken()', () {
      test('returns valid token from storage', () async {
        await setValidTokens();

        String? token = await service.getAccessToken();

        expect(token, accessToken);
      });

      test('returns null when no token stored', () async {
        String? token = await service.getAccessToken();

        expect(token, null);
      });

      test('returns null when stored token is expired', () async {
        await setExpiredTokens();

        String? token = await service.getAccessToken();

        expect(token, null);
      });
    });

    group('refreshToken()', () {
      test('stores new tokens on successful refresh', () async {
        await setValidTokens();
        mockHTTPPOSTResponse(
            '{"token": "new_token", "refreshToken": "new_refresh"}', 200);
        
        final tokens = await service.refreshToken();

        expect(tokens, isNotNull);
        expect(tokens!['accessToken'], 'new_token');
        expect(tokens['refreshToken'], 'new_refresh');
        expect(prefs.getString('accessToken'), 'new_token');
        expect(prefs.getString('refreshToken'), 'new_refresh');
      });

      test('throws exception when no refresh token exists', () async {
        mockHTTPPOSTResponse(
            '{"token": "test_token", "refreshToken": "test_refresh"}', 200);

        await expectLater(service.refreshToken(), throwsException);
      });

      test('throws exception on server error', () async {
        await setValidTokens();
        mockHTTPPOSTResponse('{"error": "Invalid refresh token"}', 400);

        await expectLater(service.refreshToken(), throwsException);
      });
    });

    group('getRefreshTokenFromPreferences()', () {
      test('returns stored refresh token', () async {
        await setValidTokens();

        final token = await service.getRefreshTokenFromPreferences();

        expect(token, accessToken);
      });

      test('returns null when no refresh token stored', () async {
        final token = await service.getRefreshTokenFromPreferences();

        expect(token, null);
      });
    });

    group('getAccessTokenFromPreferences()', () {
      test('returns stored access token', () async {
        await setValidTokens();

        final token = await service.getAccessTokenFromPreferences();

        expect(token, accessToken);
      });

      test('returns null when no access token stored', () async {
        final token = await service.getAccessTokenFromPreferences();

        expect(token, null);
      });
    });
  });

  group('API Operations', () {
    group('createSenseBoxBike()', () {
      test('creates sensebox successfully with valid authentication', () async {
        await setValidTokens();
        mockHTTPPOSTResponse('{"id": "sensebox123"}', 201);

        await expectLater(
            service.createSenseBoxBike(
                "Test Box", 52.5200, 13.4050, SenseBoxBikeModel.atrai, null),
            completes);
      });

      test('throws exception when not authenticated', () async {
        mockHTTPPOSTResponse('{"id": "sensebox123"}', 201);

        await expectLater(
            service.createSenseBoxBike(
                "Test Box", 52.5200, 13.4050, SenseBoxBikeModel.atrai, null),
            throwsException);
      });

      test('throws exception on server error', () async {
        await setValidTokens();
        mockHTTPPOSTResponse('{"error": "Invalid data"}', 400);

        await expectLater(
            service.createSenseBoxBike(
                "Test Box", 52.5200, 13.4050, SenseBoxBikeModel.atrai, null),
            throwsException);
      });
    });

    group('getSenseBoxes()', () {
      test('retrieves list of senseboxes successfully', () async {
        await setValidTokens();
        mockHTTPGETResponse(
            '{"data": {"boxes": [{"id": "box1"}, {"id": "box2"}]}}', 200);

        final boxes = await service.getSenseBoxes();

        expect(boxes, [
          {"id": "box1"},
          {"id": "box2"}
        ]);
      });

      test('returns empty list when no senseboxes exist', () async {
        await setValidTokens();
        mockHTTPGETResponse('{"data": {"boxes": []}}', 200);

        final boxes = await service.getSenseBoxes();

        expect(boxes, []);
      });

      test('throws exception when not authenticated', () async {
        mockHTTPGETResponse('{"data": {"boxes": []}}', 200);

        await expectLater(service.getSenseBoxes(), throwsException);
      });

      test('throws exception on server error', () async {
        await setValidTokens();
        mockHTTPGETResponse('{"error": "Server error"}', 500);

        await expectLater(service.getSenseBoxes(), throwsException);
      });

      test('refreshes token and retries on 401 error', () async {
        await setValidTokens();

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
                '{"data": {"boxes": [{"id": "box1"}]}}', 200);
          }
        });

        mockHTTPPOSTResponse(
            '{"token": "$accessToken", "refreshToken": "new_refresh"}', 200);

        final boxes = await service.getSenseBoxes();

        expect(boxes, [{"id": "box1"}]);
        expect(callCount, 2);
      });

      test('refreshes token and retries on 403 error', () async {
        await setValidTokens();

        int callCount = 0;
        when(() => mockHttpClient.get(
              any(),
              headers: any(named: 'headers'),
            )).thenAnswer((_) async {
          callCount++;
          if (callCount == 1) {
            return http.Response('Forbidden', 403);
          } else {
            return http.Response(
                '{"data": {"boxes": [{"id": "box1"}]}}', 200);
          }
        });

        mockHTTPPOSTResponse(
            '{"token": "$accessToken", "refreshToken": "new_refresh"}', 200);

        final boxes = await service.getSenseBoxes();

        expect(boxes, [{"id": "box1"}]);
        expect(callCount, 2);
      });

      test('throws exception when token refresh fails on 401 error', () async {
        await setValidTokens();
        when(() => mockHttpClient.get(
              any(),
              headers: any(named: 'headers'),
            )).thenAnswer((_) async => http.Response('Unauthorized', 401));

        mockHTTPPOSTResponse('{"error": "Invalid refresh token"}', 400);

        await expectLater(service.getSenseBoxes(), throwsException);
      });
    });

    group('uploadData()', () {
      test('uploads sensor data successfully', () async {
        await setValidTokens();
        mockHTTPPOSTResponse('{"success": true}', 201);

        await expectLater(
            service.uploadData('sensebox123', {"sensor1": "value1"}),
            completes);
      });

      test('throws exception when not authenticated', () async {
        when(() => mockHttpClient.post(
              any(),
              headers: any(named: 'headers'),
              body: any(named: 'body'),
            )).thenAnswer((_) async => http.Response('Unauthorized', 401));

        await expectLater(
            service.uploadData('sensebox123', {"sensor1": "value1"}),
            throwsException);
      });

      test('throws exception on client error', () async {
        await setValidTokens();
        when(() => mockHttpClient.post(
              any(),
              headers: any(named: 'headers'),
              body: any(named: 'body'),
            )).thenAnswer((_) async => http.Response('Bad Request', 400));

        await expectLater(
            service.uploadData('sensebox123', {"sensor1": "value1"}),
            throwsException);
      });

      test('automatically refreshes token when access token is expired',
          () async {
        // Set up expired access token but valid refresh token
        await setExpiredTokens();

        // Set up mocks to handle both token refresh and upload requests
        int callCount = 0;
        when(() => mockHttpClient.post(
              any(),
              headers: any(named: 'headers'),
              body: any(named: 'body'),
            )).thenAnswer((invocation) async {
          callCount++;
          final uri = invocation.positionalArguments[0] as Uri;
          
          if (uri.path.contains('/users/refresh-auth')) {
            // Token refresh request
            return http.Response(
                '{"token": "$accessToken", "refreshToken": "new_refresh"}', 200);
          } else if (uri.path.contains('/boxes/sensebox123/data')) {
            // Data upload request
            return http.Response('{"success": true}', 201);
          } else {
            throw Exception('Unexpected request to ${uri.path}');
          }
        });

        await expectLater(
            service.uploadData('sensebox123', {"sensor1": "value1"}),
            completes);
        
        // Verify both requests were made
        expect(callCount, 2);
      });
    });
  });

  group('User Data Management', () {
    group('getUserData()', () {
      test('retrieves user data successfully', () async {
        await setValidTokens();
        mockHTTPGETResponse(
            '{"data": {"me": {"name": "Test User", "email": "test@example.com"}}}',
            200);

        final userData = await service.getUserData();

        expect(userData, isNotNull);
        expect(userData!['data']['me']['name'], 'Test User');
        expect(userData['data']['me']['email'], 'test@example.com');
      });

      test('returns null when not authenticated', () async {
        mockHTTPGETResponse(
            '{"data": {"me": {"name": "Test User", "email": "test@example.com"}}}',
            200);

        final userData = await service.getUserData();

        expect(userData, null);
      });

      test('refreshes token and retries on 401 error', () async {
        await setValidTokens();

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
                '{"data": {"me": {"name": "Test User", "email": "test@example.com"}}}',
                200);
          }
        });

        mockHTTPPOSTResponse(
            '{"token": "$accessToken", "refreshToken": "new_refresh"}', 200);

        final userData = await service.getUserData();

        expect(userData, isNotNull);
        expect(userData!['data']['me']['name'], 'Test User');
        expect(callCount, 2);
      });

      test('refreshes token and retries on 403 error', () async {
        await setValidTokens();

        int callCount = 0;
        when(() => mockHttpClient.get(
              any(),
              headers: any(named: 'headers'),
            )).thenAnswer((_) async {
          callCount++;
          if (callCount == 1) {
            return http.Response('Forbidden', 403);
          } else {
            return http.Response(
                '{"data": {"me": {"name": "Test User", "email": "test@example.com"}}}',
                200);
          }
        });

        mockHTTPPOSTResponse(
            '{"token": "$accessToken", "refreshToken": "new_refresh"}', 200);

        final userData = await service.getUserData();

        expect(userData, isNotNull);
        expect(userData!['data']['me']['name'], 'Test User');
        expect(callCount, 2);
      });

      test('returns null when token refresh fails on 401 error', () async {
        await setValidTokens();
        when(() => mockHttpClient.get(
              any(),
              headers: any(named: 'headers'),
            )).thenAnswer((_) async => http.Response('Unauthorized', 401));

        mockHTTPPOSTResponse('{"error": "Invalid refresh token"}', 400);

        final userData = await service.getUserData();

        expect(userData, null);
      });

      test('returns null on server error', () async {
        await setValidTokens();
        mockHTTPGETResponse('{"error": "Internal server error"}', 500);

        final userData = await service.getUserData();

        expect(userData, null);
      });
    });
  });

  group('Caching & State Management', () {
    group('Token Caching', () {
      test('getAccessToken returns valid token when cached token is valid', () async {
        await setValidTokens();
        final token = await service.getAccessToken();

        expect(token, isNotNull);
        expect(token, isA<String>());
      });

      test('getAccessToken returns null when no cached token', () async {
        final token = await service.getAccessToken();
        expect(token, null);
      });


      test('getAccessToken caches token after first call', () async {
        await setValidTokens();

        final token1 = await service.getAccessToken();
        final token2 = await service.getAccessToken();

        expect(token1, equals(token2));
        expect(token1, isNotNull);
        expect(token2, isNotNull);
      });

      test('cached token is cleared when invalid', () async {
        await setExpiredTokens();

        final token = await service.getAccessToken();

        expect(token, null);
      });
    });

    group('User Data Caching', () {
      test('caches user data after successful API call', () async {
        await setValidTokens();
        mockHTTPGETResponse(
          '{"data": {"me": {"name": "Test User", "email": "test@example.com"}}}',
            200);

        final userData = await service.getUserData();

        expect(userData, isNotNull);
        expect(userData!['data']['me']['name'], 'Test User');
        expect(prefs.getString('userData'), isNotNull);
      });

      test('returns cached data when token is valid', () async {
        await setValidTokens();

        mockHTTPGETResponse(
          '{"data": {"me": {"name": "Test User", "email": "test@example.com"}}}',
          200);
        await service.getUserData();

        // Second call should return cached data without making API call
        final userData = await service.getUserData();

        expect(userData, isNotNull);
        expect(userData!['data']['me']['name'], 'Test User');
      });

      test('logout clears user data cache', () async {
        await setValidTokens();
        mockHTTPGETResponse(
          '{"data": {"me": {"name": "Test User", "email": "test@example.com"}}}',
            200);

        await service.getUserData();
        await service.logout();

        expect(prefs.getString('userData'), null);
      });
    });

    group('Service State', () {
      test('isAcceptingRequests returns true initially', () {
        expect(service.isAcceptingRequests, true);
      });

      test('isPermanentlyDisabled returns false initially', () {
        expect(service.isPermanentlyDisabled, false);
      });

      test('remainingRateLimitTime returns null when not rate limited', () {
        expect(service.remainingRateLimitTime, null);
      });

      test('resetPermanentDisable resets disabled state', () {
        service.resetPermanentDisable();
        expect(service.isPermanentlyDisabled, false);
      });

      test('resetPermanentDisable can be called multiple times safely', () {
        service.resetPermanentDisable();
        service.resetPermanentDisable();
        expect(service.isPermanentlyDisabled, false);
      });

      test('resetPermanentDisable maintains other service state', () {
        final initialAcceptingRequests = service.isAcceptingRequests;
        final initialRateLimitTime = service.remainingRateLimitTime;
        
        service.resetPermanentDisable();
        
        expect(service.isAcceptingRequests, initialAcceptingRequests);
        expect(service.remainingRateLimitTime, initialRateLimitTime);
      });
    });
  });
  group('Factory & Utility Methods', () {
    group('createSenseBoxBikeModel()', () {
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

      test('creates atrai model with correct grouptag', () {
        final model = service.createSenseBoxBikeModel(
          'Test Box',
          13.4050,
          52.5200,
          model: SenseBoxBikeModel.atrai,
        );

        expect(model['grouptag'], ['bike', 'atrai']);
        expect(model['sensors'], service.sensors[SenseBoxBikeModel.atrai]);
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

      test('ignores empty selected tag', () {
        final model = service.createSenseBoxBikeModel(
          'Test Box',
          13.4050,
          52.5200,
          selectedTag: '',
        );

        expect(model['grouptag'], ['bike', 'classic']);
      });

      test('handles coordinates correctly', () {
        final model = service.createSenseBoxBikeModel('Test', 13.4050, 52.5200);

        expect(model['location'], [52.5200, 13.4050]);
      });
    });

    group('sensors Configuration', () {
      test('contains configurations for both bike models', () {
        expect(service.sensors.containsKey(SenseBoxBikeModel.classic), true);
        expect(service.sensors.containsKey(SenseBoxBikeModel.atrai), true);
      });

      test('classic and atrai models have sensor lists', () {
        final classicSensors = service.sensors[SenseBoxBikeModel.classic];
        final atraiSensors = service.sensors[SenseBoxBikeModel.atrai];

        expect(classicSensors, isNotNull);
        expect(atraiSensors, isNotNull);
        expect(classicSensors, isA<List>());
        expect(atraiSensors, isA<List>());
      });

      test('sensor lists are not empty', () {
        final classicSensors = service.sensors[SenseBoxBikeModel.classic]!;
        final atraiSensors = service.sensors[SenseBoxBikeModel.atrai]!;

        expect(classicSensors.isNotEmpty, true);
        expect(atraiSensors.isNotEmpty, true);
      });
    });
  });
}