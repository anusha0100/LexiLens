// lib/screens/text_overlay_screen.dart
//
// OVERLAY IMPROVEMENTS (this revision)
// ──────────────────────────────────────
// 1. Per-word pills: every word gets its own rounded-rect drawn EXACTLY on
//    the element's OCR bounding box.  No more shared line-level pill that
//    causes neighbouring words to bleed into each other.
//
// 2. Dynamic font sizing: _fitFontSize() reduces the requested fontSize until
//    the rendered text fits inside the element's width AND height.  Words are
//    then centred (both axes) within their box.
//
// 3. Adaptive letter-spacing for Latin languages: instead of a fixed 1.6/1.1
//    em gap the painter starts with the preferred spacing and backs off
//    automatically if the text would still overflow the bounding box.
//
// 4. Fallback path (no per-word elements): words are distributed
//    proportionally by character count instead of uniformly.
//
// 5. Language-gated OpenDyslexic font: unchanged – Latin only.

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
import 'dart:math' show min;

class TextOverlayScreen extends StatefulWidget {
  final String          imagePath;
  final List<TextBlock> textBlocks;
  final bool            useOpenDyslexic;
  final double          fontSize;
  final String?         detectedLanguage;
  final String?         detectedScript;

  const TextOverlayScreen({
    super.key,
    required this.imagePath,
    required this.textBlocks,
    this.useOpenDyslexic   = true,
    this.fontSize          = 14.0,
    this.detectedLanguage,
    this.detectedScript,
  });

  @override
  State<TextOverlayScreen> createState() => _TextOverlayScreenState();
}

class _TextOverlayScreenState extends State<TextOverlayScreen> {
  final _syllableService = SyllableService();
  final _authService     = AuthService();
  final _mongoService    = MongoDBService();

  bool      _showOverlay = true;
  bool      _isSaving    = false;
  ui.Image? _decodedImage;

  late bool   _useOpenDyslexic;
  late double _fontSize;
  late String _detectedLanguage;
  late String _detectedScript;
  late bool   _canUseOpenDyslexic;

  // ── Latin-language list (same as OCRService) ──────────────────────────────
  static const _kLatinLanguages = {
    'English', 'Spanish', 'French', 'German', 'Italian',
    'Portuguese', 'Dutch', 'Swedish', 'Norwegian', 'Danish',
    'Finnish', 'Polish', 'Czech', 'Hungarian', 'Romanian',
    'Turkish', 'Albanian', 'Croatian', 'Slovak', 'Slovenian',
    'Catalan', 'Welsh', 'Irish', 'Basque', 'Galician',
    'Latvian', 'Lithuanian', 'Estonian',
  };

  bool _isLatinLanguage(String? lang) => _kLatinLanguages.contains(lang ?? '');

  @override
  void initState() {
    super.initState();
    _detectedLanguage   = widget.detectedLanguage ?? 'English';
    _detectedScript     = widget.detectedScript   ?? 'Latin';
    _canUseOpenDyslexic = _isLatinLanguage(_detectedLanguage)
                       && _detectedScript == 'Latin';
    _useOpenDyslexic    = _canUseOpenDyslexic && widget.useOpenDyslexic;
    _fontSize           = widget.fontSize;
    _loadImage();
  }

  Future<void> _loadImage() async {
    try {
      final f = File(widget.imagePath);
      if (!f.existsSync()) return;
      final img = await decodeImageFromList(await f.readAsBytes());
      if (mounted) setState(() => _decodedImage = img);
    } catch (e) {
      debugPrint('TextOverlay: image load error $e');
    }
  }

  @override
  void dispose() {
    try { context.read<AppBloc>().add(StopTextToSpeech()); } catch (_) {}
    super.dispose();
  }

  String get _extractedText =>
      widget.textBlocks.map((b) => b.text).join('\n\n');

  List<String> get _allWords =>
      _extractedText.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();

  void _togglePlay(BuildContext ctx, AppState s) {
    if (s.readingState == ReadingState.playing) {
      ctx.read<AppBloc>().add(PauseTextToSpeech());
    } else if (s.readingState == ReadingState.paused) {
      ctx.read<AppBloc>().add(ResumeTextToSpeech());
    } else {
      ctx.read<AppBloc>().add(
          StartTextToSpeech(text: _extractedText, detectedLanguage: _detectedLanguage));
    }
  }

