// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lexilens/bloc/app_bloc.dart';
import 'package:lexilens/bloc/app_events.dart';
import 'package:lexilens/bloc/app_states.dart';
import 'package:lexilens/screens/reading_screen.dart';
import 'package:lexilens/screens/upload_pdf_screen.dart';

class DocumentsScreen extends StatelessWidget {
  const DocumentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'My Documents',
          style: TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.bold,
            fontFamily: 'OpenDyslexic',
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.search, 
              color: Colors.black,
            ),
            onPressed: () {
              // TODO: Implement search
            },
          ),
        ],
      ),
      body: BlocBuilder<AppBloc, AppState>(
        builder: (context, state) {
          if (state.recentDocuments.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.description_outlined,
                    size: 80,
                    color: Colors.grey[300],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No documents yet',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey[600],
                      fontFamily: 'OpenDyslexic',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Start by scanning or uploading a document',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[500],
                      fontFamily: 'OpenDyslexic',
                    ),
                  ),
                ],
              ),
            );
          }

          return Column(
            children: [
              // Filter tabs
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20, 
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    _FilterChip(
                      label: 'All',
                      isSelected: true,
                      onTap: () {},
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'Recent',
                      isSelected: false,
                      onTap: () {},
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'Favorites',
                      isSelected: false,
                      onTap: () {},
                    ),
                  ],
                ),
              ),
              // Documents list
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: state.recentDocuments.length,
                  itemBuilder: (context, index) {
                    final doc = state.recentDocuments[index];
                    return _DocumentCard(
                      document: doc,
                      onTap: () {
                        context.read<AppBloc>().add(OpenDocument(doc.id));
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ReadingScreen(),
                          ),
                        );
                      },
                      onDelete: () {
                        context.read<AppBloc>().add(DeleteDocument(doc.id));
                      },
                      onShare: () {
                        // TODO: Implement share
                      },
                      onFavorite: () {
                        // TODO: Implement favorite
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const UploadPDFScreen(),
            ),
          );
        },
        backgroundColor: const Color(0xFFB789DA),
        icon: const Icon(Icons.add),
        label: const Text(
          'Upload',
          style: TextStyle(
            fontFamily: 'OpenDyslexic',
          ),
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 16, 
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFB789DA) : Colors.grey[200],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey[700],
            fontSize: 14,
            fontWeight: FontWeight.w600,
            fontFamily: 'OpenDyslexic',
          ),
        ),
      ),
    );
  }
}

class _DocumentCard extends StatelessWidget {
  final Document document;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onShare;
  final VoidCallback onFavorite;

  const _DocumentCard({
    required this.document,
    required this.onTap,
    required this.onDelete,
    required this.onShare,
    required this.onFavorite,
  });

  String _getTimeAgo(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else {
      return 'Just now';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 60,
                height: 80,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8D5F0),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.description,
                  color: Color(0xFFB789DA),
                  size: 32,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      document.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'OpenDyslexic',
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _getTimeAgo(document.uploadedDate),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontFamily: 'OpenDyslexic',
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.description, 
                          size: 14, 
                          color: Colors.grey[500],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'PDF',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[600],
                            fontFamily: 'OpenDyslexic',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Action menu
              PopupMenuButton(
                icon: const Icon(Icons.more_vert),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                itemBuilder: (context) => [
                  PopupMenuItem(
                    onTap: onFavorite,
                    child: Row(
                      children: [
                        const Icon(
                          Icons.star_outline, 
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        const Text('Favorite'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    onTap: onShare,
                    child: Row(
                      children: [
                        const Icon(
                          Icons.share_outlined, 
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        const Text('Share'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    onTap: onDelete,
                    child: Row(
                      children: [
                        const Icon(
                          Icons.delete_outline, 
                          size: 20, 
                          color: Colors.red,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Delete', 
                          style: TextStyle(
                            color: Colors.red,
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
    );
  }
}