// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:lexilens/screens/document_preview_screen.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  bool _isFlashOn = false;
  bool _isCapturing = false;
  String _selectedMode = 'Docs';
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _isCameraInitialized = false;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();

      if (_cameras!.isEmpty) {
        throw Exception('No cameras found');
      }

      _cameraController = CameraController(
        _cameras![0],
        ResolutionPreset.high,
        enableAudio: false,
      );

      await _cameraController!.initialize();

      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
        });
      }
    } catch (e) {
      print('Camera initialization error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Camera error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  Future<void> _captureImage() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }
    setState(() {
      _isCapturing = true;
    });
    try {
      final XFile image = await _cameraController!.takePicture();
      if (mounted) {
        setState(() {
          _isCapturing = false;
        });
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DocumentPreviewScreen(
              imagePath: image.path,
              scanMode: _selectedMode,
            ),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isCapturing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to capture: $e')),
      );
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
      );
      if (image != null && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DocumentPreviewScreen(
              imagePath: image.path,
              scanMode: _selectedMode,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to pick image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _toggleFlash() async {
    if (_cameraController == null) return;
    setState(() {
      _isFlashOn = !_isFlashOn;
    });
    await _cameraController!.setFlashMode(
      _isFlashOn ? FlashMode.torch : FlashMode.off,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: (_isCameraInitialized && _cameraController != null)
                ? ClipRect(
                    child: OverflowBox(
                      alignment: Alignment.center,
                      child: FittedBox(
                        fit: BoxFit.cover,
                        child: SizedBox(
                          width: MediaQuery.of(context).size.width,
                          height: MediaQuery.of(context).size.width * _cameraController!.value.aspectRatio,
                          child: CameraPreview(_cameraController!),
                        ),
                      ),
                    ),
                  )
                : Container(
                    color: Colors.black,
                    child: const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFFB789DA),
                      ),
                    ),
                  ),
          ),
          Center(
            child: Container(
              width: MediaQuery.of(context).size.width * 0.85,
              height: MediaQuery.of(context).size.height * 0.5,
              decoration: BoxDecoration(
                border: Border.all(
                  color: const Color(0xFFB789DA).withOpacity(0.8),
                  width: 3,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Stack(
                children: [
                  Positioned(
                    top: -2,
                    left: -2,
                    child: _buildCornerIndicator(Alignment.topLeft),
                  ),
                  Positioned(
                    top: -2,
                    right: -2,
                    child: _buildCornerIndicator(Alignment.topRight),
                  ),
                  Positioned(
                    bottom: -2,
                    left: -2,
                    child: _buildCornerIndicator(Alignment.bottomLeft),
                  ),
                  Positioned(
                    bottom: -2,
                    right: -2,
                    child: _buildCornerIndicator(Alignment.bottomRight),
                  ),
                  // Instruction text
                  Positioned(
                    bottom: 16,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Position document within frame',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontFamily: 'OpenDyslexic',
                        ),
                      ),
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
                          Icons.arrow_back,
                          color: Colors.white,
                          size: 28,
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                      IconButton(
                        icon: Icon(
                          _isFlashOn ? Icons.flash_on : Icons.flash_off,
                          color: Colors.white,
                          size: 28,
                        ),
                        onPressed: _toggleFlash,
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.more_vert,
                          color: Colors.white,
                          size: 28,
                        ),
                        onPressed: () {},
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
                    Colors.black.withOpacity(0.8),
                    Colors.transparent,
                  ],
                ),
              ),
              padding: const EdgeInsets.only(
                bottom: 32, 
                top: 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildModeButton(
                          'Docs', () {
                          setState(
                            () => _selectedMode = 'Docs',
                          );
                        }),
                        const SizedBox(width: 12),
                        _buildModeButton(
                          'ID Card', () {
                          setState(
                            () => _selectedMode = 'ID Card',
                          );
                        }),
                        const SizedBox(width: 12),
                        _buildModeButton(
                          'Receipt', () {
                          setState(
                            () => _selectedMode = 'Receipt',
                          );
                        }),
                        const SizedBox(width: 12),
                        _buildModeButton(
                          'Text', () {
                          setState(
                            () => _selectedMode = 'Text',
                          );
                        }),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildActionButton(
                          icon: Icons.photo_library,
                          onTap: _pickFromGallery,
                        ),
                        GestureDetector(
                          onTap: _isCapturing ? null : _captureImage,
                          child: Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white,
                                width: 4,
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(4),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: _isCapturing
                                      ? Colors.red
                                      : const Color(0xFFB789DA),
                                  shape: BoxShape.circle,
                                ),
                                child: _isCapturing
                                    ? const Center(
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.camera_alt,
                                        color: Colors.white,
                                        size: 32,
                                      ),
                              ),
                            ),
                          ),
                        ),
                        _buildActionButton(
                          icon: Icons.settings,
                          onTap: () {},
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCornerIndicator(Alignment alignment) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        border: Border(
          top: alignment == Alignment.topLeft || alignment == Alignment.topRight
              ? BorderSide(
                  color: const Color(0xFFB789DA).withOpacity(0.8),
                  width: 4,
                )
              : BorderSide.none,
          bottom: alignment == Alignment.bottomLeft ||
                  alignment == Alignment.bottomRight
              ? BorderSide(
                  color: const Color(0xFFB789DA).withOpacity(0.8),
                  width: 4,
                )
              : BorderSide.none,
          left: alignment == Alignment.topLeft ||
                  alignment == Alignment.bottomLeft
              ? BorderSide(
                  color: const Color(0xFFB789DA).withOpacity(0.8),
                  width: 4,
                )
              : BorderSide.none,
          right: alignment == Alignment.topRight ||
                  alignment == Alignment.bottomRight
              ? BorderSide(
                  color: const Color(0xFFB789DA).withOpacity(0.8),
                  width: 4,
                )
              : BorderSide.none,
        ),
      ),
    );
  }

  Widget _buildModeButton(String label, VoidCallback onTap) {
    final isSelected = _selectedMode == label;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 10,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFB789DA)
              : Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? const Color(0xFFB789DA)
                : Colors.white.withOpacity(0.5),
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
            fontFamily: 'OpenDyslexic',
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white.withOpacity(0.5),
          width: 2,
        ),
      ),
      child: IconButton(
        icon: Icon(
          icon,
          color: Colors.white,
          size: 24,
        ),
        onPressed: onTap,
      ),
    );
  }
}