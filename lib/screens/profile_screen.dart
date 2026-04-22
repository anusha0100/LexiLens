import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:convert';
import 'package:lexilens/services/auth_service.dart';
import 'package:lexilens/services/mongodb_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _authService = AuthService();
  final _mongoService = MongoDBService();
  final _imagePicker = ImagePicker();

  File? _profileImage;         // freshly picked from device
  String? _profileImageBase64; // persisted in MongoDB / freshly encoded

  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  // ── Load profile ─────────────────────────────────────────────────────────────
  Future<void> _loadUserProfile() async {
    setState(() => _isLoading = true);

    try {
      final userId = _authService.getUserId();

      if (userId == null) {
        _fillFromFirebaseAuth();
        return;
      }

      final settings = await _mongoService.getAllSettings(userId);

      // Name: saved value → derived from Firebase email
      final savedName = settings['user_name']?.toString() ?? '';
      _nameController.text = savedName.isNotEmpty
          ? savedName
          : _authService.getUserDisplayName();

      // Email: saved value → Firebase Auth email
      final savedEmail = settings['user_email']?.toString() ?? '';
      _emailController.text = savedEmail.isNotEmpty
          ? savedEmail
          : (_authService.getUserEmail() ?? '');

      // Phone
      _phoneController.text = settings['user_phone']?.toString() ?? '';

      // Profile photo (base64)
      final savedPhoto = settings['profile_photo']?.toString() ?? '';
      if (savedPhoto.isNotEmpty) {
        _profileImageBase64 = savedPhoto;
      }

      // If MongoDB had no name/email (first open after signup), backfill now.
      if (savedName.isEmpty || savedEmail.isEmpty) {
        _backfillMissingProfileData(userId);
      }
    } catch (e) {
      debugPrint('Error loading profile: $e');
      _fillFromFirebaseAuth();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _fillFromFirebaseAuth() {
    _nameController.text = _authService.getUserDisplayName();
    _emailController.text = _authService.getUserEmail() ?? '';
    _phoneController.text = '';
    if (mounted) setState(() => _isLoading = false);
  }

  void _backfillMissingProfileData(String userId) {
    final name = _nameController.text;
    final email = _emailController.text;
    if (name.isNotEmpty) {
      _mongoService.updateSetting(userId, 'user_name', name);
    }
    if (email.isNotEmpty) {
      _mongoService.updateSetting(userId, 'user_email', email);
    }
  }

  // ── Image picking ─────────────────────────────────────────────────────────────
  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 75,
      );

      if (image != null) {
        final file = File(image.path);
        final bytes = await file.readAsBytes();
        setState(() {
          _profileImage = file;
          _profileImageBase64 = base64Encode(bytes);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking image: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showImageSourceDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Choose Image Source',
            style: TextStyle(fontFamily: 'OpenDyslexic')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Color(0xFFB789DA)),
              title: const Text('Camera',
                  style: TextStyle(fontFamily: 'OpenDyslexic')),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library,
                  color: Color(0xFFB789DA)),
              title: const Text('Gallery',
                  style: TextStyle(fontFamily: 'OpenDyslexic')),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  // ── Avatar ────────────────────────────────────────────────────────────────────
  Widget _buildAvatarContent() {
    if (_profileImage != null) {
      return ClipOval(
        child: Image.file(_profileImage!,
            fit: BoxFit.cover, width: 120, height: 120),
      );
    }

    if (_profileImageBase64 != null && _profileImageBase64!.isNotEmpty) {
      try {
        final bytes = base64Decode(_profileImageBase64!);
        return ClipOval(
          child: Image.memory(bytes,
              fit: BoxFit.cover, width: 120, height: 120),
        );
      } catch (_) {}
    }

    final initial = _nameController.text.trim().isNotEmpty
        ? _nameController.text.trim()[0].toUpperCase()
        : 'U';

    return Center(
      child: Text(
        initial,
        style: const TextStyle(
          fontSize: 48,
          fontWeight: FontWeight.bold,
          color: Color(0xFFB789DA),
          fontFamily: 'OpenDyslexic',
        ),
      ),
    );
  }

  // ── Save ──────────────────────────────────────────────────────────────────────
  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final userId = _authService.getUserId();
      if (userId == null) throw Exception('User not logged in');

      await _mongoService.updateSetting(
          userId, 'user_name', _nameController.text.trim());
      await _mongoService.updateSetting(
          userId, 'user_email', _emailController.text.trim());
      await _mongoService.updateSetting(
          userId, 'user_phone', _phoneController.text.trim());

      if (_profileImageBase64 != null) {
        await _mongoService.updateSetting(
            userId, 'profile_photo', _profileImageBase64);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully!'),
            backgroundColor: Color(0xFFB789DA),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving profile: $e'),
              backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFFB789DA),
        title: const Text('Edit Profile',
            style: TextStyle(fontFamily: 'OpenDyslexic', color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFB789DA)))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    // Avatar
                    Stack(
                      children: [
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFFE8D5F0),
                            border: Border.all(
                                color: const Color(0xFFB789DA), width: 3),
                          ),
                          child: _buildAvatarContent(),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: GestureDetector(
                            onTap: _showImageSourceDialog,
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: const Color(0xFFB789DA),
                                shape: BoxShape.circle,
                                border:
                                    Border.all(color: Colors.white, width: 2),
                              ),
                              child: const Icon(Icons.camera_alt,
                                  color: Colors.white, size: 18),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tap camera icon to change photo',
                      style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[500],
                          fontFamily: 'OpenDyslexic'),
                    ),
                    const SizedBox(height: 32),

                    // Name
                    TextFormField(
                      controller: _nameController,
                      textCapitalization: TextCapitalization.words,
                      style: const TextStyle(fontFamily: 'OpenDyslexic'),
                      decoration: _inputDecoration('Full Name', Icons.person),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Please enter your name'
                          : null,
                    ),
                    const SizedBox(height: 20),

                    // Email
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      style: const TextStyle(fontFamily: 'OpenDyslexic'),
                      decoration: _inputDecoration('Email', Icons.email),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Please enter your email';
                        }
                        if (!v.contains('@')) {
                          return 'Please enter a valid email';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),

                    // Phone
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      style: const TextStyle(fontFamily: 'OpenDyslexic'),
                      decoration:
                          _inputDecoration('Phone Number', Icons.phone),
                    ),
                    const SizedBox(height: 40),

                    // Save
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _saveProfile,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFB789DA),
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: Colors.grey[300],
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2))
                            : const Text('Save Changes',
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    fontFamily: 'OpenDyslexic')),
                      ),
                    ),

                    // Danger Zone
                    const SizedBox(height: 32),
                    const Divider(),
                    const SizedBox(height: 16),
                    const Text('Danger Zone',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                            fontFamily: 'OpenDyslexic')),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: OutlinedButton.icon(
                        onPressed: _showDeleteAccountDialog,
                        icon: const Icon(Icons.delete_forever,
                            color: Colors.red),
                        label: const Text('Delete Account',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.red,
                                fontFamily: 'OpenDyslexic')),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.red, width: 2),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Permanently deletes your account and all associated data. This cannot be undone.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[500],
                          fontFamily: 'OpenDyslexic'),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) =>
      InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontFamily: 'OpenDyslexic'),
        prefixIcon: Icon(icon, color: const Color(0xFFB789DA)),
        border:
            OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: Color(0xFFB789DA), width: 2),
        ),
      );

  Future<void> _showDeleteAccountDialog() async {
    final passwordController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (ctx, setDlg) {
          bool obscure = true;
          return AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            title: const Text('Delete Account',
                style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'OpenDyslexic')),
            content: StatefulBuilder(
              builder: (ctx2, setField) => Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'This will permanently delete your account and all '
                    'saved documents. This action cannot be undone.',
                    style: TextStyle(fontFamily: 'OpenDyslexic'),
                  ),
                  const SizedBox(height: 16),
                  const Text('Enter your password to confirm:',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontFamily: 'OpenDyslexic')),
                  const SizedBox(height: 8),
                  TextField(
                    controller: passwordController,
                    obscureText: obscure,
                    decoration: InputDecoration(
                      hintText: 'Password',
                      hintStyle:
                          const TextStyle(fontFamily: 'OpenDyslexic'),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8)),
                      suffixIcon: IconButton(
                        icon: Icon(obscure
                            ? Icons.visibility_off
                            : Icons.visibility),
                        onPressed: () =>
                            setField(() => obscure = !obscure),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel',
                    style: TextStyle(
                        color: Colors.grey,
                        fontFamily: 'OpenDyslexic')),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                style:
                    ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Delete',
                    style: TextStyle(
                        color: Colors.white,
                        fontFamily: 'OpenDyslexic')),
              ),
            ],
          );
        },
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      final result = await _authService.deleteAccount(
          password: passwordController.text);
      passwordController.dispose();
      if (!mounted) return;
      if (result['success'] == true) {
        Navigator.of(context)
            .pushNamedAndRemoveUntil('/login', (route) => false);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(result['message'] ?? 'Deletion failed',
              style: const TextStyle(fontFamily: 'OpenDyslexic')),
          backgroundColor: Colors.red,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e',
              style: const TextStyle(fontFamily: 'OpenDyslexic')),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }
}