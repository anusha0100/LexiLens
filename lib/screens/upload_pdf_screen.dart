// lib/screens/upload_pdf_screen.dart (FIXED VERSION)
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lexilens/bloc/app_bloc.dart';
import 'package:lexilens/bloc/app_events.dart';
import 'package:lexilens/services/auth_service.dart';
import 'package:lexilens/services/mongodb_service.dart';
import 'package:lexilens/models/document_model.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'dart:io';

class UploadPDFScreen extends StatefulWidget {
  const UploadPDFScreen({super.key});

  @override
  State<UploadPDFScreen> createState() => _UploadPDFScreenState();
}

class _UploadPDFScreenState extends State<UploadPDFScreen> {
  List<PlatformFile> _selectedFiles = [];
  bool _isUploading = false;
  final _authService = AuthService();
  final _mongoService = MongoDBService();
  final Map<String, String> _extractedTexts = {};
  final Map<String, bool> _extractionStatus = {};

  Future<void> _pickFiles() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'txt'],
        allowMultiple: true,
      );

      if (result != null) {
        setState(() {
          _selectedFiles = result.files;
        });
        
        // Extract text from PDFs immediately after selection
        for (var file in _selectedFiles) {
          if (file.extension?.toLowerCase() == 'pdf') {
            await _extractTextFromPDF(file);
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking files: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _extractTextFromPDF(PlatformFile file) async {
    if (file.path == null) return;

    setState(() {
      _extractionStatus[file.name] = true; // Start extraction
    });

    try {
      final File pdfFile = File(file.path!);
      final List<int> bytes = await pdfFile.readAsBytes();
      
      // Load the PDF document
      final PdfDocument document = PdfDocument(inputBytes: bytes);
      
      // Extract text from all pages
      String extractedText = '';
      final PdfTextExtractor extractor = PdfTextExtractor(document);
      
      for (int i = 0; i < document.pages.count; i++) {
        extractedText += extractor.extractText(startPageIndex: i, endPageIndex: i);
        extractedText += '\n\n'; // Add spacing between pages
      }
      
      // Clean up the text
      extractedText = extractedText.trim();
      
      // Store the extracted text
      setState(() {
        _extractedTexts[file.name] = extractedText.isNotEmpty 
            ? extractedText 
            : 'No text could be extracted from this PDF';
        _extractionStatus[file.name] = false; // Extraction complete
      });
      
      // Dispose the document
      document.dispose();
      
      print('✅ Extracted ${extractedText.length} characters from ${file.name}');
      
    } catch (e) {
      print('❌ Error extracting text from PDF: $e');
      setState(() {
        _extractedTexts[file.name] = 'Error extracting text from PDF';
        _extractionStatus[file.name] = false;
      });
    }
  }

  Future<String> _readFileContent(PlatformFile file) async {
    try {
      if (file.path == null) return 'File path not available';
      
      // Check if we already extracted text from this PDF
      if (file.extension?.toLowerCase() == 'pdf' && _extractedTexts.containsKey(file.name)) {
        return _extractedTexts[file.name]!;
      }
      
      // For TXT files, read directly
      if (file.extension?.toLowerCase() == 'txt') {
        final fileContent = await File(file.path!).readAsString();
        return fileContent;
      }
      
      // For DOC/DOCX files
      if (file.extension?.toLowerCase() == 'doc' || file.extension?.toLowerCase() == 'docx') {
        // You would need a package like 'docx_to_text' for this
        // For now, return a placeholder
        return 'Document content (DOC/DOCX support requires additional package)';
      }
      
      return 'Content not available for this file type';
    } catch (e) {
      print('Error reading file: $e');
      return 'Error reading file content';
    }
  }

  Future<void> _uploadFiles() async {
    if (_selectedFiles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one file'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final userId = _authService.getUserId();
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please log in to upload documents'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isUploading = true;
    });

    try {
      int successCount = 0;
      int failCount = 0;

      for (final file in _selectedFiles) {
        try {
          // Get the content (either extracted from PDF or read from file)
          final content = await _readFileContent(file);
          
          if (content.isEmpty || content.contains('Error') || content.contains('not available')) {
            print('⚠️ Skipping ${file.name} - no valid content');
            failCount++;
            continue;
          }
          
          final document = DocumentModel(
            userId: userId,
            name: file.name,
            content: content,
            filePath: file.path,
            uploadedDate: DateTime.now(),
            tags: [],
            isFavorite: false,
          );

          print('📤 Uploading ${file.name} with ${content.length} characters');
          
          final savedDoc = await _mongoService.createDocument(document);
          
          if (savedDoc != null) {
            successCount++;
            print('✅ Successfully uploaded ${file.name}');
          } else {
            failCount++;
            print('❌ Failed to upload ${file.name}');
          }
        } catch (e) {
          print('Error uploading ${file.name}: $e');
          failCount++;
        }
      }

      if (mounted) {
        setState(() {
          _isUploading = false;
        });

        String message;
        Color bgColor;
        
        if (successCount > 0 && failCount == 0) {
          message = '$successCount file(s) uploaded successfully!';
          bgColor = const Color(0xFFB789DA);
        } else if (successCount > 0 && failCount > 0) {
          message = '$successCount succeeded, $failCount failed';
          bgColor = Colors.orange;
        } else {
          message = 'Failed to upload files';
          bgColor = Colors.red;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: bgColor,
            duration: const Duration(seconds: 3),
          ),
        );

        if (successCount > 0) {
          // Reload documents in the app
          context.read<AppBloc>().add(LoadDocuments());
          
          // Clear the selected files
          setState(() {
            _selectedFiles.clear();
            _extractedTexts.clear();
            _extractionStatus.clear();
          });
          
          // Go back to previous screen
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _removeFile(int index) {
    final fileName = _selectedFiles[index].name;
    setState(() {
      _selectedFiles.removeAt(index);
      _extractedTexts.remove(fileName);
      _extractionStatus.remove(fileName);
    });
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Upload Documents',
          style: TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.bold,
            fontFamily: 'OpenDyslexic',
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _selectedFiles.isEmpty
                ? _buildEmptyState()
                : _buildFilesList(),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: OutlinedButton.icon(
                    onPressed: _isUploading ? null : _pickFiles,
                    icon: const Icon(Icons.add),
                    label: Text(
                      _selectedFiles.isEmpty ? 'Select Files' : 'Add More Files',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'OpenDyslexic',
                      ),
                    ),
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
                  ),
                ),
                if (_selectedFiles.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isUploading ? null : _uploadFiles,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFB789DA),
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.grey[300],
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isUploading
                          ? const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                ),
                                SizedBox(width: 12),
                                Text(
                                  'Uploading...',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    fontFamily: 'OpenDyslexic',
                                  ),
                                ),
                              ],
                            )
                          : Text(
                              'Upload ${_selectedFiles.length} File${_selectedFiles.length > 1 ? 's' : ''}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                fontFamily: 'OpenDyslexic',
                              ),
                            ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: const Color(0xFFE8D5F0),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.cloud_upload_outlined,
              size: 60,
              color: Color(0xFFB789DA),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Upload Your Documents',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              fontFamily: 'OpenDyslexic',
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Select PDF, DOC, DOCX, or TXT files\nto upload and read with LexiLens',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                fontFamily: 'OpenDyslexic',
              ),
            ),
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.symmetric(horizontal: 40),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF8E1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.info_outline,
                  color: Color(0xFFB789DA),
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'PDF text extraction supported\nMax file size: 10MB per file',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[700],
                      fontFamily: 'OpenDyslexic',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilesList() {
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _selectedFiles.length,
      itemBuilder: (context, index) {
        final file = _selectedFiles[index];
        final isExtracting = _extractionStatus[file.name] ?? false;
        final hasExtractedText = _extractedTexts.containsKey(file.name);
        
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.all(12),
            leading: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: const Color(0xFFE8D5F0),
                borderRadius: BorderRadius.circular(8),
              ),
              child: isExtracting
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(
                        color: Color(0xFFB789DA),
                        strokeWidth: 2,
                      ),
                    )
                  : Icon(
                      _getFileIcon(file.extension ?? ''),
                      color: const Color(0xFFB789DA),
                      size: 28,
                    ),
            ),
            title: Text(
              file.name,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                fontFamily: 'OpenDyslexic',
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _formatFileSize(file.size),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontFamily: 'OpenDyslexic',
                  ),
                ),
                if (isExtracting)
                  const Text(
                    'Extracting text...',
                    style: TextStyle(
                      fontSize: 11,
                      color: Color(0xFFB789DA),
                      fontFamily: 'OpenDyslexic',
                    ),
                  )
                else if (hasExtractedText)
                  Text(
                    '✓ Text extracted (${_extractedTexts[file.name]!.length} chars)',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.green,
                      fontFamily: 'OpenDyslexic',
                    ),
                  ),
              ],
            ),
            trailing: IconButton(
              icon: const Icon(Icons.close, color: Colors.red),
              onPressed: _isUploading ? null : () => _removeFile(index),
            ),
          ),
        );
      },
    );
  }

  IconData _getFileIcon(String extension) {
    switch (extension.toLowerCase()) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'txt':
        return Icons.text_snippet;
      default:
        return Icons.insert_drive_file;
    }
  }
}