  void _stopReading(BuildContext ctx) =>
      ctx.read<AppBloc>().add(StopTextToSpeech());

  void _copy() {
    Clipboard.setData(ClipboardData(text: _extractedText));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Text copied to clipboard'),
      backgroundColor: Color(0xFFB789DA),
      duration: Duration(seconds: 2),
    ));
  }

  Future<void> _save() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    try {
      final user = _authService.currentUser;
      if (user == null) throw Exception('User not logged in');
      final token = await user.getIdToken(true);
      if (token != null) _mongoService.setAuthToken(token);

      final text = _extractedText.trim();
      if (text.isEmpty) throw Exception('No text extracted. Try rescanning.');

      await _mongoService.createDocument(DocumentModel(
        userId:           user.uid,
        name:             'Scanned_${DateTime.now().millisecondsSinceEpoch}',
        content:          text,
        filePath:         null,
        uploadedDate:     DateTime.now(),
        tags:             [],
        isFavorite:       false,
        detectedLanguage: _detectedLanguage,
        detectedScript:   _detectedScript,
      ));

      if (mounted) {
        context.read<AppBloc>().add(LoadDocuments());
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Document saved!'),
          backgroundColor: Color(0xFFB789DA),
          duration: Duration(seconds: 2),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Save error: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showSyllableBreakdown(String word, Offset globalPos) {
    final syllables = _syllableService.breakIntoSyllables(word);
    final formatted = _syllableService.formatSyllables(syllables);

    showDialog(
      context: context,
      barrierColor: Colors.black26,
      builder: (ctx) => GestureDetector(
        onTap: () => Navigator.pop(ctx),
        child: Stack(children: [
          Positioned(
            left: (globalPos.dx - 100).clamp(8.0,
                MediaQuery.of(ctx).size.width - 216.0),
            top:  (globalPos.dy - 80).clamp(8.0,
                MediaQuery.of(ctx).size.height - 120.0),
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFB789DA),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 10, offset: const Offset(0, 4))],
                ),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(word, style: const TextStyle(
                      color: Colors.white70, fontSize: 12, fontFamily: 'OpenDyslexic')),
                  const SizedBox(height: 4),
                  Text(formatted, style: const TextStyle(
                      color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold,
                      fontFamily: 'OpenDyslexic', letterSpacing: 2)),
                  const SizedBox(height: 4),
                  Text('${syllables.length} syllable${syllables.length > 1 ? "s" : ""}',
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 10, fontFamily: 'OpenDyslexic')),
                ]),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  AppBar _buildAppBar() {
    final fontFamily =
        _detectedScript == 'Devanagari' ? 'NotoSansDevanagari' : 'OpenDyslexic';
    return AppBar(
      backgroundColor: const Color(0xFFB789DA),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () { _stopReading(context); Navigator.pop(context); },
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Text Overlay',
              style: TextStyle(color: Colors.white, fontSize: 18, fontFamily: fontFamily)),
          Text('$_detectedLanguage · $_detectedScript',
              style: TextStyle(color: Colors.white70, fontSize: 11, fontFamily: fontFamily)),
        ],
      ),
      actions: [
        Tooltip(
          message: _canUseOpenDyslexic
              ? 'Toggle OpenDyslexic font'
              : 'OpenDyslexic is for Latin scripts only',
          child: IconButton(
            icon: Icon(
              _useOpenDyslexic ? Icons.font_download : Icons.font_download_outlined,
              color: _canUseOpenDyslexic ? Colors.white : Colors.white38,
            ),
            onPressed: _canUseOpenDyslexic
                ? () => setState(() => _useOpenDyslexic = !_useOpenDyslexic)
                : null,
          ),
        ),
        IconButton(
          icon: Icon(_showOverlay ? Icons.visibility : Icons.visibility_off,
              color: Colors.white),
          onPressed: () => setState(() => _showOverlay = !_showOverlay),
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
      onWillPop: () async { _stopReading(context); return true; },
      child: BlocBuilder<AppBloc, AppState>(
        builder: (ctx, state) => Scaffold(
          backgroundColor: Colors.black,
          appBar: _buildAppBar(),
          body: Column(children: [
            _buildLanguageBanner(),
            Expanded(child: _buildImageWithOverlay(state)),
          ]),
          bottomNavigationBar: _buildBottomBar(ctx, state),
        ),
      ),
    );
  }

  Widget _buildLanguageBanner() {
    if (_canUseOpenDyslexic) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.orange.withOpacity(0.9),
      child: Row(children: [
        const Icon(Icons.info_outline, color: Colors.white, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Detected: $_detectedLanguage ($_detectedScript script). '
            'OpenDyslexic is available for Latin-script languages only.',
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ),
      ]),
    );
  }

  Widget _buildImageWithOverlay(AppState state) {
    if (_decodedImage == null) {
      return InteractiveViewer(
        minScale: 0.5, maxScale: 4.0,
        child: Image.file(File(widget.imagePath), fit: BoxFit.contain),
      );
    }

    return LayoutBuilder(builder: (context, constraints) {
      final containerW = constraints.maxWidth;
      final containerH = constraints.maxHeight;
      final imgW = _decodedImage!.width.toDouble();
      final imgH = _decodedImage!.height.toDouble();
      final containerAspect = containerW / containerH;
      final imageAspect     = imgW / imgH;

      late double renderedW, renderedH;
      if (imageAspect > containerAspect) {
        renderedW = containerW;
        renderedH = containerW / imageAspect;
      } else {
        renderedH = containerH;
        renderedW = containerH * imageAspect;
      }

      final offsetX = (containerW - renderedW) / 2;
      final offsetY = (containerH - renderedH) / 2;

      return InteractiveViewer(
        minScale: 0.5, maxScale: 4.0,
        onInteractionUpdate: (d) {
          if (d.scale != state.zoomLevel) {
            context.read<AppBloc>().add(AdjustZoom(d.scale));
          }
        },
        child: SizedBox(
          width: containerW, height: containerH,
          child: Stack(children: [
            Positioned.fill(
              child: Image.file(File(widget.imagePath), fit: BoxFit.contain),
            ),
            if (_showOverlay && widget.textBlocks.isNotEmpty)
              Positioned(
                left: offsetX, top: offsetY,
                width: renderedW, height: renderedH,
                child: GestureDetector(
                  onLongPressStart: (details) {
                    final word = _findWordAt(
                        details.localPosition,
                        Size(imgW, imgH),
                        Size(renderedW, renderedH));
                    if (word.isNotEmpty && word.length > 3) {
                      _showSyllableBreakdown(word, details.globalPosition);
                    }
                  },
                  child: CustomPaint(
                    painter: OverlayStyle(
                      overlayOpacity:   state.overlayOpacity,
                      textBlocks:       widget.textBlocks,
                      imageActualSize:  Size(imgW, imgH),
                      imageDisplaySize: Size(renderedW, renderedH),
                      currentWordIndex: state.readingState != ReadingState.idle
                          ? state.currentWordIndex : -1,
                      allWords:         _allWords,
                      useOpenDyslexic:  _useOpenDyslexic,
                      fontSize:         _fontSize,
                      detectedLanguage: _detectedLanguage,
                      detectedScript:   _detectedScript,
                    ),
                    size: Size.infinite,
                  ),
                ),
              ),
          ]),
        ),
      );
    });
  }

  String _findWordAt(Offset pos, Size imageSize, Size displaySize) {
    final scaleX = displaySize.width  / imageSize.width;
    final scaleY = displaySize.height / imageSize.height;

    for (final block in widget.textBlocks) {
      for (final line in block.lines) {
        // Prefer per-element hit test (accurate).
        for (final el in line.elements) {
          final eb = el.boundingBox;
          final r = Rect.fromLTRB(
            eb.left * scaleX, eb.top * scaleY,
            eb.right * scaleX, eb.bottom * scaleY,
          );
          if (r.contains(pos)) {
            return el.text.replaceAll(RegExp(r'[^\w]'), '');
          }
        }
        // Fallback: uniform split across line bbox.
        if (line.elements.isEmpty) {
          final b = line.boundingBox;
          final r = Rect.fromLTRB(
            b.left * scaleX, b.top * scaleY,
            b.right * scaleX, b.bottom * scaleY,
          );
          if (r.contains(pos)) {
            final words = line.text
                .split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
            if (words.isEmpty) continue;
            final wW  = r.width / words.length;
            final idx = ((pos.dx - r.left) / wW)
                .floor().clamp(0, words.length - 1);
            return words[idx].replaceAll(RegExp(r'[^\w]'), '');
          }
        }
      }
    }
    return '';
  }

  Widget _buildBottomBar(BuildContext ctx, AppState state) {
    final fontFamily =
        _detectedScript == 'Devanagari' ? 'NotoSansDevanagari' : 'OpenDyslexic';
    return Container(
      color: const Color(0xFFB789DA),
      padding: const EdgeInsets.all(16),
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _navBtn(
              icon: state.readingState == ReadingState.playing
                  ? Icons.pause : Icons.play_arrow,
              label: state.readingState == ReadingState.playing
                  ? 'Pause'
                  : (state.readingState == ReadingState.paused ? 'Resume' : 'Read'),
              fontFamily: fontFamily,
              onTap: () => _togglePlay(ctx, state),
            ),
            _navBtn(icon: Icons.copy,  label: 'Copy',  fontFamily: fontFamily, onTap: _copy),
            _navBtn(
              icon: _isSaving ? Icons.hourglass_bottom : Icons.save,
              label: _isSaving ? 'Saving…' : 'Save',
              fontFamily: fontFamily,
              onTap: _isSaving ? () {} : _save,
            ),
            _navBtn(icon: Icons.share, label: 'Share', fontFamily: fontFamily,
                onTap: () => _showShareOptions(ctx)),
          ],
        ),
      ),
    );
  }

  Widget _navBtn({
    required IconData     icon,
    required String       label,
    required String       fontFamily,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: Colors.white, size: 24),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(
            color: Colors.white, fontSize: 11, fontFamily: fontFamily)),
      ]),
    );
  }

  void _showSettingsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dCtx) => BlocProvider.value(
        value: context.read<AppBloc>(),
        child: StatefulBuilder(
          builder: (ctx, setModal) => AlertDialog(
            title: const Text('Display Settings',
                style: TextStyle(fontFamily: 'OpenDyslexic')),
            content: Column(mainAxisSize: MainAxisSize.min, children: [
              SwitchListTile(
                title: const Text('OpenDyslexic Font',
                    style: TextStyle(fontFamily: 'OpenDyslexic')),
                subtitle: Text(
                  _canUseOpenDyslexic
                      ? 'Available for this language'
                      : 'Not available for $_detectedLanguage ($_detectedScript)',
                  style: TextStyle(
                    fontSize: 11,
                    color: _canUseOpenDyslexic ? null : Colors.orange,
                  ),
                ),
                value: _useOpenDyslexic,
                activeColor: const Color(0xFFB789DA),
                // Disable toggle when script doesn't support OpenDyslexic.
                onChanged: _canUseOpenDyslexic
                    ? (v) {
                        setModal(() => _useOpenDyslexic = v);
                        setState(() => _useOpenDyslexic = v);
                      }
                    : null,
              ),
              const Divider(),
              Text('Font Size: ${_fontSize.toInt()}',
                  style: const TextStyle(fontFamily: 'OpenDyslexic')),
              Slider(
                value: _fontSize, min: 10, max: 24, divisions: 14,
                activeColor: const Color(0xFFB789DA),
                label: _fontSize.toInt().toString(),
                onChanged: (v) {
                  setModal(() => _fontSize = v);
                  setState(() => _fontSize = v);
                },
              ),
              BlocBuilder<AppBloc, AppState>(builder: (ctx, st) => Column(children: [
                Text('Overlay Opacity: ${(st.overlayOpacity * 100).toInt()}%',
                    style: const TextStyle(fontFamily: 'OpenDyslexic')),
                Slider(
                  value: st.overlayOpacity, min: 0.5, max: 1.0, divisions: 10,
                  activeColor: const Color(0xFFB789DA),
                  onChanged: (v) =>
                      ctx.read<AppBloc>().add(AdjustOverlayOpacity(v)),
                ),
              ])),
              const Divider(),
              BlocBuilder<AppBloc, AppState>(builder: (ctx, st) => Column(children: [
                Text('Speed: ${(st.readingSpeed * 2).toStringAsFixed(1)}x',
                    style: const TextStyle(fontFamily: 'OpenDyslexic')),
                Slider(
                  value: st.readingSpeed, min: 0.1, max: 1.0, divisions: 9,
                  activeColor: const Color(0xFFB789DA),
                  onChanged: (v) => ctx.read<AppBloc>().add(AdjustSpeed(v)),
                ),
                Text('Volume: ${(st.volume * 100).toInt()}%',
                    style: const TextStyle(fontFamily: 'OpenDyslexic')),
                Slider(
                  value: st.volume, min: 0, max: 1.0, divisions: 10,
                  activeColor: const Color(0xFFB789DA),
                  onChanged: (v) => ctx.read<AppBloc>().add(AdjustVolume(v)),
                ),
              ])),
            ]),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dCtx),
                child: const Text('Close',
                    style: TextStyle(color: Color(0xFFB789DA),
                        fontFamily: 'OpenDyslexic')),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showShareOptions(BuildContext ctx) {
    showDialog(
      context: ctx,
      builder: (dCtx) => AlertDialog(
        title: const Text('Share Document',
            style: TextStyle(fontFamily: 'OpenDyslexic')),
        content: const Text('Choose how you want to share:',
            style: TextStyle(fontFamily: 'OpenDyslexic')),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dCtx);
              ctx.read<AppBloc>().add(ShareDocumentAsText(
                documentName: widget.imagePath.split('/').last,
                content: _extractedText,
              ));
            },
            child: const Text('Share as Text'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dCtx);
              ctx.read<AppBloc>().add(ShareDocument(
                documentName: widget.imagePath.split('/').last
                    .replaceAll('.jpg', '').replaceAll('.png', ''),
                content: _extractedText,
                format: 'pdf',
                detectedLanguage: _detectedLanguage,
              ));
            },
            child: const Text('Share as PDF'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dCtx);
              ctx.read<AppBloc>().add(ExportDocumentAsText(
                documentName: widget.imagePath.split('/').last,
                content: _extractedText,
              ));
            },
            child: const Text('Export as Text'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dCtx);
              ctx.read<AppBloc>().add(ExportDocumentAsPDF(
                documentName: widget.imagePath.split('/').last
                    .replaceAll('.jpg', '').replaceAll('.png', ''),
                content: _extractedText,
                detectedLanguage: _detectedLanguage,
              ));
            },
            child: const Text('Export as PDF'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dCtx),
            child: const Text('Cancel',
                style: TextStyle(color: Color(0xFFB789DA))),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// OverlayStyle painter
