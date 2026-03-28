// lib/screens/documents_screen.dart
// FR-025: Document search added (search bar + query logic).

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lexilens/bloc/app_bloc.dart';
import 'package:lexilens/bloc/app_events.dart';
import 'package:lexilens/bloc/app_states.dart';
import 'package:lexilens/screens/reading_screen.dart';
import 'package:lexilens/screens/upload_pdf_screen.dart';
import 'package:lexilens/services/mongodb_service.dart';

// FR-025: DocumentsScreen is now stateful so it can hold the search query.
class DocumentsScreen extends StatefulWidget {
  const DocumentsScreen({super.key});

  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

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
            icon: const Icon(Icons.refresh, color: Colors.black),
            onPressed: () {
              context.read<AppBloc>().add(LoadDocuments());
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Refreshing documents...'),
                  duration: Duration(seconds: 1),
                  backgroundColor: Color(0xFFB789DA),
                ),
              );
            },
          ),
        ],
      ),
      body: BlocBuilder<AppBloc, AppState>(
        builder: (context, state) {
          // FR-025: Filter documents by search query
          final allDocs = state.recentDocuments;
          final docs = _query.isEmpty
              ? allDocs
              : allDocs
                  .where((d) =>
                      d.name
                          .toLowerCase()
                          .contains(_query.toLowerCase()) ||
                      d.content
                          .toLowerCase()
                          .contains(_query.toLowerCase()))
                  .toList();

          return Column(
            children: [
              // ── Search bar (FR-025) ────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                child: TextField(
                  controller: _searchController,
                  onChanged: (v) => setState(() => _query = v.trim()),
                  style: const TextStyle(fontFamily: 'OpenDyslexic'),
                  decoration: InputDecoration(
                    hintText: 'Search documents…',
                    hintStyle: const TextStyle(fontFamily: 'OpenDyslexic'),
                    prefixIcon:
                        const Icon(Icons.search, color: Color(0xFFB789DA)),
                    suffixIcon: _query.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _query = '');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: Colors.grey[100],
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),

              // ── Document count ─────────────────────────────────────────
              if (allDocs.isNotEmpty)
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(
                    children: [
                      Text(
                        _query.isEmpty
                            ? '${allDocs.length} document${allDocs.length != 1 ? "s" : ""}'
                            : '${docs.length} of ${allDocs.length} documents',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                          fontFamily: 'OpenDyslexic',
                        ),
                      ),
                    ],
                  ),
                ),

              // ── Document list / empty state ────────────────────────────
              Expanded(
                child: docs.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _query.isNotEmpty
                                  ? Icons.search_off
                                  : Icons.description_outlined,
                              size: 80,
                              color: Colors.grey[300],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _query.isNotEmpty
                                  ? 'No documents match "$_query"'
                                  : 'No documents yet',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey[600],
                                fontFamily: 'OpenDyslexic',
                              ),
                            ),
                            if (_query.isEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                'Upload or scan a document to get started',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[500],
                                  fontFamily: 'OpenDyslexic',
                                ),
                              ),
                            ],
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          final doc = docs[index];
                          return _DocumentCard(
                            document: doc,
                            searchQuery: _query,
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
                            onDelete: () async {
                              final confirmed = await showDialog<bool>(
                                context: context,
                                builder: (dialogContext) => AlertDialog(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  title: const Text('Delete Document',
                                      style: TextStyle(
                                          fontFamily: 'OpenDyslexic')),
                                  content: Text(
                                    'Are you sure you want to delete "${doc.name}"? This cannot be undone.',
                                    style: const TextStyle(
                                        fontFamily: 'OpenDyslexic'),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(dialogContext, false),
                                      child: const Text('Cancel',
                                          style: TextStyle(
                                              color: Colors.grey,
                                              fontFamily: 'OpenDyslexic')),
                                    ),
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(dialogContext, true),
                                      child: const Text('Delete',
                                          style: TextStyle(
                                              color: Colors.red,
                                              fontWeight: FontWeight.bold,
                                              fontFamily: 'OpenDyslexic')),
                                    ),
                                  ],
                                ),
                              );

                              if (confirmed == true && context.mounted) {
                                final mongoService = MongoDBService();
                                final deleted =
                                    await mongoService.deleteDocument(doc.id);
                                if (context.mounted) {
                                  if (deleted) {
                                    context
                                        .read<AppBloc>()
                                        .add(DeleteDocument(doc.id));
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content:
                                            Text('Document deleted successfully'),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content:
                                            Text('Failed to delete document'),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                }
                              }
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
              builder: (_) => BlocProvider.value(
                value: context.read<AppBloc>(),
                child: const UploadPDFScreen(),
              ),
            ),
          );
        },
        backgroundColor: const Color(0xFFB789DA),
        icon: const Icon(Icons.add),
        label: const Text(
          'Upload',
          style: TextStyle(fontFamily: 'OpenDyslexic'),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Document card widget
// ─────────────────────────────────────────────────────────────────────────────

class _DocumentCard extends StatelessWidget {
  final Document document;
  final String searchQuery;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _DocumentCard({
    required this.document,
    required this.searchQuery,
    required this.onTap,
    required this.onDelete,
  });

  String _getTimeAgo(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'Just now';
  }

  // Highlight matching text in search results
  Widget _highlightText(String text, String query,
      {TextStyle? baseStyle, int? maxLines}) {
    if (query.isEmpty) {
      return Text(
        text,
        style: baseStyle,
        maxLines: maxLines,
        overflow: maxLines != null ? TextOverflow.ellipsis : null,
      );
    }
    final lower = text.toLowerCase();
    final qLower = query.toLowerCase();
    final spans = <TextSpan>[];
    int start = 0;
    while (true) {
      final idx = lower.indexOf(qLower, start);
      if (idx < 0) {
        spans.add(TextSpan(text: text.substring(start), style: baseStyle));
        break;
      }
      if (idx > start) {
        spans.add(TextSpan(text: text.substring(start, idx), style: baseStyle));
      }
      spans.add(TextSpan(
        text: text.substring(idx, idx + query.length),
        style: (baseStyle ?? const TextStyle()).copyWith(
          backgroundColor: const Color(0xFFFFE082),
          fontWeight: FontWeight.bold,
        ),
      ));
      start = idx + query.length;
    }
    return RichText(
      text: TextSpan(children: spans),
      maxLines: maxLines,
      overflow: maxLines != null ? TextOverflow.ellipsis : TextOverflow.clip,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                child: const Icon(Icons.description,
                    color: Color(0xFFB789DA), size: 32),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _highlightText(
                      document.name,
                      searchQuery,
                      baseStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'OpenDyslexic',
                      ),
                      maxLines: 1,
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
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.text_snippet,
                            size: 14, color: Colors.grey[500]),
                        const SizedBox(width: 4),
                        Text(
                          '${document.content.length} characters',
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
              PopupMenuButton(
                icon: const Icon(Icons.more_vert),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'read',
                    child: Row(children: [
                      Icon(Icons.book_outlined, size: 20),
                      SizedBox(width: 8),
                      Text('Read',
                          style: TextStyle(fontFamily: 'OpenDyslexic')),
                    ]),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(children: [
                      Icon(Icons.delete_outline, size: 20, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Delete',
                          style: TextStyle(
                              color: Colors.red,
                              fontFamily: 'OpenDyslexic')),
                    ]),
                  ),
                ],
                onSelected: (value) {
                  if (value == 'read') {
                    onTap();
                  } else if (value == 'delete') {
                    onDelete();
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}