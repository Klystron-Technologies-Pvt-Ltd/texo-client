import 'dart:convert';

/// Successful OCR response. The raw body is kept so nothing the API
/// returns is lost, even if its shape changes.
class ExtractionResult {
  /// The extracted text, or an empty string if the response carried none.
  final String text;

  /// The document type the API reported, when it reported one.
  final String? documentType;

  /// The unmodified response body, including any fields not mapped above.
  final Map<String, dynamic> raw;

  /// Creates a result directly. Most callers get one from [fromJson].
  const ExtractionResult({
    required this.text,
    this.documentType,
    required this.raw,
  });

  /// Reads a response body, tolerating the shapes the API has used:
  /// fields at the top level or nested under `data`, and text under
  /// `extracted_text`, `text` or `full_text`, in that order.
  factory ExtractionResult.fromJson(Map<String, dynamic> json) {
    final data = json['data'];
    final source = data is Map<String, dynamic> ? data : json;
    final text =
        source['extracted_text'] ?? source['text'] ?? source['full_text'] ?? '';
    return ExtractionResult(
      text: text is String ? text : jsonEncode(text),
      documentType: source['document_type']?.toString(),
      raw: json,
    );
  }

  /// [raw] rendered as indented JSON, for logging or display.
  String get prettyJson => const JsonEncoder.withIndent('  ').convert(raw);
}
