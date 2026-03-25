import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';

class DocumentExportService {
  static final DocumentExportService _instance = DocumentExportService._internal();
  factory DocumentExportService() => _instance;
  DocumentExportService._internal();

  /// Export document as plain text file
  Future<File?> exportAsText({
    required String documentName,
    required String content,
  }) async {
    try {
      final directory = await getTemporaryDirectory();
      final fileName = '${documentName}_${DateTime.now().millisecondsSinceEpoch}.txt';
      final file = File('${directory.path}/$fileName');
      
      await file.writeAsString(content);
      print('✅ Text file exported: ${file.path}');
      return file;
    } catch (e) {
      print('❌ Error exporting text: $e');
      return null;
    }
  }

  /// Export document as PDF file
  Future<File?> exportAsPDF({
    required String documentName,
    required String content,
    String? detectedLanguage,
  }) async {
    try {
      final pdf = pw.Document();
      final dateFormatter = DateFormat('yyyy-MM-dd HH:mm:ss');
      final exportDate = dateFormatter.format(DateTime.now());

      // Split content into pages (roughly 50 lines per page)
      final lines = content.split('\n');
      final linesPerPage = 50;
      final pageCount = (lines.length / linesPerPage).ceil();

      for (int pageNum = 0; pageNum < pageCount; pageNum++) {
        final startLine = pageNum * linesPerPage;
        final endLine = ((pageNum + 1) * linesPerPage).clamp(0, lines.length);
        final pageContent = lines.sublist(startLine, endLine).join('\n');

        pdf.addPage(
          pw.Page(
            build: (pw.Context context) {
              return pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Header
                  pw.Container(
                    decoration: pw.BoxDecoration(
                      border: pw.Border(
                        bottom: pw.BorderSide(width: 1),
                      ),
                    ),
                    padding: const pw.EdgeInsets.only(bottom: 12),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          documentName,
                          style: pw.TextStyle(
                            fontSize: 18,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.SizedBox(height: 6),
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text(
                              'Exported: $exportDate',
                              style: const pw.TextStyle(fontSize: 10),
                            ),
                            if (detectedLanguage != null)
                              pw.Text(
                                'Language: $detectedLanguage',
                                style: const pw.TextStyle(fontSize: 10),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 12),

                  // Content
                  pw.Expanded(
                    child: pw.Text(
                      pageContent,
                      style: const pw.TextStyle(fontSize: 11),
                    ),
                  ),

                  // Footer
                  pw.SizedBox(height: 12),
                  pw.Container(
                    decoration: pw.BoxDecoration(
                      border: pw.Border(
                        top: pw.BorderSide(width: 1),
                      ),
                    ),
                    padding: const pw.EdgeInsets.only(top: 12),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          'LexiLens',
                          style: const pw.TextStyle(fontSize: 9),
                        ),
                        pw.Text(
                          'Page ${pageNum + 1} of $pageCount',
                          style: const pw.TextStyle(fontSize: 9),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        );
      }

      // Save PDF to temporary directory
      final directory = await getTemporaryDirectory();
      final fileName = '${documentName}_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final file = File('${directory.path}/$fileName');

      final bytes = await pdf.save();
      await file.writeAsBytes(bytes);
      print('✅ PDF file exported: ${file.path}');
      return file;
    } catch (e) {
      print('❌ Error exporting PDF: $e');
      return null;
    }
  }

  /// Share document via native sharing mechanism
  Future<bool> shareDocument({
    required String documentName,
    required String content,
    required String format, // 'text' or 'pdf'
    String? detectedLanguage,
  }) async {
    try {
      File? fileToShare;

      if (format == 'pdf') {
        fileToShare = await exportAsPDF(
          documentName: documentName,
          content: content,
          detectedLanguage: detectedLanguage,
        );
      } else {
        fileToShare = await exportAsText(
          documentName: documentName,
          content: content,
        );
      }

      if (fileToShare == null || !await fileToShare.exists()) {
        print('❌ File not created for sharing');
        return false;
      }

      await Share.shareXFiles(
        [XFile(fileToShare.path)],
        text: 'Check out this document: $documentName',
        subject: documentName,
      );

      print('✅ Document share invocation succeeded');
      return true;
    } catch (e) {
      print('❌ Error sharing document: $e');
      return false;
    }
  }

  /// Share via text content (quick share without file export)
  Future<bool> shareText({
    required String documentName,
    required String content,
  }) async {
    try {
      await Share.share(
        content,
        subject: documentName,
      );

      print('✅ Text share invocation succeeded');
      return true;
    } catch (e) {
      print('❌ Error sharing text: $e');
      return false;
    }
  }

  /// Clean up temporary files (optional)
  Future<void> cleanupTemporaryFiles() async {
    try {
      final directory = await getTemporaryDirectory();
      final files = directory.listSync();
      
      for (final file in files) {
        if (file is File && (file.path.endsWith('.pdf') || file.path.endsWith('.txt'))) {
          await file.delete();
          print('🗑️ Cleaned up: ${file.path}');
        }
      }
    } catch (e) {
      print('⚠️ Error cleaning up temporary files: $e');
    }
  }
}
