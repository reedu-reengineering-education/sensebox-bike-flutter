import 'package:sensebox_bike/services/custom_exceptions.dart';
import 'dart:async';

enum UploadErrorType {
  temporary,
  permanentAuth,
  permanentClient,
}

class UploadErrorClassifier {
  static const List<String> _permanentAuthErrorPatterns = [
    'Authentication failed - user needs to re-login',
    'No refresh token found',
    'Failed to refresh token:',
    'Not authenticated',
  ];

  static UploadErrorType classifyError(dynamic error) {
    if (error is PermanentAuthenticationError) {
      return UploadErrorType.permanentAuth;
    }

    if (error is TooManyRequestsException || error is TimeoutException) {
      return UploadErrorType.temporary;
    }

    final errorString = error.toString();

    for (final pattern in _permanentAuthErrorPatterns) {
      if (errorString.contains(pattern)) {
        return UploadErrorType.permanentAuth;
      }
    }

    if (errorString.contains('Client error 400') ||
        errorString.contains('Client error 403') ||
        errorString.contains('Client error 404') ||
        errorString.contains('Client error - 400') ||
        errorString.contains('Client error - 403') ||
        errorString.contains('Client error - 404')) {
      return UploadErrorType.permanentClient;
    }

    return UploadErrorType.temporary;
  }
}
