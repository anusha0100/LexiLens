// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:lexilens/bloc/app_bloc.dart';
import 'package:lexilens/bloc/app_events.dart';
import 'package:lexilens/bloc/app_states.dart';
import 'package:lexilens/models/document_model.dart';
import 'package:lexilens/services/auth_service.dart';
import 'package:lexilens/services/mongodb_service.dart';
import 'package:lexilens/services/syllable_service.dart';

class TextOverlayScreen extends StatefulWidget {
  final String imagePath;
  final List<TextBlock> textBlocks;
  final bool useOpenDyslexic;
  final double fontSize;
  final String? detectedLanguage;
  final String? detectedScript;
  const TextOverlayScreen({
    super.key,
    required this.imagePath,
    required this.textBlocks,
    this.useOpenDyslexic = true,
    this.fontSize = 14.0,
    this.detectedLanguage,
    this.detectedScript,
  });

  @override
  State<TextOverlayScreen> createState() => _TextOverlayScreenState();
}

class _TextOverlayScreenState extends State<TextOverlayScreen> {
  final _syllableService = SyllableService();
  bool _showOverlay = true;
  final ScrollController _scrollController = ScrollController();
  ui.Image? _decodedImage;
  Size? _imageDisplaySize;
  final GlobalKey _imageKey = GlobalKey();
  late bool _useOpenDyslexic;
  late double _fontSize;
  bool _isSaving = false;
  final _authService = AuthService();
  final _mongoService = MongoDBService();
  late String _detectedLanguage;
  late String _detectedScript;
  late bool _canUseOpenDyslexic;

