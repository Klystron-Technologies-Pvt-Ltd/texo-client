import 'package:flutter_test/flutter_test.dart';
import 'package:texoclient/texoclient.dart';

void main() {
  test('reads fields from the top level', () {
    final result = ExtractionResult.fromJson({
      'text': 'hello',
      'document_type': 'drivinglicense',
    });
    expect(result.text, 'hello');
    expect(result.documentType, 'drivinglicense');
  });

  test('reads fields from a data wrapper when present', () {
    final result = ExtractionResult.fromJson({
      'success': true,
      'data': {'text': 'nested', 'document_type': 'passport'},
    });
    expect(result.text, 'nested');
    expect(result.documentType, 'passport');
  });

  test('a non-map data field is ignored', () {
    final result = ExtractionResult.fromJson({'data': 'oops', 'text': 'top'});
    expect(result.text, 'top');
  });

  test('falls back through the text field names in order', () {
    expect(
      ExtractionResult.fromJson({
        'extracted_text': 'a',
        'text': 'b',
        'full_text': 'c',
      }).text,
      'a',
    );
    expect(
      ExtractionResult.fromJson({'text': 'b', 'full_text': 'c'}).text,
      'b',
    );
    expect(ExtractionResult.fromJson({'full_text': 'c'}).text, 'c');
  });

  test('missing text becomes an empty string, not null', () {
    expect(ExtractionResult.fromJson({'success': true}).text, '');
  });

  test('non-string text is encoded as JSON', () {
    final result = ExtractionResult.fromJson({
      'text': {'lines': 2},
    });
    expect(result.text, '{"lines":2}');
  });

  test('missing document_type is null', () {
    expect(ExtractionResult.fromJson({'text': 'x'}).documentType, isNull);
  });

  test('raw keeps the whole body, including unmapped fields', () {
    final body = {'text': 'x', 'confidence': 0.9, 'request_id': 'abc'};
    final result = ExtractionResult.fromJson(body);
    expect(result.raw, body);
    expect(result.prettyJson, contains('"request_id": "abc"'));
  });
}
