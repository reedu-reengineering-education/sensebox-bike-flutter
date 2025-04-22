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

class NoSenseBoxSelected implements Exception {
  @override
  String toString() =>
      'Please login to your openSenseMap account and select box in order to allow upload sensor data to the cloud.';
}
