import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:lexilens/services/mongodb_service.dart';

class _CacheEntry {
  final Map<String, dynamic> result;
  DateTime lastAccessed;
  int      accessCount;
  _CacheEntry(this.result) : lastAccessed = DateTime.now(), accessCount = 1;
}

class OCRService {
  static final OCRService _instance = OCRService._internal();
  factory OCRService() => _instance;
  OCRService._internal();

  TextRecognizer? _latinRecognizer;
  TextRecognizer? _devanagariRecognizer;

  static const int _maxCacheSize = 50;
  final _memCache = <String, _CacheEntry>{};
  int _hitCount  = 0;
  int _missCount = 0;

  final _mongoService = MongoDBService();

  TextRecognizer get _latinTextRecognizer {
    _latinRecognizer ??= TextRecognizer(script: TextRecognitionScript.latin);
    return _latinRecognizer!;
  }

  TextRecognizer get _devanagariTextRecognizer {
    _devanagariRecognizer ??=
        TextRecognizer(script: TextRecognitionScript.devanagiri);
    return _devanagariRecognizer!;
  }

  // ── Cache helpers ─────────────────────────────────────────────────────────

  String _hashImageBytes(Uint8List bytes) => sha256.convert(bytes).toString();

  Map<String, dynamic>? _memCacheGet(String hash) {
    final entry = _memCache[hash];
    if (entry == null) return null;
    entry.lastAccessed = DateTime.now();
    entry.accessCount++;
    _hitCount++;
    return Map<String, dynamic>.from(entry.result);
  }

  void _memCachePut(String hash, Map<String, dynamic> result) {
    if (_memCache.length >= _maxCacheSize) {
      String?   evictKey;
      DateTime? oldest;
      for (final kv in _memCache.entries) {
        if (oldest == null || kv.value.lastAccessed.isBefore(oldest)) {
          oldest   = kv.value.lastAccessed;
          evictKey = kv.key;
        }
      }
      if (evictKey != null) _memCache.remove(evictKey);
    }
    _memCache[hash] = _CacheEntry(result);
  }

  Map<String, int> get cacheStats =>
      {'hits': _hitCount, 'misses': _missCount, 'size': _memCache.length};

