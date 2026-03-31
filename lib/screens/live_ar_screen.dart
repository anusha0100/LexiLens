// lib/screens/live_ar_screen.dart
// FR-005 to FR-009 – Live real-time AR camera OCR with dyslexia-friendly overlay

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

// Throttle: process a frame at most every 700 ms
const _kThrottleMs = 700;

// How many consecutive empty OCR frames before clearing the overlay
const _kEmptyFramesToClear = 4;

// Text must be detected in at least this many frames to show
const _kStabilizationThreshold = 2;

// Keep showing text for this long after last detection (ms)
const _kTextStalenessMs = 2500;

// ─────────────────────────────────────────────────────────────────────────────
// StabilizedTextBlock
// ─────────────────────────────────────────────────────────────────────────────
class StabilizedTextBlock {
  TextBlock mlBlock;
  int seenCount;
  DateTime lastSeen;

  StabilizedTextBlock(this.mlBlock)
      : seenCount = 1,
        lastSeen = DateTime.now();

  bool get isStable => seenCount >= _kStabilizationThreshold;

  void refresh(TextBlock newBlock) {
    mlBlock = newBlock;
    seenCount++;
    lastSeen = DateTime.now();
  }

  bool get isStale =>
      DateTime.now().difference(lastSeen).inMilliseconds > _kTextStalenessMs;
}

// ─────────────────────────────────────────────────────────────────────────────
// TextStabilizer
// ─────────────────────────────────────────────────────────────────────────────
class TextStabilizer {
  final Map<String, StabilizedTextBlock> _memory = {};

  List<TextBlock> update(List<TextBlock> incoming) {
    final nowKeys = <String>{};

    for (final block in incoming) {
      final key = _key(block);
      nowKeys.add(key);
      if (_memory.containsKey(key)) {
        _memory[key]!.refresh(block);
      } else {
        _memory[key] = StabilizedTextBlock(block);
      }
    }

    _memory.removeWhere((k, v) => !nowKeys.contains(k) && v.isStale);

    return _memory.values
        .where((b) => b.isStable)
        .map((b) => b.mlBlock)
        .toList();
  }

  String _key(TextBlock block) {
    final txt = block.text
        .replaceAll(RegExp(r'\s+'), '')
        .toLowerCase()
        .substring(0, block.text.length.clamp(0, 12));
    final x = (block.boundingBox.left / 20).round();
    final y = (block.boundingBox.top  / 20).round();
    return '$txt|$x,$y';
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

class _LiveArScreenState extends State<LiveArScreen>
    with WidgetsBindingObserver {
  // ── Camera ─────────────────────────────────────────────────────────────────
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  bool _cameraReady = false;

  // ── OCR ────────────────────────────────────────────────────────────────────
  final _latinRecognizer =
      TextRecognizer(script: TextRecognitionScript.latin);
  final _devaRecognizer =
      TextRecognizer(script: TextRecognitionScript.devanagiri);

  bool _ocrBusy   = false;
  int  _lastOcrMs = 0;

  // ── Overlay state ───────────────────────────────────────────────────────────
  List<TextBlock> _displayBlocks = [];

  // Raw image dimensions as captured (before any rotation).
  Size _rawImageSize = Size.zero;

  // Sensor orientation degrees (0, 90, 180, 270).
  int _sensorDeg = 0;

  int _emptyCount = 0;

  final _stabilizer = TextStabilizer();

  // ── Controls ────────────────────────────────────────────────────────────────
  bool   _useOpenDyslexic = true;
  double _fontSize        = 16.0;
  double _overlayOpacity  = 0.85;
  bool   _overlayVisible  = true;
  bool   _flashOn         = false;

  final _syllableService = SyllableService();

  // ── Syllable popup ──────────────────────────────────────────────────────────
  String?       _popWord;
  List<String>? _popSyllables;
  Offset?       _popPosition;

  // ── Pending update (batch setState) ─────────────────────────────────────────
  List<TextBlock>? _pendingBlocks;
  Size?            _pendingSize;
  bool             _pendingScheduled = false;

  // ── Actual screen size used by the overlay ───────────────────────────────────
  Size _screenSize = Size.zero;

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
    else if (st == AppLifecycleState.resumed)  _startStream();
  }

  // ── Camera initialisation ───────────────────────────────────────────────────

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras == null || _cameras!.isEmpty) {
        _err('No camera found.'); return;
      }

