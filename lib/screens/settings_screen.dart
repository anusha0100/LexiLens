import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'dart:convert';
import 'package:lexilens/bloc/app_bloc.dart';
import 'package:lexilens/bloc/app_events.dart';
import 'package:lexilens/bloc/app_states.dart';
import 'package:lexilens/screens/documents_screen.dart';
import 'package:lexilens/screens/filter_screen.dart';
import 'package:lexilens/screens/help_screen.dart';
import 'package:lexilens/screens/preferences_screen.dart';
import 'package:lexilens/screens/privacy_policy_screen.dart';
import 'package:lexilens/screens/scanner_screen.dart';
import 'package:lexilens/screens/terms_of_service_screen.dart';
import 'package:lexilens/screens/profile_screen.dart';
import 'package:lexilens/screens/auth_landing_screen.dart';
import 'package:lexilens/services/auth_service.dart';
import 'package:lexilens/services/mongodb_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String? _profilePhotoBase64;
  final _mongoService = MongoDBService();
  final _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _loadProfilePhoto();
  }

  Future<void> _loadProfilePhoto() async {
    try {
      final userId = _authService.getUserId();
      if (userId != null) {
        final settings = await _mongoService.getAllSettings(userId);
        final photo = settings['profile_photo']?.toString() ?? '';
        if (photo.isNotEmpty && mounted) {
          setState(() => _profilePhotoBase64 = photo);
        }
      }
    } catch (_) {}
  }

  Widget _buildAvatar(String userName) {
    if (_profilePhotoBase64 != null && _profilePhotoBase64!.isNotEmpty) {
      try {
        final bytes = base64Decode(_profilePhotoBase64!);
        return ClipOval(child: Image.memory(bytes, width: 80, height: 80, fit: BoxFit.cover));
      } catch (_) {}
    }
    final initial = userName.isNotEmpty ? userName[0].toUpperCase() : 'U';
    return Center(
      child: Text(initial, style: const TextStyle(color: Color(0xFFB789DA), fontSize: 32, fontWeight: FontWeight.bold, fontFamily: 'OpenDyslexic')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final tileBg = isDark ? const Color(0xFF2D2545) : Colors.white;
    final tileBorder = isDark ? const Color(0xFF3D3060) : Colors.grey.shade200;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: BlocBuilder<AppBloc, AppState>(
        builder: (context, state) {
          final userEmail = authService.getUserEmail() ?? 'user@example.com';

          return Column(
            children: [
              Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF7C3AED), Color(0xFFB789DA), Color(0xFFC89EE5)],
                    stops: [0.0, 0.6, 1.0],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
                    child: Row(
                      children: [
                        Stack(
                          children: [
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white,
                                border: Border.all(color: Colors.white, width: 3),
                                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 12, spreadRadius: 2)],
                              ),
                              child: _buildAvatar(state.userName),
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: GestureDetector(
                                onTap: () async {
                                  await Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen()));
                                  _loadProfilePhoto();
                                },
                                child: Container(
                                  width: 26,
                                  height: 26,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: const Color(0xFFB789DA), width: 2),
                                  ),
                                  child: const Icon(Icons.edit, size: 14, color: Color(0xFFB789DA)),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('My Profile', style: TextStyle(fontSize: 13, color: Colors.white70, fontFamily: 'OpenDyslexic')),
                              const SizedBox(height: 4),
                              Text(state.userName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white, fontFamily: 'OpenDyslexic')),
                              const SizedBox(height: 2),
                              Text(userEmail, style: const TextStyle(fontSize: 13, color: Colors.white70, fontFamily: 'OpenDyslexic'), overflow: TextOverflow.ellipsis),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen()));
                      _loadProfilePhoto();
                    },
                    icon: const Icon(Icons.person_outline, size: 20),
                    label: const Text('Edit Profile', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, fontFamily: 'OpenDyslexic')),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFB789DA),
                      side: const BorderSide(color: Color(0xFFB789DA), width: 2),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  children: [
                    _buildSectionHeader('App Settings', colorScheme),
                    _buildMenuItem(context: context, icon: Icons.tune, title: 'Preferences', tileBg: tileBg, tileBorder: tileBorder, colorScheme: colorScheme,
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => BlocProvider.value(value: context.read<AppBloc>(), child: const PreferencesScreen())))),
                    _buildMenuItem(context: context, icon: Icons.help_outline_rounded, title: 'Help', tileBg: tileBg, tileBorder: tileBorder, colorScheme: colorScheme,
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HelpScreen()))),
                    const SizedBox(height: 8),
                    _buildSectionHeader('Legal', colorScheme),
                    _buildMenuItem(context: context, icon: Icons.description_outlined, title: 'Terms of Service', tileBg: tileBg, tileBorder: tileBorder, colorScheme: colorScheme,
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TermsOfServiceScreen()))),
                    _buildMenuItem(context: context, icon: Icons.privacy_tip_outlined, title: 'Privacy Policy', tileBg: tileBg, tileBorder: tileBorder, colorScheme: colorScheme,
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()))),
                    const SizedBox(height: 8),
                    _buildSectionHeader('Account', colorScheme),
                    _buildMenuItem(context: context, icon: Icons.logout_rounded, title: 'Sign Out', isLogout: true, tileBg: tileBg, tileBorder: tileBorder, colorScheme: colorScheme,
                      onTap: () => _showLogoutDialog(context)),
                    _buildMenuItem(context: context, icon: Icons.delete_forever_rounded, title: 'Delete Account', isLogout: true, tileBg: tileBg, tileBorder: tileBorder, colorScheme: colorScheme,
                      onTap: () => _showDeleteAccountDialog(context)),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: tileBg,
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, -5))],
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildNavItem(icon: Icons.home_rounded, label: 'Home', isSelected: false, colorScheme: colorScheme, onTap: () => Navigator.pop(context)),
                        _buildNavItem(icon: Icons.camera_alt_rounded, label: 'Scan', isSelected: false, colorScheme: colorScheme, onTap: () {
                          context.read<AppBloc>().add(NavigateToScan());
                          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => BlocProvider.value(value: context.read<AppBloc>(), child: const ScannerScreen())));
                        }),
                        _buildNavItem(icon: Icons.description_rounded, label: 'Docs', isSelected: false, colorScheme: colorScheme, onTap: () {
                          context.read<AppBloc>().add(NavigateToDocs());
                          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => BlocProvider.value(value: context.read<AppBloc>(), child: const DocumentsScreen())));
                        }),
                        _buildNavItem(icon: Icons.filter_alt_rounded, label: 'Filter', isSelected: false, colorScheme: colorScheme, onTap: () {
                          context.read<AppBloc>().add(NavigateToFilter());
                          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => BlocProvider.value(value: context.read<AppBloc>(), child: const FilterScreen())));
                        }),
                        _buildNavItem(icon: Icons.settings_rounded, label: 'Settings', isSelected: true, colorScheme: colorScheme, onTap: () {}),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8, top: 4),
      child: Text(
        title,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: colorScheme.onSurface.withOpacity(0.5), fontFamily: 'OpenDyslexic', letterSpacing: 0.8),
      ),
    );
  }

  Widget _buildMenuItem({
    required BuildContext context,
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    required Color tileBg,
    required Color tileBorder,
    required ColorScheme colorScheme,
    bool isLogout = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: tileBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tileBorder, width: 1),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isLogout ? Colors.red.withOpacity(0.1) : const Color(0xFFB789DA).withOpacity(0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: isLogout ? Colors.red : const Color(0xFFB789DA), size: 22),
        ),
        title: Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: isLogout ? Colors.red : colorScheme.onSurface, fontFamily: 'OpenDyslexic')),
        trailing: Icon(Icons.chevron_right_rounded, color: isLogout ? Colors.red.withOpacity(0.5) : colorScheme.onSurface.withOpacity(0.35), size: 22),
        onTap: onTap,
      ),
    );
  }

  Widget _buildNavItem({required IconData icon, required String label, required bool isSelected, required ColorScheme colorScheme, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: isSelected ? const Color(0xFFB789DA) : colorScheme.onSurface.withOpacity(0.4), size: 26),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontSize: 11, color: isSelected ? const Color(0xFFB789DA) : colorScheme.onSurface.withOpacity(0.4), fontFamily: 'OpenDyslexic')),
          ],
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    final authService = AuthService();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Sign Out', style: TextStyle(fontFamily: 'OpenDyslexic', fontWeight: FontWeight.bold)),
        content: const Text('Ready to sign out? Your data stays saved for next time.', style: TextStyle(fontFamily: 'OpenDyslexic')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Stay', style: TextStyle(color: Colors.grey, fontFamily: 'OpenDyslexic'))),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              showDialog(context: context, barrierDismissible: false, builder: (context) => const Center(child: CircularProgressIndicator(color: Color(0xFFB789DA))));
              await authService.logout();
              if (context.mounted) {
                Navigator.pop(context);
                Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const AuthLandingScreen()), (route) => false);
              }
            },
            child: const Text('Sign Out', style: TextStyle(color: Colors.red, fontFamily: 'OpenDyslexic', fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(children: [
          Icon(Icons.warning_amber_rounded, color: Colors.red),
          SizedBox(width: 8),
          Text('Delete Account', style: TextStyle(fontFamily: 'OpenDyslexic', fontWeight: FontWeight.bold)),
        ]),
        content: const Text(
          'This permanently deletes your account and all saved data including your documents, settings and reading history. This cannot be undone.',
          style: TextStyle(fontFamily: 'OpenDyslexic'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel', style: TextStyle(color: Colors.grey, fontFamily: 'OpenDyslexic'))),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              _handleAccountDeletion(context);
            },
            child: const Text('Delete Forever', style: TextStyle(color: Colors.red, fontFamily: 'OpenDyslexic', fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _handleAccountDeletion(BuildContext context) async {
    final authService = AuthService();
    showDialog(context: context, barrierDismissible: false, builder: (context) => const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [CircularProgressIndicator(color: Color(0xFFB789DA)), SizedBox(height: 16), Text('Deleting account...', style: TextStyle(color: Colors.white, fontFamily: 'OpenDyslexic'))])));
    final result = await authService.deleteAccount();
    if (context.mounted) {
      Navigator.pop(context);
      if (result['success']) {
        Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const AuthLandingScreen()), (route) => false);
      } else if (result['requiresReauth'] == true) {
        _showReauthDialog(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['message'] ?? 'Failed to delete account'), backgroundColor: Colors.red));
      }
    }
  }

  void _showReauthDialog(BuildContext context) {
    final authService = AuthService();
    final passwordController = TextEditingController();
    bool obscurePassword = true;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Text('Confirm Identity', style: TextStyle(fontFamily: 'OpenDyslexic', fontWeight: FontWeight.bold)),
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Enter your password to continue:', style: TextStyle(fontFamily: 'OpenDyslexic')),
            const SizedBox(height: 16),
            TextField(
              controller: passwordController,
              obscureText: obscurePassword,
              decoration: InputDecoration(
                labelText: 'Password',
                labelStyle: const TextStyle(fontFamily: 'OpenDyslexic'),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                suffixIcon: IconButton(icon: Icon(obscurePassword ? Icons.visibility : Icons.visibility_off), onPressed: () => setState(() => obscurePassword = !obscurePassword)),
              ),
              style: const TextStyle(fontFamily: 'OpenDyslexic'),
            ),
          ]),
          actions: [
            TextButton(onPressed: () { passwordController.dispose(); Navigator.pop(dialogContext); }, child: const Text('Cancel', style: TextStyle(color: Colors.grey, fontFamily: 'OpenDyslexic'))),
            TextButton(
              onPressed: () async {
                final password = passwordController.text.trim();
                if (password.isEmpty) return;
                Navigator.pop(dialogContext);
                passwordController.dispose();
                showDialog(context: context, barrierDismissible: false, builder: (context) => const Center(child: CircularProgressIndicator(color: Color(0xFFB789DA))));
                final result = await authService.deleteAccount(password: password);
                if (context.mounted) {
                  Navigator.pop(context);
                  if (result['success']) {
                    Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const AuthLandingScreen()), (route) => false);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['message'] ?? 'Failed'), backgroundColor: Colors.red));
                  }
                }
              },
              child: const Text('Confirm and Delete', style: TextStyle(color: Colors.red, fontFamily: 'OpenDyslexic', fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}