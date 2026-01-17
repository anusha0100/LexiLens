import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lexilens/services/mongodb_service.dart';
import 'package:lexilens/services/auth_service.dart';

class DocumentDebugScreen extends StatefulWidget {
  const DocumentDebugScreen({super.key});

  @override
  State<DocumentDebugScreen> createState() => _DocumentDebugScreenState();
}

class _DocumentDebugScreenState extends State<DocumentDebugScreen> {
  final _mongoService = MongoDBService();
  final _authService = AuthService();
  List<Map<String, dynamic>> _documents = [];
  bool _isLoading = false;
  String? _selectedDocId;
  String? _selectedDocContent;

  @override
  void initState() {
    super.initState();
    _loadDocuments();
  }

  Future<void> _loadDocuments() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final userId = _authService.getUserId();
      if (userId != null) {
        final docs = await _mongoService.getUserDocuments(userId);
        setState(() {
          _documents = docs.map((doc) => {
            'id': doc.id,
            'name': doc.name,
            'contentLength': doc.content.length,
            'content': doc.content,
            'uploadDate': doc.uploadedDate.toString(),
          }).toList();
        });
      }
    } catch (e) {
      print('Error loading documents: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFB789DA),
        title: const Text(
          'Document Debug',
          style: TextStyle(color: Colors.white, fontFamily: 'OpenDyslexic'),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadDocuments,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.blue[50],
                  child: Text(
                    '${_documents.length} documents in database',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontFamily: 'OpenDyslexic',
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: _documents.length,
                    itemBuilder: (context, index) {
                      final doc = _documents[index];
                      return Card(
                        margin: const EdgeInsets.all(8),
                        child: ExpansionTile(
                          title: Text(
                            doc['name'] ?? 'Unnamed',
                            style: const TextStyle(fontFamily: 'OpenDyslexic'),
                          ),
                          subtitle: Text(
                            'Content: ${doc['contentLength']} characters',
                            style: const TextStyle(fontFamily: 'OpenDyslexic'),
                          ),
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'ID: ${doc['id']}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontFamily: 'Courier',
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Upload Date: ${doc['uploadDate']}',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  const SizedBox(height: 16),
                                  const Text(
                                    'Content Preview:',
                                    style: TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 8),
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.grey[200],
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: SelectableText(
                                      doc['content'] ?? 'No content',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontFamily: 'OpenDyslexic',
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Row(
                                    children: [
                                      ElevatedButton.icon(
                                        onPressed: () {
                                          Clipboard.setData(
                                            ClipboardData(text: doc['content'] ?? ''),
                                          );
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(
                                              content: Text('Content copied to clipboard'),
                                              backgroundColor: Color(0xFFB789DA),
                                            ),
                                          );
                                        },
                                        icon: const Icon(Icons.copy),
                                        label: const Text('Copy Content'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFFB789DA),
                                          foregroundColor: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}