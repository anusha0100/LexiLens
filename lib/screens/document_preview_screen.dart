// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'dart:io';
import 'package:lexilens/screens/text_overlay_screen.dart';
import 'package:lexilens/services/ocr_service.dart';

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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeCornerPoints();
    });
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

  Future<void> _processDocument() async {
    setState(() {
      _isProcessing = true;
    });
    try {
      final textBlocks = await _ocrService.extractTextBlocks(widget.imagePath);
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => TextOverlayScreen(
              imagePath: widget.imagePath,
              textBlocks: textBlocks,
              useOpenDyslexic: widget.useOpenDyslexic,
              fontSize: widget.fontSize,
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
          if (widget.imagePath.isNotEmpty)
            Center(
              child: Stack(
                children: [
                  Image.file(
                    File(widget.imagePath),
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
          // Top bar
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
                        onPressed: () => Navigator.pop(context),
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
                      const SizedBox(width: 48),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Bottom controls
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
                            onTap: () {},
                          ),
                          _buildActionButton(
                            icon: Icons.crop,
                            label: 'Crop',
                            onTap: () {},
                          ),
                          _buildActionButton(
                            icon: Icons.filter,
                            label: 'Filter',
                            onTap: () {},
                          ),
                          _buildActionButton(
                            icon: Icons.auto_fix_high,
                            label: 'Adjust',
                            onTap: () {},
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
                        onPressed: () => Navigator.pop(context),
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
  }) {
    return InkWell(
      onTap: onTap,
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
    );
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

    // Grid lines
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