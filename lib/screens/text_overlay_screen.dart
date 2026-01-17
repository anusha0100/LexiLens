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

class TextOverlayScreen extends StatefulWidget {
  final String imagePath;
  final List<TextBlock> textBlocks;
  final bool useOpenDyslexic; 
  final double fontSize; 
  const TextOverlayScreen({
    super.key,
    required this.imagePath,
    required this.textBlocks,
    this.useOpenDyslexic = true,
    this.fontSize = 14.0,
  });

  @override
  State<TextOverlayScreen> createState() => _TextOverlayScreenState();
}

class _TextOverlayScreenState extends State<TextOverlayScreen> {
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

  @override
  void initState() {
    super.initState();
    _useOpenDyslexic = widget.useOpenDyslexic;
    _fontSize = widget.fontSize;
    _loadImage();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _getImageDisplaySize();
    });
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
    return _extractedText.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
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

  void _toggleFontStyle() {
    setState(() {
      _useOpenDyslexic = !_useOpenDyslexic;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _useOpenDyslexic 
              ? 'Using OpenDyslexic font' 
              : 'Using default font'
        ),
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

      // Create document model from extracted text
      final document = DocumentModel(
        userId: userId,
        name: 'Scanned_${DateTime.now().millisecondsSinceEpoch}',
        content: _extractedText,
        filePath: widget.imagePath,
        uploadedDate: DateTime.now(),
        tags: [],
        isFavorite: false,
      );

      // Save to MongoDB
      final savedDoc = await _mongoService.createDocument(document);

      if (savedDoc != null && mounted) {
        // Success - update the app state
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


  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AppBloc, AppState>(
      builder: (context, state) {
        return Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: const Color(0xFFB789DA),
            title: Text(
              _useOpenDyslexic 
                  ? 'OpenDyslexic Overlay' 
                  : 'Recognized Text',
              style: const TextStyle(
                fontFamily: 'OpenDyslexic',
                color: Colors.white,
              ),
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
                onPressed: () => _showSettingsDialog(context, state),
              ),
              if (state.readingState != ReadingState.idle)
                IconButton(
                  icon: const Icon(Icons.stop, color: Colors.white),
                  onPressed: () => _stopReading(context),
                ),
            ],
          ),
          body: InteractiveViewer(
            minScale: 0.5,
            maxScale: 4.0,
            child: Center(
              child: _buildOverlayContent(state),
            ),
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

    return Stack(
      children: [
        // Original image
        Image.file(
          File(widget.imagePath),
          key: _imageKey,
          fit: BoxFit.contain,
        ),
        // Text overlay
        if (_showOverlay)
          Positioned.fill(
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
              ),
            ),
          ),
      ],
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

  void _showSettingsDialog(BuildContext context, AppState state) {
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
  final List<TextBlock> textBlocks;
  final Size imageActualSize;
  final Size imageDisplaySize;
  final int currentWordIndex;
  final List<String> allWords;
  final bool useOpenDyslexic;
  final double fontSize;

  OverlayStyle({
    required this.textBlocks,
    required this.imageActualSize,
    required this.imageDisplaySize,
    required this.currentWordIndex,
    required this.allWords,
    required this.useOpenDyslexic,
    required this.fontSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final scaleX = imageDisplaySize.width / imageActualSize.width;
    final scaleY = imageDisplaySize.height / imageActualSize.height;
    int globalWordIndex = 0;
    
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
        final words = lineText.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
        
        if (words.isEmpty) continue;
        
        final lineStartIndex = globalWordIndex;
        final lineEndIndex = lineStartIndex + words.length;
        final isLineActive = currentWordIndex >= lineStartIndex && 
                             currentWordIndex < lineEndIndex;
        
        final backgroundPaint = Paint()
          ..color = const Color(0xFFEEEEEE).withOpacity(0.75)
          ..style = PaintingStyle.fill;
        
        final bgRect = RRect.fromRectAndRadius(
          Rect.fromLTRB(
            left - 4,
            top - 2,
            right + 4,
            bottom + 2,
          ),
          const Radius.circular(4),
        );
        
        canvas.drawRRect(bgRect, backgroundPaint);
        
        // Calculate font size based on line height and user setting
        final calculatedFontSize = (lineHeight * 0.5).clamp(8.0, fontSize);
        
        final testStyle = TextStyle(
          fontSize: calculatedFontSize,
          fontWeight: FontWeight.w500,
          fontFamily: useOpenDyslexic ? 'OpenDyslexic' : null,
          height: 1.0,
        );
        
        final testPainter = TextPainter(
          text: TextSpan(text: lineText, style: testStyle),
          textDirection: TextDirection.ltr,
        );
        testPainter.layout();
        
        final availableWidth = lineWidth - 8; 
        final scaleFactor = testPainter.width > availableWidth 
            ? availableWidth / testPainter.width 
            : 1.0;
        
        final adjustedFontSize = (calculatedFontSize * scaleFactor).clamp(7.0, fontSize);
        
        double currentX = left + 4;
        for (int wordIdx = 0; wordIdx < words.length; wordIdx++) {
          final word = words[wordIdx];
          final isCurrentWord = isLineActive && 
                                (globalWordIndex + wordIdx) == currentWordIndex;
          
          final textStyle = TextStyle(
            color: isCurrentWord ? Colors.red.shade800 : Colors.black87,
            fontSize: adjustedFontSize,
            fontWeight: isCurrentWord ? FontWeight.bold : FontWeight.w500,
            fontFamily: useOpenDyslexic ? 'OpenDyslexic' : null,
            height: 1.0,
            letterSpacing: useOpenDyslexic ? 0.5 : 0,
          );

          final textSpan = TextSpan(text: word, style: textStyle);
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

  @override
  bool shouldRepaint(OverlayStyle oldDelegate) {
    return oldDelegate.currentWordIndex != currentWordIndex ||
           oldDelegate.imageDisplaySize != imageDisplaySize ||
           oldDelegate.useOpenDyslexic != useOpenDyslexic ||
           oldDelegate.fontSize != fontSize;
  }
}