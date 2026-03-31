// lib/screens/live_ar_screen.dart
// FR-005 to FR-009 – Live real-time AR camera OCR with dyslexia-friendly overlay
//
// FIXES in this revision
// ──────────────────────
// 1. Language-gated OpenDyslexic font: the dyslexic font is applied ONLY when
//    the detected script is Latin (English, Spanish, French, German, Italian,
//    Portuguese, Dutch, etc.).  For Devanagari (Hindi/Marathi/Sanskrit) and any
//    other non-Latin script the font falls back to the appropriate system font
//    so glyphs are never rendered as □ boxes.
//
// 2. Recogniser pipeline runs Latin first then Devanagari; picks the result
//    with the strongest signal (ratio-based, matching OCRService logic).
//
// 3. _ArOverlayPainter now receives `detectedScript` so it can always choose
//    the correct font regardless of the useOpenDyslexic toggle state.
//
// 4. Text overlay spacing overhaul:
//    • wordGapFactor raised to 0.65em (OpenDyslexic) / 0.50em (Latin).
//    • letterSpacing raised to 1.6 (OpenDyslexic) / 1.1 (plain Latin).
//    • Background pill inflated on ALL four sides by vPad.
//    • Per-element TextPainter maxWidth: elW + ls*len + 16 (was +8).
//    • Fallback word-loop cursor resets to lineRect.left+4 per line.

// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import 'package:lexilens/bloc/app_bloc.dart';
import 'package:lexilens/services/syllable_service.dart';

const _kPrimary = Color(0xFF7B4FA6);
const _kAccent  = Color(0xFFB789DA);

const _kThrottleMs           = 700;
const _kEmptyFramesToClear   = 4;
const _kStabilizationThreshold = 2;
const _kTextStalenessMs      = 2500;

bool _isLatinScript(String? script) => script == 'Latin';

// ─────────────────────────────────────────────────────────────────────────────
// StabilizedTextBlock / TextStabilizer
// ─────────────────────────────────────────────────────────────────────────────
class StabilizedTextBlock {
  TextBlock mlBlock;
  int       seenCount;
  DateTime  lastSeen;

  StabilizedTextBlock(this.mlBlock)
      : seenCount = 1,
        lastSeen  = DateTime.now();

  bool get isStable => seenCount >= _kStabilizationThreshold;
  bool get isStale  =>
      DateTime.now().difference(lastSeen).inMilliseconds > _kTextStalenessMs;

  void refresh(TextBlock b) { mlBlock = b; seenCount++; lastSeen = DateTime.now(); }
}

class TextStabilizer {
  final _memory = <String, StabilizedTextBlock>{};

  List<TextBlock> update(List<TextBlock> incoming) {
    final nowKeys = <String>{};
    for (final b in incoming) {
      final k = _key(b);
      nowKeys.add(k);
      _memory.containsKey(k) ? _memory[k]!.refresh(b) : _memory[k] = StabilizedTextBlock(b);
    }
    _memory.removeWhere((k, v) => !nowKeys.contains(k) && v.isStale);
    return _memory.values.where((b) => b.isStable).map((b) => b.mlBlock).toList();
  }

  String _key(TextBlock b) {
    final txt = b.text.replaceAll(RegExp(r'\s+'), '').toLowerCase()
        .substring(0, b.text.length.clamp(0, 12));
    return '$txt|${(b.boundingBox.left / 20).round()},${(b.boundingBox.top / 20).round()}';
  }

  void clear() => _memory.clear();
}

// ─────────────────────────────────────────────────────────────────────────────
// LiveArScreen
// ─────────────────────────────────────────────────────────────────────────────
class LiveArScreen extends StatefulWidget {
  const LiveArScreen({super.key});
  @override
  State<LiveArScreen> createState() => _LiveArScreenState();
}

class _LiveArScreenState extends State<LiveArScreen> with WidgetsBindingObserver {
  // Camera
  CameraController?        _controller;
  List<CameraDescription>? _cameras;
  bool _cameraReady = false;

