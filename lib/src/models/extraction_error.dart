/// Base type for every failure the Texo client reports.
///
/// Sealed, so a `switch` over it is checked for exhaustiveness at compile time.
sealed class ExtractionException implements Exception {
  /// Human-readable description, safe to show to a user.
  final String message;

  /// Creates an exception carrying [message].
  const ExtractionException(this.message);

  @override
  String toString() => '$runtimeType: $message';
}

/// The request was malformed or rejected: HTTP 400, 413, 422, or a 200
/// response carrying `success: false`. Not retried.
class BadRequestException extends ExtractionException {
  /// Creates the exception with the server's explanation.
  const BadRequestException(super.message);
}

/// The API key is missing, invalid or not permitted: HTTP 401 or 403.
class UnauthorizedException extends ExtractionException {
  /// Creates the exception with the server's explanation.
  const UnauthorizedException(super.message);
}

/// The image exceeds the size limit. Detected locally, before uploading.
class FileTooLargeException extends ExtractionException {
  /// Size of the rejected image, in bytes.
  final int size;

  /// The maximum accepted size, in bytes.
  final int limit;

  /// Creates the exception and builds a message from [size] and [limit].
  FileTooLargeException(this.size, this.limit)
    : super('File is ${size ~/ 1024} KB; limit is ${limit ~/ 1024} KB');
}

/// The bytes are not a recognized image format, or the server returned 415.
class UnsupportedFormatException extends ExtractionException {
  /// The detected MIME type, or `null` when nothing could be detected.
  final String? mime;

  /// Creates the exception for the optionally detected [mime] type.
  const UnsupportedFormatException(this.mime)
    : super('Unsupported image format');
}

/// Too many requests: HTTP 429. Back off before trying again.
class RateLimitException extends ExtractionException {
  /// Creates the exception with the server's explanation.
  const RateLimitException(super.message);
}

/// The server failed: HTTP 5xx. Retried automatically.
class ServerException extends ExtractionException {
  /// The HTTP status returned, when one was received.
  final int? statusCode;

  /// Creates the exception, optionally recording [statusCode].
  const ServerException(super.message, {this.statusCode});
}

/// The request never reached the server. Retried automatically.
class NetworkException extends ExtractionException {
  /// The underlying transport error, when available.
  final Object? cause;

  /// Creates the exception, optionally recording the underlying [cause].
  const NetworkException(super.message, {this.cause});
}

/// The connection, upload or response timed out. Retried automatically.
class TimeoutException extends ExtractionException {
  /// Creates the exception with a description of which phase timed out.
  const TimeoutException(super.message);
}

/// The caller cancelled the request through its `CancelToken`.
class CancelledException extends ExtractionException {
  /// Creates the exception.
  const CancelledException() : super('Request cancelled');
}

/// The image could not be obtained: the picker or camera failed to open,
/// permission was denied, or the chosen file could not be read.
///
/// Only `TexoClientWidget` raises this; `ImageTextExtractor` never picks.
class PickerException extends ExtractionException {
  /// The underlying platform error.
  final Object? cause;

  /// Creates the exception, recording the underlying [cause].
  const PickerException(super.message, {this.cause});
}

/// A failure with no more specific type. Should not normally occur.
class UnknownException extends ExtractionException {
  /// The underlying error.
  final Object? cause;

  /// Creates the exception, recording the underlying [cause].
  const UnknownException(super.message, {this.cause});
}

/// Maps a non-success HTTP response to a typed exception.
ExtractionException mapError(int? status, Map<String, dynamic>? body) {
  final msg =
      (body?['message'] ?? body?['error'] ?? body?['detail'])?.toString() ??
      'Request failed (HTTP $status)';
  return switch (status) {
    400 || 422 => BadRequestException(msg),
    401 || 403 => UnauthorizedException(msg),
    413 => BadRequestException(msg),
    415 => const UnsupportedFormatException(null),
    429 => RateLimitException(msg),
    _ when status != null && status >= 500 => ServerException(
      msg,
      statusCode: status,
    ),
    // 200 with success:false, or other unexpected codes
    _ => BadRequestException(msg),
  };
}