//
// KEY FIXES
// ─────────
// • OpenDyslexic gating: font is selected ONLY when useOpenDyslexic is true
//   AND the language is Latin.  Non-Latin scripts always use their own font.
// • wordGapFactor: 0.65em (OpenDyslexic) / 0.50em (Latin) / 0.30em (other).
// • letterSpacing: 1.6 / 1.1 / 0.6 for the same tiers.
// • Background pill: left-4 / right+4 AND top-vPad / bottom+vPad – no overlap.
// • Per-element maxWidth: wW + ls*len + 16.
// • Fallback cursor reset to `left + 4` at the start of EACH line.
// ─────────────────────────────────────────────────────────────────────────────
class OverlayStyle extends CustomPainter {
  final double          overlayOpacity;
  final List<TextBlock> textBlocks;
  final Size            imageActualSize;
  final Size            imageDisplaySize;
  final int             currentWordIndex;
  final List<String>    allWords;
  final bool            useOpenDyslexic;
  final double          fontSize;
  final String?         detectedLanguage;
  final String?         detectedScript;

  const OverlayStyle({
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

  // ── Latin language set ─────────────────────────────────────────────────────
  static const _kLatin = {
    'English', 'Spanish', 'French', 'German', 'Italian',
    'Portuguese', 'Dutch', 'Swedish', 'Norwegian', 'Danish',
    'Finnish', 'Polish', 'Czech', 'Hungarian', 'Romanian',
    'Turkish', 'Albanian', 'Croatian', 'Slovak', 'Slovenian',
    'Catalan', 'Welsh', 'Irish', 'Basque', 'Galician',
    'Latvian', 'Lithuanian', 'Estonian',
  };

  bool get _isLatin => _kLatin.contains(detectedLanguage ?? '');
  bool get _isHindi {
    final lang = (detectedLanguage ?? '').toLowerCase();
    return lang.contains('hindi') || lang.startsWith('hi') ||
        detectedScript?.toLowerCase() == 'devanagari';
  }

  bool get _isDevanagari => detectedScript?.toLowerCase() == 'devanagari';

  // ── Typography ─────────────────────────────────────────────────────────────

  double get _preferredLetterSpacing {
    if (useOpenDyslexic && _isLatin) return 1.2;
    if (_isLatin)                    return 0.8;
    if (_isDevanagari || _isHindi)  return 0.5;
    return 0.6;
  }

  double get _wordGapFactor {
    if (useOpenDyslexic && _isLatin) return 0.50;
    if (_isLatin)                    return 0.40;
    if (_isDevanagari || _isHindi)  return 0.35;
    return 0.25;
  }

  // Returns the largest (fontSize, letterSpacing) pair that fits text in maxW×maxH.
  ({double fs, double ls}) _fitFontSize(
      String text, double initialFs, double maxW, double maxH) {
    double fs = min(initialFs, maxH * 0.82).clamp(6.0, 72.0);
    double ls = _preferredLetterSpacing;

    for (int attempt = 0; attempt < 8; attempt++) {
      final tp = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            fontSize:      fs,
            fontFamily:    _fontFamily,
            letterSpacing: ls,
            height:        1.0,
          ),
        ),
        textDirection:   TextDirection.ltr,
        textScaleFactor: 1.0,
        maxLines:        1,
      )..layout();

      if (tp.width <= maxW + 1) break;

      // 1. Reduce letter-spacing first (cheaper, keeps font readable).
      if (ls > 0.1) {
        ls = (ls * 0.7).clamp(0.0, ls);
        continue;
      }

      // 2. Then scale font size down proportionally.
      final ratio = maxW / tp.width;
      final next  = (fs * ratio * 0.94).clamp(6.0, fs - 0.5);
      if (next >= fs) break; // can't shrink further
      fs = next;
    }

