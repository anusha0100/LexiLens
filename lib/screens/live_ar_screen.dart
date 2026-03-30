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
import 'package:lexilens/bloc/app_states.dart';
import 'package:lexilens/services/syllable_service.dart';

const _kPrimary = Color(0xFF7B4FA6);
const _kAccent  = Color(0xFFB789DA);

// Minimum ms between OCR calls — 600 ms gives stable, flicker-free output.
const _kThrottleMs = 600;

// How many consecutive empty OCR results are required before the overlay is
// actually cleared.  This prevents a single bad frame from wiping legible text.
const _kEmptyFramesToClear = 5;

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

  // ── OCR ───────────────────────────────────────────────────────────────────
  // Single Latin recogniser for the live stream; Devanagari runs only when
  // Latin yields nothing, avoiding two heavy ML calls per frame.
  final TextRecognizer _recognizer =
      TextRecognizer(script: TextRecognitionScript.latin);
  final TextRecognizer _devRecognizer =
      TextRecognizer(script: TextRecognitionScript.devanagiri);

  // Guards: at most one OCR future in-flight at a time.
  bool _ocrRunning = false;
  int  _lastOcrMs  = 0;

  // ── Overlay state — written only from the main isolate via setState ────────
  List<TextBlock> _textBlocks = [];
  Size  _imageSize      = Size.zero;
  int   _sensorRotation = 0;

  // FIX: Track consecutive empty frames so we don't wipe the overlay on a
  // single blurry / transitional frame.
  int _emptyFrameCount = 0;

  // ── UI controls ───────────────────────────────────────────────────────────
  bool   _useOpenDyslexic = true;
  double _fontSize        = 16.0;
  double _overlayOpacity  = 0.85;
  bool   _overlayVisible  = true;
  bool   _isFlashOn       = false;

  final _syllableService = SyllableService();

  // ── Syllable popup ────────────────────────────────────────────────────────
  String?       _tappedWord;
  List<String>? _tappedSyllables;
  Offset?       _tappedPosition;

  // ── Pending overlay update — batched to avoid redundant rebuilds ──────────
  // New blocks are stashed here; a single post-frame callback flushes them.
  List<TextBlock>? _pendingBlocks;
  Size?            _pendingImageSize;
  bool             _pendingScheduled = false;

  /// Helper: Rotate a coordinate rectangle from image space to screen space
  Rect _rotateRect(Rect box) {
    if (_sensorRotation == 0 || _sensorRotation == 180) {
      return box;
    }

    final double imgW = _imageSize.width;
    final double imgH = _imageSize.height;

    if (_sensorRotation == 90) {
      // 90° clockwise: (x, y) → (imgH - y, x)
      final newLeft = imgH - box.bottom;
      final newTop = box.left;
      final newRight = imgH - box.top;
      final newBottom = box.right;
      return Rect.fromLTRB(newLeft, newTop, newRight, newBottom);
    } else if (_sensorRotation == 270) {
      // 270° clockwise: (x, y) → (y, imgW - x)
      final newLeft = box.top;
      final newTop = imgW - box.right;
      final newRight = box.bottom;
      final newBottom = imgW - box.left;
      return Rect.fromLTRB(newLeft, newTop, newRight, newBottom);
    }

    return box;
  }

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
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_controller == null || !_controller!.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      _stopStream();
    } else if (state == AppLifecycleState.resumed) {
      _startStream();
    }
  }

  // ── Camera init ───────────────────────────────────────────────────────────

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras == null || _cameras!.isEmpty) {
        _showError('No camera found on this device.');
        return;
      }
      _sensorRotation = _cameras![0].sensorOrientation;

      _controller = CameraController(
        _cameras![0],
        // Low resolution → faster OCR, less flicker.
        ResolutionPreset.low,
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

  void _startStream() => _controller?.startImageStream(_onCameraImage);

  void _stopStream() {
    if (_controller?.value.isStreamingImages == true) {
      _controller?.stopImageStream();
    }
  }

  // ── Frame handler ─────────────────────────────────────────────────────────

  void _onCameraImage(CameraImage image) {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    if (_ocrRunning || nowMs - _lastOcrMs < _kThrottleMs) return;

    _ocrRunning = true;
    _lastOcrMs  = nowMs;

    _processFrame(image).catchError((_) {}).whenComplete(() {
      _ocrRunning = false;
    });
  }

  Future<void> _processFrame(CameraImage image) async {
    final inputImage = _buildInputImage(image);
    if (inputImage == null) return;

    final result = await _recognizer.processImage(inputImage);
    List<TextBlock> blocks = result.blocks;

    // Only fall back to Devanagari when Latin yields nothing.
    if (blocks.isEmpty || result.text.trim().isEmpty) {
      final devResult = await _devRecognizer.processImage(inputImage);
      if (devResult.text.isNotEmpty) blocks = devResult.blocks;
    }

    // FIX: Stability — only clear the overlay after _kEmptyFramesToClear
    // consecutive empty results.  This prevents a single blurry frame from
    // making the overlay vanish and reappear (flicker).
    if (blocks.isEmpty) {
      _emptyFrameCount++;
      if (_emptyFrameCount < _kEmptyFramesToClear) {
        // Keep the existing overlay; do not schedule a rebuild.
        return;
      }
      // Enough consecutive empty frames — now it is safe to clear.
    } else {
      _emptyFrameCount = 0;
    }

    _pendingBlocks    = blocks;
    _pendingImageSize = Size(image.width.toDouble(), image.height.toDouble());

    if (!_pendingScheduled) {
      _pendingScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          if (_pendingBlocks    != null) _textBlocks = _pendingBlocks!;
          if (_pendingImageSize != null) _imageSize  = _pendingImageSize!;
          _pendingBlocks    = null;
          _pendingImageSize = null;
          _pendingScheduled = false;
        });
      });
    }
  }
