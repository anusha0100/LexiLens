import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'dart:convert';
import 'package:lexilens/bloc/app_bloc.dart';
import 'package:lexilens/bloc/app_events.dart';
import 'package:lexilens/bloc/app_states.dart';
import 'package:lexilens/screens/reading_screen.dart';
import 'package:lexilens/screens/filter_screen.dart';
import 'package:lexilens/screens/scanner_screen.dart';
import 'package:lexilens/screens/live_ar_screen.dart';
import 'package:lexilens/screens/upload_pdf_screen.dart';
import 'package:lexilens/screens/documents_screen.dart';
import 'package:lexilens/screens/settings_screen.dart';
import 'package:lexilens/services/auth_service.dart';
import 'package:lexilens/services/mongodb_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? _profilePhotoBase64;
  final _mongoService = MongoDBService();
  final _authService = AuthService();

  @override
  void initState() {
    super.initState();
    context.read<AppBloc>().add(LoadUserProfile());
    context.read<AppBloc>().add(LoadDocuments());
    context.read<AppBloc>().add(LoadUserSettings());
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
        return ClipOval(child: Image.memory(bytes, width: 50, height: 50, fit: BoxFit.cover));
      } catch (_) {}
    }
    final initial = userName.isNotEmpty ? userName[0].toUpperCase() : 'U';
    return Center(
      child: Text(initial, style: const TextStyle(color: Color(0xFFB789DA), fontSize: 22, fontWeight: FontWeight.bold, fontFamily: 'OpenDyslexic')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        title: const Text('LexiLens', style: TextStyle(color: Color(0xFFB789DA), fontSize: 22, fontWeight: FontWeight.bold, fontFamily: 'OpenDyslexic')),
        actions: [
          IconButton(
            icon: Icon(Icons.menu_rounded, color: colorScheme.onSurface),
            onPressed: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (_) => BlocProvider.value(value: context.read<AppBloc>(), child: const SettingsScreen())));
              _loadProfilePhoto();
            },
          ),
        ],
      ),
      body: BlocBuilder<AppBloc, AppState>(
        builder: (context, state) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Profile header
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF7C3AED), Color(0xFFB789DA)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [BoxShadow(color: const Color(0xFFB789DA).withOpacity(0.35), blurRadius: 16, offset: const Offset(0, 6))],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          border: Border.all(color: Colors.white.withOpacity(0.6), width: 2),
                        ),
                        child: _buildAvatar(state.userName),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Welcome back,', style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.8), fontFamily: 'OpenDyslexic')),
                            Text(state.userName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white, fontFamily: 'OpenDyslexic'), overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
                        child: Text('${state.recentDocuments.length} docs', style: const TextStyle(fontSize: 12, color: Colors.white, fontFamily: 'OpenDyslexic')),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                Text('Tools', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'OpenDyslexic', color: colorScheme.onSurface)),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(child: _ToolCard(title: 'Text To Speech', icon: Icons.record_voice_over_rounded, color: const Color(0xFFB789DA), onTap: () {
                      if (state.recentDocuments.isNotEmpty) {
                        final firstDoc = state.recentDocuments.first;
                        context.read<AppBloc>().add(OpenDocument(firstDoc.id));
                        Navigator.push(context, MaterialPageRoute(builder: (_) => BlocProvider.value(value: context.read<AppBloc>(), child: const ReadingScreen())));
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No documents yet. Scan or upload one first.'), backgroundColor: Color(0xFFB789DA)));
                      }
                    })),
                    const SizedBox(width: 14),
                    Expanded(child: _ToolCard(title: 'Scan A Doc', icon: Icons.document_scanner_rounded, color: const Color(0xFF7C3AED), onTap: () {
                      context.read<AppBloc>().add(NavigateToScan());
                      Navigator.push(context, MaterialPageRoute(builder: (_) => BlocProvider.value(value: context.read<AppBloc>(), child: const ScannerScreen())));
                    })),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(child: _ToolCard(title: 'Word Filter', icon: Icons.filter_alt_rounded, color: const Color(0xFF9B6FC4), onTap: () {
                      context.read<AppBloc>().add(NavigateToFilter());
                      Navigator.push(context, MaterialPageRoute(builder: (_) => BlocProvider.value(value: context.read<AppBloc>(), child: const FilterScreen())));
                    })),
                    const SizedBox(width: 14),
                    Expanded(child: _ToolCard(title: 'Upload PDF', icon: Icons.cloud_upload_rounded, color: const Color(0xFFB789DA), onTap: () {
                      context.read<AppBloc>().add(UploadPDF());
                      Navigator.push(context, MaterialPageRoute(builder: (_) => BlocProvider.value(value: context.read<AppBloc>(), child: const UploadPDFScreen())));
                    })),
                  ],
                ),
                const SizedBox(height: 14),
                _ToolCard(title: 'Live AR Reader', icon: Icons.view_in_ar_rounded, color: const Color(0xFF6D28D9), wide: true, onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => BlocProvider.value(value: context.read<AppBloc>(), child: const LiveArScreen())));
                }),
                const SizedBox(height: 28),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Recent Documents', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'OpenDyslexic', color: colorScheme.onSurface)),
                    TextButton(
                      onPressed: () {
                        context.read<AppBloc>().add(NavigateToDocs());
                        Navigator.push(context, MaterialPageRoute(builder: (_) => BlocProvider.value(value: context.read<AppBloc>(), child: const DocumentsScreen())));
                      },
                      child: Text('See all', style: TextStyle(fontSize: 13, color: colorScheme.onSurface.withOpacity(0.5), fontFamily: 'OpenDyslexic')),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                state.recentDocuments.isEmpty
                    ? _buildEmptyState(context)
                    : ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: state.recentDocuments.length > 3 ? 3 : state.recentDocuments.length,
                        itemBuilder: (context, index) {
                          final doc = state.recentDocuments[index];
                          return _DocumentCard(
                            document: doc,
                            onTap: () {
                              context.read<AppBloc>().add(OpenDocument(doc.id));
                              Navigator.push(context, MaterialPageRoute(builder: (_) => BlocProvider.value(value: context.read<AppBloc>(), child: const ReadingScreen())));
                            },
                            onDelete: () => context.read<AppBloc>().add(DeleteDocument(doc.id)),
                          );
                        },
                      ),
              ],
            ),
          );
        },
      ),
      bottomNavigationBar: _BottomNavBar(
        onNavigate: (index) {
          switch (index) {
            case 0: break;
            case 1:
              context.read<AppBloc>().add(NavigateToScan());
              Navigator.push(context, MaterialPageRoute(builder: (_) => BlocProvider.value(value: context.read<AppBloc>(), child: const ScannerScreen()))).then((_) { if (context.mounted) context.read<AppBloc>().add(NavigateToHome()); });
              break;
            case 2:
              context.read<AppBloc>().add(NavigateToDocs());
              Navigator.push(context, MaterialPageRoute(builder: (_) => BlocProvider.value(value: context.read<AppBloc>(), child: const DocumentsScreen()))).then((_) { if (context.mounted) context.read<AppBloc>().add(NavigateToHome()); });
              break;
            case 3:
              context.read<AppBloc>().add(NavigateToFilter());
              Navigator.push(context, MaterialPageRoute(builder: (_) => BlocProvider.value(value: context.read<AppBloc>(), child: const FilterScreen()))).then((_) { if (context.mounted) context.read<AppBloc>().add(NavigateToHome()); });
              break;
            case 4:
              context.read<AppBloc>().add(NavigateToSettings());
              Navigator.push(context, MaterialPageRoute(builder: (_) => BlocProvider.value(value: context.read<AppBloc>(), child: const SettingsScreen()))).then((_) {
                if (context.mounted) {
                  context.read<AppBloc>().add(NavigateToHome());
                  _loadProfilePhoto();
                }
              });
              break;
          }
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: colorScheme.surfaceVariant.withOpacity(0.4),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(Icons.description_outlined, size: 56, color: colorScheme.onSurface.withOpacity(0.25)),
          const SizedBox(height: 14),
          Text('No documents yet', style: TextStyle(fontSize: 16, color: colorScheme.onSurface.withOpacity(0.55), fontFamily: 'OpenDyslexic')),
          const SizedBox(height: 6),
          Text('Scan a page or upload a PDF to get started', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: colorScheme.onSurface.withOpacity(0.4), fontFamily: 'OpenDyslexic')),
        ],
      ),
    );
  }
}

