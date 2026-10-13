import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import '../models/extraction_error.dart';
import '../models/extraction_result.dart';
import '../texo_client.dart';
import '../texo_source.dart';

/// Extensions accepted by [TexoSource.files], matching what `MimeDetector`
/// can identify. Used with `FileType.custom`, which is what routes iOS to the
/// Files app — `FileType.image` there opens the photo library instead.
const _imageExtensions = <String>[
  'jpg',
  'jpeg',
  'png',
  'gif',
  'bmp',
  'webp',
  'heic',
];

/// A button that picks or captures an image, extracts its text, and reports the
/// result.
///
/// It owns the upload lifecycle: it disables itself while working, shows a
/// progress spinner, and creates and disposes its own [ImageTextExtractor]
/// unless you supply one.
///
/// ```dart
/// TexoClientWidget(
///   label: 'Upload',
///   icon: Icons.upload,
///   apiKey: apiKey,
///   documentType: 'drivinglicense',
///   onResponse: (result) => print(result.text),
///   onError: (error) => print(error.message),
/// )
/// ```
///
/// Without [onError], failures are shown in a `SnackBar`, which requires a
/// `Scaffold` ancestor.
class TexoClientWidget extends StatefulWidget {
  /// Creates the button.
  ///
  /// Asserts that [image] is non-null whenever [showImageIcon] is true.
  const TexoClientWidget({
    super.key,
    required this.label,
    required this.apiKey,
    required this.documentType,
    this.source = TexoSource.files,
    this.storeImage = false,
    this.enabled = true,
    this.onResponse,
    this.onImagePicked,
    this.onError,
    this.icon,
    this.showImageIcon = false,
    this.image,
    this.leadingSize = 20,
    this.backgroundColor,
    this.foregroundColor,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    this.borderRadius = const BorderRadius.all(Radius.circular(20)),
    this.extractor,
  }) : assert(
         !showImageIcon || image != null,
         'showImage is true but no image was given',
       );

  /// Text shown on the button.
  final String label;

  /// Texo API key. Changing it rebuilds the internal extractor.
  final String apiKey;

  /// Document type passed to the API, e.g. `'drivinglicense'`.
  final String documentType;

  /// Where the image comes from: the file browser, the photo library or the
  /// camera. See [TexoSource]; on iOS the first two are different places.
  final TexoSource source;

  /// Whether the API should retain the uploaded image.
  final bool storeImage;

  /// Whether the button accepts taps. It also disables itself while uploading.
  final bool enabled;

  /// Called after a successful extraction.
  ///
  /// Use `result.text` for the extracted text, or `result.raw` for the
  /// unmodified response body.
  final void Function(ExtractionResult result)? onResponse;

  /// Called as soon as the user picks an image, before the upload starts.
  final void Function(Uint8List bytes, String filename)? onImagePicked;

  /// Called on failure, with `error.message` ready to display.
  ///
  /// [ExtractionException] is sealed, so a `switch` over it is exhaustive.
  /// Without this callback, errors are shown in a `SnackBar`, which requires a
  /// `Scaffold` ancestor.
  final void Function(ExtractionException error)? onError;

  /// Leading icon. Ignored when [showImageIcon] is true.
  final IconData? icon;

  /// Whether to use [image] as the leading icon instead of [icon].
  final bool showImageIcon;

  /// Leading image, required when [showImageIcon] is true.
  final ImageProvider? image;

  /// Size of the leading icon and of the progress spinner.
  final double leadingSize;

  /// Button fill. Defaults to the theme's `primary`.
  final Color? backgroundColor;

  /// Label and icon color. Defaults to the theme's `onPrimary`.
  final Color? foregroundColor;

  /// Padding inside the button.
  final EdgeInsetsGeometry padding;

  /// Corner radius of the button.
  final BorderRadius borderRadius;

  /// An extractor to use instead of creating one. You own its disposal.
  final ImageTextExtractor? extractor;

  @override
  State<TexoClientWidget> createState() => TexoClientWidgetState();
}

/// State for [TexoClientWidget]. Public so tests can reach it.
class TexoClientWidgetState extends State<TexoClientWidget> {
  /// The most recent successful result, or null before the first one.
  ExtractionResult? result;
  final _picker = ImagePicker();
  late ImageTextExtractor _extractor;
  bool _ownsExtractor = false;
  bool _loading = false;
  double _progress = 0;
  // A camera button on Windows would throw the moment it was tapped, so it
  // presents as disabled instead.
  bool get _enabled => widget.enabled && !_loading && widget.source.isSupported;

