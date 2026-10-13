import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:texoclient/texoclient.dart';

void main() {
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  test('files and gallery work on every platform', () {
    for (final platform in TargetPlatform.values) {
      debugDefaultTargetPlatformOverride = platform;
      expect(TexoSource.files.isSupported, isTrue, reason: '$platform');
      expect(TexoSource.gallery.isSupported, isTrue, reason: '$platform');
    }
    debugDefaultTargetPlatformOverride = null;
  });

  test('camera works on mobile', () {
    for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
      debugDefaultTargetPlatformOverride = platform;
      expect(TexoSource.camera.isSupported, isTrue, reason: '$platform');
    }
    debugDefaultTargetPlatformOverride = null;
  });

  test('camera is unsupported on desktop', () {
    // image_picker_windows, _macos and _linux throw a StateError for
    // ImageSource.camera unless a cameraDelegate is set, so the widget must
    // disable itself rather than let the tap through.
    for (final platform in [
      TargetPlatform.windows,
      TargetPlatform.macOS,
      TargetPlatform.linux,
    ]) {
      debugDefaultTargetPlatformOverride = platform;
      expect(TexoSource.camera.isSupported, isFalse, reason: '$platform');
    }
    debugDefaultTargetPlatformOverride = null;
  });
}
