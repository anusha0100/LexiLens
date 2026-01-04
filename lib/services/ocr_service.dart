import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class OCRService {
  static final OCRService _instance = OCRService._internal();
  factory OCRService() => _instance;
  OCRService._internal();

  Future<String> extractText(String imagePath) async {
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
    
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final recognizedText = await textRecognizer.processImage(inputImage);
      return recognizedText.text;
    } catch (e) {
      print('Error extracting text: $e');
      rethrow;
    } finally {
      textRecognizer.close();
    }
  }

  Future<List<TextBlock>> extractTextBlocks(String imagePath) async {
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
    
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final recognizedText = await textRecognizer.processImage(inputImage);
      return recognizedText.blocks;
    } catch (e) {
      print('Error extracting text blocks: $e');
      rethrow;
    } finally {
      textRecognizer.close();
    }
  }
}