class _ToolCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool wide;

  const _ToolCard({required this.title, required this.icon, required this.color, required this.onTap, this.wide = false});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: wide ? 80 : 110,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [color, color.withOpacity(0.8)], begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: color.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: wide
            ? Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(icon, size: 30, color: Colors.white),
                const SizedBox(width: 12),
                Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white, fontFamily: 'OpenDyslexic')),
              ])
            : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(icon, size: 36, color: Colors.white),
                const SizedBox(height: 8),
                Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white, fontFamily: 'OpenDyslexic')),
              ]),
      ),
    );
  }
}

class _DocumentCard extends StatelessWidget {
  final Document document;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _DocumentCard({required this.document, required this.onTap, required this.onDelete});

  String _getTimeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays > 0) return '${diff.inDays} day${diff.inDays > 1 ? 's' : ''} ago';
    if (diff.inHours > 0) return '${diff.inHours} hour${diff.inHours > 1 ? 's' : ''} ago';
    return 'Just now';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 2,
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: Container(
          width: 48,
          height: 60,
          decoration: BoxDecoration(color: const Color(0xFFB789DA).withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
          child: const Icon(Icons.description_rounded, color: Color(0xFFB789DA)),
        ),
        title: Text(document.name, style: const TextStyle(fontWeight: FontWeight.w600, fontFamily: 'OpenDyslexic'), overflow: TextOverflow.ellipsis),
        subtitle: Text(_getTimeAgo(document.uploadedDate), style: TextStyle(fontSize: 12, color: colorScheme.onSurface.withOpacity(0.5), fontFamily: 'OpenDyslexic')),
        trailing: PopupMenuButton(
          icon: Icon(Icons.more_vert_rounded, color: colorScheme.onSurface.withOpacity(0.5)),
          itemBuilder: (context) => [PopupMenuItem(onTap: onDelete, child: const Text('Delete'))],
        ),
        onTap: onTap,
      ),
    );
  }
}