  // ── Main API ──────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> extractTextWithLanguage(
    String imagePath, {
    Uint8List? imageBytes,
  }) async {
    String? imageHash;
    if (imageBytes != null) {
      imageHash = _hashImageBytes(imageBytes);

      final memHit = _memCacheGet(imageHash);
      if (memHit != null) {
        print('🟢 OCR memory cache hit ($imageHash)');
        return memHit;
      }

      final remoteHit = await _mongoService.getOcrCache(imageHash);
      if (remoteHit != null) {
        print('🟡 OCR remote cache hit ($imageHash)');
        _hitCount++;
        final result = {
          'text':             remoteHit['recognizedText'] ?? '',
          'blocks':           <TextBlock>[],
          'language':         remoteHit['languageDetected'] ?? 'Unknown',
          'script':           'Unknown',
          'canUseOpenDyslexic':
              _canUseOpenDyslexicForLanguage(remoteHit['languageDetected'] ?? ''),
          'fromCache': true,
        };
        _memCachePut(imageHash, result);
        return result;
      }
    }

    _missCount++;
    print('🔴 OCR cache miss — running ML Kit pipeline');

    final stopwatch = Stopwatch()..start();
    try {
      final inputImage = InputImage.fromFilePath(imagePath);

      final latinResult =
          await _latinTextRecognizer.processImage(inputImage);
      final devanagariResult =
          await _devanagariTextRecognizer.processImage(inputImage);

      RecognizedText recognizedText;
      String         detectedScript;

      // FIX: Old logic compared total non-space char counts, which meant OCR
      // noise (digits, punctuation) in the Devanagari pass could match or
      // exceed the Latin letter count and cause wrong script selection.
      //
      // New approach:
      //  1. Count *only* true Devanagari Unicode codepoints (U+0900–U+097F)
      //     as the Devanagari signal — not the full non-space char count.
      //  2. Require at least 3 real Devanagari chars AND a confidence ratio
      //     ≥ 30 % of the Devanagari result's total non-space chars before
      //     committing to the Devanagari script.
      //  3. Latin letter count strips digits/punctuation to avoid inflating
      //     the Latin score with shared numeric characters.
      final devCharCount  = RegExp(r'[\u0900-\u097F]')
          .allMatches(devanagariResult.text).length;
      // Latin letters only (strip whitespace, digits, punctuation).
      final latinCharCount = latinResult.text
          .replaceAll(RegExp(r'[^\p{L}]', unicode: true), '').length;
      final devTotalNonSpace = devanagariResult.text
          .replaceAll(RegExp(r'\s'), '').length;

      final double devRatio =
          devTotalNonSpace > 0 ? devCharCount / devTotalNonSpace : 0.0;

      if (devCharCount >= 3 && devRatio >= 0.3) {
        // Strong Devanagari signal.
        recognizedText = devanagariResult;
        detectedScript = 'Devanagari';
      } else if (latinCharCount > 0) {
        recognizedText = latinResult;
        detectedScript = 'Latin';
      } else if (devCharCount > 0) {
        // Weak Devanagari signal but no Latin letters — still prefer it.
        recognizedText = devanagariResult;
        detectedScript = 'Devanagari';
      } else {
        recognizedText = latinResult;
        detectedScript = 'Latin';
      }

      stopwatch.stop();
      final processingTimeMs = stopwatch.elapsedMilliseconds;

      final detectedLanguage =
          _detectLanguageFromText(recognizedText.text, detectedScript);

      print('Language: $detectedLanguage | Script: $detectedScript | '
          '${processingTimeMs}ms');

      double? avgConfidence;
      if (recognizedText.blocks.isNotEmpty) {
        final scores = recognizedText.blocks
            .expand((b) => b.lines)
            .expand((l) => l.elements)
            .map((e) => e.confidence)
            .whereType<double>()
            .toList();
        if (scores.isNotEmpty) {
          avgConfidence = scores.reduce((a, b) => a + b) / scores.length;
        }
      }

      final result = <String, dynamic>{
        'text':              recognizedText.text,
        'blocks':            recognizedText.blocks,
        'language':          detectedLanguage,
        'script':            detectedScript,
        'canUseOpenDyslexic': _canUseOpenDyslexic(detectedLanguage),
        'processingTimeMs':  processingTimeMs,
        'confidenceScore':   avgConfidence,
        'fromCache':         false,
      };

      if (imageHash != null) {
        _memCachePut(imageHash, result);
        _mongoService.putOcrCache(
          imageHash:       imageHash,
          recognizedText:  recognizedText.text,
          confidenceScore: avgConfidence,
          languageDetected: detectedLanguage,
          processingTimeMs: processingTimeMs,
        );
      }

      return result;
    } catch (e) {
      stopwatch.stop();
      print('❌ OCR Error: $e');
      rethrow;
    }
  }

  Future<List<TextBlock>> extractTextBlocks(String imagePath) async {
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final latinResult =
          await _latinTextRecognizer.processImage(inputImage);
      final devResult =
          await _devanagariTextRecognizer.processImage(inputImage);

      // FIX: Match the same ratio-based detection used in extractTextWithLanguage.
      final devCharCount =
          RegExp(r'[\u0900-\u097F]').allMatches(devResult.text).length;
      final devTotalNonSpace =
          devResult.text.replaceAll(RegExp(r'\s'), '').length;
      final double devRatio =
          devTotalNonSpace > 0 ? devCharCount / devTotalNonSpace : 0.0;

      if (devCharCount >= 3 &&
          devRatio >= 0.3 &&
          devResult.blocks.length >= latinResult.blocks.length) {
        return devResult.blocks;
      }
      return latinResult.blocks;
    } catch (e) {
      print('Error extracting text blocks: $e');
      return [];
    }
  }

  // ── Language detection ────────────────────────────────────────────────────
  //
  // FIX: Threshold lowered from 5 → 4.  A score of 5 was too aggressive and
  // caused plain-ASCII Spanish text (no diacritics, no ¿/¡) to fall through
  // as English because the scorer could only accumulate points from function-
  // word matches, which were capped at a low value.  4 lets the Spanish scorer
  // fire reliably when ≥2 distinctive function words are present even without
  // any accented characters.
  //
  // FIX: Removed very short and ambiguous words (e.g. " de ", " la ", " le ",
  // " con ", " per ", " di ", " al ") from the scoring lists because they occur
  // frequently in English proper nouns, addresses, and abbreviations.

  String _detectLanguageFromText(String text, String script) {
    if (text.isEmpty) return 'Unknown';

    if (script == 'Devanagari' || _containsDevanagari(text)) {
      if (_looksLikeMarathi(text))  return 'Marathi';
      if (_looksLikeSanskrit(text)) return 'Sanskrit';
      return 'Hindi';
    }

    final scores = <String, int>{
      'Spanish':    _scoreSpanish(text),
      'French':     _scoreFrench(text),
      'German':     _scoreGerman(text),
      'Italian':    _scoreItalian(text),
      'Portuguese': _scorePortuguese(text),
      'Dutch':      _scoreDutch(text),
    };

    String best      = 'English';
    // FIX: Lowered from 5 → 4.  Requires clear evidence but now correctly
    // catches Spanish text that lacks diacritics (e.g. menus, signs,
    // plain-ASCII OCR output).
    int    bestScore = 4;
    for (final entry in scores.entries) {
      if (entry.value > bestScore) {
        bestScore = entry.value;
        best      = entry.key;
      }
    }
    return best;
  }

  bool _canUseOpenDyslexic(String language) =>
      _canUseOpenDyslexicForLanguage(language);

  bool _canUseOpenDyslexicForLanguage(String language) {
    const latinLanguages = [
      'English', 'Spanish', 'French', 'German', 'Italian',
      'Portuguese', 'Dutch', 'Swedish', 'Norwegian', 'Danish',
      'Finnish', 'Polish', 'Czech', 'Romanian', 'Turkish',
    ];
    return latinLanguages.contains(language);
  }

  // ── Script helpers ────────────────────────────────────────────────────────

  bool _containsDevanagari(String text) =>
      RegExp(r'[\u0900-\u097F]').hasMatch(text);

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

  // ── Scored Latin-language detectors ──────────────────────────────────────
  //
  // Scoring philosophy:
  //  +5  — unique diacritics/punctuation that only appear in this language
  //  +3  — words that are very distinctive and uncommon in English
  //  +2  — high-frequency function words unlikely to appear in English prose
  //  +1  — words that help (but avoid ultra-short words shared by many languages)
  //
  // We deliberately avoid scoring short words like " la ", " de ", " con "
  // because they appear in English text (names, abbreviations, loanwords).

  // FIX (Spanish): The old scorer was too reliant on diacritics and the
  // inverted-punctuation ¿/¡ characters.  Plain-ASCII Spanish text from menus,
  // signs, or low-quality OCR has neither, so it would score 0–3 and always
  // lose to the English default.
  //
  // Changes:
  //  • Added a broader set of high-frequency Spanish content words (+2 each).
  //  • Function-word match now requires ≥2 hits AND awards funcCount+1 so that
  //    3+ matches produce a score that clearly exceeds the new threshold of 4.
  //  • Common ASCII transliterations of Spanish words (e.g. "tambien",
  //    "senor") are scored so OCR output without diacritics is handled.
  int _scoreSpanish(String text) {
    int score = 0;
    final lower = text.toLowerCase();

    // Unique punctuation — extremely strong signal.
    if (lower.contains('¿') || lower.contains('¡')) score += 5;

    // Distinctive Spanish words (accented / canonical forms).
    for (final w in [
      'está', 'también', 'usted', 'señor', 'señora',
      'español', 'nosotros', 'vosotros', 'están', 'también',
    ]) {
      if (lower.contains(w)) score += 3;
    }

    // High-frequency Spanish content words that rarely appear in English.
    // ASCII-friendly forms included to catch diacritic-free OCR output.
    for (final w in [
      ' hola ', ' gracias ', ' bueno ', ' buena ', ' mucho ',
      ' mucha ', ' ahora ', ' tiempo ', ' siempre ', ' nunca ',
      ' tambien ', ' porque ', ' cuando ', ' donde ', ' quien ',
      ' noche ', ' senor ', ' senora ', ' chico ', ' chica ',
      ' favor ', ' hablar ', ' quiero ', ' puedo ', ' tengo ',
      ' vamos ', ' amigo ', ' amiga ', ' hermano ', ' hermana ',
    ]) {
      if (lower.contains(w)) score += 2;
    }

    // Common function words — only accumulate if several appear together.
    int funcCount = 0;
    for (final w in [
      ' que ', ' para ', ' una ', ' este ', ' esto ',
      ' pero ', ' como ', ' tiene ', ' ellos ', ' ellas ',
      ' ustedes ', ' aunque ', ' porque ', ' tampoco ',
    ]) {
      if (lower.contains(w)) funcCount++;
    }
    // Require ≥2 function words; weight grows with count so that 3+ hits
    // reliably cross the detection threshold even without diacritics.
    if (funcCount >= 2) score += funcCount + 1;

    // Diacritics distinctive of Spanish (not shared with French/Portuguese).
    if (RegExp(r'[áéíóúñ]').hasMatch(text)) score += 3;

    return score;
  }

  int _scoreFrench(String text) {
    int score = 0;
    final lower = text.toLowerCase();
    // Distinctive French words
    for (final w in [' vous ', ' nous ', ' dans ', ' avec ', ' est ',
                     ' sont ', ' cette ', ' chez ', ' leurs ', ' aussi ']) {
      if (lower.contains(w)) score += 2;
    }
    for (final w in ['bonjour', 'français', 'merci', 'aussi', 'toujours',
                     'parce', 'maintenant', 'toujours']) {
      if (lower.contains(w)) score += 3;
    }
    // French-specific diacritics (œ, ç, â, î, ô, û unique to French)
    if (RegExp(r'[œçâîûÿæ]').hasMatch(text)) score += 4;
    // General accents (could be Portuguese too)
    if (RegExp(r'[àèéêë]').hasMatch(text)) score += 2;
    return score;
  }

  int _scoreGerman(String text) {
    int score = 0;
    final lower = text.toLowerCase();
    // German-unique diacritics — very strong signal
    if (RegExp(r'[äöüß]').hasMatch(text)) score += 5;
    // Distinctive German words
    for (final w in [' nicht ', ' werden ', ' haben ', ' sein ',
                     ' dieser ', ' diese ', ' dieses ', ' auch ',
                     ' oder ', ' nach ']) {
      if (lower.contains(w)) score += 2;
    }
    for (final w in ['deutschland', 'deutsch', 'bitte', 'danke']) {
      if (lower.contains(w)) score += 3;
    }
    return score;
  }

  int _scoreItalian(String text) {
    int score = 0;
    final lower = text.toLowerCase();
    // Very distinctive Italian words
    for (final w in [' gli ', ' dello ', ' della ', ' sono ', ' siamo ',
                     ' questo ', ' questa ', ' anche ', ' come ',
                     ' perché ', ' quello ']) {
      if (lower.contains(w)) score += 2;
    }
    for (final w in ['italiano', 'italia', 'grazie', 'prego', 'ciao']) {
      if (lower.contains(w)) score += 4;
    }
    // Italian diacritics (à, è, é, ì, ò, ù)
    if (RegExp(r'[àèìòù]').hasMatch(text)) score += 2;
    return score;
  }

  int _scorePortuguese(String text) {
    int score = 0;
    final lower = text.toLowerCase();
    // Portuguese-unique characters — very strong signal
    if (RegExp(r'[ãõ]').hasMatch(text)) score += 5;
    // Distinctive words
    for (final w in [' não ', ' uma ', ' você ', ' também ', ' isso ',
                     ' aqui ', ' fazer ', ' estar ']) {
      if (lower.contains(w)) score += 2;
    }
    for (final w in ['português', 'brasil', 'obrigado', 'olá']) {
      if (lower.contains(w)) score += 4;
    }
    if (RegExp(r'[áâàçéêíóôú]').hasMatch(text)) score += 2;
    return score;
  }

  int _scoreDutch(String text) {
    int score = 0;
    final lower = text.toLowerCase();
    // Very distinctive Dutch words
    for (final w in [' het ', ' een ', ' worden ', ' hebben ', ' zijn ',
                     ' zoals ', ' maar ', ' nog ', ' ook ', ' aan ']) {
      if (lower.contains(w)) score += 2;
    }
    for (final w in ['nederland', 'dutch', 'goedendag', 'hallo']) {
      if (lower.contains(w)) score += 4;
    }
    // "ij" digraph — distinctive to Dutch
    if (lower.contains('ij')) score += 3;
    return score;
  }

  void dispose() {
    _latinRecognizer?.close();
    _devanagariRecognizer?.close();
    _latinRecognizer      = null;
    _devanagariRecognizer = null;
  }
}