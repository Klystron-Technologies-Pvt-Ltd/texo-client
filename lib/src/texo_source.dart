import 'package:flutter/foundation.dart';

/// Where `TexoClientWidget` gets its image.
enum TexoSource {
  /// The platform's file browser.
  ///
  /// Files and iCloud Drive on iOS, the document picker on Android, a file
  /// dialog on Windows, a file input on web. This is the only source that
  /// reaches images saved outside the photo library, such as a scan in
  /// iCloud Drive or a PDF export sitting in Downloads.
  ///
  /// On iOS this is *not* the camera roll — photos taken with the phone live
  /// in Photos, which is [gallery]. Offer both if your users may have either.
  ///
  /// Files arrive at their original size, with no downscaling, so a large
  /// photo can exceed the 10 MB limit.
  files,

  /// The photo library.
  ///
  /// Photos on iOS, the gallery on Android, a file input on web and Windows.
  /// Use this for pictures the user took themselves; use [files] for documents
  /// they saved or received.
  gallery,

  /// The camera.
  ///
  /// Not available on Windows, macOS or Linux, where the platform has no
  /// camera implementation. Check [isSupported] before offering it;
  /// `TexoClientWidget` disables itself automatically rather than throwing.
  camera;

  /// Whether this source works on the platform the app is running on.
  ///
  /// Only [camera] is ever unsupported.
  bool get isSupported => switch (this) {
    TexoSource.files || TexoSource.gallery => true,
    TexoSource.camera =>
      kIsWeb ||
          defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS,
  };
}