      _sensorDeg = _cameras![0].sensorOrientation;

      _controller = CameraController(
        _cameras![0],
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid
            ? ImageFormatGroup.nv21
            : ImageFormatGroup.bgra8888,
      );
      await _controller!.initialize();
      if (!mounted) return;
      setState(() => _cameraReady = true);
      _startStream();
    } catch (e) {
      _err('Camera init failed: $e');
    }
  }

  void _startStream() => _controller?.startImageStream(_onFrame);

  void _stopStream() {
    if (_controller?.value.isStreamingImages == true) {
      _controller!.stopImageStream();
    }
  }

  // ── Frame processing ─────────────────────────────────────────────────────────

  void _onFrame(CameraImage img) {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (_ocrBusy || now - _lastOcrMs < _kThrottleMs) return;
    _ocrBusy   = true;
    _lastOcrMs = now;
    _processFrame(img)
        .catchError((_) {})
        .whenComplete(() => _ocrBusy = false);
  }

  Future<void> _processFrame(CameraImage img) async {
    final inputImage = _toInputImage(img);
    if (inputImage == null) return;

    var result = await _latinRecognizer.processImage(inputImage);
    if (result.blocks.isEmpty) {
      final dev = await _devaRecognizer.processImage(inputImage);
      if (dev.blocks.isNotEmpty) result = dev;
    }

    final stable = _stabilizer.update(result.blocks);

    if (stable.isEmpty) {
      _emptyCount++;
      if (_emptyCount < _kEmptyFramesToClear) return;
    } else {
      _emptyCount = 0;
    }

    // FIX: always record the raw image size from every processed frame,
    // not only when stable blocks exist. This ensures _rawImageSize is
    // populated even before the stabiliser promotes any blocks, so the
    // overlay condition (_rawImageSize != Size.zero) is satisfied promptly.
    _pendingBlocks = stable;
    _pendingSize   = Size(img.width.toDouble(), img.height.toDouble());

    if (!_pendingScheduled) {
      _pendingScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          if (_pendingBlocks != null) _displayBlocks = _pendingBlocks!;
          // Always update the raw size so overlay alignment is never stale.
          if (_pendingSize != null)   _rawImageSize  = _pendingSize!;
          _pendingBlocks    = null;
          _pendingSize      = null;
          _pendingScheduled = false;
        });
      });
    }
  }

  // ── InputImage builder ────────────────────────────────────────────────────────

  InputImage? _toInputImage(CameraImage img) {
    final cam = _cameras?[0];
    if (cam == null) return null;

    final rotation = InputImageRotationValue.fromRawValue(cam.sensorOrientation);
    if (rotation == null) return null;

    final format = InputImageFormatValue.fromRawValue(img.format.raw);
    if (format == null) return null;

    Uint8List bytes;
    if (Platform.isAndroid) {
      final allBytes = <int>[];
      for (final plane in img.planes) {
        allBytes.addAll(plane.bytes);
      }
      bytes = Uint8List.fromList(allBytes);
    } else {
      bytes = img.planes[0].bytes;
    }

    return InputImage.fromBytes(
      bytes: bytes,
      metadata: InputImageMetadata(
        size:        Size(img.width.toDouble(), img.height.toDouble()),
        rotation:    rotation,
        format:      format,
        bytesPerRow: img.planes[0].bytesPerRow,
      ),
    );
  }

  // ── Flash ────────────────────────────────────────────────────────────────────

  Future<void> _toggleFlash() async {
    if (_controller == null) return;
    setState(() => _flashOn = !_flashOn);
    await _controller!.setFlashMode(_flashOn ? FlashMode.torch : FlashMode.off);
  }

  // ── Long-press → syllable popup ──────────────────────────────────────────────

  void _onLongPress(LongPressStartDetails details) {
    if (_displayBlocks.isEmpty || _rawImageSize == Size.zero) return;
    final touch = details.localPosition;
    final tf    = _CoverTransform(_rawImageSize, _sensorDeg, _screenSize);

    for (final block in _displayBlocks) {
      for (final line in block.lines) {
        for (final el in line.elements) {
          final screenRect = tf.toScreen(el.boundingBox);
          if (screenRect.contains(touch)) {
            final word = el.text.replaceAll(RegExp(r'[^\w]'), '');
            if (word.length > 2) {
              final syllables = _syllableService.breakIntoSyllables(word);
              setState(() {
                _popWord      = word;
                _popSyllables = syllables;
                _popPosition  = details.globalPosition;
              });
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

  // ── Helpers ──────────────────────────────────────────────────────────────────

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

  // ── Build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    _screenSize = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Camera preview ──────────────────────────────────────────────────
          if (_cameraReady && _controller != null)
            GestureDetector(
              onLongPressStart: _onLongPress,
              child: CameraPreview(_controller!),
            )
          else
            const Center(child: CircularProgressIndicator(color: _kAccent)),

          // ── AR text overlay ─────────────────────────────────────────────────
          // FIX: Guard now uses _rawImageSize != Size.zero as the primary
          // condition; _displayBlocks can be empty (we still show the painter
          // so it can clear itself). The overlay was previously invisible
          // because _rawImageSize stayed Size.zero until a stable block
          // appeared — but stable blocks require the rawImageSize to already be
          // set. The _processFrame() fix above decouples the two.
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
                    useOpenDyslexic: _useOpenDyslexic,
                    fontSize:        _fontSize,
                    opacity:         _overlayOpacity,
                  ),
                ),
              ),
            ),

          // ── Syllable popup ──────────────────────────────────────────────────
          if (_popWord != null && _popSyllables != null)
            _SyllablePopup(
              word:      _popWord!,
              syllables: _popSyllables!,
              position:  _popPosition ?? Offset.zero,
              onDismiss: () => setState(() { _popWord = null; _popSyllables = null; }),
            ),

          // ── Top bar ─────────────────────────────────────────────────────────
          _buildTopBar(),

          // ── Bottom status ───────────────────────────────────────────────────
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: _buildBottomBar(),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Positioned(
      top: 0, left: 0, right: 0,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end:   Alignment.bottomCenter,
            colors: [Colors.black.withOpacity(0.7), Colors.transparent],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: [
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
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.fiber_manual_record, color: Colors.red, size: 10),
                      SizedBox(width: 4),
                      Text('LIVE AR',
                          style: TextStyle(color: Colors.white, fontSize: 11,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(_flashOn ? Icons.flash_on : Icons.flash_off,
                      color: Colors.white, size: 28),
                  onPressed: _toggleFlash,
                ),
                IconButton(
                  icon: Icon(_overlayVisible
                      ? Icons.visibility : Icons.visibility_off,
                      color: Colors.white, size: 28),
                  onPressed: () => setState(() => _overlayVisible = !_overlayVisible),
                ),
                IconButton(
                  icon: const Icon(Icons.tune, color: Colors.white, size: 28),
                  onPressed: _showSettings,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end:   Alignment.topCenter,
          colors: [Colors.black.withOpacity(0.75), Colors.transparent],
        ),
      ),
      padding: const EdgeInsets.only(bottom: 28, top: 16, left: 24, right: 24),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _displayBlocks.isEmpty
                  ? 'Point at text to begin'
                  : '${_displayBlocks.fold<int>(0, (s, b) => s + b.lines.fold(0, (s2, l) => s2 + l.elements.length))} words detected',
              style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 12,
                  fontFamily: 'OpenDyslexic'),
            ),
            const SizedBox(height: 6),
            Text('Long-press a word for syllable breakdown',
                style: TextStyle(
                    color: Colors.white.withOpacity(0.55), fontSize: 11)),
          ],
        ),
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('AR Overlay Settings',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'OpenDyslexic',
                      color: Theme.of(ctx).colorScheme.onSurface)),
              const SizedBox(height: 16),
              SwitchListTile(
                title: Text('OpenDyslexic Font',
                    style: TextStyle(
                        fontFamily: 'OpenDyslexic',
                        color: Theme.of(ctx).colorScheme.onSurface)),
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _slider(BuildContext ctx, StateSetter setModal,
      String label, double value, double min, double max,
      ValueChanged<double> cb) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: TextStyle(fontFamily: 'OpenDyslexic',
                    color: Theme.of(ctx).colorScheme.onSurface)),
            Text(value.toStringAsFixed(1),
                style: const TextStyle(
                    fontFamily: 'OpenDyslexic',
                    color: _kPrimary,
                    fontWeight: FontWeight.bold)),
          ],
        ),
        Slider(value: value, min: min, max: max, activeColor: _kAccent, onChanged: cb),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _CoverTransform  –  maps ML Kit bounding boxes → screen pixels
