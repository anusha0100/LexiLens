// lib/services/ocr_service.dart
import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class OCRService {
  static final OCRService _instance = OCRService._internal();
  factory OCRService() => _instance;
  OCRService._internal();

  TextRecognizer? _latinRecognizer;
  TextRecognizer? _devanagariRecognizer;

  // Get or create Latin recognizer (English, Spanish, French, German, etc.)
  TextRecognizer get _latinTextRecognizer {
    _latinRecognizer ??= TextRecognizer(script: TextRecognitionScript.latin);
    return _latinRecognizer!;
  }

  // Get or create Devanagari recognizer (Hindi, Sanskrit, Marathi)
  TextRecognizer get _devanagariTextRecognizer {
    _devanagariRecognizer ??= TextRecognizer(script: TextRecognitionScript.devanagiri);
    return _devanagariRecognizer!;
  }

  /// Extract text with automatic language detection
  Future<Map<String, dynamic>> extractTextWithLanguage(String imagePath) async {
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      
      print('🔍 Starting OCR with language detection...');
      
      // Try Latin script first
      print('📖 Attempting Latin script recognition...');
      var latinResult = await _latinTextRecognizer.processImage(inputImage);
      
      // Try Devanagari script
      print('📖 Attempting Devanagari script recognition...');
      var devanagariResult = await _devanagariTextRecognizer.processImage(inputImage);
      
      // Determine which result is better
      RecognizedText recognizedText;
      String detectedScript;
      
      if (devanagariResult.text.length > latinResult.text.length) {
        // Devanagari has more text
        recognizedText = devanagariResult;
        detectedScript = 'Devanagari';
        print('✅ Using Devanagari script (${devanagariResult.text.length} chars)');
      } else if (latinResult.text.length > 10) {
        // Latin has sufficient text
        recognizedText = latinResult;
        detectedScript = 'Latin';
        print('✅ Using Latin script (${latinResult.text.length} chars)');
      } else if (devanagariResult.text.length > 0) {
        // Fall back to Devanagari if Latin failed
        recognizedText = devanagariResult;
        detectedScript = 'Devanagari';
        print('✅ Using Devanagari script as fallback');
      } else {
        // Use Latin as last resort
        recognizedText = latinResult;
        detectedScript = 'Latin';
        print('⚠️ Using Latin script as last resort');
      }

      final detectedLanguage = _detectLanguageFromText(recognizedText.text, detectedScript);
      
      print('📝 Extracted text length: ${recognizedText.text.length}');
      print('🌍 Detected language: $detectedLanguage');
      print('📜 Detected script: $detectedScript');
      
      return {
        'text': recognizedText.text,
        'blocks': recognizedText.blocks,
        'language': detectedLanguage,
        'script': detectedScript,
        'canUseOpenDyslexic': _canUseOpenDyslexic(detectedLanguage),
      };
    } catch (e) {
      print('❌ OCR Error: $e');
      rethrow;
    }
  }

  /// Extract text blocks for overlay
  Future<List<TextBlock>> extractTextBlocks(String imagePath) async {
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      
      // Try both scripts
      var latinResult = await _latinTextRecognizer.processImage(inputImage);
      var devanagariResult = await _devanagariTextRecognizer.processImage(inputImage);
      
      // Return the one with more blocks
      if (devanagariResult.blocks.length > latinResult.blocks.length) {
        return devanagariResult.blocks;
      } else {
        return latinResult.blocks;
      }
    } catch (e) {
      print('Error extracting text blocks: $e');
      return [];
    }
  }

  /// Detect specific language from text content and script
  String _detectLanguageFromText(String text, String script) {
    if (text.isEmpty) return 'Unknown';
    
    // Check for Devanagari script first
    if (script == 'Devanagari' || _containsDevanagari(text)) {
      // Check for specific Devanagari languages
      if (_looksLikeMarathi(text)) return 'Marathi';
      if (_looksLikeSanskrit(text)) return 'Sanskrit';
      return 'Hindi'; // Default for Devanagari
    }
    
    // For Latin script, detect specific language
    if (_looksLikeSpanish(text)) return 'Spanish';
    if (_looksLikeFrench(text)) return 'French';
    if (_looksLikeGerman(text)) return 'German';
    if (_looksLikeItalian(text)) return 'Italian';
    if (_looksLikePortuguese(text)) return 'Portuguese';
    if (_looksLikeDutch(text)) return 'Dutch';
    
    // Default to English for Latin script
    return 'English';
  }

  /// Check if OpenDyslexic font can be used for this language
  bool _canUseOpenDyslexic(String language) {
    // OpenDyslexic works well with Latin-based scripts only
    final latinLanguages = [
      'English',
      'Spanish',
      'French',
      'German',
      'Italian',
      'Portuguese',
      'Dutch',
      'Swedish',
      'Norwegian',
      'Danish',
      'Finnish',
      'Polish',
      'Czech',
      'Romanian',
      'Turkish',
    ];
    
    return latinLanguages.contains(language);
  }

  // Character pattern detection helpers
  bool _containsDevanagari(String text) {
    // Devanagari Unicode range: U+0900 to U+097F
    return RegExp(r'[\u0900-\u097F]').hasMatch(text);
  }

  bool _looksLikeHindi(String text) {
    // Hindi uses Devanagari script with specific common words
    if (!_containsDevanagari(text)) return false;
    
    // Common Hindi words (in Devanagari)
    final hindiPatterns = [
      'का', 'की', 'के', 'में', 'से', 'को', 'है', 'हैं', 'था', 'थी', 'और'
    ];
    
    return hindiPatterns.any((pattern) => text.contains(pattern));
  }

  bool _looksLikeMarathi(String text) {
    if (!_containsDevanagari(text)) return false;
    
    // Marathi-specific characters and patterns
    // Marathi uses additional characters like ळ (ḷa)
    return RegExp(r'[\u0933]').hasMatch(text) || // ळ
           text.contains('आहे') || // Common Marathi word
           text.contains('होते');
  }

  bool _looksLikeSanskrit(String text) {
    if (!_containsDevanagari(text)) return false;
    
    // Sanskrit uses more complex conjuncts and Vedic accents
    return RegExp(r'[\u0951\u0952\u0970]').hasMatch(text) ||
           text.contains('॥'); // Sanskrit verse marker
  }

  // Latin language detection helpers
  bool _looksLikeSpanish(String text) {
    final spanishPatterns = ['el ', 'la ', 'los ', 'las ', 'que ', 'de ', 'para ', 'con '];
    final lowerText = text.toLowerCase();
    return spanishPatterns.any((pattern) => lowerText.contains(pattern)) ||
           RegExp(r'[áéíóúñü]').hasMatch(text);
  }

  bool _looksLikeFrench(String text) {
    final frenchPatterns = ['le ', 'la ', 'les ', 'de ', 'du ', 'des ', 'et ', 'est ', 'pour '];
    final lowerText = text.toLowerCase();
    return frenchPatterns.any((pattern) => lowerText.contains(pattern)) ||
           RegExp(r'[àâæçéèêëïîôùûüÿœ]').hasMatch(text);
  }

  bool _looksLikeGerman(String text) {
    final germanPatterns = ['der ', 'die ', 'das ', 'den ', 'dem ', 'des ', 'und ', 'ist ', 'nicht '];
    final lowerText = text.toLowerCase();
    return germanPatterns.any((pattern) => lowerText.contains(pattern)) ||
           RegExp(r'[äöüß]').hasMatch(text);
  }

  bool _looksLikeItalian(String text) {
    final italianPatterns = ['il ', 'la ', 'le ', 'gli ', 'di ', 'che ', 'per ', 'con '];
    final lowerText = text.toLowerCase();
    return italianPatterns.any((pattern) => lowerText.contains(pattern)) ||
           RegExp(r'[àèéìíîòóùú]').hasMatch(text);
  }

  bool _looksLikePortuguese(String text) {
    final portuguesePatterns = ['o ', 'a ', 'os ', 'as ', 'de ', 'para ', 'com ', 'em '];
    final lowerText = text.toLowerCase();
    return portuguesePatterns.any((pattern) => lowerText.contains(pattern)) ||
           RegExp(r'[ãáàâçéêíóôõú]').hasMatch(text);
  }

  bool _looksLikeDutch(String text) {
    final dutchPatterns = ['de ', 'het ', 'een ', 'van ', 'en ', 'op ', 'is ', 'voor '];
    final lowerText = text.toLowerCase();
    return dutchPatterns.any((pattern) => lowerText.contains(pattern)) ||
           RegExp(r'ij').hasMatch(text.toLowerCase());
  }

  /// Clean up resources
  void dispose() {
    _latinRecognizer?.close();
    _devanagariRecognizer?.close();
    _latinRecognizer = null;
    _devanagariRecognizer = null;
  }
}