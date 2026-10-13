## 1.0.0

Initial release.

- `ImageTextExtractor` — OCR client with automatic retry on transient failures
  and typed exceptions for every error case.
- `TexoClientWidget` — button that picks or captures an image and extracts text,
  with progress reporting and themeable appearance. `onResponse` hands back an
  `ExtractionResult`; `onError` hands back a sealed `ExtractionException`, so
  callers can switch on the failure exhaustively.
- `TexoSource` — pick from the file browser (`files`, the default, reaching the
  Files app and iCloud Drive on iOS), the photo library (`gallery`) or the
  camera (`camera`). `files` and `gallery` work on iOS, Android, Web and
  Windows; `camera` reports `isSupported == false` on desktop and the widget
  disables itself there rather than throwing.
- Magic-byte MIME detection for JPEG, PNG, GIF, BMP, WebP and HEIC.
- Client-side 10 MB size gate, so oversized uploads fail before they start.