InputImage? _buildInputImage(CameraImage image) {
    final camera = _cameras?[0];
    if (camera == null) return null;

    final rotation = InputImageRotationValue.fromRawValue(camera.sensorOrientation);
    if (rotation == null) return null;

    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null) return null;

    // FIX: Concatenate all planes so NV21 on Android receives both Y + UV data
    final WriteBuffer allBytes = WriteBuffer();
    for (final Plane plane in image.planes) {
      allBytes.putUint8List(plane.bytes);
    }
    final bytes = allBytes.done().buffer.asUint8List();

    return InputImage.fromBytes(
      bytes: bytes,
      metadata: InputImageMetadata(
        size:        Size(image.width.toDouble(), image.height.toDouble()),
        rotation:    rotation,
        format:      format,
        bytesPerRow: image.planes.first.bytesPerRow,
      ),
    );
  }


  // ── Flash ──────────────────────────────────────────────────────────────────

  Future<void> _toggleFlash() async {
    if (_controller == null) return;
    setState(() => _isFlashOn = !_isFlashOn);
    await _controller!
        .setFlashMode(_isFlashOn ? FlashMode.torch : FlashMode.off);
  }

  // ── Syllable popup ─────────────────────────────────────────────────────────

  void _onLongPress(LongPressStartDetails details) {
    if (_textBlocks.isEmpty || _imageSize == Size.zero) return;

    final screenSize = MediaQuery.of(context).size;
    final touchPos   = details.localPosition;

    final bool   rotated = _sensorRotation == 90 || _sensorRotation == 270;
    final double imageW  = rotated ? _imageSize.height : _imageSize.width;
    final double imageH  = rotated ? _imageSize.width  : _imageSize.height;
    final double scaleX  = screenSize.width  / imageW;
    final double scaleY  = screenSize.height / imageH;

    for (final block in _textBlocks) {
      for (final line in block.lines) {
        for (final element in line.elements) {
          final box = element.boundingBox;
          // Apply rotation transformation to bounding box
          final rotatedBox = _rotateRect(box);
          final scaled = Rect.fromLTRB(
            rotatedBox.left  * scaleX, rotatedBox.top    * scaleY,
            rotatedBox.right * scaleX, rotatedBox.bottom * scaleY,
          );
          if (scaled.contains(touchPos)) {
            final word = element.text.replaceAll(RegExp(r'[^\w]'), '');
            if (word.length > 2) {
              final syllables = _syllableService.breakIntoSyllables(word);
              setState(() {
                _tappedWord      = word;
                _tappedSyllables = syllables;
                _tappedPosition  = details.globalPosition;
              });
              Future.delayed(const Duration(seconds: 3), () {
                if (mounted) {
                  setState(() {
                    _tappedWord = null;
                    _tappedSyllables = null;
                    _tappedPosition  = null;
                  });
                }
              });
            }
            return;
          }
        }
      }
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopStream();
    _controller?.dispose();
    _recognizer.close();
    _devRecognizer.close();
    super.dispose();
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Camera preview
          if (_cameraReady && _controller != null)
            GestureDetector(
              onLongPressStart: _onLongPress,
              child: CameraPreview(_controller!),
            )
          else
            const Center(child: CircularProgressIndicator(color: _kAccent)),

          // AR overlay
          if (_cameraReady && _overlayVisible &&
              _textBlocks.isNotEmpty && _imageSize != Size.zero)
            Positioned.fill(
              child: CustomPaint(
                painter: _LiveOverlayPainter(
                  textBlocks:    _textBlocks,
                  imageSize:     _imageSize,
                  useOpenDyslexic: _useOpenDyslexic,
                  fontSize:      _fontSize,
                  opacity:       _overlayOpacity,
                  sensorRotation: _sensorRotation,
                ),
              ),
            ),

          // Syllable popup
          if (_tappedWord != null && _tappedSyllables != null)
            _SyllablePopup(
              word:      _tappedWord!,
              syllables: _tappedSyllables!,
              position:  _tappedPosition ?? Offset.zero,
              onDismiss: () => setState(() {
                _tappedWord = null; _tappedSyllables = null; _tappedPosition = null;
              }),
            ),

          _buildTopBar(context),
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: _buildBottomControls(),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
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
                              fontWeight: FontWeight.bold, fontFamily: 'OpenDyslexic')),
                    ],
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(_isFlashOn ? Icons.flash_on : Icons.flash_off,
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
              _textBlocks.isEmpty
                  ? 'Point at text to begin'
                  : '${_textBlocks.fold<int>(0, (s, b) => s + b.lines.fold(0, (s2, l) => s2 + l.elements.length))} words detected',
              style: TextStyle(color: Colors.white.withOpacity(0.8),
                  fontSize: 12, fontFamily: 'OpenDyslexic'),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.touch_app, color: Colors.white54, size: 14),
                const SizedBox(width: 4),
                Text('Long-press a word for syllable breakdown',
                    style: TextStyle(color: Colors.white.withOpacity(0.6),
                        fontSize: 11, fontFamily: 'OpenDyslexic')),
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
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold,
                      fontFamily: 'OpenDyslexic',
                      color: Theme.of(ctx).colorScheme.onSurface)),
              const SizedBox(height: 16),
              SwitchListTile(
                title: Text('OpenDyslexic Font',
                    style: TextStyle(fontFamily: 'OpenDyslexic',
                        color: Theme.of(ctx).colorScheme.onSurface)),
                value: _useOpenDyslexic,
                activeColor: _kAccent,
                onChanged: (v) {
                  setModal(() => _useOpenDyslexic = v);
                  setState(() => _useOpenDyslexic = v);
                },
              ),
              _buildSlider(ctx, setModal, 'Font Size', _fontSize, 12, 36,
                  (v) { setModal(() => _fontSize = v); setState(() => _fontSize = v); }),
              _buildSlider(ctx, setModal, 'Overlay Opacity', _overlayOpacity, 0.5, 1.0,
                  (v) { setModal(() => _overlayOpacity = v); setState(() => _overlayOpacity = v); }),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSlider(BuildContext ctx, StateSetter setModal,
      String label, double value, double min, double max, ValueChanged<double> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(fontFamily: 'OpenDyslexic',
                color: Theme.of(ctx).colorScheme.onSurface)),
            Text(value.toStringAsFixed(1),
                style: const TextStyle(fontFamily: 'OpenDyslexic',
                    color: _kPrimary, fontWeight: FontWeight.bold)),
          ],
        ),
        Slider(value: value, min: min, max: max, activeColor: _kAccent, onChanged: onChanged),
      ],
    );
  }
}

