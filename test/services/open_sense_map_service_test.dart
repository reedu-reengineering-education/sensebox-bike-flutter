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
    
    service = OpenSenseMapService(
      client: mockHttpClient,
      prefs: Future.value(prefs),
    );
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

  });

  group('API Operations', () {
    group('createSenseBoxBike()', () {
      test('creates sensebox successfully with valid authentication', () async {
        await setValidTokens();
        mockHTTPPOSTResponse('{"id": "sensebox123"}', 201);

        final model = {
          'name': 'Test Box',
          'exposure': 'mobile',
          'location': [52.5200, 13.4050],
          'grouptag': ['bike', 'atrai'],
          'sensors': [],
        };

        await expectLater(service.createSenseBoxBike(model), completes);
      });

      test('throws exception on error', () async {
        await setValidTokens();
        mockHTTPPOSTResponse('{"error": "Invalid data"}', 400);

        final model = {
          'name': 'Test Box',
          'exposure': 'mobile',
          'location': [52.5200, 13.4050],
          'grouptag': ['bike', 'atrai'],
          'sensors': [],
        };

        await expectLater(service.createSenseBoxBike(model), throwsException);
      });

      test('throws exception on error', () async {
        await setValidTokens();
        mockHTTPPOSTResponse('{"error": "Invalid data"}', 400);

        final model = {
          'name': 'Test Box',
          'exposure': 'mobile',
          'location': [52.5200, 13.4050],
          'grouptag': ['bike', 'atrai'],
          'sensors': [],
        };

        await expectLater(service.createSenseBoxBike(model), throwsException);
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

      test('throws exception when not authenticated', () async {
        mockHTTPGETResponse('{"data": {"boxes": []}}', 200);

        await expectLater(service.getSenseBoxes(), throwsException);
      });

      test('refreshes token and retries on authentication error', () async {
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
        mockHTTPGETResponse(
          '{"data": {"box": {"_id": "sensebox123", "useAuth": true, "access_token": "box-token-123"}}}',
          200,
        );
        mockHTTPPOSTResponse('{"success": true}', 201);

        await expectLater(
            service.uploadData('sensebox123', {"sensor1": "value1"}),
            completes);
      });

      test('throws exception on error', () async {
        await setValidTokens();
        mockHTTPGETResponse(
          '{"data": {"box": {"_id": "sensebox123", "useAuth": true, "access_token": "box-token-123"}}}',
          200,
        );
        when(() => mockHttpClient.post(
              any(),
              headers: any(named: 'headers'),
              body: any(named: 'body'),
            )).thenAnswer((_) async => http.Response('Bad Request', 400));

        await expectLater(
            service.uploadData('sensebox123', {"sensor1": "value1"}),
            throwsException);
      });

      test('loads missing box token and uploads with box auth', () async {
        await setValidTokens();
        mockHTTPGETResponse(
          '{"data": {"box": {"_id": "sensebox123", "useAuth": true, "access_token": "box-token-123"}}}',
          200,
        );
        mockHTTPPOSTResponse('{"success": true}', 201);

        await expectLater(
          service.uploadData(
            'sensebox123',
            {"sensor1": "value1"},
          ),
          completes,
        );
      });

      test(
          'loads missing box token when user box endpoint returns direct data shape',
          () async {
        await setValidTokens();
        mockHTTPGETResponse(
          '{"data": {"_id": "sensebox123", "useAuth": true, "access_token": "box-token-xyz"}}',
          200,
        );
        mockHTTPPOSTResponse('{"success": true}', 201);

        await expectLater(
          service.uploadData(
            'sensebox123',
            {"sensor1": "value1"},
          ),
          completes,
        );
      });

      test('prefers fresh server box token over stale cached token', () async {
        await setValidTokens();

        when(() => mockHttpClient.get(
              any(),
              headers: any(named: 'headers'),
            )).thenAnswer((_) async => http.Response(
                  '{"data": {"box": {"_id": "sensebox123", "useAuth": true, "access_token": "fresh-token"}}}',
                  200,
                ));

        when(() => mockHttpClient.post(
              any(),
              headers: any(named: 'headers'),
              body: any(named: 'body'),
            )).thenAnswer((invocation) async {
          final headers =
              invocation.namedArguments[#headers] as Map<String, String>;
          final authHeader = headers['Authorization'];
          if (authHeader == 'fresh-token') {
            return http.Response('{"success": true}', 201);
          }
          return http.Response('{"message":"device access token not valid"}', 401);
        });

        await expectLater(
          service.uploadData(
            'sensebox123',
            {"sensor1": "value1"},
            boxAccessToken: 'stale-token',
          ),
          completes,
        );
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

      test('refreshes token and retries on authentication error', () async {
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

      test('returns null when token refresh fails', () async {
        await setValidTokens();
        when(() => mockHttpClient.get(
              any(),
              headers: any(named: 'headers'),
            )).thenAnswer((_) async => http.Response('Unauthorized', 401));

        mockHTTPPOSTResponse('{"error": "Invalid refresh token"}', 400);

        final userData = await service.getUserData();

        expect(userData, null);
      });
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

  group('saveUserData', () {
    test('saves user data from registration or login response format', () async {
      final responseData = {
        'data': {
          'user': {
            'name': 'Test User',
            'email': 'test@example.com',
            'role': 'user'
          }
        }
      };

      final result = await service.saveUserData(responseData);

      expect(result, isTrue);

      final savedUserData = await service.getUserData();
      expect(savedUserData, isNotNull);
      expect(savedUserData!['data']['me']['name'], equals('Test User'));
      expect(savedUserData['data']['me']['email'], equals('test@example.com'));
    });

    test('returns false when data format is invalid', () async {
      final responseData = {
        'data': {'other': 'value'}
      };

      final result = await service.saveUserData(responseData);

      expect(result, isFalse);
    });

    test('handles null values in user data', () async {
      final responseData = {
        'data': {
          'user': {
            'name': 'User with nulls',
            'email': null,
            'role': 'user',
            'preferences': null
          }
        }
      };

      final result = await service.saveUserData(responseData);

      expect(result, isTrue);

      final savedUserData = await service.getUserData();
      expect(savedUserData, isNotNull);
      final userData = savedUserData!['data']['me'];

      expect(userData['name'], equals('User with nulls'));
      expect(userData['email'], isNull);
      expect(userData['role'], equals('user'));
      expect(userData['preferences'], isNull);
    });
  });
}