  // OCR – Latin covers all Latin-script languages; Devanagari covers Hindi / Marathi / Sanskrit
  final _latinRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
  final _devaRecognizer  = TextRecognizer(script: TextRecognitionScript.devanagiri);

  bool _ocrBusy   = false;
  int  _lastOcrMs = 0;

  // Overlay state
  List<TextBlock> _displayBlocks  = [];
  String          _detectedScript = 'Latin';
  Size            _rawImageSize   = Size.zero;
  int             _sensorDeg      = 0;
  int             _emptyCount     = 0;
  final           _stabilizer     = TextStabilizer();

  // Controls
  bool   _useOpenDyslexic = true;
  double _fontSize        = 16.0;
  double _overlayOpacity  = 0.85;
  bool   _overlayVisible  = true;
  bool   _flashOn         = false;

  final _syllableService = SyllableService();

  // Syllable popup
  String?       _popWord;
  List<String>? _popSyllables;
  Offset?       _popPosition;

  // Pending batch
  List<TextBlock>? _pendingBlocks;
  Size?            _pendingSize;
  String?          _pendingScript;
  bool             _pendingScheduled = false;

  Size _screenSize = Size.zero;

  // Dyslexic font is active only when toggle is on AND script is Latin.
  bool get _dyslexicActive => _useOpenDyslexic && _isLatinScript(_detectedScript);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final s = context.read<AppBloc>().state;
      setState(() {
        _useOpenDyslexic = s.useOpenDyslexic;
        _fontSize        = s.fontSize.clamp(12.0, 36.0);
        _overlayOpacity  = s.overlayOpacity;
      });
    });
    _initCamera();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState st) {
    if (_controller == null || !_controller!.value.isInitialized) return;
    if (st == AppLifecycleState.inactive) _stopStream();
    else if (st == AppLifecycleState.resumed) _startStream();
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras == null || _cameras!.isEmpty) { _err('No camera found.'); return; }
      _sensorDeg = _cameras![0].sensorOrientation;
      _controller = CameraController(
        _cameras![0], ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid
            ? ImageFormatGroup.nv21 : ImageFormatGroup.bgra8888,
      );
      await _controller!.initialize();
      if (!mounted) return;
      setState(() => _cameraReady = true);
      _startStream();
    } catch (e) { _err('Camera init failed: $e'); }
  }

  void _startStream() => _controller?.startImageStream(_onFrame);
  void _stopStream() {
    if (_controller?.value.isStreamingImages == true) _controller!.stopImageStream();
  }

  void _onFrame(CameraImage img) {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (_ocrBusy || now - _lastOcrMs < _kThrottleMs) return;
    _ocrBusy = true; _lastOcrMs = now;
    _processFrame(img).catchError((_) {}).whenComplete(() => _ocrBusy = false);
  }

  Future<void> _processFrame(CameraImage img) async {
    final inputImage = _toInputImage(img);
    if (inputImage == null) return;

    final latinResult = await _latinRecognizer.processImage(inputImage);
    final devaResult  = await _devaRecognizer.processImage(inputImage);

    // Same ratio-based script selection as OCRService.
    final devCharCount    = RegExp(r'[\u0900-\u097F]').allMatches(devaResult.text).length;
    final devTotalNonSpace = devaResult.text.replaceAll(RegExp(r'\s'), '').length;
    final double devRatio  = devTotalNonSpace > 0 ? devCharCount / devTotalNonSpace : 0.0;

    RecognizedText bestResult;
    String         detectedScript;

    if (devCharCount >= 3 && devRatio >= 0.3) {
      bestResult = devaResult; detectedScript = 'Devanagari';
    } else if (latinResult.blocks.isNotEmpty) {
      bestResult = latinResult; detectedScript = 'Latin';
    } else if (devaResult.blocks.isNotEmpty) {
      bestResult = devaResult; detectedScript = 'Devanagari';
    } else {
      bestResult = latinResult; detectedScript = 'Latin';
    }

    final stable = _stabilizer.update(bestResult.blocks);

    if (stable.isEmpty) {
      _emptyCount++;
      if (_emptyCount < _kEmptyFramesToClear) return;
    } else {
      _emptyCount = 0;
    }

    _pendingBlocks = stable;
    _pendingSize   = Size(img.width.toDouble(), img.height.toDouble());
    _pendingScript = detectedScript;

    if (!_pendingScheduled) {
      _pendingScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          if (_pendingBlocks != null) _displayBlocks  = _pendingBlocks!;
          if (_pendingSize   != null) _rawImageSize   = _pendingSize!;
          if (_pendingScript != null) _detectedScript = _pendingScript!;
          _pendingBlocks = null; _pendingSize = null;
          _pendingScript = null; _pendingScheduled = false;
        });
      });
    }
  }

  InputImage? _toInputImage(CameraImage img) {
    final cam = _cameras?[0];
    if (cam == null) return null;
    final rotation = InputImageRotationValue.fromRawValue(cam.sensorOrientation);
    final format   = InputImageFormatValue.fromRawValue(img.format.raw);
    if (rotation == null || format == null) return null;

    Uint8List bytes;
    if (Platform.isAndroid) {
      final all = <int>[];
      for (final p in img.planes) all.addAll(p.bytes);
      bytes = Uint8List.fromList(all);
    } else {
      bytes = img.planes[0].bytes;
    }
    return InputImage.fromBytes(
      bytes: bytes,
      metadata: InputImageMetadata(
        size: Size(img.width.toDouble(), img.height.toDouble()),
        rotation: rotation, format: format,
        bytesPerRow: img.planes[0].bytesPerRow,
      ),
    );
  }

  Future<void> _toggleFlash() async {
    if (_controller == null) return;
    setState(() => _flashOn = !_flashOn);
    await _controller!.setFlashMode(_flashOn ? FlashMode.torch : FlashMode.off);
  }

  void _onLongPress(LongPressStartDetails details) {
    if (_displayBlocks.isEmpty || _rawImageSize == Size.zero) return;
    final tf = _CoverTransform(_rawImageSize, _sensorDeg, _screenSize);
    for (final block in _displayBlocks) {
      for (final line in block.lines) {
        for (final el in line.elements) {
          if (tf.toScreen(el.boundingBox).contains(details.localPosition)) {
            final word = el.text.replaceAll(RegExp(r'[^\w]'), '');
            if (word.length > 2) {
              final syllables = _syllableService.breakIntoSyllables(word);
              setState(() { _popWord = word; _popSyllables = syllables; _popPosition = details.globalPosition; });
              Future.delayed(const Duration(seconds: 3), () {
                if (mounted) setState(() { _popWord = null; _popSyllables = null; });
              });
            }
            return;
          }
        }
      }
    }
  }

  void _err(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopStream();
    _controller?.dispose();
    _latinRecognizer.close();
    _devaRecognizer.close();
    _stabilizer.clear();
    super.dispose();
  }

  // ─── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    _screenSize = MediaQuery.of(context).size;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(fit: StackFit.expand, children: [
        if (_cameraReady && _controller != null)
          GestureDetector(onLongPressStart: _onLongPress, child: CameraPreview(_controller!))
        else
          const Center(child: CircularProgressIndicator(color: _kAccent)),

        if (_cameraReady && _overlayVisible && _rawImageSize != Size.zero)
          Positioned.fill(
            child: AnimatedOpacity(
              opacity: 1.0,
              duration: const Duration(milliseconds: 200),
              child: CustomPaint(
                painter: _ArOverlayPainter(
                  blocks:          _displayBlocks,
                  rawImageSize:    _rawImageSize,
                  sensorDeg:       _sensorDeg,
                  useOpenDyslexic: _dyslexicActive,
                  detectedScript:  _detectedScript,
                  fontSize:        _fontSize,
                  opacity:         _overlayOpacity,
                ),
              ),
            ),
          ),

        if (_popWord != null && _popSyllables != null)
          _SyllablePopup(
            word: _popWord!, syllables: _popSyllables!,
            position: _popPosition ?? Offset.zero,
            onDismiss: () => setState(() { _popWord = null; _popSyllables = null; }),
          ),

        _buildTopBar(),
        Positioned(bottom: 0, left: 0, right: 0, child: _buildBottomBar()),
      ]),
    );
  }

  Widget _buildTopBar() {
    return Positioned(
      top: 0, left: 0, right: 0,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [Colors.black.withOpacity(0.7), Colors.transparent],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
                onPressed: () => Navigator.pop(context),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _kAccent.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.fiber_manual_record, color: Colors.red, size: 10),
                  const SizedBox(width: 4),
                  const Text('LIVE AR',
                      style: TextStyle(color: Colors.white, fontSize: 11,
                          fontWeight: FontWeight.bold)),
                  if (_displayBlocks.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.25),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _detectedScript == 'Devanagari' ? 'देव' : 'ABC',
                        style: const TextStyle(color: Colors.white, fontSize: 10,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ]),
              ),
              const Spacer(),
              IconButton(
                icon: Icon(_flashOn ? Icons.flash_on : Icons.flash_off,
                    color: Colors.white, size: 28),
                onPressed: _toggleFlash,
              ),
              IconButton(
                icon: Icon(_overlayVisible ? Icons.visibility : Icons.visibility_off,
                    color: Colors.white, size: 28),
                onPressed: () => setState(() => _overlayVisible = !_overlayVisible),
              ),
              IconButton(
                icon: const Icon(Icons.tune, color: Colors.white, size: 28),
                onPressed: _showSettings,
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    final wordCount = _displayBlocks.fold<int>(
      0, (s, b) => s + b.lines.fold(0, (s2, l) => s2 + l.elements.length));
    final showFontWarning = _useOpenDyslexic
        && !_isLatinScript(_detectedScript)
        && _displayBlocks.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter, end: Alignment.topCenter,
          colors: [Colors.black.withOpacity(0.75), Colors.transparent],
        ),
      ),
      padding: const EdgeInsets.only(bottom: 28, top: 16, left: 24, right: 24),
      child: SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (showFontWarning)
            Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.85),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'OpenDyslexic is for Latin scripts only — using system font',
                style: TextStyle(color: Colors.white, fontSize: 10),
                textAlign: TextAlign.center,
              ),
            ),
          Text(
            _displayBlocks.isEmpty
                ? 'Point at text to begin'
                : '$wordCount word${wordCount == 1 ? '' : 's'} detected'
                  ' · ${_detectedScript == 'Devanagari' ? 'Devanagari' : 'Latin'} script',
            style: TextStyle(
              color: Colors.white.withOpacity(0.85),
              fontSize: 12,
              fontFamily: _dyslexicActive ? 'OpenDyslexic' : null,
            ),
          ),
          const SizedBox(height: 6),
          Text('Long-press a word for syllable breakdown',
              style: TextStyle(color: Colors.white.withOpacity(0.55), fontSize: 11)),
        ]),
      ),
    );
  }

  void _showSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setModal) => Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            Text('AR Overlay Settings',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold,
                    fontFamily: 'OpenDyslexic',
                    color: Theme.of(ctx).colorScheme.onSurface)),
            const SizedBox(height: 16),
            SwitchListTile(
              title: Text('OpenDyslexic Font (Latin scripts only)',
                  style: TextStyle(fontFamily: 'OpenDyslexic',
                      color: Theme.of(ctx).colorScheme.onSurface)),
              subtitle: Text(
                _isLatinScript(_detectedScript)
                    ? 'Active for current script'
                    : 'Inactive — current script: $_detectedScript',
                style: TextStyle(fontSize: 11,
                    color: _isLatinScript(_detectedScript)
                        ? Colors.green : Colors.orange),
              ),
              value: _useOpenDyslexic,
              activeColor: _kAccent,
              onChanged: (v) {
                setModal(() => _useOpenDyslexic = v);
                setState(() => _useOpenDyslexic = v);
              },
            ),
            _slider(ctx, setModal, 'Font Size', _fontSize, 12, 36,
                (v) { setModal(() => _fontSize = v); setState(() => _fontSize = v); }),
            _slider(ctx, setModal, 'Overlay Opacity', _overlayOpacity, 0.5, 1.0,
                (v) { setModal(() => _overlayOpacity = v); setState(() => _overlayOpacity = v); }),
          ]),
        ),
      ),
    );
  }

  Widget _slider(BuildContext ctx, StateSetter setModal,
      String label, double value, double min, double max, ValueChanged<double> cb) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: TextStyle(fontFamily: 'OpenDyslexic',
            color: Theme.of(ctx).colorScheme.onSurface)),
        Text(value.toStringAsFixed(1), style: const TextStyle(
            fontFamily: 'OpenDyslexic', color: _kPrimary, fontWeight: FontWeight.bold)),
      ]),
      Slider(value: value, min: min, max: max, activeColor: _kAccent, onChanged: cb),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _CoverTransform
