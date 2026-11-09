import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:sensebox_bike/models/upload_progress.dart';
import 'package:sensebox_bike/services/custom_exceptions.dart';
import 'package:sensebox_bike/services/opensensemap_service.dart';
import 'package:sensebox_bike/services/upload_error_classifier.dart';

void main() {
  group('isAuthError', () {
    test('login problems are auth errors', () {
      expect(UploadErrorClassifier.isAuthError(PermanentAuthenticationError()),
          isTrue);
      expect(UploadErrorClassifier.isAuthError(AuthException()), isTrue);
    });

    test('other errors are not', () {
      for (final error in [
        TimeoutException('x'),
        ServerErrorException(503),
        OpenSenseMapApiException(422, 'Upload failed', ''),
        Exception('Some unknown error'),
      ]) {
        expect(UploadErrorClassifier.isAuthError(error), isFalse,
            reason: '$error');
      }
    });
  });

  group('failureKindOf', () {
    test('distinguishes connection and API response failures', () {
      expect(UploadErrorClassifier.failureKindOf(TimeoutException('x')),
          UploadFailureKind.connection);
      expect(
          UploadErrorClassifier.failureKindOf(
              http.ClientException('Failed host lookup')),
          UploadFailureKind.connection);
      expect(UploadErrorClassifier.failureKindOf(ServerErrorException(500)),
          UploadFailureKind.apiResponse);
      expect(UploadErrorClassifier.failureKindOf(Exception('x')),
          UploadFailureKind.other);
      expect(UploadErrorClassifier.failureKindOf(AuthException()),
          UploadFailureKind.authentication);
    });
  });

  group('describe', () {
    test('describes timeouts', () {
      expect(
          UploadErrorClassifier.describe(
              TimeoutException('x', const Duration(seconds: 25))),
          'No response within 25 s');
    });

    test('shortens socket errors', () {
      expect(
          UploadErrorClassifier.describe(const SocketException(
              'Connection refused',
              osError: OSError('Connection refused', 111))),
          'Connection refused (Connection refused)');
    });

    test('includes status code and API message for server errors', () {
      expect(
          UploadErrorClassifier.describe(
              ServerErrorException(503, '{"message":"Service Unavailable"}')),
          'HTTP 503: Service Unavailable');
    });

    test('drops HTML error pages', () {
      expect(
          UploadErrorClassifier.describe(
              ServerErrorException(502, '<html>Bad gateway</html>')),
          'HTTP 502');
    });
  });
}