//
// CameraPreview uses BoxFit.cover:
//   scale = max(screenW / logicalW, screenH / logicalH)
//   cropX = (logicalW * scale − screenW) / 2
//   cropY = (logicalH * scale − screenH) / 2
//   screenX = boxX * scale − cropX
//   screenY = boxY * scale − cropY
// ─────────────────────────────────────────────────────────────────────────────
class _CoverTransform {
  final double scale;
  final double cropX;
  final double cropY;

  factory _CoverTransform(Size rawImg, int sensorDeg, Size screen) {
    final rotated  = sensorDeg == 90 || sensorDeg == 270;
    final logicalW = rotated ? rawImg.height : rawImg.width;
    final logicalH = rotated ? rawImg.width  : rawImg.height;

    final sw = screen.width  / logicalW;
    final sh = screen.height / logicalH;
    final s  = sw > sh ? sw : sh;

    final cx = (logicalW * s - screen.width)  / 2;
    final cy = (logicalH * s - screen.height) / 2;

    return _CoverTransform._(s, cx, cy);
  }

  const _CoverTransform._(this.scale, this.cropX, this.cropY);

  Rect toScreen(Rect box) => Rect.fromLTRB(
    box.left   * scale - cropX,
    box.top    * scale - cropY,
    box.right  * scale - cropX,
    box.bottom * scale - cropY,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// _ArOverlayPainter
//
// FIXES vs original:
//  1. letterSpacing: 1.4 (OpenDyslexic) · 1.0 (plain Latin) so letters never
//     blur together under camera distortion.
//  2. Explicit inter-word gap (wordGapFactor × fontSize) applied in BOTH the
//     per-element and fallback paths — words were previously drawn packed
//     bounding-box to bounding-box with zero breathing room.
//  3. fontSize is NOT clamped to elementHeight — the user setting is used
//     directly (min 8 px). Clamping to line height was squashing glyphs.
//  4. Vertical padding is 25 % of line height so descenders are fully visible.
//  5. textScaleFactor: 1.0 — prevents system-level scaling from misaligning
//     text within bounding boxes.
//  6. height: 1.15 for open leading.
//  7. Background pill is off-white #F5F5F5 for better contrast on dark scenes.
//  8. paint() returns early but gracefully (no crash) when blocks is empty —
//     this is expected during the "no text in frame" state.
// ─────────────────────────────────────────────────────────────────────────────
class _ArOverlayPainter extends CustomPainter {
  final List<TextBlock> blocks;
  final Size   rawImageSize;
  final int    sensorDeg;
  final bool   useOpenDyslexic;
  final double fontSize;
  final double opacity;

  const _ArOverlayPainter({
    required this.blocks,
    required this.rawImageSize,
    required this.sensorDeg,
    required this.useOpenDyslexic,
    required this.fontSize,
    required this.opacity,
  });

  // ── Typography helpers ─────────────────────────────────────────────────────

  double get _letterSpacing => useOpenDyslexic ? 1.4 : 1.0;
  double get _wordGapFactor => useOpenDyslexic ? 0.55 : 0.40;
  String? get _fontFamily   => useOpenDyslexic ? 'OpenDyslexic' : null;

  @override
  void paint(Canvas canvas, Size screenSize) {
    // Early-out when no image size is known yet (before first frame processed).
    if (rawImageSize == Size.zero) return;
    // When blocks is empty we simply paint nothing — overlay is transparent.
    if (blocks.isEmpty) return;

    final tf = _CoverTransform(rawImageSize, sensorDeg, screenSize);

    final bgPaint = Paint()
      ..color = const Color(0xFFF5F5F5).withOpacity(opacity * 0.92)
      ..style = PaintingStyle.fill;

    // Clamp fontSize once; do NOT clamp to line height per element.
    final fs  = fontSize.clamp(8.0, 36.0);
    final ls  = _letterSpacing;
    final wgf = _wordGapFactor;
    final ff  = _fontFamily;

    for (final block in blocks) {
      for (final line in block.lines) {
        final lineRect = tf.toScreen(line.boundingBox);

        // Skip if outside screen bounds.
        if (lineRect.bottom < 0 || lineRect.top > screenSize.height ||
            lineRect.right  < 0 || lineRect.left > screenSize.width) continue;

        final lineH = lineRect.height.clamp(8.0, double.infinity);
        // 25 % vertical padding so descenders are visible.
        final vPad  = (lineH * 0.25).clamp(3.0, 10.0);

        // Background pill for the whole line.
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            lineRect.inflate(vPad), const Radius.circular(5)),
          bgPaint,
        );

        // ── Per-element path (preferred) ─────────────────────────────────────
        if (line.elements.isNotEmpty) {
          for (final el in line.elements) {
            final elRect = tf.toScreen(el.boundingBox);
            final elW    = elRect.width.clamp(4.0, double.infinity);

            final tp = TextPainter(
              text: TextSpan(
                text: el.text,
                style: TextStyle(
                  color:         Colors.black87,
                  fontSize:      fs,
                  fontFamily:    ff,
                  fontWeight:    FontWeight.w600,
                  height:        1.15,
                  letterSpacing: ls,
                ),
              ),
              textDirection:   TextDirection.ltr,
              textScaleFactor: 1.0,
              maxLines:        1,
            )..layout(maxWidth: elW + ls * el.text.length + 8);

            // Centre vertically within the padded line rect.
            final textY = lineRect.top - vPad +
                ((lineH + vPad * 2) - tp.height) / 2;
            tp.paint(canvas, Offset(elRect.left + 1, textY));
          }

        // ── Fallback path (no per-element data) ──────────────────────────────
        } else {
          final words = line.text
              .split(RegExp(r'\s+'))
              .where((w) => w.isNotEmpty)
              .toList();
          final gap = fs * wgf; // explicit inter-word spacing
          double cx = lineRect.left + 2;

          for (final word in words) {
            final tp = TextPainter(
              text: TextSpan(
                text: word,
                style: TextStyle(
                  color:         Colors.black87,
                  fontSize:      fs,
                  fontFamily:    ff,
                  fontWeight:    FontWeight.w600,
                  height:        1.15,
                  letterSpacing: ls,
                ),
              ),
              textDirection:   TextDirection.ltr,
              textScaleFactor: 1.0,
              maxLines:        1,
            )..layout();

            final textY = lineRect.top - vPad +
                ((lineH + vPad * 2) - tp.height) / 2;
            tp.paint(canvas, Offset(cx, textY));

            // Advance by word width + explicit gap.
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
      old.fontSize        != fontSize        ||
      old.opacity         != opacity;
}

// ─────────────────────────────────────────────────────────────────────────────
// _SyllablePopup
// ─────────────────────────────────────────────────────────────────────────────
class _SyllablePopup extends StatelessWidget {
  final String       word;
  final List<String> syllables;
  final Offset       position;
  final VoidCallback onDismiss;

  const _SyllablePopup({
    required this.word,
    required this.syllables,
    required this.position,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final s    = MediaQuery.of(context).size;
    final left = (position.dx - 100).clamp(8.0, s.width  - 216.0);
    final top  = (position.dy - 90 ).clamp(8.0, s.height - 120.0);

    return Positioned(
      left: left, top: top,
      child: GestureDetector(
        onTap: onDismiss,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: _kAccent,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.3),
                    blurRadius: 10, offset: const Offset(0, 4)),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(word,
                    style: const TextStyle(color: Colors.white70, fontSize: 12,
                        fontFamily: 'OpenDyslexic')),
                const SizedBox(height: 4),
                Text(syllables.join(' · '),
                    style: const TextStyle(color: Colors.white, fontSize: 20,
                        fontWeight: FontWeight.bold, fontFamily: 'OpenDyslexic',
                        letterSpacing: 2)),
                const SizedBox(height: 4),
                Text('${syllables.length} syllable${syllables.length != 1 ? "s" : ""}',
                    style: const TextStyle(color: Colors.white70, fontSize: 10,
                        fontFamily: 'OpenDyslexic')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}