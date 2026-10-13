import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:texoclient/texoclient.dart';

// Paste your key from https://klys.ai/texo/ here.
const String texoApiKey = 'YOUR_TEXO_API_KEY';
const String texoDocumentType = 'drivinglicense';

bool get hasTexoApiKey =>
    texoApiKey.isNotEmpty && texoApiKey != 'YOUR_TEXO_API_KEY';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Texo OCR',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  ExtractionResult? result;
  Uint8List? imageBytes;
  ExtractionException? error;

  void _onImagePicked(Uint8List bytes, String _) => setState(() {
    imageBytes = bytes;
    result = null;
    error = null;
  });

  void _onResponse(ExtractionResult value) => setState(() {
    result = value;
    error = null;
  });

  void _onError(ExtractionException value) => setState(() => error = value);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: scheme.inversePrimary,
        title: const Text('Texo OCR'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!hasTexoApiKey) const _MissingKeyBanner(),
              Row(
                children: [
                  Expanded(
                    child: TexoClientWidget(
                      // The default. On iOS this opens Files and iCloud
                      // Drive, not the camera roll.
                      source: TexoSource.files,
                      label: 'Files',
                      icon: Icons.folder_open,
                      apiKey: texoApiKey,
                      documentType: texoDocumentType,
                      enabled: hasTexoApiKey,
                      onImagePicked: _onImagePicked,
                      onResponse: _onResponse,
                      onError: _onError,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TexoClientWidget(
                      source: TexoSource.gallery,
                      label: 'Photos',
                      icon: Icons.photo_library,
                      apiKey: texoApiKey,
                      documentType: texoDocumentType,
                      enabled: hasTexoApiKey,
                      backgroundColor: scheme.secondaryContainer,
                      foregroundColor: scheme.onSecondaryContainer,
                      onImagePicked: _onImagePicked,
                      onResponse: _onResponse,
                      onError: _onError,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Disables itself on Windows, macOS and Linux, where there is no
              // camera implementation, rather than throwing when tapped.
              TexoClientWidget(
                source: TexoSource.camera,
                label: TexoSource.camera.isSupported
                    ? 'Camera'
                    : 'Camera (not on this platform)',
                showImageIcon: true,
                image: const AssetImage('asset/image/check-out.png'),
                apiKey: texoApiKey,
                documentType: texoDocumentType,
                enabled: hasTexoApiKey,
                backgroundColor: scheme.tertiaryContainer,
                foregroundColor: scheme.onTertiaryContainer,
                onImagePicked: _onImagePicked,
                onResponse: _onResponse,
                onError: _onError,
              ),
              const SizedBox(height: 16),
              _ImagePreview(bytes: imageBytes),
              _ResponseView(result: result, error: error),
            ],
          ),
        ),
      ),
    );
  }
}

class _MissingKeyBanner extends StatelessWidget {
  const _MissingKeyBanner();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Card(
        color: theme.colorScheme.errorContainer,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'No API key. Set texoApiKey at the top of lib/main.dart.',
            style: TextStyle(color: theme.colorScheme.onErrorContainer),
          ),
        ),
      ),
    );
  }
}

class _ImagePreview extends StatelessWidget {
  const _ImagePreview({required this.bytes});

  final Uint8List? bytes;

  @override
  Widget build(BuildContext context) {
    final data = bytes;
    if (data == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.memory(data, height: 220, fit: BoxFit.contain),
      ),
    );
  }
}

class _ResponseView extends StatelessWidget {
  const _ResponseView({required this.result, required this.error});

  final ExtractionResult? result;
  final ExtractionException? error;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final failure = error;
    if (failure != null) {
      return Card(
        color: theme.colorScheme.errorContainer,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                // The sealed type tells you what went wrong, not just the text.
                failure.runtimeType.toString(),
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.onErrorContainer,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                failure.message,
                style: TextStyle(color: theme.colorScheme.onErrorContainer),
              ),
            ],
          ),
        ),
      );
    }

    final value = result;
    if (value == null) {
      return Padding(
        padding: const EdgeInsets.only(top: 32),
        child: Text(
          'Upload or capture an image to extract text.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium,
        ),
      );
    }

    final body = value.prettyJson;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Response', style: theme.textTheme.titleMedium),
                ),
                IconButton(
                  tooltip: 'Copy',
                  icon: const Icon(Icons.copy),
                  onPressed: () => Clipboard.setData(ClipboardData(text: body)),
                ),
              ],
            ),
            SelectableText(body),
          ],
        ),
      ),
    );
  }
}
