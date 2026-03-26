import 'package:flutter/material.dart';
import 'dart:io';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image/image.dart' as img;
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:lexilens/screens/text_overlay_screen.dart';
import 'package:lexilens/screens/filter_screen.dart';
import 'package:lexilens/services/ocr_service.dart';
import 'package:lexilens/bloc/app_bloc.dart';
import 'package:path_provider/path_provider.dart';

class DocumentPreviewScreen extends StatefulWidget {
  final String imagePath;
  final String scanMode;
  final bool useOpenDyslexic;
  final double fontSize;

  const DocumentPreviewScreen({
    super.key,
    required this.imagePath,
    required this.scanMode,
    this.useOpenDyslexic = true,
    this.fontSize = 14.0,
  });

  @override
  State<DocumentPreviewScreen> createState() => _DocumentPreviewScreenState();
}

class _DocumentPreviewScreenState extends State<DocumentPreviewScreen> {
  bool _isProcessing = false;
  final List<Offset> _cornerPoints = [];
  final _ocrService = OCRService();
  final GlobalKey _imageKey = GlobalKey();
  Size? _imageSize;
  String _currentImagePath = '';
  int _rotationAngle = 0;
  double _brightness = 0.0;
  double _contrast = 1.0;
  img.Image? _originalImage;
  img.Image? _processedImage;

