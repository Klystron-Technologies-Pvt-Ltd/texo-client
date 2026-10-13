import 'package:flutter_test/flutter_test.dart';
import 'package:texoclient/texoclient.dart';

void main() {
  group('mapError status mapping', () {
    test('400 and 422 are bad requests', () {
      expect(mapError(400, {'message': 'nope'}), isA<BadRequestException>());
      expect(mapError(422, {'message': 'nope'}), isA<BadRequestException>());
    });

    test('401 and 403 are unauthorized', () {
      expect(
        mapError(401, {'message': 'bad key'}),
        isA<UnauthorizedException>(),
      );
      expect(
        mapError(403, {'message': 'bad key'}),
        isA<UnauthorizedException>(),
      );
    });

    test('413 is reported as a bad request', () {
      expect(mapError(413, {'message': 'too big'}), isA<BadRequestException>());
    });

    test('415 is an unsupported format', () {
      expect(mapError(415, null), isA<UnsupportedFormatException>());
    });

    test('429 is a rate limit', () {
      expect(
        mapError(429, {'message': 'slow down'}),
        isA<RateLimitException>(),
      );
    });

    test('5xx carries the status code through', () {
      final error = mapError(503, {'message': 'down'});
      expect(error, isA<ServerException>());
      expect((error as ServerException).statusCode, 503);
    });

    test('an unexpected status falls through to bad request', () {
      expect(mapError(200, {'success': false}), isA<BadRequestException>());
      expect(mapError(null, null), isA<BadRequestException>());
    });
  });

  group('mapError message extraction', () {
    test('prefers message, then error, then detail', () {
      expect(mapError(400, {'message': 'a', 'error': 'b'}).message, 'a');
      expect(mapError(400, {'error': 'b', 'detail': 'c'}).message, 'b');
      expect(mapError(400, {'detail': 'c'}).message, 'c');
    });

    test('falls back to the status when the body says nothing', () {
      expect(mapError(418, {}).message, 'Request failed (HTTP 418)');
      expect(mapError(null, null).message, 'Request failed (HTTP null)');
    });

    test('stringifies a non-string message', () {
      expect(mapError(400, {'message': 42}).message, '42');
    });
  });

  test('FileTooLargeException reports sizes in KB', () {
    final error = FileTooLargeException(20 * 1024, 10 * 1024);
    expect(error.size, 20 * 1024);
    expect(error.limit, 10 * 1024);
    expect(error.message, 'File is 20 KB; limit is 10 KB');
  });

  test('PickerException and UnknownException carry their cause', () {
    final cause = StateError('no camera');
    expect(PickerException('Could not open camera', cause: cause).cause, cause);
    expect(UnknownException('odd', cause: cause).cause, cause);
  });

  test('a switch over the sealed type is exhaustive without a default', () {
    // Fails to compile if a subtype is added and not handled here, which is
    // the point of sealing ExtractionException.
    String describe(ExtractionException e) => switch (e) {
      BadRequestException() => 'bad-request',
      UnauthorizedException() => 'unauthorized',
      FileTooLargeException() => 'too-large',
      UnsupportedFormatException() => 'unsupported',
      RateLimitException() => 'rate-limit',
      ServerException() => 'server',
      NetworkException() => 'network',
      TimeoutException() => 'timeout',
      CancelledException() => 'cancelled',
      PickerException() => 'picker',
      UnknownException() => 'unknown',
    };

    expect(describe(const CancelledException()), 'cancelled');
    expect(describe(const PickerException('x')), 'picker');
    expect(describe(FileTooLargeException(2048, 1024)), 'too-large');
  });

  test('toString includes the runtime type', () {
    expect(
      const CancelledException().toString(),
      'CancelledException: Request cancelled',
    );
  });
}
