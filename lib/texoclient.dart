/// Flutter client and drop-in button widget for the Texo OCR API.
///
/// Two entry points, depending on how much control you want:
///
/// * [TexoClientWidget] — a button that picks or captures an image, uploads it
///   and hands you the response. No state management required.
/// * [ImageTextExtractor] — the bare HTTP client, if you already have the image
///   bytes or want to drive the request yourself.
library;

export 'src/texo_client.dart';
export 'src/mime_detector.dart';
export 'src/models/extraction_result.dart';
export 'src/models/extraction_error.dart';
export 'src/texo_source.dart';
export 'src/widgets/texo_widget.dart';

// Appears in this package's public signatures but is defined by dio, so it is
// re-exported rather than making callers depend on dio themselves.
export 'package:dio/dio.dart' show CancelToken;
