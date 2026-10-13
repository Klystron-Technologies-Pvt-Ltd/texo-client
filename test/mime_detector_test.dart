import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:texoclient/texoclient.dart';

/// Builds a 16-byte buffer starting with [header], so length checks pass.
Uint8List bytes(List<int> header) =>
    Uint8List.fromList([...header, ...List.filled(16 - header.length, 0)]);

Uint8List ftyp(String brand) => bytes([
  0, 0, 0, 0, // box size, ignored
  0x66, 0x74, 0x79, 0x70, // 'ftyp'
  ...brand.codeUnits,
]);

void main() {
  group('detect', () {
    test('JPEG', () {
      expect(MimeDetector.detect(bytes([0xFF, 0xD8, 0xFF])), 'image/jpeg');
    });

    test('PNG', () {
      expect(MimeDetector.detect(bytes([0x89, 0x50, 0x4E, 0x47])), 'image/png');
    });

    test('GIF', () {
      expect(MimeDetector.detect(bytes([0x47, 0x49, 0x46])), 'image/gif');
    });

    test('BMP', () {
      expect(MimeDetector.detect(bytes([0x42, 0x4D])), 'image/bmp');
    });

    test('WebP needs both the RIFF header and the WEBP tag', () {
      final webp = bytes([
        0x52, 0x49, 0x46, 0x46, // 'RIFF'
        0, 0, 0, 0, // file size, ignored
        0x57, 0x45, 0x42, 0x50, // 'WEBP'
      ]);
      expect(MimeDetector.detect(webp), 'image/webp');

      // RIFF without the WEBP tag is some other RIFF container, not an image.
      final riffOnly = bytes([0x52, 0x49, 0x46, 0x46]);
      expect(MimeDetector.detect(riffOnly), isNull);
    });

    test('every accepted HEIC brand', () {
      for (final brand in ['heic', 'heix', 'hevc', 'hevx', 'mif1', 'msf1']) {
        expect(MimeDetector.detect(ftyp(brand)), 'image/heic', reason: brand);
      }
    });

    test('an ftyp box with an unknown brand is rejected', () {
      expect(MimeDetector.detect(ftyp('qt  ')), isNull);
    });

    test('buffers shorter than 12 bytes return null', () {
      final truncatedJpeg = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0, 0]);
      expect(MimeDetector.detect(truncatedJpeg), isNull);
      expect(MimeDetector.detect(Uint8List(0)), isNull);
    });

    test('unrecognized bytes return null', () {
      expect(MimeDetector.detect(bytes([0x00, 0x01, 0x02, 0x03])), isNull);
    });
  });

  group('extensionFor', () {
    test('maps each known type', () {
      expect(MimeDetector.extensionFor('image/jpeg'), 'jpg');
      expect(MimeDetector.extensionFor('image/png'), 'png');
      expect(MimeDetector.extensionFor('image/gif'), 'gif');
      expect(MimeDetector.extensionFor('image/bmp'), 'bmp');
      expect(MimeDetector.extensionFor('image/webp'), 'webp');
      expect(MimeDetector.extensionFor('image/heic'), 'heic');
    });

    test('falls back to bin', () {
      expect(MimeDetector.extensionFor('application/pdf'), 'bin');
    });
  });
}
