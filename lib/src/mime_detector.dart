import 'dart:typed_data';

/// Detects image MIME types from magic bytes, so we never trust file extensions.
class MimeDetector {
  /// Returns the MIME type of [b], or `null` if it is not a recognized image.
  ///
  /// Recognizes JPEG, PNG, GIF, BMP, WebP and HEIC. Buffers shorter than 12
  /// bytes always return `null`.
  static String? detect(Uint8List b) {
    if (b.length < 12) return null;
    if (b[0] == 0xFF && b[1] == 0xD8 && b[2] == 0xFF) return 'image/jpeg';
    if (b[0] == 0x89 && b[1] == 0x50 && b[2] == 0x4E && b[3] == 0x47) {
      return 'image/png';
    }
    if (b[0] == 0x47 && b[1] == 0x49 && b[2] == 0x46) return 'image/gif';
    if (b[0] == 0x42 && b[1] == 0x4D) return 'image/bmp';
    // RIFF....WEBP
    if (b[0] == 0x52 &&
        b[1] == 0x49 &&
        b[2] == 0x46 &&
        b[3] == 0x46 &&
        b[8] == 0x57 &&
        b[9] == 0x45 &&
        b[10] == 0x42 &&
        b[11] == 0x50) {
      return 'image/webp';
    }
    // ....ftypheic / heix / mif1 etc.
    if (b[4] == 0x66 && b[5] == 0x74 && b[6] == 0x79 && b[7] == 0x70) {
      final brand = String.fromCharCodes(b.sublist(8, 12));
      if (const {
        'heic',
        'heix',
        'hevc',
        'hevx',
        'mif1',
        'msf1',
      }.contains(brand)) {
        return 'image/heic';
      }
    }
    return null;
  }

  /// The conventional file extension for [mime], or `bin` if unrecognized.
  static String extensionFor(String mime) => switch (mime) {
    'image/jpeg' => 'jpg',
    'image/png' => 'png',
    'image/gif' => 'gif',
    'image/bmp' => 'bmp',
    'image/webp' => 'webp',
    'image/heic' => 'heic',
    _ => 'bin',
  };
}
