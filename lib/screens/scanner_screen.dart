// ignore_for_file: deprecated_member_use, use_build_context_synchronously

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
  bool _textSelectionEnabled = false;
  bool _openDyslexicOverlay = false; 
  double _fontSize = 14.0; 

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
              useOpenDyslexic: _openDyslexicOverlay,
              fontSize: _fontSize,
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
              useOpenDyslexic: _openDyslexicOverlay,
              fontSize: _fontSize,
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

  void _toggleTextSelection() {
    setState(() {
      _textSelectionEnabled = !_textSelectionEnabled;
      if (_textSelectionEnabled) {
        _openDyslexicOverlay = true;
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _textSelectionEnabled 
              ? 'Text selection enabled with OpenDyslexic font' 
              : 'Text selection disabled'
        ),
        backgroundColor: const Color(0xFFB789DA),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showFontSizeDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text(
                'Adjust Font Size',
                style: TextStyle(
                  fontFamily: 'OpenDyslexic',
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Sample Text',
                    style: TextStyle(
                      fontSize: _fontSize,
                      fontFamily: 'OpenDyslexic',
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Size:',
                        style: TextStyle(fontFamily: 'OpenDyslexic'),
                      ),
                      Text(
                        _fontSize.toInt().toString(),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontFamily: 'OpenDyslexic',
                        ),
                      ),
                    ],
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '10',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey[600],
                          fontFamily: 'OpenDyslexic',
                        ),
                      ),
                      Text(
                        '24',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontFamily: 'OpenDyslexic',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
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
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Font size set to ${_fontSize.toInt()}'),
                        backgroundColor: const Color(0xFFB789DA),
                        duration: const Duration(seconds: 1),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFB789DA),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text(
                    'Apply',
                    style: TextStyle(fontFamily: 'OpenDyslexic'),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showMoreOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Scanner Options',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'OpenDyslexic',
                  ),
                ),
                const SizedBox(height: 20),
                _buildOptionTile(
                  icon: Icons.text_fields,
                  title: 'Text Selection',
                  subtitle: _textSelectionEnabled 
                      ? 'Enabled (OpenDyslexic)' 
                      : 'Disabled',
                  trailing: Switch(
                    value: _textSelectionEnabled,
                    activeColor: const Color(0xFFB789DA),
                    onChanged: (value) {
                      setState(() {
                        _textSelectionEnabled = value;
                        _openDyslexicOverlay = value;
                      });
                      Navigator.pop(context);
                      _toggleTextSelection();
                    },
                  ),
                ),
                _buildOptionTile(
                  icon: Icons.format_size,
                  title: 'Font Size',
                  subtitle: 'Current: ${_fontSize.toInt()}',
                  onTap: () {
                    Navigator.pop(context);
                    _showFontSizeDialog();
                  },
                ),
                _buildOptionTile(
                  icon: Icons.grid_on,
                  title: 'Grid Overlay',
                  subtitle: 'Show alignment grid',
                  onTap: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Grid overlay feature coming soon!'),
                        backgroundColor: Color(0xFFB789DA),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildOptionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
    Widget? trailing,
  }) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: const Color(0xFFE8D5F0),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          color: const Color(0xFFB789DA),
          size: 22,
        ),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          fontFamily: 'OpenDyslexic',
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 13,
          color: Colors.grey[600],
          fontFamily: 'OpenDyslexic',
        ),
      ),
      trailing: trailing ?? const Icon(Icons.chevron_right),
      onTap: onTap,
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
                  // Text selection indicator
                  if (_textSelectionEnabled && _openDyslexicOverlay)
                    Positioned(
                      top: 16,
                      left: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFB789DA).withOpacity(0.9),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.font_download,
                              color: Colors.white,
                              size: 14,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'OpenDyslexic',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'OpenDyslexic',
                              ),
                            ),
                          ],
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
                      Row(
                        children: [
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
                            onPressed: _showMoreOptions,
                          ),
                        ],
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
                          onTap: _showMoreOptions,
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