  @override
  void initState() {
    super.initState();
    _detectedLanguage = widget.detectedLanguage ?? 'English';
    _detectedScript = widget.detectedScript ?? 'Latin';
    _canUseOpenDyslexic = _shouldUseOpenDyslexic();
    _useOpenDyslexic = _canUseOpenDyslexic && widget.useOpenDyslexic;
    _fontSize = widget.fontSize;
    _loadImage();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _getImageDisplaySize();
    });
  }

  bool _shouldUseOpenDyslexic() {
    final latinLanguages = [
      'English','Spanish','French','German','Italian',
      'Portuguese','Dutch','Swedish','Norwegian','Danish',
    ];
    return latinLanguages.contains(_detectedLanguage);
  }

  Widget _buildLanguageInfoBanner() {
    if (!_canUseOpenDyslexic) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        color: Colors.orange.withOpacity(0.9),
        child: Row(
          children: [
            const Icon(Icons.info_outline, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Detected: $_detectedLanguage ($_detectedScript script).',
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ],
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Future<void> _loadImage() async {
    try {
      final imageFile = File(widget.imagePath);
      if (!imageFile.existsSync()) {
        print('Image file not found at path: ${widget.imagePath}');
        return;
      }
      final bytes = await imageFile.readAsBytes();
      final image = await decodeImageFromList(bytes);
      if (mounted) {
        setState(() {
          _decodedImage = image;
        });
        _getImageDisplaySize();
      }
    } catch (e) {
      print('Error loading image: $e');
    }
  }

  void _getImageDisplaySize() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final RenderBox? renderBox =
          _imageKey.currentContext?.findRenderObject() as RenderBox?;
      if (renderBox != null && mounted) {
        setState(() {
          _imageDisplaySize = renderBox.size;
        });
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    try {
      // FIX: Always stop TTS when this screen is disposed (covers back button,
      // system back gesture, and any other route-pop path).
      context.read<AppBloc>().add(StopTextToSpeech());
    } catch (e) {
      // Context might not be available during dispose
    }
    super.dispose();
  }

  String get _extractedText {
    return widget.textBlocks.map((block) => block.text).join('\n\n');
  }

  List<String> get _allWords {
    return _extractedText
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
  }

  void _togglePlayPause(BuildContext context, AppState state) {
    if (state.readingState == ReadingState.playing) {
      context.read<AppBloc>().add(PauseTextToSpeech());
    } else if (state.readingState == ReadingState.paused) {
      context.read<AppBloc>().add(ResumeTextToSpeech());
    } else {
      context.read<AppBloc>().add(StartTextToSpeech(
          text: _extractedText, detectedLanguage: _detectedLanguage));
    }
  }

  void _stopReading(BuildContext context) {
    context.read<AppBloc>().add(StopTextToSpeech());
  }

  void _copyToClipboard() {
    Clipboard.setData(ClipboardData(text: _extractedText));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Text copied to clipboard'),
        duration: Duration(seconds: 2),
        backgroundColor: Color(0xFFB789DA),
      ),
    );
  }

  void _showSyllableBreakdown(String word, Offset position) {
    final syllables = _syllableService.breakIntoSyllables(word);
    final formatted = _syllableService.formatSyllables(syllables);

    showDialog(
      context: context,
      barrierColor: Colors.black26,
      builder: (context) => GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Stack(
          children: [
            Positioned(
              left: position.dx - 100,
              top: position.dy - 80,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFB789DA),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        word,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontFamily: 'OpenDyslexic',
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        formatted,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'OpenDyslexic',
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${syllables.length} syllable${syllables.length > 1 ? 's' : ''}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 10,
                          fontFamily: 'OpenDyslexic',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _toggleFontStyle() {
    setState(() {
      _useOpenDyslexic = !_useOpenDyslexic;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_useOpenDyslexic
            ? 'Using OpenDyslexic font'
            : 'Using default font'),
        duration: const Duration(seconds: 1),
        backgroundColor: const Color(0xFFB789DA),
      ),
    );
  }

  Future<void> _saveDocument() async {
    if (_isSaving) return;
    setState(() { _isSaving = true; });

    try {
      final user = _authService.currentUser;
      if (user == null) throw Exception('User not logged in');

      final token = await user.getIdToken(true);
      if (token != null) _mongoService.setAuthToken(token);

      final userId = user.uid;
      final text = _extractedText.trim();
      if (text.isEmpty) {
        throw Exception(
            'No text was extracted from this scan. Try rescanning with better lighting.');
      }

      final document = DocumentModel(
        userId: userId,
        name: 'Scanned_${DateTime.now().millisecondsSinceEpoch}',
        content: text,
        filePath: null,
        uploadedDate: DateTime.now(),
        tags: [],
        isFavorite: false,
        detectedLanguage: _detectedLanguage,
        detectedScript: _detectedScript,
      );

      await _mongoService.createDocument(document);

      if (mounted) {
        context.read<AppBloc>().add(LoadDocuments());
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Document saved successfully!'),
            backgroundColor: Color(0xFFB789DA),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving document: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) setState(() { _isSaving = false; });
    }
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFFB789DA),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Text Overlay',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontFamily: _detectedScript == 'Devanagari'
                  ? 'NotoSansDevanagari'
                  : 'OpenDyslexic',
            ),
          ),
          Text(
            'Language: $_detectedLanguage',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontFamily: _detectedScript == 'Devanagari'
                  ? 'NotoSansDevanagari'
                  : 'OpenDyslexic',
            ),
          ),
        ],
      ),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () {
          // FIX: Stop TTS immediately when the back button in the AppBar is pressed.
          _stopReading(context);
          Navigator.pop(context);
        },
      ),
      actions: [
        IconButton(
          icon: Icon(
            _useOpenDyslexic
                ? Icons.font_download
                : Icons.font_download_outlined,
            color: Colors.white,
          ),
          tooltip: _useOpenDyslexic
              ? 'Switch to default font'
              : 'Switch to OpenDyslexic',
          onPressed: _toggleFontStyle,
        ),
        IconButton(
          icon: Icon(
            _showOverlay ? Icons.visibility : Icons.visibility_off,
            color: Colors.white,
          ),
          tooltip: _showOverlay ? 'Hide Overlay' : 'Show Overlay',
          onPressed: () {
            setState(() { _showOverlay = !_showOverlay; });
          },
        ),
        IconButton(
          icon: const Icon(Icons.settings, color: Colors.white),
          onPressed: () => _showSettingsDialog(context),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      // FIX: Intercept the system/hardware back button and stop TTS before popping.
      onWillPop: () async {
        _stopReading(context);
        return true;
      },
      child: BlocBuilder<AppBloc, AppState>(
        builder: (context, state) {
          return Scaffold(
            backgroundColor: Colors.black,
            appBar: _buildAppBar(),
            body: Column(
              children: [
                _buildLanguageInfoBanner(),
                Expanded(
                  child: InteractiveViewer(
                    minScale: 0.5,
                    maxScale: 4.0,
                    child: Center(
                      child: _buildOverlayContent(state),
                    ),
                  ),
                ),
              ],
            ),
            bottomNavigationBar: Container(
              color: const Color(0xFFB789DA),
              padding: const EdgeInsets.all(16),
              child: SafeArea(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildBottomButton(
                      icon: state.readingState == ReadingState.playing
                          ? Icons.pause
                          : Icons.play_arrow,
                      label: state.readingState == ReadingState.playing
                          ? 'Pause'
                          : (state.readingState == ReadingState.paused
                              ? 'Resume'
                              : 'Read'),
                      onTap: () => _togglePlayPause(context, state),
                    ),
                    _buildBottomButton(
                      icon: Icons.copy,
                      label: 'Copy',
                      onTap: _copyToClipboard,
                    ),
                    _buildBottomButton(
                      icon: _isSaving ? Icons.hourglass_bottom : Icons.save,
                      label: _isSaving ? 'Saving...' : 'Save',
                      onTap: _isSaving ? () {} : _saveDocument,
                    ),
                    _buildBottomButton(
                      icon: Icons.share,
                      label: 'Share',
                      onTap: () => _showShareOptions(context),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildOverlayContent(AppState state) {
    if (_decodedImage == null || _imageDisplaySize == null) {
      return Image.file(
        File(widget.imagePath),
        key: _imageKey,
        fit: BoxFit.contain,
      );
    }

    return InteractiveViewer(
      minScale: 1.0,
      maxScale: 3.0,
      scaleEnabled: true,
      panEnabled: true,
      onInteractionUpdate: (details) {
        if (details.scale != state.zoomLevel) {
          context.read<AppBloc>().add(AdjustZoom(details.scale));
        }
      },
      child: Stack(
        children: [
          Image.file(
            File(widget.imagePath),
            key: _imageKey,
            fit: BoxFit.contain,
          ),
          // FIX: Only show overlay if it's enabled AND we have text blocks to display
          if (_showOverlay && widget.textBlocks.isNotEmpty && _decodedImage != null && _imageDisplaySize != null)
            Positioned.fill(
              child: GestureDetector(
                onLongPressStart: (details) {
                  final word = _findWordAtPosition(details.localPosition);
                  if (word.isNotEmpty && word.length > 3) {
                    _showSyllableBreakdown(word, details.globalPosition);
                  }
                },
                child: CustomPaint(
                  painter: OverlayStyle(
                    textBlocks: widget.textBlocks,
                    imageActualSize: Size(
                      _decodedImage!.width.toDouble(),
                      _decodedImage!.height.toDouble(),
                    ),
                    imageDisplaySize: _imageDisplaySize!,
                    currentWordIndex: state.readingState != ReadingState.idle
                        ? state.currentWordIndex
                        : -1,
                    allWords: _allWords,
                    useOpenDyslexic: _useOpenDyslexic,
                    fontSize: _fontSize,
                    overlayOpacity: state.overlayOpacity,
                    detectedLanguage: _detectedLanguage,
                    detectedScript: _detectedScript,
                  ),
                  size: Size.infinite,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBottomButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 24),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontFamily: _detectedScript == 'Devanagari'
                  ? 'NotoSansDevanagari'
                  : 'OpenDyslexic',
            ),
          ),
        ],
      ),
    );
  }

  String _findWordAtPosition(Offset position) {
    if (_decodedImage == null || _imageDisplaySize == null) return '';

    final scaleX = _imageDisplaySize!.width / _decodedImage!.width;
    final scaleY = _imageDisplaySize!.height / _decodedImage!.height;

    for (final block in widget.textBlocks) {
      for (final line in block.lines) {
        final boundingBox = line.boundingBox;
        final scaledRect = Rect.fromLTRB(
          boundingBox.left * scaleX,
          boundingBox.top * scaleY,
          boundingBox.right * scaleX,
          boundingBox.bottom * scaleY,
        );

        if (scaledRect.contains(position)) {
          final words = line.text.split(RegExp(r'\s+'));
          final wordWidth = scaledRect.width / words.length;
          final relativeX = position.dx - scaledRect.left;
          final wordIndex = (relativeX / wordWidth).floor();

          if (wordIndex >= 0 && wordIndex < words.length) {
            return words[wordIndex].replaceAll(RegExp(r'[^\w]'), '');
          }
        }
      }
    }

    return '';
  }

  void _showSettingsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => BlocProvider.value(
        value: context.read<AppBloc>(),
        child: StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text(
                'Display Settings',
                style: TextStyle(fontFamily: 'OpenDyslexic'),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SwitchListTile(
                    title: const Text(
                      'OpenDyslexic Font',
                      style: TextStyle(fontFamily: 'OpenDyslexic'),
                    ),
                    subtitle: const Text(
                      'Use dyslexia-friendly font',
                      style: TextStyle(fontSize: 12),
                    ),
                    value: _useOpenDyslexic,
                    activeColor: const Color(0xFFB789DA),
                    onChanged: (value) {
                      setState(() { _useOpenDyslexic = value; });
                      this.setState(() { _useOpenDyslexic = value; });
                    },
                  ),
                  const Divider(),
                  Text(
                    'Font Size: ${_fontSize.toInt()}',
                    style: const TextStyle(fontFamily: 'OpenDyslexic'),
                  ),
                  Slider(
                    value: _fontSize,
                    min: 10.0,
                    max: 24.0,
                    divisions: 14,
                    activeColor: const Color(0xFFB789DA),
                    label: _fontSize.toInt().toString(),
                    onChanged: (value) {
                      setState(() { _fontSize = value; });
                      this.setState(() { _fontSize = value; });
                    },
                  ),
                  BlocBuilder<AppBloc, AppState>(
                    builder: (context, state) {
                      return Column(
                        children: [
                          Text(
                            'Overlay Opacity: ${(state.overlayOpacity * 100).toInt()}%',
                            style: const TextStyle(fontFamily: 'OpenDyslexic'),
                          ),
                          Slider(
                            value: state.overlayOpacity,
                            min: 0.5,
                            max: 1.0,
                            divisions: 10,
                            activeColor: const Color(0xFFB789DA),
                            label: '${(state.overlayOpacity * 100).toInt()}%',
                            onChanged: (value) {
                              context
                                  .read<AppBloc>()
                                  .add(AdjustOverlayOpacity(value));
                            },
                          ),
                        ],
                      );
                    },
                  ),
                  const Divider(),
                  BlocBuilder<AppBloc, AppState>(
                    builder: (context, state) {
                      return Column(
                        children: [
                          Text(
                            'Reading Speed: ${(state.readingSpeed * 2).toStringAsFixed(1)}x',
                            style: const TextStyle(fontFamily: 'OpenDyslexic'),
                          ),
                          Slider(
                            value: state.readingSpeed,
                            min: 0.1,
                            max: 1.0,
                            divisions: 9,
                            activeColor: const Color(0xFFB789DA),
                            onChanged: (value) {
                              context.read<AppBloc>().add(AdjustSpeed(value));
                            },
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Volume: ${(state.volume * 100).toInt()}%',
                            style: const TextStyle(fontFamily: 'OpenDyslexic'),
                          ),
                          Slider(
                            value: state.volume,
                            min: 0.0,
                            max: 1.0,
                            divisions: 10,
                            activeColor: const Color(0xFFB789DA),
                            onChanged: (value) {
                              context.read<AppBloc>().add(AdjustVolume(value));
                            },
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text(
                    'Close',
                    style: TextStyle(
                      color: Color(0xFFB789DA),
                      fontFamily: 'OpenDyslexic',
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _showShareOptions(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(
          'Share Document',
          style: TextStyle(fontFamily: 'OpenDyslexic'),
        ),
        content: const Text(
          'Choose how you want to share:',
          style: TextStyle(fontFamily: 'OpenDyslexic'),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              context.read<AppBloc>().add(ShareDocumentAsText(
                documentName: widget.imagePath.split('/').last,
                content: _extractedText,
              ));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Sharing text...'),
                  backgroundColor: Color(0xFFB789DA),
                  duration: Duration(seconds: 1),
                ),
              );
            },
            child: const Text('Share as Text'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              context.read<AppBloc>().add(ShareDocument(
                documentName: widget.imagePath
                    .split('/')
                    .last
                    .replaceAll('.jpg', '')
                    .replaceAll('.png', ''),
                content: _extractedText,
                format: 'pdf',
                detectedLanguage: _detectedLanguage,
              ));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Creating PDF...'),
                  backgroundColor: Color(0xFFB789DA),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            child: const Text('Share as PDF'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              context.read<AppBloc>().add(ExportDocumentAsText(
                documentName: widget.imagePath.split('/').last,
                content: _extractedText,
              ));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Exporting text...'),
                  backgroundColor: Color(0xFFB789DA),
                  duration: Duration(seconds: 1),
                ),
              );
            },
            child: const Text('Export as Text'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              context.read<AppBloc>().add(ExportDocumentAsPDF(
                documentName: widget.imagePath
                    .split('/')
                    .last
                    .replaceAll('.jpg', '')
                    .replaceAll('.png', ''),
                content: _extractedText,
                detectedLanguage: _detectedLanguage,
              ));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Creating PDF...'),
                  backgroundColor: Color(0xFFB789DA),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            child: const Text('Export as PDF'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Color(0xFFB789DA)),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// OverlayStyle painter
// FIX: layout() called without maxWidth so OpenDyslexic glyphs (wider than
// system fonts) are never truncated. Background rect gets vertical padding
// to accommodate the font's taller ascenders/descenders.
// ---------------------------------------------------------------------------
class OverlayStyle extends CustomPainter {
  final double overlayOpacity;
  final List<TextBlock> textBlocks;
  final Size imageActualSize;
  final Size imageDisplaySize;
  final int currentWordIndex;
  final List<String> allWords;
  final bool useOpenDyslexic;
  final double fontSize;
  final String? detectedLanguage;
  final String? detectedScript;

  OverlayStyle({
    required this.overlayOpacity,
    required this.textBlocks,
    required this.imageActualSize,
    required this.imageDisplaySize,
    required this.currentWordIndex,
    required this.allWords,
    required this.useOpenDyslexic,
    required this.fontSize,
    this.detectedLanguage,
    this.detectedScript,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // FIX: Safety check — if no data, return immediately
    if (textBlocks.isEmpty || imageActualSize == Size.zero || imageDisplaySize == Size.zero) {
      return;
    }

    final containerAspect = imageDisplaySize.width / imageDisplaySize.height;
    final imageAspect     = imageActualSize.width  / imageActualSize.height;

    late Size renderedSize;
    if (imageAspect > containerAspect) {
      renderedSize = Size(imageDisplaySize.width, imageDisplaySize.width / imageAspect);
    } else {
      renderedSize = Size(imageDisplaySize.height * imageAspect, imageDisplaySize.height);
    }
    final offsetX = (imageDisplaySize.width  - renderedSize.width)  / 2;
    final offsetY = (imageDisplaySize.height - renderedSize.height) / 2;

    final scaleX = renderedSize.width  / imageActualSize.width;
    final scaleY = renderedSize.height / imageActualSize.height;
    int globalWordIndex = 0;

    final shouldUseOpenDyslexic =
        useOpenDyslexic && _isLatinLanguage(detectedLanguage);
    final shouldUseDevanagariFont =
        !shouldUseOpenDyslexic && detectedScript == 'Devanagari';

    // FIX: Paint all text blocks with proper coordinate transformation
    for (final block in textBlocks) {
      for (final line in block.lines) {
        final boundingBox = line.boundingBox;
        final left   = boundingBox.left   * scaleX + offsetX;
        final top    = boundingBox.top    * scaleY + offsetY;
        final right  = boundingBox.right  * scaleX + offsetX;
        final bottom = boundingBox.bottom * scaleY + offsetY;
        final scaledRect = Rect.fromLTRB(left, top, right, bottom);
        final lineHeight = scaledRect.height;
        final lineText   = line.text;
        final words = lineText
            .split(RegExp(r'\s+'))
            .where((w) => w.isNotEmpty)
            .toList();

        if (words.isEmpty) continue;

        final lineStartIndex = globalWordIndex;
        final lineEndIndex   = lineStartIndex + words.length;
        final isLineActive   = currentWordIndex >= lineStartIndex &&
            currentWordIndex < lineEndIndex;

        // FIX: Add vertical padding so OpenDyslexic's taller glyphs fit
        // inside the background rect without clipping.
        final double vPad = shouldUseOpenDyslexic ? lineHeight * 0.25 : 2.0;

        final backgroundPaint = Paint()
          ..color = const Color(0xFFEEEEEE).withOpacity(overlayOpacity)
          ..style = PaintingStyle.fill;

        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTRB(left - 4, top - vPad, right + 4, bottom + vPad),
            const Radius.circular(4),
          ),
          backgroundPaint,
        );

        final defaultFontFamily = shouldUseOpenDyslexic
            ? 'OpenDyslexic'
            : (shouldUseDevanagariFont ? 'NotoSansDevanagari' : null);

        if (line.elements.isNotEmpty) {
          for (int wordIdx = 0; wordIdx < line.elements.length; wordIdx++) {
            final element = line.elements[wordIdx];
            final word    = element.text;
            final wordBox = element.boundingBox;
            if (wordBox == null) continue;

            final wordLeft   = wordBox.left   * scaleX + offsetX;
            final wordTop    = wordBox.top    * scaleY + offsetY;
            final wordWidth  = wordBox.width  * scaleX;
            final wordHeight = wordBox.height * scaleY;

            final isCurrentWord =
                isLineActive && (globalWordIndex + wordIdx) == currentWordIndex;

            final wordStyle = TextStyle(
              color: isCurrentWord ? Colors.red.shade800 : Colors.black87,
              // FIX: use fontSize (user setting) as ceiling; clamp to actual
              // word-box height so text never overflows its detected region.
              fontSize: fontSize.clamp(7.0, wordHeight.clamp(7.0, fontSize + 4)),
              fontWeight: isCurrentWord ? FontWeight.bold : FontWeight.w500,
              fontFamily: defaultFontFamily,
              height: 1.0,
              letterSpacing: shouldUseOpenDyslexic ? 0.5 : 0,
            );

            final textPainter = TextPainter(
              text: TextSpan(text: word, style: wordStyle),
              textDirection: TextDirection.ltr,
              maxLines: 1,
              // FIX: layout without maxWidth so OpenDyslexic glyphs are never
              // truncated — the word is placed at its exact bounding-box origin
              // so overflow goes rightward into natural inter-word space.
            )..layout();

            if (isCurrentWord) {
              final highlightPaint = Paint()
                ..color = Colors.yellow.withOpacity(0.6)
                ..style = PaintingStyle.fill;

              canvas.drawRRect(
                RRect.fromRectAndRadius(
                  Rect.fromLTWH(
                      wordLeft - 2, wordTop - vPad,
                      wordWidth + 4, wordHeight + vPad * 2),
                  const Radius.circular(2),
                ),
                highlightPaint,
              );
            }

            final bgH   = wordHeight + vPad * 2;
            final textY = (wordTop - vPad) + (bgH - textPainter.height) / 2;
            textPainter.paint(canvas, Offset(wordLeft, textY));
          }

          globalWordIndex += line.elements.length;
          continue;
        }

        // ── Fallback: no per-word elements — render whole line ──────────────
        final calculatedFontSize = (lineHeight * 0.55).clamp(8.0, fontSize);

        final textStyle = TextStyle(
          fontSize: calculatedFontSize,
          fontWeight: FontWeight.w500,
          fontFamily: defaultFontFamily,
          height: 1.0,
        );

        // Measure full line to compute a scale-down factor if it is wider
        // than the available box, then re-render word-by-word so individual
        // words can still be highlighted by the TTS word index.
        final testPainter = TextPainter(
          text: TextSpan(text: lineText, style: textStyle),
          textDirection: TextDirection.ltr,
        )..layout();

        final availableWidth = scaledRect.width - 8;
        final scaleFactor    = testPainter.width > availableWidth
            ? availableWidth / testPainter.width
            : 1.0;
        final adjustedFontSize =
            (calculatedFontSize * scaleFactor).clamp(7.0, fontSize);

        double currentX = left + 4;
        for (int wordIdx = 0; wordIdx < words.length; wordIdx++) {
          final word = words[wordIdx];
          final isCurrentWord =
              isLineActive && (globalWordIndex + wordIdx) == currentWordIndex;

          final wordStyle = TextStyle(
            color: isCurrentWord ? Colors.red.shade800 : Colors.black87,
            fontSize: adjustedFontSize,
            fontWeight: isCurrentWord ? FontWeight.bold : FontWeight.w500,
            fontFamily: defaultFontFamily,
            height: 1.0,
            letterSpacing: shouldUseOpenDyslexic ? 0.5 : 0,
          );

          // FIX: layout without maxWidth — same reasoning as per-element path.
          final textPainter = TextPainter(
            text: TextSpan(text: word, style: wordStyle),
            textDirection: TextDirection.ltr,
          )..layout();

          if (isCurrentWord) {
            final highlightPaint = Paint()
              ..color = Colors.yellow.withOpacity(0.6)
              ..style = PaintingStyle.fill;

            canvas.drawRRect(
              RRect.fromRectAndRadius(
                Rect.fromLTWH(
                  currentX - 1,
                  top - vPad + 1,
                  textPainter.width + 2,
                  lineHeight + vPad * 2 - 2,
                ),
                const Radius.circular(2),
              ),
              highlightPaint,
            );
          }

          final bgTop = top - vPad;
          final bgH   = lineHeight + vPad * 2;
          final textY = bgTop + (bgH - textPainter.height) / 2;
          textPainter.paint(canvas, Offset(currentX, textY));
          // Advance by actual painted width + a small word-gap.
          currentX += textPainter.width +
              (shouldUseOpenDyslexic ? adjustedFontSize * 0.25 : adjustedFontSize * 0.15);
        }

        globalWordIndex += words.length;
      }
    }
  }

  bool _isLatinLanguage(String? language) {
    if (language == null) return true;
    const latinLanguages = [
      'English','Spanish','French','German','Italian',
      'Portuguese','Dutch','Swedish','Norwegian','Danish',
    ];
    return latinLanguages.contains(language);
  }

  @override
  bool shouldRepaint(OverlayStyle oldDelegate) {
    return oldDelegate.currentWordIndex != currentWordIndex ||
        oldDelegate.imageDisplaySize != imageDisplaySize ||
        oldDelegate.useOpenDyslexic != useOpenDyslexic ||
        oldDelegate.fontSize != fontSize ||
        oldDelegate.overlayOpacity != overlayOpacity;
  }
}
