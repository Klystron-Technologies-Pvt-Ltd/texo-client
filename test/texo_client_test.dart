import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:texoclient/texoclient.dart';

/// Answers requests from a scripted list, one entry per attempt, so retry
/// behaviour is observable without touching the network.
///
/// Entries are factories rather than values: a [ResponseBody] wraps a
/// single-subscription stream, so each attempt needs its own.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.script);

  final List<ResponseBody Function()> script;
  int calls = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    // The last entry answers every further attempt.
    final build = script[calls.clamp(0, script.length - 1)];
    calls++;
    return build();
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody Function() _json(int status, Map<String, dynamic> body) =>
    () => ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

ImageTextExtractor _client(_FakeAdapter adapter, {int maxRetries = 1}) {
  final dio = Dio(
    BaseOptions(baseUrl: 'https://example.test', validateStatus: (_) => true),
  )..httpClientAdapter = adapter;
  return ImageTextExtractor(
    apiKey: 'test-key',
    dio: dio,
    maxRetries: maxRetries,
  );
}

/// A 16-byte buffer whose magic bytes identify it as a PNG.
final _png = Uint8List.fromList([
  0x89,
  0x50,
  0x4E,
  0x47,
  ...List.filled(12, 0),
]);

Future<ExtractionResult> _extract(ImageTextExtractor client) => client
    .extractFromBytes(_png, apikey: 'test-key', documentType: 'drivinglicense');

void main() {
  test('a blank API key is rejected at construction', () {
    expect(() => ImageTextExtractor(apiKey: ''), throwsArgumentError);
    expect(() => ImageTextExtractor(apiKey: '   '), throwsArgumentError);
  });

  group('client-side gates fire before any request', () {
    test('empty bytes', () async {
      final adapter = _FakeAdapter([_json(200, {})]);
      await expectLater(
        _client(
          adapter,
        ).extractFromBytes(Uint8List(0), apikey: 'k', documentType: 'x'),
        throwsA(isA<BadRequestException>()),
      );
      expect(adapter.calls, 0);
    });

    test('oversize image', () async {
      final adapter = _FakeAdapter([_json(200, {})]);
      final huge = Uint8List(ImageTextExtractor.maxFileSizeBytes + 1)
        ..setRange(0, 4, [0x89, 0x50, 0x4E, 0x47]);
      await expectLater(
        _client(adapter).extractFromBytes(huge, apikey: 'k', documentType: 'x'),
        throwsA(isA<FileTooLargeException>()),
      );
      expect(adapter.calls, 0);
    });

    test('unrecognized format', () async {
      final adapter = _FakeAdapter([_json(200, {})]);
      await expectLater(
        _client(
          adapter,
        ).extractFromBytes(Uint8List(32), apikey: 'k', documentType: 'x'),
        throwsA(isA<UnsupportedFormatException>()),
      );
      expect(adapter.calls, 0);
    });
  });

  test('a successful response is parsed', () async {
    final adapter = _FakeAdapter([
      _json(200, {
        'success': true,
        'data': {'text': 'hello', 'document_type': 'drivinglicense'},
      }),
    ]);
    final result = await _extract(_client(adapter));

    expect(result.text, 'hello');
    expect(result.documentType, 'drivinglicense');
    expect(adapter.calls, 1);
  });

  test('a 200 carrying success:false is still an error', () async {
    final adapter = _FakeAdapter([
      _json(200, {'success': false, 'message': 'unreadable'}),
    ]);
    await expectLater(
      _extract(_client(adapter)),
      throwsA(
        isA<BadRequestException>().having(
          (e) => e.message,
          'message',
          'unreadable',
        ),
      ),
    );
    expect(adapter.calls, 1, reason: 'not a transient failure');
  });

  test('a 5xx is retried, then thrown', () async {
    final adapter = _FakeAdapter([
      _json(500, {'message': 'boom'}),
    ]);
    await expectLater(
      _extract(_client(adapter, maxRetries: 2)),
      throwsA(isA<ServerException>()),
    );
    expect(adapter.calls, 3, reason: 'initial attempt plus two retries');
  });

  test('a 5xx that recovers returns the later success', () async {
    final adapter = _FakeAdapter([
      _json(503, {'message': 'restarting'}),
      _json(200, {
        'success': true,
        'data': {'text': 'recovered'},
      }),
    ]);
    final result = await _extract(_client(adapter));

    expect(result.text, 'recovered');
    expect(adapter.calls, 2);
  });

  test('a 4xx is not retried', () async {
    final adapter = _FakeAdapter([
      _json(401, {'message': 'bad key'}),
    ]);
    await expectLater(
      _extract(_client(adapter, maxRetries: 3)),
      throwsA(isA<UnauthorizedException>()),
    );
    expect(adapter.calls, 1);
  });

  test('a cancelled token surfaces as CancelledException', () async {
    final adapter = _FakeAdapter([
      _json(200, {'success': true}),
    ]);
    final token = CancelToken()..cancel();

    await expectLater(
      _client(adapter).extractFromBytes(
        _png,
        apikey: 'test-key',
        documentType: 'x',
        cancelToken: token,
      ),
      throwsA(isA<CancelledException>()),
    );
  });

  test('close releases the client without throwing', () {
    expect(
      () => _client(_FakeAdapter([_json(200, {})])).close(),
      returnsNormally,
    );
  });
}
