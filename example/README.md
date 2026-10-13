# texoclient_example

Runnable demo of the [`texo`](../) package: upload or photograph a document and see the extracted
text.

```sh
flutter run --dart-define=TEXO_API_KEY=your_key_here
```

Without the `--dart-define` the app still starts, but the buttons are disabled and it tells you
the key is missing.

See the package README for the iOS `Info.plist` entries `image_picker` requires.
