// lib/screens/live_ar_screen.dart
// FR-005 to FR-009 – Live real-time AR camera OCR with dyslexia-friendly overlay
// Processes CameraImage frames from startImageStream, overlays recognised text
// at ~200 ms intervals (throttled to avoid saturating the OCR pipeline).

// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import 'package:lexilens/bloc/app_bloc.dart';
import 'package:lexilens/bloc/app_events.dart';
import 'package:lexilens/bloc/app_states.dart';
import 'package:lexilens/services/syllable_service.dart';

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------
const _kPrimary = Color(0xFF7B4FA6);
const _kAccent = Color(0xFFB789DA);

/// Minimum interval between successive OCR calls (ms).
const _kOcrThrottleMs = 200;

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------
class LiveArScreen extends StatefulWidget {
  const LiveArScreen({super.key});

  @override
  State<LiveArScreen> createState() => _LiveArScreenState();
}

class _LiveArScreenState extends State<LiveArScreen>
    with WidgetsBindingObserver {
  // ── Camera ────────────────────────────────────────────────────────────────
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  bool _cameraReady = false;

  // ── OCR ──────────────────────────────────────────────────────────────────
  final TextRecognizer _latinRecognizer =
      TextRecognizer(script: TextRecognitionScript.latin);
  final TextRecognizer _devanagariRecognizer =
      TextRecognizer(script: TextRecognitionScript.devanagiri);

  bool _processingFrame = false;
  DateTime _lastOcrTime = DateTime.fromMillisecondsSinceEpoch(0);

  // ── Overlay state ─────────────────────────────────────────────────────────
  List<TextBlock> _textBlocks = [];
  Size _imageSize = Size.zero;
  int _frameRotation = 0;

  // ── UI controls ───────────────────────────────────────────────────────────
  bool _useOpenDyslexic = true;
  double _fontSize = 16.0;
  double _overlayOpacity = 0.85;
  bool _overlayVisible = true;
  bool _isFlashOn = false;

  final _syllableService = SyllableService();

  // ── Freeze-frame for syllable lookup ─────────────────────────────────────
  String? _tappedWord;
  List<String>? _tappedSyllables;
  Offset? _tappedPosition;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final s = context.read<AppBloc>().state;
        setState(() {
          _useOpenDyslexic = s.useOpenDyslexic;
          _fontSize = s.fontSize.clamp(12.0, 36.0);
          _overlayOpacity = s.overlayOpacity;
        });
      }
    });
    _initCamera();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_controller == null || !_controller!.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      _stopStream();
    } else if (state == AppLifecycleState.resumed) {
      _startStream();
    }
  }

  // ── Camera init ──────────────────────────────────────────────────────────

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras == null || _cameras!.isEmpty) {
        _showError('No camera found on this device.');
        return;
      }

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
      _showError('Camera initialisation failed: $e');
    }
  }

  void _startStream() {
    _controller?.startImageStream(_onCameraImage);
  }

  void _stopStream() {
    if (_controller?.value.isStreamingImages == true) {
      _controller?.stopImageStream();
    }
  }

  // ── Frame handler ────────────────────────────────────────────────────────

  Future<void> _onCameraImage(CameraImage image) async {
    final now = DateTime.now();
    if (_processingFrame ||
        now.difference(_lastOcrTime).inMilliseconds < _kOcrThrottleMs) {
      return;
    }
    _processingFrame = true;
    _lastOcrTime = now;

    try {
      final inputImage = _buildInputImage(image);
      if (inputImage == null) return;

      final result = await _latinRecognizer.processImage(inputImage);

      List<TextBlock> blocks = result.blocks;
      if (blocks.isEmpty || result.text.trim().isEmpty) {
        final devResult =
            await _devanagariRecognizer.processImage(inputImage);
        if (devResult.text.isNotEmpty) {
          blocks = devResult.blocks;
        }
      }

      if (mounted) {
        setState(() {
          _textBlocks = blocks;
          _imageSize = Size(
            image.width.toDouble(),
            image.height.toDouble(),
          );
          _frameRotation = _getSensorRotation();
        });
      }
    } catch (_) {
      // Swallow OCR errors silently – next frame will retry
    } finally {
      _processingFrame = false;
    }
  }

  InputImage? _buildInputImage(CameraImage image) {
    final camera = _cameras?[0];
    if (camera == null) return null;

    final rotation =
        InputImageRotationValue.fromRawValue(camera.sensorOrientation);
    if (rotation == null) return null;

    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null) return null;

    final plane = image.planes.first;

    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  int _getSensorRotation() {
    return _cameras?.isNotEmpty == true
        ? _cameras![0].sensorOrientation
        : 0;
  }

  // ── Flash ─────────────────────────────────────────────────────────────────

  Future<void> _toggleFlash() async {
    if (_controller == null) return;
    setState(() => _isFlashOn = !_isFlashOn);
    await _controller!
        .setFlashMode(_isFlashOn ? FlashMode.torch : FlashMode.off);
  }

  // ── Syllable pop-up ───────────────────────────────────────────────────────

  void _onLongPress(TapDownDetails details) {
    if (_textBlocks.isEmpty) return;

    final screenSize = MediaQuery.of(context).size;
    final touchPos = details.localPosition;

    final bool rotated = _frameRotation == 90 || _frameRotation == 270;
    final double imageW = rotated ? _imageSize.height : _imageSize.width;
    final double imageH = rotated ? _imageSize.width : _imageSize.height;

    final scaleX = screenSize.width / imageW;
    final scaleY = screenSize.height / imageH;

    for (final block in _textBlocks) {
      for (final line in block.lines) {
        for (final element in line.elements) {
          final box = element.boundingBox;
          final scaledBox = Rect.fromLTRB(
            box.left * scaleX,
            box.top * scaleY,
            box.right * scaleX,
            box.bottom * scaleY,
          );
          if (scaledBox.contains(touchPos)) {
            final word =
                element.text.replaceAll(RegExp(r'[^\w]'), '');
            if (word.length > 2) {
              final syllables =
                  _syllableService.breakIntoSyllables(word);
              setState(() {
                _tappedWord = word;
                _tappedSyllables = syllables;
                _tappedPosition = details.globalPosition;
              });
              Future.delayed(
                  const Duration(seconds: 3),
                  () => mounted
                      ? setState(() {
                          _tappedWord = null;
                          _tappedSyllables = null;
                          _tappedPosition = null;
                        })
                      : null);
            }
            return;
          }
        }
      }
    }
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  // ── Dispose ──────────────────────────────────────────────────────────────

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopStream();
    _controller?.dispose();
    _latinRecognizer.close();
    _devanagariRecognizer.close();
    super.dispose();
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Camera preview ──────────────────────────────────────────────
          if (_cameraReady && _controller != null)
            GestureDetector(
              onLongPressStart: (d) =>
                  _onLongPress(TapDownDetails(globalPosition: d.globalPosition, localPosition: d.localPosition)),
              child: CameraPreview(_controller!),
            )
          else
            const Center(
              child: CircularProgressIndicator(color: _kAccent),
            ),

          // ── Live AR text overlay ────────────────────────────────────────
          if (_cameraReady &&
              _overlayVisible &&
              _textBlocks.isNotEmpty &&
              _imageSize != Size.zero)
            Positioned.fill(
              child: CustomPaint(
                painter: _LiveOverlayPainter(
                  textBlocks: _textBlocks,
                  imageSize: _imageSize,
                  useOpenDyslexic: _useOpenDyslexic,
                  fontSize: _fontSize,
                  opacity: _overlayOpacity,
                  sensorRotation: _frameRotation,
                ),
              ),
            ),

          // ── Syllable pop-up ─────────────────────────────────────────────
          if (_tappedWord != null && _tappedSyllables != null)
            _SyllablePopup(
              word: _tappedWord!,
              syllables: _tappedSyllables!,
              position: _tappedPosition ?? Offset.zero,
              onDismiss: () => setState(() {
                _tappedWord = null;
                _tappedSyllables = null;
                _tappedPosition = null;
              }),
            ),

          // ── Top bar ─────────────────────────────────────────────────────
          _buildTopBar(context),

          // ── Bottom controls ─────────────────────────────────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildBottomControls(),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.black.withOpacity(0.7), Colors.transparent],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back,
                      color: Colors.white, size: 28),
                  onPressed: () => Navigator.pop(context),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _kAccent.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.fiber_manual_record,
                          color: Colors.red, size: 10),
                      SizedBox(width: 4),
                      Text(
                        'LIVE AR',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'OpenDyslexic',
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(
                    _isFlashOn ? Icons.flash_on : Icons.flash_off,
                    color: Colors.white,
                    size: 28,
                  ),
                  onPressed: _toggleFlash,
                ),
                IconButton(
                  icon: Icon(
                    _overlayVisible
                        ? Icons.visibility
                        : Icons.visibility_off,
                    color: Colors.white,
                    size: 28,
                  ),
                  onPressed: () =>
                      setState(() => _overlayVisible = !_overlayVisible),
                ),
                IconButton(
                  icon: const Icon(Icons.tune,
                      color: Colors.white, size: 28),
                  onPressed: _showSettings,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomControls() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Colors.black.withOpacity(0.75), Colors.transparent],
        ),
      ),
      padding:
          const EdgeInsets.only(bottom: 28, top: 16, left: 24, right: 24),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _textBlocks.isEmpty
                  ? 'Point at text to begin'
                  : '${_textBlocks.fold<int>(0, (sum, b) => sum + b.lines.fold(0, (s, l) => s + l.elements.length))} words detected',
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 12,
                fontFamily: 'OpenDyslexic',
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.touch_app,
                    color: Colors.white54, size: 14),
                const SizedBox(width: 4),
                Text(
                  'Long-press a word for syllable breakdown',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 11,
                    fontFamily: 'OpenDyslexic',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setModal) => Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'AR Overlay Settings',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'OpenDyslexic',
                ),
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('OpenDyslexic Font',
                    style: TextStyle(fontFamily: 'OpenDyslexic')),
                value: _useOpenDyslexic,
                activeColor: _kAccent,
                onChanged: (v) {
                  setModal(() => _useOpenDyslexic = v);
                  setState(() => _useOpenDyslexic = v);
                },
              ),
              _buildSliderRow(
                'Font Size',
                _fontSize,
                12.0,
                36.0,
                (v) {
                  setModal(() => _fontSize = v);
                  setState(() => _fontSize = v);
                },
              ),
              _buildSliderRow(
                'Overlay Opacity',
                _overlayOpacity,
                0.5,
                1.0,
                (v) {
                  setModal(() => _overlayOpacity = v);
                  setState(() => _overlayOpacity = v);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSliderRow(
    String label,
    double value,
    double min,
    double max,
    ValueChanged<double> onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: const TextStyle(fontFamily: 'OpenDyslexic')),
            Text(value.toStringAsFixed(1),
                style: const TextStyle(
                    fontFamily: 'OpenDyslexic',
                    color: _kPrimary,
                    fontWeight: FontWeight.bold)),
          ],
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          activeColor: _kAccent,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Live overlay painter  — FIX: x resets per line; layout uses unconstrained
// width so OpenDyslexic glyphs are never clipped; background height is padded
// to accommodate the font's larger descenders/ascenders.
// ---------------------------------------------------------------------------
class _LiveOverlayPainter extends CustomPainter {
  final List<TextBlock> textBlocks;
  final Size imageSize;
  final bool useOpenDyslexic;
  final double fontSize;
  final double opacity;
  final int sensorRotation;

  const _LiveOverlayPainter({
    required this.textBlocks,
    required this.imageSize,
    required this.useOpenDyslexic,
    required this.fontSize,
    required this.opacity,
    required this.sensorRotation,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (imageSize == Size.zero) return;

    // Account for sensor rotation so bounding-box coordinates map correctly
    // onto portrait-mode screen space.
    final bool rotated = sensorRotation == 90 || sensorRotation == 270;
    final double imageW = rotated ? imageSize.height : imageSize.width;
    final double imageH = rotated ? imageSize.width : imageSize.height;

    final double scaleX = size.width / imageW;
    final double scaleY = size.height / imageH;

    final bgPaint = Paint()
      ..color = const Color(0xFFEEEEEE).withOpacity(opacity * 0.9)
      ..style = PaintingStyle.fill;

    for (final block in textBlocks) {
      for (final line in block.lines) {
        final box = line.boundingBox;
        final scaledRect = Rect.fromLTRB(
          box.left * scaleX,
          box.top * scaleY,
          box.right * scaleX,
          box.bottom * scaleY,
        );

        final lineHeight = scaledRect.height;
        // FIX: Add vertical padding so OpenDyslexic ascenders/descenders are
        // fully visible inside the background pill.
        final double vPad = useOpenDyslexic ? lineHeight * 0.25 : 3.0;

        canvas.drawRRect(
          RRect.fromRectAndRadius(
            scaledRect.inflate(vPad),
            const Radius.circular(4),
          ),
          bgPaint,
        );

        if (line.elements.isNotEmpty) {
          // FIX: reset x to the left edge of this line on every iteration.
          double x = scaledRect.left + 2;

          for (final element in line.elements) {
            final wordBox = element.boundingBox;
            final wordHeight = wordBox.height * scaleY;

            // FIX: use fontSize (user setting) as the target size, clamped to
            // the detected word height so the text fits within the bounding box.
            final double targetSize =
                fontSize.clamp(8.0, wordHeight.clamp(8.0, fontSize + 4));

            final style = TextStyle(
              color: Colors.black87,
              fontSize: targetSize,
              fontFamily: useOpenDyslexic ? 'OpenDyslexic' : null,
              fontWeight: FontWeight.w500,
              height: 1.0,
              letterSpacing: useOpenDyslexic ? 0.5 : 0,
            );

            final tp = TextPainter(
              text: TextSpan(text: element.text, style: style),
              textDirection: TextDirection.ltr,
              maxLines: 1,
              // FIX: layout without a maxWidth constraint so OpenDyslexic
              // glyphs (which are wider than system fonts) are never truncated.
            )..layout();

            // Vertically centre text within the background rect.
            final double bgTop = scaledRect.top - vPad;
            final double bgHeight = lineHeight + vPad * 2;
            final textY = bgTop + (bgHeight - tp.height) / 2;

            tp.paint(canvas, Offset(x, textY));
            // FIX: advance x by the actual painted width plus a small gap.
            x += tp.width + (useOpenDyslexic ? 6.0 : 4.0);
          }
        } else {
          // Fallback: no per-word elements – render the whole line text.
          final double targetSize = lineHeight.clamp(8.0, fontSize);
          final style = TextStyle(
            color: Colors.black87,
            fontSize: targetSize,
            fontFamily: useOpenDyslexic ? 'OpenDyslexic' : null,
            fontWeight: FontWeight.w500,
            height: 1.0,
          );
          final tp = TextPainter(
            text: TextSpan(text: line.text, style: style),
            textDirection: TextDirection.ltr,
            maxLines: 1,
          )..layout();

          final double bgTop = scaledRect.top - 3;
          final double bgHeight = lineHeight + 6;
          final textY = bgTop + (bgHeight - tp.height) / 2;
          tp.paint(canvas, Offset(scaledRect.left + 2, textY));
        }
      }
    }
  }

  @override
  bool shouldRepaint(_LiveOverlayPainter old) =>
      old.textBlocks != textBlocks ||
      old.imageSize != imageSize ||
      old.useOpenDyslexic != useOpenDyslexic ||
      old.fontSize != fontSize ||
      old.opacity != opacity ||
      old.sensorRotation != sensorRotation;
}

// ---------------------------------------------------------------------------
// Syllable pop-up widget
// ---------------------------------------------------------------------------
class _SyllablePopup extends StatelessWidget {
  final String word;
  final List<String> syllables;
  final Offset position;
  final VoidCallback onDismiss;

  const _SyllablePopup({
    required this.word,
    required this.syllables,
    required this.position,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    double left = position.dx - 100;
    double top = position.dy - 90;
    left = left.clamp(8.0, screenSize.width - 216.0);
    top = top.clamp(8.0, screenSize.height - 120.0);

    return Positioned(
      left: left,
      top: top,
      child: GestureDetector(
        onTap: onDismiss,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: _kAccent,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4)),
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
                      fontFamily: 'OpenDyslexic'),
                ),
                const SizedBox(height: 4),
                Text(
                  syllables.join(' · '),
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
                  '${syllables.length} syllable${syllables.length != 1 ? 's' : ''}',
                  style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 10,
                      fontFamily: 'OpenDyslexic'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}