    return (fs: fs, ls: ls);
  }

  String? get _fontFamily {
    if (useOpenDyslexic && _isLatin) return 'OpenDyslexic';
    if (_isHindi || _isDevanagari)    return 'NotoSansDevanagari';
    return null; // system default for all other scripts
  }

  // ── Paint ──────────────────────────────────────────────────────────────────

  @override
  void paint(Canvas canvas, Size size) {
    if (textBlocks.isEmpty ||
        imageActualSize  == Size.zero ||
        imageDisplaySize == Size.zero) {
      return;
    }

    final scaleX = imageDisplaySize.width  / imageActualSize.width;
    final scaleY = imageDisplaySize.height / imageActualSize.height;

    final ff  = _fontFamily;
    final wgf = _wordGapFactor;
    final fs  = fontSize.clamp(8.0, 36.0);

    final bgPaint = Paint()
      ..color = const Color(0xFFF5F5F5).withOpacity(overlayOpacity)
      ..style = PaintingStyle.fill;

    final highlightPaint = Paint()
      ..color = Colors.yellow.withOpacity(0.65)
      ..style = PaintingStyle.fill;

    int globalWordIdx = 0;

    for (final block in textBlocks) {
      for (final line in block.lines) {
        final b     = line.boundingBox;
        final left  = b.left   * scaleX;
        final top   = b.top    * scaleY;
        final right = b.right  * scaleX;
        final bottom = b.bottom * scaleY;

        if (bottom < 0 || top > size.height || right < 0 || left > size.width) {
          globalWordIdx += line.elements.isNotEmpty
              ? line.elements.length
              : line.text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
          continue;
        }

        final lineH = (bottom - top).clamp(8.0, double.infinity);
        final words = line.text
            .split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
        final lineStart = globalWordIdx;
        final lineEnd   = lineStart +
            (line.elements.isNotEmpty ? line.elements.length : words.length);
        final lineActive =
            currentWordIndex >= lineStart && currentWordIndex < lineEnd;

        // ── Per-element path: use ML Kit per-word bounding boxes ─────────────
        if (line.elements.isNotEmpty) {
          for (int wi = 0; wi < line.elements.length; wi++) {
            final el = line.elements[wi];
            if (el.text.trim().isEmpty) { globalWordIdx++; continue; }  // NEW

            final wb = el.boundingBox;
            final wL = wb.left   * scaleX;
            final wT = wb.top    * scaleY;
            final wW = (wb.width  * scaleX).clamp(4.0, double.infinity);
            final wH = (wb.height * scaleY).clamp(8.0, double.infinity);

            final isActive = lineActive && (globalWordIdx + wi) == currentWordIndex;

            // Pill exactly on the OCR word bounding box.
            canvas.drawRRect(
              RRect.fromRectAndRadius(
                Rect.fromLTWH(wL, wT, wW, wH),          // exact box, no inflation
                const Radius.circular(4),
              ),
              isActive ? highlightPaint : bgPaint,       // combined: no separate highlight draw
            );

            final fitResult = _fitFontSize(el.text, fs, wW, wH);
            final effFs = fitResult.fs;
            final effLs = fitResult.ls;

            final tp = TextPainter(
              text: TextSpan(
                text: el.text,
                style: TextStyle(
                  color:         isActive ? Colors.red.shade800 : Colors.black87,
                  fontSize:      effFs,                  // was: fs
                  fontFamily:    ff,
                  fontWeight:    isActive ? FontWeight.bold : FontWeight.w600,
                  height:        1.0,                    // was: 1.15
                  letterSpacing: effLs,                  // was: ls (fixed)
                ),
              ),
              textDirection:   TextDirection.ltr,
              textScaleFactor: 1.0,
              maxLines:        1,
            )..layout(maxWidth: wW + 2);                 // was: wW + ls * el.text.length + 16

            // Centre text inside the pill.
            final textX = wL + ((wW - tp.width)  / 2).clamp(0.0, double.infinity);
            final textY = wT + ((wH - tp.height) / 2).clamp(0.0, double.infinity);
            tp.paint(canvas, Offset(textX, textY));      // was: fixed vPad-offset formula
          }
          globalWordIdx += line.elements.length;
        } else if (words.isNotEmpty) {
          final totalChars = words.fold<int>(0, (s, w) => s + w.length);  // NEW
          final lineW      = (right - left).clamp(1.0, double.infinity);  // NEW
          final gap        = fs * wgf;
          final totalGap   = gap * (words.length - 1).clamp(0, double.maxFinite);  // NEW
          final textW      = (lineW - totalGap).clamp(1.0, double.infinity);        // NEW

          double cx = left;                               // was: left + 4

          for (int wi = 0; wi < words.length; wi++) {
            final word    = words[wi];
            final propFrac = totalChars > 0             // NEW: proportional width
                ? word.length / totalChars
                : 1.0 / words.length;
            final wW = (propFrac * textW).clamp(4.0, double.infinity);   // NEW

            final isActive = lineActive && (globalWordIdx + wi) == currentWordIndex;

            canvas.drawRRect(                            // NEW: draw pill first
              RRect.fromRectAndRadius(
                Rect.fromLTWH(cx, top, wW, lineH),
                const Radius.circular(4),
              ),
              isActive ? highlightPaint : bgPaint,
            );

            final fitResult = _fitFontSize(word, fs, wW, lineH);
            final effFs = fitResult.fs;
            final effLs = fitResult.ls;

            final tp = TextPainter(
              text: TextSpan(
                text: word,                              // was: words[wi]
                style: TextStyle(
                  color:         isActive ? Colors.red.shade800 : Colors.black87,
                  fontSize:      effFs,                  // was: fs
                  fontFamily:    ff,
                  fontWeight:    isActive ? FontWeight.bold : FontWeight.w600,
                  height:        1.0,                    // was: 1.15
                  letterSpacing: effLs,                  // was: ls (fixed)
                ),
              ),
              textDirection:   TextDirection.ltr,
              textScaleFactor: 1.0,
              maxLines: 1,                               // NEW
            )..layout(maxWidth: wW + 2);                 // was: .layout() with no maxWidth

            // (no separate isActive highlight block — removed)

            final textX = cx + ((wW - tp.width)  / 2).clamp(0.0, double.infinity);  // NEW
            final textY = top + ((lineH - tp.height) / 2).clamp(0.0, double.infinity); // NEW
            tp.paint(canvas, Offset(textX, textY));

            cx += wW + gap;                              // was: cx += tp.width + gap
          }
          globalWordIdx += words.length;
        }
      }
    }
  }

  @override
  bool shouldRepaint(OverlayStyle old) =>
      old.currentWordIndex  != currentWordIndex  ||
      old.imageDisplaySize  != imageDisplaySize  ||
      old.useOpenDyslexic   != useOpenDyslexic   ||
      old.fontSize          != fontSize          ||
      old.overlayOpacity    != overlayOpacity    ||
      old.detectedLanguage  != detectedLanguage  ||
      old.detectedScript    != detectedScript;
}