// ── Painter ───────────────────────────────────────────────────────────────────

class _LiveOverlayPainter extends CustomPainter {
  final List<TextBlock> textBlocks;
  final Size   imageSize;
  final bool   useOpenDyslexic;
  final double fontSize;
  final double opacity;
  final int    sensorRotation;

  const _LiveOverlayPainter({
    required this.textBlocks,
    required this.imageSize,
    required this.useOpenDyslexic,
    required this.fontSize,
    required this.opacity,
    required this.sensorRotation,
  });

  /// Transforms a coordinate from image space to rotated screen space
  Rect _rotateRect(Rect box) {
    if (sensorRotation == 0 || sensorRotation == 180) {
      return box;
    }

    final double imgW = imageSize.width;
    final double imgH = imageSize.height;

    if (sensorRotation == 90) {
      // 90° clockwise: (x, y) → (imgH - y, x)
      final newLeft = imgH - box.bottom;
      final newTop = box.left;
      final newRight = imgH - box.top;
      final newBottom = box.right;
      return Rect.fromLTRB(newLeft, newTop, newRight, newBottom);
    } else if (sensorRotation == 270) {
      // 270° clockwise: (x, y) → (y, imgW - x)
      final newLeft = box.top;
      final newTop = imgW - box.right;
      final newRight = box.bottom;
      final newBottom = imgW - box.left;
      return Rect.fromLTRB(newLeft, newTop, newRight, newBottom);
    }

    return box;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (imageSize == Size.zero) return;

    final bool   rotated = sensorRotation == 90 || sensorRotation == 270;
    final double imageW  = rotated ? imageSize.height : imageSize.width;
    final double imageH  = rotated ? imageSize.width  : imageSize.height;
    final double scaleX  = size.width  / imageW;
    final double scaleY  = size.height / imageH;

    final bgPaint = Paint()
      ..color = const Color(0xFFEEEEEE).withOpacity(opacity * 0.9)
      ..style = PaintingStyle.fill;

    for (final block in textBlocks) {
      for (final line in block.lines) {
        final box = line.boundingBox;
        // Apply rotation transformation to bounding box
        final rotatedBox = _rotateRect(box);
        final rect = Rect.fromLTRB(
          rotatedBox.left  * scaleX, rotatedBox.top    * scaleY,
          rotatedBox.right * scaleX, rotatedBox.bottom * scaleY,
        );
        final lineH = rect.height;
        final vPad  = useOpenDyslexic ? lineH * 0.22 : 3.0;

        // Background pill
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect.inflate(vPad), const Radius.circular(4)),
          bgPaint,
        );

        if (line.elements.isNotEmpty) {
          double x = rect.left + 2;
          for (final element in line.elements) {
            final wBox   = element.boundingBox;
            // Apply rotation transformation to get correct dimensions
            final rotatedWBox = _rotateRect(Rect.fromLTRB(
              wBox.left, wBox.top, wBox.right, wBox.bottom,
            ));
            final wH     = rotatedWBox.height * scaleY;
            final target = fontSize.clamp(8.0, wH.clamp(8.0, fontSize + 4));

            final tp = TextPainter(
              text: TextSpan(
                text: element.text,
                style: TextStyle(
                  color:         Colors.black87,
                  fontSize:      target,
                  fontFamily:    useOpenDyslexic ? 'OpenDyslexic' : null,
                  fontWeight:    FontWeight.w500,
                  height:        1.0,
                  letterSpacing: useOpenDyslexic ? 0.5 : 0,
                ),
              ),
              textDirection: TextDirection.ltr,
              maxLines: 1,
            )..layout();

            final bgTop = rect.top - vPad;
            final bgH   = lineH + vPad * 2;
            tp.paint(canvas, Offset(x, bgTop + (bgH - tp.height) / 2));
            x += tp.width + (useOpenDyslexic ? 6.0 : 4.0);
          }
        } else {
          final tp = TextPainter(
            text: TextSpan(
              text: line.text,
              style: TextStyle(
                color:      Colors.black87,
                fontSize:   lineH.clamp(8.0, fontSize),
                fontFamily: useOpenDyslexic ? 'OpenDyslexic' : null,
                fontWeight: FontWeight.w500,
                height:     1.0,
              ),
            ),
            textDirection: TextDirection.ltr,
            maxLines: 1,
          )..layout();
          final bgTop = rect.top - 3;
          final bgH   = lineH + 6;
          tp.paint(canvas, Offset(rect.left + 2, bgTop + (bgH - tp.height) / 2));
        }
      }
    }
  }

  @override
  bool shouldRepaint(_LiveOverlayPainter old) =>
      old.textBlocks    != textBlocks    ||
      old.imageSize     != imageSize     ||
      old.useOpenDyslexic != useOpenDyslexic ||
      old.fontSize      != fontSize      ||
      old.opacity       != opacity       ||
      old.sensorRotation != sensorRotation;
}

// ── Syllable popup ─────────────────────────────────────────────────────────────

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
    final s = MediaQuery.of(context).size;
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