// ─────────────────────────────────────────────────────────────────────────────
class _CoverTransform {
  final double scale, cropX, cropY;

  factory _CoverTransform(Size rawImg, int sensorDeg, Size screen) {
    final rotated  = sensorDeg == 90 || sensorDeg == 270;
    final logicalW = rotated ? rawImg.height : rawImg.width;
    final logicalH = rotated ? rawImg.width  : rawImg.height;
    final s  = (screen.width / logicalW) > (screen.height / logicalH)
        ? screen.width / logicalW : screen.height / logicalH;
    return _CoverTransform._(s,
        (logicalW * s - screen.width)  / 2,
        (logicalH * s - screen.height) / 2);
  }

  const _CoverTransform._(this.scale, this.cropX, this.cropY);

  Rect toScreen(Rect box) => Rect.fromLTRB(
    box.left   * scale - cropX, box.top    * scale - cropY,
    box.right  * scale - cropX, box.bottom * scale - cropY,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// _ArOverlayPainter
// ─────────────────────────────────────────────────────────────────────────────
class _ArOverlayPainter extends CustomPainter {
  final List<TextBlock> blocks;
  final Size   rawImageSize;
  final int    sensorDeg;
  final bool   useOpenDyslexic;  // pre-gated: false when script is non-Latin
  final String detectedScript;
  final double fontSize;
  final double opacity;

  const _ArOverlayPainter({
    required this.blocks,
    required this.rawImageSize,
    required this.sensorDeg,
    required this.useOpenDyslexic,
    required this.detectedScript,
    required this.fontSize,
    required this.opacity,
  });

  double get _letterSpacing {
    if (useOpenDyslexic)              return 1.6;
    if (detectedScript == 'Latin')    return 1.1;
    if (detectedScript == 'Devanagari') return 0.6;
    return 0.8;
  }

  double get _wordGapFactor {
    if (useOpenDyslexic)              return 0.65;
    if (detectedScript == 'Latin')    return 0.50;
    return 0.30;
  }

  String? get _fontFamily {
    if (useOpenDyslexic)              return 'OpenDyslexic';
    if (detectedScript == 'Devanagari') return 'NotoSansDevanagari';
    return null;
  }

  @override
  void paint(Canvas canvas, Size screenSize) {
    if (rawImageSize == Size.zero || blocks.isEmpty) return;

    final tf = _CoverTransform(rawImageSize, sensorDeg, screenSize);
    final bgPaint = Paint()
      ..color = const Color(0xFFF5F5F5).withOpacity(opacity * 0.92)
      ..style = PaintingStyle.fill;

    final fs  = fontSize.clamp(8.0, 36.0);
    final ls  = _letterSpacing;
    final wgf = _wordGapFactor;
    final ff  = _fontFamily;

    for (final block in blocks) {
      for (final line in block.lines) {
        final lineRect = tf.toScreen(line.boundingBox);

        if (lineRect.bottom < 0 || lineRect.top > screenSize.height ||
            lineRect.right  < 0 || lineRect.left > screenSize.width) continue;

        final lineH = lineRect.height.clamp(8.0, double.infinity);
        final vPad  = (lineH * 0.28).clamp(3.0, 12.0);

        // Background pill inflated on all four sides.
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTRB(
              lineRect.left - 4,  lineRect.top    - vPad,
              lineRect.right + 4, lineRect.bottom + vPad,
            ),
            const Radius.circular(6),
          ),
          bgPaint,
        );

        if (line.elements.isNotEmpty) {
          // Per-element path (preferred).
          for (final el in line.elements) {
            final elRect = tf.toScreen(el.boundingBox);
            final elW    = elRect.width.clamp(4.0, double.infinity);

            final tp = TextPainter(
              text: TextSpan(
                text: el.text,
                style: TextStyle(
                  color: Colors.black87, fontSize: fs, fontFamily: ff,
                  fontWeight: FontWeight.w600, height: 1.15, letterSpacing: ls,
                ),
              ),
              textDirection: TextDirection.ltr,
              textScaleFactor: 1.0,
              maxLines: 1,
            )..layout(maxWidth: elW + ls * el.text.length + 16);

            tp.paint(canvas, Offset(
              elRect.left + 1,
              lineRect.top - vPad + ((lineH + vPad * 2) - tp.height) / 2,
            ));
          }
        } else {
          // Fallback: word-by-word layout.
          final words = line.text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
          final gap = fs * wgf;
          double cx = lineRect.left + 4; // reset per line

          for (final word in words) {
            final tp = TextPainter(
              text: TextSpan(
                text: word,
                style: TextStyle(
                  color: Colors.black87, fontSize: fs, fontFamily: ff,
                  fontWeight: FontWeight.w600, height: 1.15, letterSpacing: ls,
                ),
              ),
              textDirection: TextDirection.ltr,
              textScaleFactor: 1.0,
              maxLines: 1,
            )..layout();

            tp.paint(canvas, Offset(
              cx,
              lineRect.top - vPad + ((lineH + vPad * 2) - tp.height) / 2,
            ));
            cx += tp.width + gap;
          }
        }
      }
    }
  }

