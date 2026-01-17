// lib/screens/settings_screen.dart (UPDATED)
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lexilens/bloc/app_bloc.dart';
import 'package:lexilens/bloc/app_states.dart';
import 'package:lexilens/screens/help_screen.dart';
import 'package:lexilens/screens/preferences_screen.dart';
import 'package:lexilens/screens/privacy_policy_screen.dart';
import 'package:lexilens/screens/terms_of_service_screen.dart';
import 'package:lexilens/screens/profile_screen.dart';
import 'package:lexilens/screens/auth_landing_screen.dart';
import 'package:lexilens/screens/backend_test_screen.dart';
import 'package:lexilens/services/auth_service.dart';
import 'package:lexilens/screens/document_debug_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();

    return Scaffold(
      backgroundColor: Colors.white,
      body: BlocBuilder<AppBloc, AppState>(
        builder: (context, state) {
          final userEmail = authService.getUserEmail() ?? 'user@example.com';

          return Column(
            children: [
              // Profile Header Section
              Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFFB789DA),
                      Color(0xFFC89EE5),
                    ],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Stack(
                              children: [
                                Container(
                                  width: 80,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 3,
                                    ),
                                  ),
                                  child: CircleAvatar(
                                    radius: 37,
                                    backgroundColor: Colors.white,
                                    child: Text(
                                      state.userName.isNotEmpty
                                          ? state.userName[0].toUpperCase()
                                          : 'U',
                                      style: const TextStyle(
                                        color: Color(0xFFB789DA),
                                        fontSize: 32,
                                        fontWeight: FontWeight.bold,
                                        fontFamily: 'OpenDyslexic',
                                      ),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: GestureDetector(
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => const ProfileScreen(),
                                        ),
                                      );
                                    },
                                    child: Container(
                                      width: 26,
                                      height: 26,
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: const Color(0xFFB789DA),
                                          width: 2,
                                        ),
                                      ),
                                      child: const Icon(
                                        Icons.edit,
                                        size: 14,
                                        color: Color(0xFFB789DA),
                                      ),
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
                                  const Text(
                                    'My Profile',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.white70,
                                      fontFamily: 'OpenDyslexic',
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    state.userName,
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                      fontFamily: 'OpenDyslexic',
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    userEmail,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Colors.white70,
                                      fontFamily: 'OpenDyslexic',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Edit Profile Button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ProfileScreen(),
                        ),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFB789DA),
                      side: const BorderSide(
                        color: Color(0xFFB789DA),
                        width: 2,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Edit Profile',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'OpenDyslexic',
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Menu Items Section
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  children: [
                    _buildMenuItem(
                      context: context,
                      icon: Icons.settings,
                      title: 'Preferences',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const PreferencesScreen(),
                          ),
                        );
                      },
                    ),
                    _buildMenuItem(
                      context: context,
                      icon: Icons.help_outline,
                      title: 'Help',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const HelpScreen(),
                          ),
                        );
                      },
                    ),
                    _buildMenuItem(
                      context: context,
                      icon: Icons.bug_report,
                      title: 'Document Debug',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const DocumentDebugScreen(),
                          ),
                        );
                      },
                    ),
                    _buildMenuItem(
                      context: context,
                      icon: Icons.bug_report,
                      title: 'Backend Testing',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const BackendTestScreen(),
                          ),
                        );
                      },
                    ),
                    _buildMenuItem(
                      context: context,
                      icon: Icons.description_outlined,
                      title: 'Terms of Service',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const TermsOfServiceScreen(),
                          ),
                        );
                      },
                    ),
                    _buildMenuItem(
                      context: context,
                      icon: Icons.privacy_tip_outlined,
                      title: 'Privacy Policy',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const PrivacyPolicyScreen(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    _buildMenuItem(
                      context: context,
                      icon: Icons.logout,
                      title: 'Logout',
                      isLogout: true,
                      onTap: () {
                        _showLogoutDialog(context);
                      },
                    ),
                  ],
                ),
              ),
              // Bottom Navigation Bar
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, -5),
                    ),
                  ],
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildNavItem(
                          icon: Icons.home,
                          label: 'Home',
                          isSelected: false,
                          onTap: () => Navigator.pop(context),
                        ),
                        _buildNavItem(
                          icon: Icons.camera_alt,
                          label: 'Scan',
                          isSelected: false,
                          onTap: () {},
                        ),
                        _buildNavItem(
                          icon: Icons.description,
                          label: 'Docs',
                          isSelected: false,
                          onTap: () {},
                        ),
                        _buildNavItem(
                          icon: Icons.filter_alt,
                          label: 'Filter',
                          isSelected: false,
                          onTap: () {},
                        ),
                        _buildNavItem(
                          icon: Icons.settings,
                          label: 'Setting',
                          isSelected: true,
                          onTap: () {},
                        ),
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

  Widget _buildMenuItem({
    required BuildContext context,
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isLogout = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey[200]!,
          width: 1,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 4,
        ),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isLogout
                ? Colors.red.withOpacity(0.1)
                : const Color(0xFFB789DA).withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: isLogout ? Colors.red : const Color(0xFFB789DA),
            size: 22,
          ),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: isLogout ? Colors.red : Colors.black87,
            fontFamily: 'OpenDyslexic',
          ),
        ),
        trailing: Icon(
          Icons.chevron_right,
          color: isLogout ? Colors.red : Colors.grey[400],
          size: 24,
        ),
        onTap: onTap,
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: isSelected ? const Color(0xFFB789DA) : Colors.grey[400],
            size: 26,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: isSelected ? const Color(0xFFB789DA) : Colors.grey[400],
              fontFamily: 'OpenDyslexic',
            ),
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    final authService = AuthService();

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Logout',
            style: TextStyle(
              fontFamily: 'OpenDyslexic',
              fontWeight: FontWeight.bold,
            ),
          ),
          content: const Text(
            'Are you sure you want to logout?',
            style: TextStyle(
              fontFamily: 'OpenDyslexic',
            ),
          ),
          actions: [
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
            TextButton(
              onPressed: () async {
                Navigator.pop(dialogContext);

                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFFB789DA),
                    ),
                  ),
                );

                await authService.logout();

                if (context.mounted) {
                  Navigator.pop(context);

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Logged out successfully'),
                      backgroundColor: Color(0xFFB789DA),
                    ),
                  );

                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AuthLandingScreen(),
                    ),
                    (route) => false,
                  );
                }
              },
              child: const Text(
                'Logout',
                style: TextStyle(
                  color: Colors.red,
                  fontFamily: 'OpenDyslexic',
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
