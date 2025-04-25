class TooManyRequestsException implements Exception {
  final int retryAfter;

  TooManyRequestsException(this.retryAfter);

  @override
  String toString() => 'TooManyRequestsException: Retry after $retryAfter seconds.';
}

class LocationPermissionDenied implements Exception {
  @override
  String toString() =>
      'Please allow the current app to access location of the current device in the phone settings.';
}

class ScanPermissionDenied implements Exception {
  @override
  String toString() =>
      'Please allow the current app to scan nearby devices in the phone settings.';
}

class LoginError implements Exception {
  Object? error;
  LoginError(this.error);
  @override
  String toString() => 'Error happened during login. Details: $error';
}

class RegistrationError implements Exception {
  Object? error;
  RegistrationError(this.error);
  @override
  String toString() =>
      'Error happened during account registration. Details: $error';
}

class NoSenseBoxSelected implements Exception {
  @override
  String toString() =>
      'Please login to your openSenseMap account and select box in order to allow upload sensor data to the cloud.';
}
