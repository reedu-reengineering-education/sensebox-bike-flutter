import 'package:flutter_test/flutter_test.dart';
import 'package:sensebox_bike/utils/opensensemap_utils.dart';

void main() {
  group('OpenSenseMap Utils', () {
    group('safeJsonDecode', () {
      test('parses valid JSON successfully', () {
        const jsonString = '{"message": "success", "data": {"id": 123}}';
        final result = safeJsonDecode(jsonString);
        
        expect(result['message'], 'success');
        expect(result['data']['id'], 123);
      });

      test('parses complex nested JSON successfully', () {
        const jsonString = '''
        {
          "user": {
            "id": "123",
            "email": "test@example.com",
            "profile": {
              "name": "John Doe",
              "settings": {
                "notifications": true
              }
            }
          },
          "tokens": {
            "accessToken": "abc123",
            "refreshToken": "def456"
          }
        }
        ''';
        final result = safeJsonDecode(jsonString);
        
        expect(result['user']['email'], 'test@example.com');
        expect(result['user']['profile']['name'], 'John Doe');
        expect(result['tokens']['accessToken'], 'abc123');
      });

      test('throws exception for empty string', () {
        expect(
          () => safeJsonDecode(''),
          throwsA(isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Empty response from API'),
          )),
        );
      });

      test('throws exception for invalid JSON syntax', () {
        const invalidJson = '{"invalid": json}';
        expect(
          () => safeJsonDecode(invalidJson),
          throwsA(isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Invalid JSON response from API'),
          )),
        );
      });

      test('throws exception for malformed JSON with missing quotes', () {
        const malformedJson = '{message: "test"}';
        expect(
          () => safeJsonDecode(malformedJson),
          throwsA(isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Invalid JSON response from API'),
          )),
        );
      });

      test('throws exception for incomplete JSON', () {
        const incompleteJson = '{"message": "test"';
        expect(
          () => safeJsonDecode(incompleteJson),
          throwsA(isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Invalid JSON response from API'),
          )),
        );
      });

      test('throws exception for non-JSON string', () {
        const nonJson = 'This is not JSON at all';
        expect(
          () => safeJsonDecode(nonJson),
          throwsA(isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Invalid JSON response from API'),
          )),
        );
      });

      test('handles whitespace-only string as empty', () {
        expect(
          () => safeJsonDecode('   '),
          throwsA(isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Empty response from API'),
          )),
        );
      });

      test('parses JSON with whitespace correctly', () {
        const jsonWithWhitespace = '  {"message": "test"}  ';
        final result = safeJsonDecode(jsonWithWhitespace);
        expect(result['message'], 'test');
      });
    });

    group('extractUserData', () {
      test('extracts user data from valid login response', () {
        final responseData = {
          'code': 'Authorized',
          'message': 'Successfully signed in',
          'data': {
            'user': {
              'name': 'Maria-device-ber',
              'email': 'maria@reedu.de',
              'role': 'user',
              'language': 'en_US',
              'boxes': ['67d937c2b6275400071c38bf', '688a0bc986d4ca00082daf6e'],
              'emailIsConfirmed': true
            }
          },
          'token': 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...',
          'refreshToken': 'GeLuhpS1plwhy1Ym5NGOl3tV/KIkCPRi7obuIxFLy70='
        };

        final userData = extractUserData(responseData);

        expect(userData, isNotNull);
        expect(userData!['name'], 'Maria-device-ber');
        expect(userData['email'], 'maria@reedu.de');
        expect(userData['role'], 'user');
        expect(userData['language'], 'en_US');
        expect(userData['emailIsConfirmed'], true);
        expect(userData['boxes'], isA<List>());
        expect(userData['boxes'].length, 2);
      });

      test('extracts user data from valid registration response', () {
        final responseData = {
          'code': 'Created',
          'message': 'Successfully registered new user',
          'data': {
            'user': {
              'name': 'Maria Zadnepryanets',
              'email': 'mika.waldenberg@gmail.com',
              'role': 'user',
              'language': 'en_US',
              'boxes': [],
              'emailIsConfirmed': false
            }
          },
          'token': 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...',
          'refreshToken': 'YZlG3IhV4Jsy80ggGFlJLTtd0UyYKW/Qax980OZXAac='
        };

        final userData = extractUserData(responseData);

        expect(userData, isNotNull);
        expect(userData!['name'], 'Maria Zadnepryanets');
        expect(userData['email'], 'mika.waldenberg@gmail.com');
        expect(userData['role'], 'user');
        expect(userData['language'], 'en_US');
        expect(userData['emailIsConfirmed'], false);
        expect(userData['boxes'], isA<List>());
        expect(userData['boxes'].length, 0);
      });

      test('returns null when data field is missing', () {
        final responseData = {
          'code': 'Authorized',
          'message': 'Successfully signed in',
          'token': 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...',
          'refreshToken': 'GeLuhpS1plwhy1Ym5NGOl3tV/KIkCPRi7obuIxFLy70='
        };

        final userData = extractUserData(responseData);

        expect(userData, isNull);
      });

      test('returns null when user field is missing', () {
        final responseData = {
          'code': 'Authorized',
          'message': 'Successfully signed in',
          'data': {
            'otherField': 'some value'
          },
          'token': 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...',
          'refreshToken': 'GeLuhpS1plwhy1Ym5NGOl3tV/KIkCPRi7obuIxFLy70='
        };

        final userData = extractUserData(responseData);

        expect(userData, isNull);
      });

      test('returns null when data is not a map', () {
        final responseData = {
          'code': 'Authorized',
          'message': 'Successfully signed in',
          'data': 'not a map',
          'token': 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...',
          'refreshToken': 'GeLuhpS1plwhy1Ym5NGOl3tV/KIkCPRi7obuIxFLy70='
        };

        final userData = extractUserData(responseData);

        expect(userData, isNull);
      });

      test('returns null for empty response', () {
        final responseData = <String, dynamic>{};

        final userData = extractUserData(responseData);

        expect(userData, isNull);
      });
    });

    group('extractBoxIds', () {
      test('extracts box IDs from response with boxes', () {
        final responseData = {
          'code': 'Authorized',
          'message': 'Successfully signed in',
          'data': {
            'user': {
              'name': 'Maria-device-ber',
              'email': 'maria@reedu.de',
              'boxes': ['67d937c2b6275400071c38bf', '688a0bc986d4ca00082daf6e', '688a0c0d86d4ca00082df9b6']
            }
          }
        };

        final boxIds = extractBoxIds(responseData);

        expect(boxIds, isA<List<String>>());
        expect(boxIds.length, 3);
        expect(boxIds[0], '67d937c2b6275400071c38bf');
        expect(boxIds[1], '688a0bc986d4ca00082daf6e');
        expect(boxIds[2], '688a0c0d86d4ca00082df9b6');
      });

      test('returns empty list when boxes array is empty', () {
        final responseData = {
          'code': 'Created',
          'message': 'Successfully registered new user',
          'data': {
            'user': {
              'name': 'Maria Zadnepryanets',
              'email': 'mika.waldenberg@gmail.com',
              'boxes': []
            }
          }
        };

        final boxIds = extractBoxIds(responseData);

        expect(boxIds, isA<List<String>>());
        expect(boxIds.length, 0);
      });

      test('returns empty list when boxes field is missing', () {
        final responseData = {
          'code': 'Authorized',
          'message': 'Successfully signed in',
          'data': {
            'user': {
              'name': 'Maria-device-ber',
              'email': 'maria@reedu.de'
            }
          }
        };

        final boxIds = extractBoxIds(responseData);

        expect(boxIds, isA<List<String>>());
        expect(boxIds.length, 0);
      });

      test('returns empty list when user data is missing', () {
        final responseData = {
          'code': 'Authorized',
          'message': 'Successfully signed in',
          'data': {}
        };

        final boxIds = extractBoxIds(responseData);

        expect(boxIds, isA<List<String>>());
        expect(boxIds.length, 0);
      });

      test('handles non-string box IDs by converting to string', () {
        final responseData = {
          'code': 'Authorized',
          'message': 'Successfully signed in',
          'data': {
            'user': {
              'name': 'Maria-device-ber',
              'email': 'maria@reedu.de',
              'boxes': [123, 456, 789] // Numbers instead of strings
            }
          }
        };

        final boxIds = extractBoxIds(responseData);

        expect(boxIds, isA<List<String>>());
        expect(boxIds.length, 3);
        expect(boxIds[0], '123');
        expect(boxIds[1], '456');
        expect(boxIds[2], '789');
      });
    });

    group('hasValidUserData', () {
      test('returns true for valid user data', () {
        final responseData = {
          'code': 'Authorized',
          'message': 'Successfully signed in',
          'data': {
            'user': {
              'name': 'Maria-device-ber',
              'email': 'maria@reedu.de'
            }
          }
        };

        final hasValidData = hasValidUserData(responseData);

        expect(hasValidData, isTrue);
      });

      test('returns false for missing user data', () {
        final responseData = {
          'code': 'Authorized',
          'message': 'Successfully signed in',
          'data': {}
        };

        final hasValidData = hasValidUserData(responseData);

        expect(hasValidData, isFalse);
      });
    });

    group('hasBoxIds', () {
      test('returns true when boxes are present', () {
        final responseData = {
          'code': 'Authorized',
          'message': 'Successfully signed in',
          'data': {
            'user': {
              'name': 'Maria-device-ber',
              'email': 'maria@reedu.de',
              'boxes': ['67d937c2b6275400071c38bf']
            }
          }
        };

        final hasBoxes = hasBoxIds(responseData);

        expect(hasBoxes, isTrue);
      });

      test('returns false when boxes array is empty', () {
        final responseData = {
          'code': 'Created',
          'message': 'Successfully registered new user',
          'data': {
            'user': {
              'name': 'Maria Zadnepryanets',
              'email': 'mika.waldenberg@gmail.com',
              'boxes': []
            }
          }
        };

        final hasBoxes = hasBoxIds(responseData);

        expect(hasBoxes, isFalse);
      });

      test('returns false when boxes field is missing', () {
        final responseData = {
          'code': 'Authorized',
          'message': 'Successfully signed in',
          'data': {
            'user': {
              'name': 'Maria-device-ber',
              'email': 'maria@reedu.de'
            }
          }
        };

        final hasBoxes = hasBoxIds(responseData);

        expect(hasBoxes, isFalse);
      });
    });
  });
}
