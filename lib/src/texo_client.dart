import 'dart:typed_data';
import 'package:dio/dio.dart';

import 'mime_detector.dart';
import 'models/extraction_result.dart';
import 'models/extraction_error.dart';

/// HTTP client for the Texo OCR API.
///
/// Uploads an image and returns the extracted text. Transient failures
/// ([ServerException], [NetworkException], [TimeoutException]) are retried with
/// exponential backoff; every other failure throws immediately.
///
/// Call [close] when finished to release the underlying HTTP client.
///
/// ```dart
/// final extractor = ImageTextExtractor(apiKey: key);
/// try {
///   final result = await extractor.extractFromBytes(
///     bytes,
///     apikey: key,
///     documentType: 'drivinglicense',
///   );
///   print(result.text);
/// } on ExtractionException catch (e) {
///   print(e.message);
/// } finally {
///   extractor.close();
/// }
/// ```
class ImageTextExtractor {
  /// The production Texo API endpoint, used when no `baseUrl` is given.
  static const String defaultBaseUrl =
      'https://api-v2-756341732140.europe-west1.run.app/v2';

  /// Largest image accepted, in bytes. Enforced before upload.
  static const int maxFileSizeBytes = 10 * 1024 * 1024;

  final Dio _dio;

  /// How many times a transient failure is retried before it is thrown.
  final int maxRetries;

  /// Creates a client.
  ///
  /// Throws [ArgumentError] if [apiKey] is blank. [timeout] applies to the
  /// response; the connect timeout is fixed at 15 seconds.
  ImageTextExtractor({
    required String apiKey,
    String? baseUrl,
    Duration timeout = const Duration(seconds: 60),
    this.maxRetries = 2,
    Dio? dio, // injected in tests
  }) : _dio =
           dio ??
           Dio(
             BaseOptions(
               baseUrl: baseUrl ?? defaultBaseUrl,
               connectTimeout: const Duration(seconds: 15),
               receiveTimeout: timeout,
               // we map status codes ourselves
               validateStatus: (_) => true,
             ),
           ) {
    if (apiKey.trim().isEmpty) {
      throw ArgumentError.value(apiKey, 'apiKey', 'must not be empty');
    }
  }

  /// Uploads [bytes] and returns the extracted text.
  ///
  /// The image format is detected from magic bytes, not from [filename], so a
  /// wrong or missing extension is harmless. [onProgress] reports upload
  /// progress; [cancelToken] aborts the request, which then throws
  /// [CancelledException].
  ///
  /// Throws a [BadRequestException] if [bytes] is empty, a
  /// [FileTooLargeException] above [maxFileSizeBytes], an
  /// [UnsupportedFormatException] if the bytes are not a recognized image, or
  /// one of the other [ExtractionException] subtypes on a failed request.
  Future<ExtractionResult> extractFromBytes(
    Uint8List bytes, {
    String? filename,
    required String apikey,
    required String documentType,
    bool storeImage = false,
    void Function(int sent, int total)? onProgress,
    CancelToken? cancelToken,
  }) async {
    // --- client-side gates: fail before spending bandwidth ---
    if (bytes.isEmpty) {
      throw const BadRequestException('Image data is empty');
    }
    if (bytes.length > maxFileSizeBytes) {
      throw FileTooLargeException(bytes.length, maxFileSizeBytes);
    }
    final mime = MimeDetector.detect(bytes);
    if (mime == null) {
      throw const UnsupportedFormatException(null);
    }

    final name = filename ?? 'image.${MimeDetector.extensionFor(mime)}';
    FormData buildForm() => FormData.fromMap({
      'api_key': apikey,
      'store_image': storeImage.toString(),
      'document_type': documentType,
      'image': MultipartFile.fromBytes(
        bytes,
        filename: name,
        // dio's own alias for http_parser's MediaType, so we need not depend
        // on http_parser directly.
        contentType: DioMediaType.parse(mime),
      ),
    });

    return _withRetry(() async {
      final res = await _dio.post<Map<String, dynamic>>(
        '/app-ocr/process',
        data: buildForm(),
        onSendProgress: onProgress,
        cancelToken: cancelToken,
      );

      final body = res.data;
      final ok = res.statusCode == 200 && (body?['success'] == true);
      if (!ok) throw mapError(res.statusCode, body);
      return ExtractionResult.fromJson(body!);
    });
  }

  /// Reads [file] and delegates to [extractFromBytes].
  ///
  /// [file] is anything exposing `readAsBytes()` and `path` — a `dart:io` File
  /// or an `XFile` — kept untyped so this also compiles for web.
  ///
  /// Note: [apikey] is required in practice despite being nullable; passing
  /// `null` throws. This is fixed in 2.0.
  Future<ExtractionResult> extractFromFile(
    /* io.File */ dynamic file, {
    required String documentType,
    String? apikey,
    bool storeImage = false,
    void Function(int, int)? onProgress,
    CancelToken? cancelToken,
  }) async {
    final bytes = await file.readAsBytes() as Uint8List;
    return extractFromBytes(
      bytes,
      apikey: apikey!,
      // split on both separators instead of dart:io Platform, so this also compiles for web
      filename: (file.path as String).split(RegExp(r'[\\/]')).last,
      documentType: documentType,
      storeImage: storeImage,
      onProgress: onProgress,
      cancelToken: cancelToken,
    );
  }

  Future<T> _withRetry<T>(Future<T> Function() op) async {
    var attempt = 0;
    while (true) {
      try {
        return await op();
      } on DioException catch (e) {
        if (CancelToken.isCancel(e)) throw const CancelledException();
        final err = _fromDio(e);
        if (!_retryable(err) || attempt >= maxRetries) throw err;
      } on ExtractionException catch (e) {
        if (!_retryable(e) || attempt >= maxRetries) rethrow;
      }
      // 400ms, 800ms, 1600ms…
      await Future<void>.delayed(Duration(milliseconds: 400 << attempt));
      attempt++;
    }
  }

  bool _retryable(ExtractionException e) =>
      e is ServerException || e is NetworkException || e is TimeoutException;

  ExtractionException _fromDio(DioException e) => switch (e.type) {
    DioExceptionType.connectionTimeout ||
    DioExceptionType.sendTimeout ||
    DioExceptionType.receiveTimeout => const TimeoutException(
      'Request timed out',
    ),
    DioExceptionType.connectionError => NetworkException(
      'Network unavailable',
      cause: e.error,
    ),
    _ => NetworkException(e.message ?? 'Request failed', cause: e.error),
  };

  /// Releases the underlying HTTP client. Call this when you are done.
  void close() => _dio.close();
}
