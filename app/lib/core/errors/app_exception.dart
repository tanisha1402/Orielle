/// Typed errors raised by the data layer and surfaced by the UI.
class AppException implements Exception {
  const AppException(this.message, {this.cause});

  final String message;
  final Object? cause;

  /// Short heading for error panels.
  String get title => 'Something went wrong';

  /// Wraps any thrown object into an [AppException].
  static AppException wrap(Object error) {
    if (error is AppException) return error;
    return AppException(error.toString(), cause: error);
  }

  @override
  String toString() => '$runtimeType: $message';
}

/// Missing or invalid build-time configuration (for example no API URL).
class ConfigurationException extends AppException {
  const ConfigurationException(super.message, {super.cause});

  @override
  String get title => 'Backend not configured';
}

/// The backend could not be reached.
class NetworkException extends AppException {
  const NetworkException(super.message, {super.cause});

  @override
  String get title => 'Backend unreachable';
}

/// The request exceeded the configured timeout.
class RequestTimeoutException extends AppException {
  const RequestTimeoutException(super.message, {super.cause});

  @override
  String get title => 'Request timed out';
}

/// The backend answered with an unexpected HTTP status.
class HttpStatusException extends AppException {
  const HttpStatusException(super.message,
      {required this.statusCode, super.cause});

  final int statusCode;

  @override
  String get title => 'Backend error ($statusCode)';
}

/// The requested record does not exist (HTTP 404 or unknown mock id).
class NotFoundException extends AppException {
  const NotFoundException(super.message, {super.cause});

  @override
  String get title => 'Not found';
}

/// A response could not be parsed into the expected typed model.
class ParseException extends AppException {
  const ParseException(super.message, {super.cause});

  @override
  String get title => 'Unexpected data format';
}
