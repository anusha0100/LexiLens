import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class OCRService {
  static final OCRService _instance = OCRService._internal();
  factory OCRService() => _instance;
  OCRService._internal();

  TextRecognizer? _latinRecognizer;
  TextRecognizer? _devanagariRecognizer;

  TextRecognizer get _latinTextRecognizer {
    _latinRecognizer ??= TextRecognizer(script: TextRecognitionScript.latin);
    return _latinRecognizer!;
  }

  TextRecognizer get _devanagariTextRecognizer {
    _devanagariRecognizer ??=
        TextRecognizer(script: TextRecognitionScript.devanagiri);
    return _devanagariRecognizer!;
  }

  Future<Map<String, dynamic>> extractTextWithLanguage(
      String imagePath) async {
    try {
      final inputImage = InputImage.fromFilePath(imagePath);

      print('🔍 Starting OCR with language detection...');

      print('📖 Attempting Latin script recognition...');
      final latinResult = await _latinTextRecognizer.processImage(inputImage);

      print('📖 Attempting Devanagari script recognition...');
      final devanagariResult =
          await _devanagariTextRecognizer.processImage(inputImage);

      RecognizedText recognizedText;
      String detectedScript;

      // Count actual Devanagari unicode characters – a reliable signal.
      final devanagariCharCount =
          RegExp(r'[\u0900-\u097F]').allMatches(devanagariResult.text).length;
      // Total printable characters (non-whitespace) in each result.
      final latinCharCount =
          latinResult.text.replaceAll(RegExp(r'\s'), '').length;
      final devanagariTotalChars =
          devanagariResult.text.replaceAll(RegExp(r'\s'), '').length;

      // Prefer Devanagari when there are genuine Devanagari codepoints AND
      // the Devanagari recogniser captured at least as much text as Latin.
      if (devanagariCharCount > 0 &&
          devanagariTotalChars >= latinCharCount * 0.8) {
        recognizedText = devanagariResult;
        detectedScript = 'Devanagari';
        print(
            '✅ Using Devanagari script ($devanagariCharCount Devanagari chars)');
      } else if (latinCharCount > 0) {
        recognizedText = latinResult;
        detectedScript = 'Latin';
        print('✅ Using Latin script ($latinCharCount chars)');
      } else if (devanagariTotalChars > 0) {
        recognizedText = devanagariResult;
        detectedScript = 'Devanagari';
        print('✅ Using Devanagari script as fallback');
      } else {
        recognizedText = latinResult;
        detectedScript = 'Latin';
        print('⚠️ Using Latin script as last resort');
      }

      final detectedLanguage =
          _detectLanguageFromText(recognizedText.text, detectedScript);

      print('Extracted text length: ${recognizedText.text.length}');
      print('Detected language: $detectedLanguage');
      print('Detected script: $detectedScript');

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

  Future<List<TextBlock>> extractTextBlocks(String imagePath) async {
    try {
      final inputImage = InputImage.fromFilePath(imagePath);

      final latinResult = await _latinTextRecognizer.processImage(inputImage);
      final devanagariResult =
          await _devanagariTextRecognizer.processImage(inputImage);

      final hasDevanagari =
          RegExp(r'[\u0900-\u097F]').hasMatch(devanagariResult.text);
      if (hasDevanagari &&
          devanagariResult.blocks.length >= latinResult.blocks.length) {
        return devanagariResult.blocks;
      }
      return latinResult.blocks;
    } catch (e) {
      print('Error extracting text blocks: $e');
      return [];
    }
  }

  // ---------------------------------------------------------------------------
  // Language detection
  // ---------------------------------------------------------------------------

  String _detectLanguageFromText(String text, String script) {
    if (text.isEmpty) return 'Unknown';

    // ── Devanagari / Indic ───────────────────────────────────────────────────
    if (script == 'Devanagari' || _containsDevanagari(text)) {
      if (_looksLikeMarathi(text)) return 'Marathi';
      if (_looksLikeSanskrit(text)) return 'Sanskrit';
      // Default Devanagari → Hindi
      return 'Hindi';
    }

    // ── Latin-script languages ──────────────────────────────────────────────
    // Score each language; return the highest-confidence match, defaulting
    // to English if nothing scores above a minimal threshold.
    final scores = <String, int>{
      'Spanish': _scoreSpanish(text),
      'French': _scoreFrench(text),
      'German': _scoreGerman(text),
      'Italian': _scoreItalian(text),
      'Portuguese': _scorePortuguese(text),
      'Dutch': _scoreDutch(text),
    };

    String best = 'English';
    int bestScore = 2; // minimum threshold to override English
    for (final entry in scores.entries) {
      if (entry.value > bestScore) {
        bestScore = entry.value;
        best = entry.key;
      }
    }
    return best;
  }

  bool _canUseOpenDyslexic(String language) {
    const latinLanguages = [
      'English', 'Spanish', 'French', 'German', 'Italian',
      'Portuguese', 'Dutch', 'Swedish', 'Norwegian', 'Danish',
      'Finnish', 'Polish', 'Czech', 'Romanian', 'Turkish',
    ];
    return latinLanguages.contains(language);
  }

  // ---------------------------------------------------------------------------
  // Script helpers
  // ---------------------------------------------------------------------------

  bool _containsDevanagari(String text) =>
      RegExp(r'[\u0900-\u097F]').hasMatch(text);

  bool _looksLikeHindi(String text) {
    if (!_containsDevanagari(text)) return false;
    const hindiPatterns = [
      'का', 'की', 'के', 'में', 'से', 'को', 'है', 'हैं', 'था', 'थी', 'और'
    ];
    return hindiPatterns.any((p) => text.contains(p));
  }

  bool _looksLikeMarathi(String text) {
    if (!_containsDevanagari(text)) return false;
    return RegExp(r'[\u0933]').hasMatch(text) ||
        text.contains('आहे') ||
        text.contains('होते') ||
        text.contains('नाही');
  }

  bool _looksLikeSanskrit(String text) {
    if (!_containsDevanagari(text)) return false;
    return RegExp(r'[\u0951\u0952\u0970]').hasMatch(text) ||
        text.contains('॥');
  }

  // ---------------------------------------------------------------------------
  // Scored Latin-language detectors
  // Each method returns an integer score; higher = more confident.
  // ---------------------------------------------------------------------------

  int _scoreSpanish(String text) {
    int score = 0;
    final lower = text.toLowerCase();
    // High-confidence function words unique(ish) to Spanish
    for (final w in ['¿', '¡', 'está', 'también', 'usted', 'señor']) {
      if (lower.contains(w)) score += 3;
    }
    for (final w in [' el ', ' la ', ' los ', ' las ', ' que ', ' con ', ' para ']) {
      if (lower.contains(w)) score += 1;
    }
    if (RegExp(r'[áéíóúñü]').hasMatch(text)) score += 2;
    return score;
  }

  int _scoreFrench(String text) {
    int score = 0;
    final lower = text.toLowerCase();
    for (final w in [' les ', ' des ', ' est ', ' une ', ' vous ', ' nous ', ' dans ', ' avec ']) {
      if (lower.contains(w)) score += 2;
    }
    for (final w in [' le ', ' la ', ' et ', ' du ', ' de ', ' pour ']) {
      if (lower.contains(w)) score += 1;
    }
    if (RegExp(r'[àâæçéèêëïîôùûüÿœ]').hasMatch(text)) score += 2;
    return score;
  }

  int _scoreGerman(String text) {
    int score = 0;
    final lower = text.toLowerCase();
    for (final w in [' der ', ' die ', ' das ', ' nicht ', ' werden ', ' haben ', ' sein ']) {
      if (lower.contains(w)) score += 2;
    }
    for (final w in [' und ', ' ist ', ' den ', ' dem ', ' des ']) {
      if (lower.contains(w)) score += 1;
    }
    if (RegExp(r'[äöüß]').hasMatch(text)) score += 3;
    return score;
  }

  int _scoreItalian(String text) {
    int score = 0;
    final lower = text.toLowerCase();
    for (final w in [' gli ', ' dello ', ' della ', ' sono ', ' questo ', ' perché ']) {
      if (lower.contains(w)) score += 3;
    }
    for (final w in [' il ', ' la ', ' le ', ' di ', ' che ', ' per ', ' con ']) {
      if (lower.contains(w)) score += 1;
    }
    if (RegExp(r'[àèéìíîòóùú]').hasMatch(text)) score += 2;
    return score;
  }

  int _scorePortuguese(String text) {
    int score = 0;
    final lower = text.toLowerCase();
    for (final w in [' não ', ' uma ', ' isso ', ' você ', ' também ']) {
      if (lower.contains(w)) score += 3;
    }
    for (final w in [' os ', ' as ', ' de ', ' para ', ' com ', ' em ']) {
      if (lower.contains(w)) score += 1;
    }
    if (RegExp(r'[ãáàâçéêíóôõú]').hasMatch(text)) score += 2;
    return score;
  }

  int _scoreDutch(String text) {
    int score = 0;
    final lower = text.toLowerCase();
    for (final w in [' het ', ' een ', ' worden ', ' hebben ', ' zijn ', ' zoals ']) {
      if (lower.contains(w)) score += 3;
    }
    for (final w in [' de ', ' van ', ' en ', ' op ', ' is ', ' voor ']) {
      if (lower.contains(w)) score += 1;
    }
    if (lower.contains('ij')) score += 2;
    return score;
  }

  void dispose() {
    _latinRecognizer?.close();
    _devanagariRecognizer?.close();
    _latinRecognizer = null;
    _devanagariRecognizer = null;
  }
} 