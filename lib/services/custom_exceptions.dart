class TooManyRequestsException implements Exception {
  final int retryAfter;

  TooManyRequestsException(this.retryAfter);

  @override
  String toString() => 'TooManyRequestsException: Retry after $retryAfter seconds.';
}