class _BottomNavBar extends StatelessWidget {
  final Function(int) onNavigate;
  const _BottomNavBar({required this.onNavigate});

  int _tabToIndex(AppTab tab) {
    switch (tab) {
      case AppTab.home: return 0;
      case AppTab.scan: return 1;
      case AppTab.docs: return 2;
      case AppTab.filter: return 3;
      case AppTab.settings: return 4;
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AppBloc, AppState>(
      builder: (context, state) {
        final isDarkMode = Theme.of(context).brightness == Brightness.dark;
        return BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          selectedItemColor: isDarkMode ? const Color(0xFFD4ACEA) : const Color(0xFFB789DA),
          unselectedItemColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
          backgroundColor: isDarkMode ? const Color(0xFF2D2545) : Colors.white,
          elevation: 8,
          currentIndex: _tabToIndex(state.currentTab),
          onTap: onNavigate,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'Home'),
            BottomNavigationBarItem(icon: Icon(Icons.camera_alt_rounded), label: 'Scan'),
            BottomNavigationBarItem(icon: Icon(Icons.description_rounded), label: 'Docs'),
            BottomNavigationBarItem(icon: Icon(Icons.filter_alt_rounded), label: 'Filter'),
            BottomNavigationBarItem(icon: Icon(Icons.settings_rounded), label: 'Settings'),
          ],
        );
      },
    );
  }
}