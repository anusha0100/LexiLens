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

  File? _profileImage;
  String? _profileImageBase64;

  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    setState(() => _isLoading = true);
    try {
      final userId = _authService.getUserId();
      if (userId == null) {
        _fillFromFirebaseAuth();
        return;
      }
      final settings = await _mongoService.getAllSettings(userId);

      final savedName = settings['user_name']?.toString() ?? '';
      _nameController.text = savedName.isNotEmpty ? savedName : _authService.getUserDisplayName();

      final savedEmail = settings['user_email']?.toString() ?? '';
      _emailController.text = savedEmail.isNotEmpty ? savedEmail : (_authService.getUserEmail() ?? '');

      _phoneController.text = settings['user_phone']?.toString() ?? '';

      final savedPhoto = settings['profile_photo']?.toString() ?? '';
      if (savedPhoto.isNotEmpty) {
        _profileImageBase64 = savedPhoto;
      }

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
    if (name.isNotEmpty) _mongoService.updateSetting(userId, 'user_name', name);
    if (email.isNotEmpty) _mongoService.updateSetting(userId, 'user_email', email);
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _imagePicker.pickImage(source: source, maxWidth: 512, maxHeight: 512, imageQuality: 75);
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not pick image: $e'), backgroundColor: Colors.red));
      }
    }
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 16),
              const Text('Change Photo', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'OpenDyslexic')),
              const SizedBox(height: 12),
              ListTile(
                leading: Container(width: 44, height: 44, decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFFB789DA).withOpacity(0.12)), child: const Icon(Icons.camera_alt_rounded, color: Color(0xFFB789DA))),
                title: const Text('Take a photo', style: TextStyle(fontFamily: 'OpenDyslexic')),
                onTap: () { Navigator.pop(context); _pickImage(ImageSource.camera); },
              ),
              ListTile(
                leading: Container(width: 44, height: 44, decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFFB789DA).withOpacity(0.12)), child: const Icon(Icons.photo_library_rounded, color: Color(0xFFB789DA))),
                title: const Text('Choose from gallery', style: TextStyle(fontFamily: 'OpenDyslexic')),
                onTap: () { Navigator.pop(context); _pickImage(ImageSource.gallery); },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarContent() {
    if (_profileImage != null) {
      return ClipOval(child: Image.file(_profileImage!, fit: BoxFit.cover, width: 120, height: 120));
    }
    if (_profileImageBase64 != null && _profileImageBase64!.isNotEmpty) {
      try {
        final bytes = base64Decode(_profileImageBase64!);
        return ClipOval(child: Image.memory(bytes, fit: BoxFit.cover, width: 120, height: 120));
      } catch (_) {}
    }
    final initial = _nameController.text.trim().isNotEmpty ? _nameController.text.trim()[0].toUpperCase() : 'U';
    return Center(
      child: Text(initial, style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Color(0xFFB789DA), fontFamily: 'OpenDyslexic')),
    );
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      final userId = _authService.getUserId();
      if (userId == null) throw Exception('Not signed in');

      await _mongoService.updateSetting(userId, 'user_name', _nameController.text.trim());
      await _mongoService.updateSetting(userId, 'user_email', _emailController.text.trim());
      await _mongoService.updateSetting(userId, 'user_phone', _phoneController.text.trim());

      if (_profileImageBase64 != null) {
        await _mongoService.updateSetting(userId, 'profile_photo', _profileImageBase64);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile saved'), backgroundColor: Color(0xFFB789DA)));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not save profile: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFB789DA)))
          : CustomScrollView(
              slivers: [
                SliverAppBar(
                  expandedHeight: 220,
                  pinned: true,
                  backgroundColor: const Color(0xFF7C3AED),
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  flexibleSpace: FlexibleSpaceBar(
                    background: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF7C3AED), Color(0xFFB789DA)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: SafeArea(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(height: 30),
                            Stack(
                              children: [
                                Container(
                                  width: 120,
                                  height: 120,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white,
                                    border: Border.all(color: Colors.white, width: 4),
                                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 16, spreadRadius: 2)],
                                  ),
                                  child: _buildAvatarContent(),
                                ),
                                Positioned(
                                  bottom: 4,
                                  right: 4,
                                  child: GestureDetector(
                                    onTap: _showImageSourceDialog,
                                    child: Container(
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        shape: BoxShape.circle,
                                        border: Border.all(color: const Color(0xFFB789DA), width: 2),
                                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 6)],
                                      ),
                                      child: const Icon(Icons.camera_alt_rounded, color: Color(0xFFB789DA), size: 18),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              _nameController.text.trim().isNotEmpty ? _nameController.text.trim() : 'Your Name',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white, fontFamily: 'OpenDyslexic'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  title: const Text('Edit Profile', style: TextStyle(fontFamily: 'OpenDyslexic', color: Colors.white, fontSize: 18)),
                ),
                SliverToBoxAdapter(
                  child: Form(
                    key: _formKey,
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Personal Info', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: colorScheme.onSurface.withOpacity(0.5), fontFamily: 'OpenDyslexic', letterSpacing: 0.8)),
                          const SizedBox(height: 14),
                          _buildField(controller: _nameController, label: 'Full Name', icon: Icons.person_outline_rounded, isDark: isDark,
                            validator: (v) => (v == null || v.trim().isEmpty) ? 'Name is required' : null),
                          const SizedBox(height: 14),
                          _buildField(controller: _emailController, label: 'Email', icon: Icons.mail_outline_rounded, keyboardType: TextInputType.emailAddress, isDark: isDark,
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return 'Email is required';
                              if (!v.contains('@')) return 'Enter a valid email';
                              return null;
                            }),
                          const SizedBox(height: 14),
                          _buildField(controller: _phoneController, label: 'Phone Number', icon: Icons.phone_outlined, keyboardType: TextInputType.phone, isDark: isDark),
                          const SizedBox(height: 32),
                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton(
                              onPressed: _isSaving ? null : _saveProfile,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFB789DA),
                                foregroundColor: Colors.white,
                                disabledBackgroundColor: Colors.grey.shade300,
                                elevation: 3,
                                shadowColor: const Color(0xFFB789DA).withOpacity(0.4),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                              child: _isSaving
                                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                  : const Text('Save Changes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, fontFamily: 'OpenDyslexic')),
                            ),
                          ),
                          const SizedBox(height: 32),
                          const Divider(),
                          const SizedBox(height: 16),
                          Text('Danger Zone', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.red.shade700, fontFamily: 'OpenDyslexic', letterSpacing: 0.8)),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: OutlinedButton.icon(
                              onPressed: _showDeleteAccountDialog,
                              icon: const Icon(Icons.delete_forever_rounded, color: Colors.red),
                              label: const Text('Delete Account', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.red, fontFamily: 'OpenDyslexic')),
                              style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red, width: 1.5), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text('Permanently deletes your account and all data. Cannot be undone.', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontFamily: 'OpenDyslexic')),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required bool isDark,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textCapitalization: TextCapitalization.words,
      style: TextStyle(fontFamily: 'OpenDyslexic', color: isDark ? Colors.white : Colors.black87),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontFamily: 'OpenDyslexic'),
        prefixIcon: Icon(icon, color: const Color(0xFFB789DA)),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFB789DA), width: 2)),
        filled: true,
        fillColor: isDark ? const Color(0xFF2D2545) : Colors.grey.shade50,
      ),
      validator: validator,
    );
  }

  Future<void> _showDeleteAccountDialog() async {
    final passwordController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (ctx, setDlg) {
          bool obscure = true;
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            title: const Text('Delete Account', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontFamily: 'OpenDyslexic')),
            content: StatefulBuilder(
              builder: (ctx2, setField) => Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('This permanently deletes your account and all saved data. This cannot be undone.', style: TextStyle(fontFamily: 'OpenDyslexic')),
                  const SizedBox(height: 16),
                  const Text('Enter your password to confirm:', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'OpenDyslexic')),
                  const SizedBox(height: 8),
                  TextField(
                    controller: passwordController,
                    obscureText: obscure,
                    decoration: InputDecoration(
                      hintText: 'Password',
                      hintStyle: const TextStyle(fontFamily: 'OpenDyslexic'),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      suffixIcon: IconButton(icon: Icon(obscure ? Icons.visibility_off : Icons.visibility), onPressed: () => setField(() => obscure = !obscure)),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel', style: TextStyle(color: Colors.grey, fontFamily: 'OpenDyslexic'))),
              ElevatedButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Delete', style: TextStyle(color: Colors.white, fontFamily: 'OpenDyslexic')),
              ),
            ],
          );
        },
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      final result = await _authService.deleteAccount(password: passwordController.text);
      passwordController.dispose();
      if (!mounted) return;
      if (result['success'] == true) {
        Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['message'] ?? 'Deletion failed', style: const TextStyle(fontFamily: 'OpenDyslexic')), backgroundColor: Colors.red));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e', style: const TextStyle(fontFamily: 'OpenDyslexic')), backgroundColor: Colors.red));
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