  @override
  void initState() {
    super.initState();
    _buildExtractor();
  }

  @override
  void didUpdateWidget(TexoClientWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.apiKey != oldWidget.apiKey ||
        widget.extractor != oldWidget.extractor) {
      if (_ownsExtractor) _extractor.close();
      _buildExtractor();
    }
  }

  void _buildExtractor() {
    _ownsExtractor = widget.extractor == null;
    _extractor = widget.extractor ?? ImageTextExtractor(apiKey: widget.apiKey);
  }

  @override
  void dispose() {
    if (_ownsExtractor) _extractor.close();
    super.dispose();
  }

  /// Opens the source and reads what the user chose, or null if they cancelled.
  Future<(Uint8List bytes, String filename)?> _pick() async {
    switch (widget.source) {
      case TexoSource.camera:
        final file = await _picker.pickImage(
          source: ImageSource.camera,
          imageQuality: 90,
        );
        if (file == null) return null;
        return (await file.readAsBytes(), file.name);

      case TexoSource.files:
      case TexoSource.gallery:
        // FileType.custom is what sends iOS to the Files app; FileType.image
        // would open the photo library there instead.
        final isFiles = widget.source == TexoSource.files;
        final file = await FilePicker.pickFile(
          type: isFiles ? FileType.custom : FileType.image,
          allowedExtensions: isFiles ? _imageExtensions : null,
        );
        if (file == null) return null;
        return (await file.readAsBytes(), file.name);
    }
  }

  Future<void> _run() async {
    if (_loading) return;

    final (Uint8List, String)? picked;
    try {
      picked = await _pick();
    } catch (e) {
      _fail(PickerException('Could not open ${widget.source.name}', cause: e));
      return;
    }
    if (picked == null) return;

    final (bytes, filename) = picked;
    if (!mounted) return;
    widget.onImagePicked?.call(bytes, filename);

    setState(() {
      _loading = true;
      _progress = 0;
    });

    try {
      final ExtractionResult result = await _extractor.extractFromBytes(
        bytes,
        apikey: widget.apiKey,
        documentType: widget.documentType,
        filename: filename,
        storeImage: widget.storeImage,
        onProgress: (sent, total) {
          if (total <= 0 || !mounted) return;
          setState(() => _progress = sent / total);
        },
      );
      if (!mounted) return;
      setState(() {
        this.result = result;
        _loading = false;
      });
      widget.onResponse?.call(result);
    } on ExtractionException catch (e) {
      _fail(e);
    } catch (e) {
      _fail(UnknownException(e.toString(), cause: e));
    }
  }

  void _fail(ExtractionException error) {
    if (!mounted) return;
    setState(() => _loading = false);
    if (widget.onError != null) {
      widget.onError!(error);
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final background = _enabled
        ? (widget.backgroundColor ?? scheme.primary)
        : scheme.onSurface.withValues(alpha: 0.12);
    final foreground = _enabled
        ? (widget.foregroundColor ?? scheme.onPrimary)
        : scheme.onSurface.withValues(alpha: 0.38);

    final leading = _buildLeading(foreground);

    return Material(
      color: background,
      borderRadius: widget.borderRadius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: _enabled ? _run : null,
        child: Padding(
          padding: widget.padding,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (leading != null) ...[leading, const SizedBox(width: 8)],
              Flexible(
                child: Text(
                  widget.label,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: foreground,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget? _buildLeading(Color foreground) {
    if (_loading) {
      return SizedBox(
        width: widget.leadingSize,
        height: widget.leadingSize,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: foreground,
          // indeterminate until the upload reports real numbers
          value: _progress > 0 && _progress < 1 ? _progress : null,
        ),
      );
    }
    if (widget.showImageIcon && widget.image != null) {
      return Image(
        image: widget.image!,
        width: widget.leadingSize,
        height: widget.leadingSize,
        fit: BoxFit.contain,
      );
    }
    if (widget.icon != null) {
      return Icon(widget.icon, size: widget.leadingSize, color: foreground);
    }
    return null;
  }
}
