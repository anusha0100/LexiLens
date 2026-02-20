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
      'English',
      'Spanish',
      'French',
      'German',
      'Italian',
      'Portuguese',
      'Dutch',
      'Swedish',
      'Norwegian',
      'Danish',
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
                'Detected: $_detectedLanguage ($_detectedScript script). Using system font for proper rendering.',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontFamily: 'OpenDyslexic',
                ),
              ),
            ),
          ],
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Future<void> _loadImage() async {
    final imageFile = File(widget.imagePath);
    final bytes = await imageFile.readAsBytes();
    final image = await decodeImageFromList(bytes);
    if (mounted) {
      setState(() {
        _decodedImage = image;
      });
      _getImageDisplaySize();
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
      context.read<AppBloc>().add(StartTextToSpeech(text: _extractedText));
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

    setState(() {
      _isSaving = true;
    });

    try {
      final userId = _authService.getUserId();

      if (userId == null) {
        throw Exception('User not logged in');
      }

      final document = DocumentModel(
        userId: userId,
        name: 'Scanned_${DateTime.now().millisecondsSinceEpoch}',
        content: _extractedText,
        filePath: widget.imagePath,
        uploadedDate: DateTime.now(),
        tags: [],
        isFavorite: false,
      );

      
      final savedDoc = await _mongoService.createDocument(document);

      if (savedDoc != null && mounted) {
        
        context.read<AppBloc>().add(LoadDocuments());

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Document saved successfully!'),
            backgroundColor: Color(0xFFB789DA),
            duration: Duration(seconds: 2),
          ),
        );
      } else {
        throw Exception('Failed to save document');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving document: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFFB789DA),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Text Overlay',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontFamily: 'OpenDyslexic',
            ),
          ),
          Text(
            'Language: $_detectedLanguage',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontFamily: 'OpenDyslexic',
            ),
          ),
        ],
      ),
      leading: IconButton(
        icon: const Icon(
          Icons.arrow_back,
          color: Colors.white,
        ),
        onPressed: () {
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
            setState(() {
              _showOverlay = !_showOverlay;
            });
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
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AppBloc, AppState>(
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
                        : (state.readingState == ReadingState.paused
                            ? Icons.play_arrow
                            : Icons.play_arrow),
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
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Share feature coming soon!'),
                          backgroundColor: Color(0xFFB789DA),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
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
          if (_showOverlay)
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
                  ),
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
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontFamily: 'OpenDyslexic',
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
                      setState(() {
                        _useOpenDyslexic = value;
                      });
                      this.setState(() {
                        _useOpenDyslexic = value;
                      });
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
                      setState(() {
                        _fontSize = value;
                      });
                      this.setState(() {
                        _fontSize = value;
                      });
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
}

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
  });

  @override
  void paint(Canvas canvas, Size size) {
    final scaleX = imageDisplaySize.width / imageActualSize.width;
    final scaleY = imageDisplaySize.height / imageActualSize.height;
    int globalWordIndex = 0;

    
    final shouldUseOpenDyslexic =
        useOpenDyslexic && _isLatinLanguage(detectedLanguage);

    for (final block in textBlocks) {
      for (final line in block.lines) {
        final boundingBox = line.boundingBox;
        final left = boundingBox.left * scaleX;
        final top = boundingBox.top * scaleY;
        final right = boundingBox.right * scaleX;
        final bottom = boundingBox.bottom * scaleY;
        final scaledRect = Rect.fromLTRB(left, top, right, bottom);
        final lineHeight = scaledRect.height;
        final lineWidth = scaledRect.width;
        final lineText = line.text;
        final words =
            lineText.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();

        if (words.isEmpty) continue;

        final lineStartIndex = globalWordIndex;
        final lineEndIndex = lineStartIndex + words.length;
        final isLineActive = currentWordIndex >= lineStartIndex &&
            currentWordIndex < lineEndIndex;

        
        final backgroundPaint = Paint()
          ..color = const Color(0xFFEEEEEE).withOpacity(overlayOpacity)
          ..style = PaintingStyle.fill;

        final bgRect = RRect.fromRectAndRadius(
          Rect.fromLTRB(left - 4, top - 2, right + 4, bottom + 2),
          const Radius.circular(4),
        );

        canvas.drawRRect(bgRect, backgroundPaint);

        
        final calculatedFontSize = (lineHeight * 0.5).clamp(8.0, fontSize);

      
        final textStyle = TextStyle(
          fontSize: calculatedFontSize,
          fontWeight: FontWeight.w500,
          fontFamily: shouldUseOpenDyslexic ? 'OpenDyslexic' : null,
          height: 1.0,
        );

        final testPainter = TextPainter(
          text: TextSpan(text: lineText, style: textStyle),
          textDirection: TextDirection.ltr,
        );
        testPainter.layout();

        final availableWidth = lineWidth - 8;
        final scaleFactor = testPainter.width > availableWidth
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
            fontFamily: shouldUseOpenDyslexic ? 'OpenDyslexic' : null,
            height: 1.0,
            letterSpacing: shouldUseOpenDyslexic ? 0.5 : 0,
          );

          final textSpan = TextSpan(text: word, style: wordStyle);
          final textPainter = TextPainter(
            text: textSpan,
            textDirection: TextDirection.ltr,
          );
          textPainter.layout();

          if (isCurrentWord) {
            final highlightPaint = Paint()
              ..color = Colors.yellow.withOpacity(0.6)
              ..style = PaintingStyle.fill;

            final highlightRect = RRect.fromRectAndRadius(
              Rect.fromLTWH(
                currentX - 1,
                top + 1,
                textPainter.width + 2,
                lineHeight - 2,
              ),
              const Radius.circular(2),
            );

            canvas.drawRRect(highlightRect, highlightPaint);
          }

          final textY = top + (lineHeight - textPainter.height) / 2;
          textPainter.paint(canvas, Offset(currentX, textY));
          currentX += textPainter.width + (adjustedFontSize * 0.15);
        }

        globalWordIndex += words.length;
      }
    }
  }

  bool _isLatinLanguage(String? language) {
    if (language == null) return true;

    final latinLanguages = [
      'English',
      'Spanish',
      'French',
      'German',
      'Italian',
      'Portuguese',
      'Dutch',
      'Swedish',
      'Norwegian',
      'Danish',
    ];

    return latinLanguages.contains(language);
  }

  @override
  bool shouldRepaint(OverlayStyle oldDelegate) {
    return oldDelegate.currentWordIndex != currentWordIndex ||
        oldDelegate.imageDisplaySize != imageDisplaySize ||
        oldDelegate.useOpenDyslexic != useOpenDyslexic ||
        oldDelegate.fontSize != fontSize;
  }
}
