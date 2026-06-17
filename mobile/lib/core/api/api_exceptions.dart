class ApiException implements Exception {
  final int statusCode;
  final String message;
  final Object? body;
  ApiException(this.statusCode, this.message, [this.body]);
  @override
  String toString() => 'ApiException($statusCode): $message';
}

class NetworkException extends ApiException {
  NetworkException(String message) : super(0, message);
}

/// Thrown when the server returns HTTP 429.
///
/// The [Dio] interceptor in `api_client.dart` automatically shows a global
/// SnackBar when a 429 is received, so call sites should generally catch and
/// swallow this exception silently (e.g. log + ignore) instead of toasting
/// the user again.
class RateLimitedException extends ApiException {
  RateLimitedException([
    String message = 'Too many requests. Please slow down.',
  ]) : super(429, message);
}
