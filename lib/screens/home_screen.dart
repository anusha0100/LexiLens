// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lexilens/bloc/app_bloc.dart';
import 'package:lexilens/bloc/app_events.dart';
import 'package:lexilens/bloc/app_states.dart';
import 'package:lexilens/screens/reading_screen.dart';
import 'package:lexilens/screens/filter_screen.dart';
import 'package:lexilens/screens/scanner_screen.dart';
import 'package:lexilens/screens/upload_pdf_screen.dart';
import 'package:lexilens/screens/documents_screen.dart';
import 'package:lexilens/screens/settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    // Load user profile and documents
    context.read<AppBloc>().add(LoadUserProfile());
    context.read<AppBloc>().add(LoadDocuments());
    context.read<AppBloc>().add(LoadUserSettings());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'LexiLens',
          style: TextStyle(
            color: Color(0xFFB789DA),
            fontSize: 20,
            fontWeight: FontWeight.bold,
            fontFamily: 'OpenDyslexic',
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.menu, color: Colors.black),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => BlocProvider.value(
                    value: context.read<AppBloc>(),
                    child: const SettingsScreen(),
                  ),
                ),
              );
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
                // Welcome Section with Username
                Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFFE8D5F0),
                      ),
                      child: Center(
                        child: Text(
                          state.userName.isNotEmpty 
                              ? state.userName[0].toUpperCase()
                              : 'U',
                          style: const TextStyle(
                            color: Color(0xFFB789DA),
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'OpenDyslexic',
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Welcome, ${state.userName}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'OpenDyslexic',
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const Text(
                            'Ready To Make Your Day Easy?',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                              fontFamily: 'OpenDyslexic',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 30),

                // Tools Section
                const Text(
                  'Tools',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'OpenDyslexic',
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _ToolCard(
                        title: 'Text To Speech',
                        icon: Icons.record_voice_over,
                        color: const Color(0xFFB789DA),
                        onTap: () {
                          if (state.recentDocuments.isNotEmpty) {
                            final firstDoc = state.recentDocuments.first;
                            context.read<AppBloc>().add(OpenDocument(firstDoc.id));
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => BlocProvider.value(
                                  value: context.read<AppBloc>(),
                                  child: const ReadingScreen(),
                                ),
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('No documents available. Please scan or upload a document first.'),
                                backgroundColor: Color(0xFFB789DA),
                              ),
                            );
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _ToolCard(
                        title: 'Scan A Text Doc',
                        icon: Icons.document_scanner,
                        color: const Color(0xFFB789DA),
                        onTap: () {
                          context.read<AppBloc>().add(NavigateToScan());
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => BlocProvider.value(
                                value: context.read<AppBloc>(),
                                child: const ScannerScreen(),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _ToolCard(
                        title: 'Filter',
                        icon: Icons.filter_alt,
                        color: const Color(0xFFB789DA),
                        onTap: () {
                          context.read<AppBloc>().add(NavigateToFilter());
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => BlocProvider.value(
                                value: context.read<AppBloc>(),
                                child: const FilterScreen(),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _ToolCard(
                        title: 'Upload PDFs',
                        icon: Icons.cloud_upload,
                        color: const Color(0xFFB789DA),
                        onTap: () {
                          context.read<AppBloc>().add(UploadPDF());
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => BlocProvider.value(
                                value: context.read<AppBloc>(),
                                child: const UploadPDFScreen(),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 30),

                // Recent Documents Section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Recent Documents',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'OpenDyslexic',
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        context.read<AppBloc>().add(NavigateToDocs());
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => BlocProvider.value(
                              value: context.read<AppBloc>(),
                              child: const DocumentsScreen(),
                            ),
                          ),
                        );
                      },
                      child: const Row(
                        children: [
                          Text(
                            'Tap Any File To Resume',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                              fontFamily: 'OpenDyslexic',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // Documents List or Empty State
                state.recentDocuments.isEmpty
                    ? _buildEmptyState(context)
                    : ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: state.recentDocuments.length > 3 
                            ? 3 
                            : state.recentDocuments.length,
                        itemBuilder: (context, index) {
                          final doc = state.recentDocuments[index];
                          return _DocumentCard(
                            document: doc,
                            onTap: () {
                              context.read<AppBloc>().add(OpenDocument(doc.id));
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => BlocProvider.value(
                                    value: context.read<AppBloc>(),
                                    child: const ReadingScreen(),
                                  ),
                                ),
                              );
                            },
                            onDelete: () {
                              context.read<AppBloc>().add(DeleteDocument(doc.id));
                            },
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
            case 0:
              // Already on home
              break;
            case 1:
              context.read<AppBloc>().add(NavigateToScan());
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => BlocProvider.value(
                    value: context.read<AppBloc>(),
                    child: const ScannerScreen(),
                  ),
                ),
              );
              break;
            case 2:
              context.read<AppBloc>().add(NavigateToDocs());
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => BlocProvider.value(
                    value: context.read<AppBloc>(),
                    child: const DocumentsScreen(),
                  ),
                ),
              );
              break;
            case 3:
              context.read<AppBloc>().add(NavigateToFilter());
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => BlocProvider.value(
                    value: context.read<AppBloc>(),
                    child: const FilterScreen(),
                  ),
                ),
              );
              break;
            case 4:
              context.read<AppBloc>().add(NavigateToSettings());
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => BlocProvider.value(
                    value: context.read<AppBloc>(),
                    child: const SettingsScreen(),
                  ),
                ),
              );
              break;
          }
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Icon(
            Icons.description_outlined,
            size: 64,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            'No documents yet',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
              fontFamily: 'OpenDyslexic',
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Upload or scan a document to get started',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[500],
              fontFamily: 'OpenDyslexic',
            ),
          ),
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

  const _ToolCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 120,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: Colors.white),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.white,
                fontFamily: 'OpenDyslexic',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DocumentCard extends StatelessWidget {
  final Document document;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _DocumentCard({
    required this.document,
    required this.onTap,
    required this.onDelete,
  });

  String _getTimeAgo(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return 'Opened ${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
    } else if (difference.inHours > 0) {
      return 'Opened ${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
    } else {
      return 'Opened recently';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: Container(
          width: 50,
          height: 70,
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            Icons.description,
            color: Color(0xFFB789DA),
          ),
        ),
        title: Text(
          document.name,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontFamily: 'OpenDyslexic',
          ),
        ),
        subtitle: Text(
          _getTimeAgo(document.uploadedDate),
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
            fontFamily: 'OpenDyslexic',
          ),
        ),
        trailing: PopupMenuButton(
          icon: const Icon(Icons.more_vert),
          itemBuilder: (context) => [
            PopupMenuItem(
              onTap: onDelete,
              child: const Text('Delete'),
            ),
          ],
        ),
        onTap: onTap,
      ),
    );
  }
}

class _BottomNavBar extends StatelessWidget {
  final Function(int) onNavigate;

  const _BottomNavBar({required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AppBloc, AppState>(
      builder: (context, state) {
        return BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          selectedItemColor: const Color(0xFFB789DA),
          unselectedItemColor: Colors.grey,
          currentIndex: 0,
          onTap: onNavigate,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.camera_alt),
              label: 'Scan',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.description),
              label: 'Docs',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.filter_alt),
              label: 'Filter',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings),
              label: 'Setting',
            ),
          ],
        );
      },
    );
  }
}