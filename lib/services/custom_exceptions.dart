class TooManyRequestsException implements Exception {
  final int retryAfter;

  TooManyRequestsException(this.retryAfter);

  @override
  String toString() => 'TooManyRequestsException: Retry after $retryAfter seconds.';
}

class LocationPermissionDenied implements Exception {
  @override
  String toString() =>
      'Location services are disabled or access is denied. Please enable location services and allow the app to access your location in the phone settings.';
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

class ExportDirectoryAccessError implements Exception {
  @override
  String toString() =>
      'Error accessing export directory. Please make sure the app has permission to access the storage.';
}

class UploadFailureError implements Exception {
  @override
  String toString() =>
      'Data upload failed. Please check your internet connection and try again.';
}

class DirectUploadFailureError implements Exception {
  @override
  String toString() =>
      'Real-time upload failed due to connectivity issues. Your data has been saved locally. After stopping the recording, you can upload the track manually from the track overview.';
}

class PermanentAuthenticationError implements Exception {
  final String? details;

  PermanentAuthenticationError([this.details]);

  @override
  String toString() => details != null
      ? 'Authentication failed permanently: $details. Data upload is stopped but all data is stored locally.'
      : 'Authentication failed permanently. Data upload is stopped but all data is stored locally. Please log in again to continue uploading data.';
}

class TrackHasNoGeolocationsException implements Exception {
  final int? trackId;

  TrackHasNoGeolocationsException([this.trackId]);

  @override
  String toString() => 'Track has no geolocation data and cannot be uploaded.';
}