  @override
  void initState() {
    super.initState();
    _currentImagePath = widget.imagePath;
    _loadImage();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeCornerPoints();
    });
  }

  Future<void> _loadImage() async {
    try {
      final bytes = await File(_currentImagePath).readAsBytes();
      final image = img.decodeImage(bytes);
      if (image != null) {
        setState(() {
          _originalImage = image.clone();
          _processedImage = image.clone();
        });
      }
    } catch (e) {
      print('Error loading image: $e');
    }
  }

  void _initializeCornerPoints() {
    final RenderBox? renderBox = _imageKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox != null) {
      final size = renderBox.size;
      setState(() {
        _imageSize = size;
        _cornerPoints.clear();
        _cornerPoints.addAll([
          Offset(size.width * 0.1, size.height * 0.15),
          Offset(size.width * 0.9, size.height * 0.15),
          Offset(size.width * 0.9, size.height * 0.85),
          Offset(size.width * 0.1, size.height * 0.85),
        ]);
      });
    }
  }

  Future<void> _rotateImage() async {
    if (_originalImage == null) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      _rotationAngle = (_rotationAngle + 90) % 360;
      
      img.Image rotated = _originalImage!.clone();
      
      switch (_rotationAngle) {
        case 90:
          rotated = img.copyRotate(rotated, angle: 90);
          break;
        case 180:
          rotated = img.copyRotate(rotated, angle: 180);
          break;
        case 270:
          rotated = img.copyRotate(rotated, angle: 270);
          break;
      }

      if (_brightness != 0.0 || _contrast != 1.0) {
        rotated = _applyColorAdjustments(rotated);
      }

      final tempDir = await getTemporaryDirectory();
      final tempPath = '${tempDir.path}/rotated_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final File tempFile = File(tempPath);
      await tempFile.writeAsBytes(img.encodeJpg(rotated, quality: 95));

      setState(() {
        _processedImage = rotated;
        _currentImagePath = tempPath;
        _isProcessing = false;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _initializeCornerPoints();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Image rotated'),
            duration: Duration(seconds: 1),
            backgroundColor: Color(0xFFB789DA),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isProcessing = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Rotation error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _cropImage() async {
    if (_processedImage == null || _cornerPoints.length != 4 || _imageSize == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to crop: Invalid selection'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      final scaleX = _processedImage!.width / _imageSize!.width;
      final scaleY = _processedImage!.height / _imageSize!.height;

      final imageCorners = _cornerPoints.map((point) {
        return Offset(
          (point.dx * scaleX).clamp(0.0, _processedImage!.width.toDouble()),
          (point.dy * scaleY).clamp(0.0, _processedImage!.height.toDouble()),
        );
      }).toList();

      final minX = imageCorners.map((p) => p.dx).reduce((a, b) => a < b ? a : b).toInt();
      final maxX = imageCorners.map((p) => p.dx).reduce((a, b) => a > b ? a : b).toInt();
      final minY = imageCorners.map((p) => p.dy).reduce((a, b) => a < b ? a : b).toInt();
      final maxY = imageCorners.map((p) => p.dy).reduce((a, b) => a > b ? a : b).toInt();

      final width = (maxX - minX).clamp(1, _processedImage!.width);
      final height = (maxY - minY).clamp(1, _processedImage!.height);

      final cropped = img.copyCrop(
        _processedImage!,
        x: minX,
        y: minY,
        width: width,
        height: height,
      );

      final tempDir = await getTemporaryDirectory();
      final tempPath = '${tempDir.path}/cropped_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final File tempFile = File(tempPath);
      await tempFile.writeAsBytes(img.encodeJpg(cropped, quality: 95));

      setState(() {
        _processedImage = cropped;
        _currentImagePath = tempPath;
        _isProcessing = false;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _initializeCornerPoints();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Image cropped'),
            duration: Duration(seconds: 1),
            backgroundColor: Color(0xFFB789DA),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isProcessing = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Crop error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showAdjustDialog() {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text(
                'Adjust Image',
                style: TextStyle(
                  fontFamily: 'OpenDyslexic',
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Brightness',
                    style: TextStyle(
                      fontFamily: 'OpenDyslexic',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Row(
                    children: [
                      const Icon(Icons.brightness_low, size: 20),
                      Expanded(
                        child: Slider(
                          value: _brightness,
                          min: -50,
                          max: 50,
                          divisions: 20,
                          activeColor: const Color(0xFFB789DA),
                          onChanged: (value) {
                            setDialogState(() {
                              _brightness = value;
                            });
                          },
                        ),
                      ),
                      const Icon(Icons.brightness_high, size: 20),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Contrast',
                    style: TextStyle(
                      fontFamily: 'OpenDyslexic',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Row(
                    children: [
                      const Icon(Icons.contrast, size: 20),
                      Expanded(
                        child: Slider(
                          value: _contrast,
                          min: 0.5,
                          max: 2.0,
                          divisions: 30,
                          activeColor: const Color(0xFFB789DA),
                          onChanged: (value) {
                            setDialogState(() {
                              _contrast = value;
                            });
                          },
                        ),
                      ),
                      const Icon(Icons.contrast, size: 24),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Brightness: ${_brightness.toInt()} | Contrast: ${_contrast.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                      fontFamily: 'OpenDyslexic',
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    setDialogState(() {
                      _brightness = 0.0;
                      _contrast = 1.0;
                    });
                  },
                  child: const Text(
                    'Reset',
                    style: TextStyle(
                      color: Colors.grey,
                      fontFamily: 'OpenDyslexic',
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(
                      color: Colors.grey,
                      fontFamily: 'OpenDyslexic',
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                    _applyAdjustments();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFB789DA),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text(
                    'Apply',
                    style: TextStyle(
                      fontFamily: 'OpenDyslexic',
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  img.Image _applyColorAdjustments(img.Image image) {
    if (_brightness != 0.0) {
      for (var pixel in image) {
        final r = (pixel.r + _brightness).clamp(0, 255).toInt();
        final g = (pixel.g + _brightness).clamp(0, 255).toInt();
        final b = (pixel.b + _brightness).clamp(0, 255).toInt();
        pixel
          ..r = r
          ..g = g
          ..b = b;
      }
    }
    
    if (_contrast != 1.0) {
      final factor = (259 * (_contrast * 100 + 255)) / (255 * (259 - _contrast * 100));
      for (var pixel in image) {
        final r = (factor * (pixel.r - 128) + 128).clamp(0, 255).toInt();
        final g = (factor * (pixel.g - 128) + 128).clamp(0, 255).toInt();
        final b = (factor * (pixel.b - 128) + 128).clamp(0, 255).toInt();
        pixel
          ..r = r
          ..g = g
          ..b = b;
      }
    }
    
    return image;
  }

  Future<void> _applyAdjustments() async {
    if (_originalImage == null) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      img.Image adjusted = _originalImage!.clone();

      switch (_rotationAngle) {
        case 90:
          adjusted = img.copyRotate(adjusted, angle: 90);
          break;
        case 180:
          adjusted = img.copyRotate(adjusted, angle: 180);
          break;
        case 270:
          adjusted = img.copyRotate(adjusted, angle: 270);
          break;
      }

      adjusted = _applyColorAdjustments(adjusted);

      final tempDir = await getTemporaryDirectory();
      final tempPath = '${tempDir.path}/adjusted_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final File tempFile = File(tempPath);
      await tempFile.writeAsBytes(img.encodeJpg(adjusted, quality: 95));

      setState(() {
        _processedImage = adjusted;
        _currentImagePath = tempPath;
        _isProcessing = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Adjustments applied'),
            duration: Duration(seconds: 1),
            backgroundColor: Color(0xFFB789DA),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isProcessing = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Adjustment error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _openFilterScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: context.read<AppBloc>(),
          child: const FilterScreen(),
        ),
      ),
    );
  }

  Future<void> _processDocument() async {
    setState(() {
      _isProcessing = true;
    });
    
    try {
      final ocrResult = await _ocrService.extractTextWithLanguage(_currentImagePath);

      // Copy the processed image to the app's permanent documents directory so
      // it survives this screen being disposed by Navigator.pushReplacement.
      final appDir = await getApplicationDocumentsDirectory();
      final permanentPath =
          '${appDir.path}/scan_${DateTime.now().millisecondsSinceEpoch}.jpg';
      await File(_currentImagePath).copy(permanentPath);

      if (mounted) {
        setState(() {
          _isProcessing = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Detected: ${ocrResult['language']} (${ocrResult['script']} script)',
              style: const TextStyle(fontFamily: 'OpenDyslexic'),
            ),
            backgroundColor: const Color(0xFFB789DA),
            duration: const Duration(seconds: 2),
          ),
        );

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => BlocProvider.value(
              value: context.read<AppBloc>(),
              child: TextOverlayScreen(
                imagePath: permanentPath,
                textBlocks: ocrResult['blocks'] as List<TextBlock>,
                useOpenDyslexic: ocrResult['canUseOpenDyslexic'] as bool? ?? widget.useOpenDyslexic,
                fontSize: widget.fontSize,
                detectedLanguage: ocrResult['language'] as String,
                detectedScript: ocrResult['script'] as String,
              ),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('OCR Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          if (_currentImagePath.isNotEmpty)
            Center(
              child: Stack(
                children: [
                  Image.file(
                    File(_currentImagePath),
                    key: _imageKey,
                    fit: BoxFit.contain,
                  ),
                  if (_cornerPoints.length == 4 && _imageSize != null)
                    Positioned.fill(
                      child: CustomPaint(
                        painter: DocumentBorderPainter(
                          _cornerPoints,
                          _imageSize!,
                        ),
                      ),
                    ),
                ],
              ),
            )
          else
            Container(
              color: Colors.grey[900],
              child: const Center(
                child: Text(
                  'No image',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          
          if (_cornerPoints.length == 4 && _imageSize != null)
            ..._cornerPoints.asMap().entries.map((entry) {
              final index = entry.key;
              final point = entry.value;
              final screenSize = MediaQuery.of(context).size;
              final xOffset = (screenSize.width - _imageSize!.width) / 2;
              final yOffset = (screenSize.height - _imageSize!.height) / 2;
              return Positioned(
                left: xOffset + point.dx - 15,
                top: yOffset + point.dy - 15,
                child: GestureDetector(
                  onPanUpdate: (details) {
                    setState(() {
                      double newDx = (_cornerPoints[index].dx + details.delta.dx)
                          .clamp(0.0, _imageSize!.width);
                      double newDy = (_cornerPoints[index].dy + details.delta.dy)
                          .clamp(0.0, _imageSize!.height);
                      _cornerPoints[index] = Offset(newDx, newDy);
                    });
                  },
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: const Color(0xFFB789DA),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.5),
                          blurRadius: 4,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          
          if (_isProcessing)
            Container(
              color: Colors.black54,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(
                      color: Color(0xFFB789DA),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Processing...',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontFamily: 'OpenDyslexic',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.7),
                    Colors.transparent,
                  ],
                ),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.close, 
                          color: Colors.white, 
                          size: 28,
                        ),
                        onPressed: _isProcessing ? null : () => Navigator.pop(context),
                      ),
                      Column(
                        children: [
                          Text(
                            widget.scanMode,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              fontFamily: 'OpenDyslexic',
                            ),
                          ),
                          if (widget.useOpenDyslexic)
                            Container(
                              margin: const EdgeInsets.only(top: 4),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFB789DA),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Text(
                                'OpenDyslexic',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontFamily: 'OpenDyslexic',
                                ),
                              ),
                            ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.refresh, 
                          color: Colors.white, 
                          size: 28,
                        ),
                        tooltip: 'Reset',
                        onPressed: _isProcessing ? null : () {
                          setState(() {
                            _currentImagePath = widget.imagePath;
                            _rotationAngle = 0;
                            _brightness = 0.0;
                            _contrast = 1.0;
                          });
                          _loadImage();
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            _initializeCornerPoints();
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withOpacity(0.9),
                    Colors.transparent,
                  ],
                ),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildActionButton(
                            icon: Icons.crop_rotate,
                            label: 'Rotate',
                            onTap: _isProcessing ? () {} : _rotateImage,
                            isEnabled: !_isProcessing,
                          ),
                          _buildActionButton(
                            icon: Icons.crop,
                            label: 'Crop',
                            onTap: _isProcessing ? () {} : _cropImage,
                            isEnabled: !_isProcessing,
                          ),
                          _buildActionButton(
                            icon: Icons.filter,
                            label: 'Filter',
                            onTap: _isProcessing ? () {} : _openFilterScreen,
                            isEnabled: !_isProcessing,
                          ),
                          _buildActionButton(
                            icon: Icons.auto_fix_high,
                            label: 'Adjust',
                            onTap: _isProcessing ? () {} : _showAdjustDialog,
                            isEnabled: !_isProcessing,
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _isProcessing ? null : _processDocument,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFB789DA),
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: Colors.grey[700],
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _isProcessing
                              ? const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    ),
                                    SizedBox(width: 12),
                                    Text(
                                      'Processing...',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        fontFamily: 'OpenDyslexic',
                                      ),
                                    ),
                                  ],
                                )
                              : const Text(
                                  'Process Document',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    fontFamily: 'OpenDyslexic',
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: _isProcessing ? null : () => Navigator.pop(context),
                        child: const Text(
                          'Retake',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white,
                            fontFamily: 'OpenDyslexic',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isEnabled = true,
  }) {
    return InkWell(
      onTap: isEnabled ? onTap : null,
      child: Opacity(
        opacity: isEnabled ? 1.0 : 0.5,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: const Color(0xFFB789DA).withOpacity(0.3),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontFamily: 'OpenDyslexic',
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    if (_currentImagePath != widget.imagePath && File(_currentImagePath).existsSync()) {
      try {
        File(_currentImagePath).deleteSync();
      } catch (e) {
        print('Error deleting temp file: $e');
      }
    }
    super.dispose();
  }
}

class DocumentBorderPainter extends CustomPainter {
  final List<Offset> corners;
  final Size imageSize;

  DocumentBorderPainter(this.corners, this.imageSize);

  @override
  void paint(Canvas canvas, Size size) {
    if (corners.length != 4) return;

    final paint = Paint()
      ..color = const Color(0xFFB789DA)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    final fillPaint = Paint()
      ..color = const Color(0xFFB789DA).withOpacity(0.2)
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(corners[0].dx, corners[0].dy)
      ..lineTo(corners[1].dx, corners[1].dy)
      ..lineTo(corners[2].dx, corners[2].dy)
      ..lineTo(corners[3].dx, corners[3].dy)
      ..close();

    canvas.drawPath(path, fillPaint);
    canvas.drawPath(path, paint);
    
    final gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.3)
      ..strokeWidth = 1;

    for (int i = 1; i < 3; i++) {
      final y = corners[0].dy + (corners[3].dy - corners[0].dy) * i / 3;
      canvas.drawLine(
        Offset(corners[0].dx, y),
        Offset(corners[1].dx, y),
        gridPaint,
      );
    }

    for (int i = 1; i < 3; i++) {
      final x = corners[0].dx + (corners[1].dx - corners[0].dx) * i / 3;
      canvas.drawLine(
        Offset(x, corners[0].dy),
        Offset(x, corners[3].dy),
        gridPaint,
      );
    }
  }

  @override
  bool shouldRepaint(DocumentBorderPainter oldDelegate) {
    return oldDelegate.corners != corners;
  }
}
