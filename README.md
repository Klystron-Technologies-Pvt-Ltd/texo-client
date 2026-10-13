# texoclient

Flutter client and drop-in button widget for the Texo OCR API. Pick or capture an image and get
structured data back, with typed errors and automatic retries.

## Install

```yaml
dependencies:
  texoclient: ^1.0.0
```

```dart
import 'package:texoclient/texoclient.dart';
```

## Platform support

| | Android | iOS | Web | Windows | macOS | Linux |
| --- | --- | --- | --- | --- | --- | --- |
| Files / gallery | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Camera | ✅ | ✅ | ✅\* | ❌ | ❌ | ❌ |

\* On desktop browsers, the camera falls back to a file chooser.

**Camera capture is not available on Windows, macOS or Linux.** There the camera button disables
itself rather than throwing; check `TexoSource.camera.isSupported` to hide it instead. The iOS
camera permission and the macOS entitlement are covered under [Platform setup](#platform-setup).

## Get an API key

You need a Texo API key and at least one document type set up for your account. To buy an API key
and set up document types, visit **[klys.ai/texo](https://klys.ai/texo/)**.

The `documentType` you pass (for example `'drivinglicense'`) must be one that is set up for your
key there; otherwise the API rejects the request.

Define the key and document type once and pass them to the widget or the client:

```dart
const String texoApiKey = 'YOUR_TEXO_API_KEY';
const String texoDocumentType = 'drivinglicense';
```

Keep your real key out of public repositories.

## Quick start — the widget

`TexoClientWidget` is a button. Tapping it opens the gallery or the camera, uploads what the user
picks, and calls you back with the result. It owns the loading state and shows upload progress.

```dart
TexoClientWidget(
  label: 'Upload doc',
  icon: Icons.upload_file_rounded,
  source: TexoSource.files,
  apiKey: texoApiKey,
  documentType: texoDocumentType,
  backgroundColor: Colors.teal.withValues(alpha: 0.12),
  foregroundColor: Colors.teal,
  onImagePicked: (bytes, filename) => setState(() => _preview = bytes),
  onResponse: (ExtractionResult result) {
    print(result.text);       // the extracted text
    print(result.raw);        // the unmodified response body
  },
  onError: (ExtractionException error) {
    print(error.message);     // ready to display
  },
)
```

### Where the image comes from

`source:` takes a `TexoSource`. It defaults to `files`.

| `TexoSource` | iOS | Android | Web | Windows | macOS | Linux |
| --- | --- | --- | --- | --- | --- | --- |
| `files` (default) | **Files, iCloud Drive** | Document picker | File input | File dialog | File dialog | File dialog |
| `gallery` | Photos | Gallery | File input | File dialog | File dialog | File dialog |
| `camera` | Camera | Camera | Camera (file chooser on desktop browsers) | **unsupported** | **unsupported** | **unsupported** |

**On iOS, `files` and `gallery` are different places.** Photos taken with the phone live in Photos
and are reached with `gallery`; a scan saved to iCloud Drive or received as an attachment is
reached with `files`. Offer both if your users might have either.

`camera` has no implementation on Windows, macOS or Linux. The widget checks and **disables itself
rather than throwing**, so a camera button is safe to render anywhere — but you can hide it
yourself:

```dart
if (TexoSource.camera.isSupported)
  TexoClientWidget(source: TexoSource.camera, label: 'Camera', ...)
```

One caveat: `files` and `gallery` upload the original file unchanged, so a large original can
exceed the 10 MB limit and fail with `FileTooLargeException`. Only `camera` re-encodes the photo
(JPEG quality 90) before upload.

If you do not pass `onError`, failures are shown in a `SnackBar`, which requires a `Scaffold`
ancestor.

Because `ExtractionException` is sealed, you can branch on the failure exhaustively — the compiler
tells you if you miss a case:

```dart
onError: (error) => setState(() => _message = switch (error) {
  UnauthorizedException() => 'Check your API key.',
  PickerException()       => 'Allow camera access to continue.',
  FileTooLargeException(:final limit) => 'Keep images under ${limit ~/ 1024} KB.',
  _ => error.message,
}),
```

### Appearance

| Parameter | Default | Purpose |
| --- | --- | --- |
| `backgroundColor` / `foregroundColor` | theme `primary` / `onPrimary` | Button colors |
| `icon` | none | Leading `IconData` |
| `showImageIcon` + `image` | `false` | Use an `ImageProvider` as the leading icon instead |
| `leadingSize` | `20` | Size of the icon and the progress spinner |
| `padding` | `16` × `12` | Inner padding |
| `borderRadius` | `20` | Corner radius |
| `enabled` | `true` | Disables the button; it also disables itself while uploading |

### Behavior

| Parameter | Default | Purpose |
| --- | --- | --- |
| `source` | `TexoSource.files` | Where the image comes from; see above |
| `storeImage` | `false` | Whether the API should keep the uploaded image |
| `extractor` | none | Use your own `ImageTextExtractor`; you are then responsible for closing it |

## Quick start — the client

Use `ImageTextExtractor` directly when you already have bytes, or when you want to drive the
request yourself.

```dart
final extractor = ImageTextExtractor(apiKey: texoApiKey);

try {
  final result = await extractor.extractFromBytes(
    bytes,
    apikey: texoApiKey,
    documentType: texoDocumentType,
    onProgress: (sent, total) => print('${sent / total}'),
  );
  print(result.text);          // the response's `extracted_text` field
  print(result.documentType);  // as reported by the API, if any
  print(result.prettyJson);    // the full response body, indented
} on ExtractionException catch (e) {
  print(e.message);
} finally {
  extractor.close();
}
```

Always call `close()` when you are done; it releases the underlying HTTP client.

`extractFromFile(file, apikey: ..., documentType: ...)` does the same for a `dart:io` `File` or an
`XFile`. Its `apikey` is nullable in the signature but must be passed; `null` throws.

Cancel an in-flight request by passing a `cancelToken` and calling `token.cancel()`; the call then
throws `CancelledException`.

### Constructor options

| Parameter | Default | Purpose |
| --- | --- | --- |
| `apiKey` | required | Throws `ArgumentError` if blank |
| `baseUrl` | Texo production API | Point at a different environment |
| `timeout` | 60 s | Receive timeout (connect timeout is fixed at 15 s) |
| `maxRetries` | `2` | Retries on transient failures only |

## Errors

Every failure is an `ExtractionException`, a sealed type — a `switch` over it is checked by the
compiler for exhaustiveness.

| Type | When | Retried |
| --- | --- | --- |
| `BadRequestException` | Empty image data; HTTP 400, 413, 422 or another unexpected status; or a 200 with `success: false` | no |
| `UnauthorizedException` | HTTP 401 or 403 — bad or missing API key | no |
| `FileTooLargeException` | Image exceeds 10 MB; caught before upload | no |
| `UnsupportedFormatException` | Bytes are not a recognized image, or HTTP 415 | no |
| `RateLimitException` | HTTP 429 | no |
| `ServerException` | HTTP 5xx | yes |
| `NetworkException` | Connection failed | yes |
| `TimeoutException` | Connect, send or receive timed out | yes |
| `CancelledException` | The `CancelToken` was cancelled | no |
| `PickerException` | The picker or camera failed to open, permission was denied, or the file could not be read. Widget only | no |
| `UnknownException` | Anything else; should not normally occur | no |

Retries use exponential backoff starting at 400 ms and doubling (400 ms, 800 ms, 1600 ms, …). With
the default `maxRetries: 2`, a request is tried at most three times.

This package's `TimeoutException` has the same name as the one in `dart:async`. If you import both,
hide one: `import 'dart:async' hide TimeoutException;`.

## Limits and supported formats

- Maximum upload size: **10 MB** (`ImageTextExtractor.maxFileSizeBytes`), enforced client-side.
- Formats are detected from magic bytes, not the filename: JPEG, PNG, GIF, BMP, WebP, HEIC.

## Platform setup

Only `TexoSource.camera` needs anything. `files` and `gallery` go through
[`file_picker`](https://pub.dev/packages/file_picker), which requires no permissions on iOS,
Android, Web or Windows.

### iOS — only if you use `camera`

Add to `ios/Runner/Info.plist`. **Without it the app crashes as soon as the camera opens**, which is
the most common integration problem:

```xml
<key>NSCameraUsageDescription</key>
<string>Used to photograph documents for text extraction.</string>
```

`NSPhotoLibraryUsageDescription` is not needed: on iOS, `gallery` opens PHPicker (through
`file_picker`), which is read-only and requires no usage description.

### Android, Web, Windows

Nothing to configure. Android needs `compileSdk` 34 or higher.

### macOS — only if you target it

A sandboxed macOS app needs a files entitlement in both `macos/Runner/DebugProfile.entitlements`
and `Release.entitlements`, or every pick fails:

```xml
<key>com.apple.security.files.user-selected.read-only</key>
<true/>
```
                   
For the authoritative, up-to-date setup see the
[`file_picker`](https://pub.dev/packages/file_picker) and
[`image_picker`](https://pub.dev/packages/image_picker#installation) docs.

## Example

A complete runnable app lives in [`example/`](example/):

Set `texoApiKey` at the top of `example/lib/main.dart`, then:

```sh
cd example
flutter run
```

## License

MIT — see [LICENSE](LICENSE).