  @override
  bool shouldRepaint(_ArOverlayPainter old) =>
      old.blocks          != blocks          ||
      old.rawImageSize    != rawImageSize    ||
      old.sensorDeg       != sensorDeg       ||
      old.useOpenDyslexic != useOpenDyslexic ||
      old.detectedScript  != detectedScript  ||
      old.fontSize        != fontSize        ||
      old.opacity         != opacity;
}

// ─────────────────────────────────────────────────────────────────────────────
// _SyllablePopup
// ─────────────────────────────────────────────────────────────────────────────
class _SyllablePopup extends StatelessWidget {
  final String word; final List<String> syllables;
  final Offset position; final VoidCallback onDismiss;

  const _SyllablePopup({
    required this.word, required this.syllables,
    required this.position, required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final s = MediaQuery.of(context).size;
    return Positioned(
      left: (position.dx - 100).clamp(8.0, s.width  - 216.0),
      top:  (position.dy - 90 ).clamp(8.0, s.height - 120.0),
      child: GestureDetector(
        onTap: onDismiss,
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
              Text(word, style: const TextStyle(color: Colors.white70,
                  fontSize: 12, fontFamily: 'OpenDyslexic')),
              const SizedBox(height: 4),
              Text(syllables.join(' · '), style: const TextStyle(
                  color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold,
                  fontFamily: 'OpenDyslexic', letterSpacing: 2)),
              const SizedBox(height: 4),
              Text('${syllables.length} syllable${syllables.length != 1 ? "s" : ""}',
                  style: const TextStyle(color: Colors.white70, fontSize: 10,
                      fontFamily: 'OpenDyslexic')),
            ]),
          ),
        ),
      ),
    );
  }
}