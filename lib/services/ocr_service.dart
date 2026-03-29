import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:lexilens/services/mongodb_service.dart';

/// A single in-memory cache entry.
class _CacheEntry {
  final Map<String, dynamic> result;
  DateTime lastAccessed;
  int accessCount;

  _CacheEntry(this.result)
      : lastAccessed = DateTime.now(),
        accessCount = 1;
}

class OCRService {
  static final OCRService _instance = OCRService._internal();
  factory OCRService() => _instance;
  OCRService._internal();

  TextRecognizer? _latinRecognizer;
  TextRecognizer? _devanagariRecognizer;

  // ── In-memory LRU cache (SDS DFD process 1.3 / D1 OCR Cache) ───────────────
  // Capacity-bounded map; oldest-accessed entry is evicted when full.
  static const int _maxCacheSize = 50;
  final _memCache = <String, _CacheEntry>{};
  int _hitCount = 0;
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

  // ── Cache helpers ────────────────────────────────────────────────────────────

  /// Compute a SHA-256 hash of the image file bytes, used as the cache key.
  String _hashImageBytes(Uint8List bytes) {
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Look up [imageHash] in the in-memory cache.
  /// Updates [lastAccessed] and [accessCount] on a hit.
  Map<String, dynamic>? _memCacheGet(String imageHash) {
    final entry = _memCache[imageHash];
    if (entry == null) return null;
    entry.lastAccessed = DateTime.now();
    entry.accessCount++;
    _hitCount++;
    return Map<String, dynamic>.from(entry.result);
  }

  /// Insert [result] into the in-memory cache under [imageHash].
  /// Evicts the least-recently-accessed entry when at capacity.
  void _memCachePut(String imageHash, Map<String, dynamic> result) {
    if (_memCache.length >= _maxCacheSize) {
      // Find and remove the entry with the oldest lastAccessed timestamp.
      String? evictKey;
      DateTime? oldest;
      for (final kv in _memCache.entries) {
        if (oldest == null || kv.value.lastAccessed.isBefore(oldest)) {
          oldest = kv.value.lastAccessed;
          evictKey = kv.key;
        }
      }
      if (evictKey != null) _memCache.remove(evictKey);
    }
    _memCache[imageHash] = _CacheEntry(result);
  }

  // ── Public API ───────────────────────────────────────────────────────────────

  /// Returns cache hit/miss statistics for diagnostics.
  Map<String, int> get cacheStats => {
        'hits': _hitCount,
        'misses': _missCount,
        'size': _memCache.length,
      };

  /// Main entry point: checks memory cache → remote cache → ML Kit pipeline.
  ///
  /// [imageBytes] is optional; when provided the image is hashed for caching.
  /// When null (e.g. from a live-AR frame where bytes are not readily
  /// available), caching is skipped and the image is processed directly.
  Future<Map<String, dynamic>> extractTextWithLanguage(
    String imagePath, {
    Uint8List? imageBytes,
  }) async {
    // ── 1. Hash the image ──────────────────────────────────────────────────
    String? imageHash;
    if (imageBytes != null) {
      imageHash = _hashImageBytes(imageBytes);

      // ── 2. Memory cache hit ────────────────────────────────────────────
      final memHit = _memCacheGet(imageHash);
      if (memHit != null) {
        print('🟢 OCR memory cache hit for $imageHash '
            '(access #${_memCache[imageHash]?.accessCount})');
        return memHit;
      }

      // ── 3. Remote cache hit ────────────────────────────────────────────
      final remoteHit = await _mongoService.getOcrCache(imageHash);
      if (remoteHit != null) {
        print('🟡 OCR remote cache hit for $imageHash');
        _hitCount++;
        final result = {
          'text': remoteHit['recognizedText'] ?? '',
          'blocks': <TextBlock>[],   // blocks are not stored remotely
          'language': remoteHit['languageDetected'] ?? 'Unknown',
          'script': 'Unknown',
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

    // ── 4. Full ML Kit pipeline (SDS processes 1.2 Preprocess + 1.3 Recognize)
    final stopwatch = Stopwatch()..start();

    try {
      final inputImage = InputImage.fromFilePath(imagePath);

      print('📖 Attempting Latin script recognition...');
      final latinResult = await _latinTextRecognizer.processImage(inputImage);

      print('📖 Attempting Devanagari script recognition...');
      final devanagariResult =
          await _devanagariTextRecognizer.processImage(inputImage);

      RecognizedText recognizedText;
      String detectedScript;

      final devanagariCharCount =
          RegExp(r'[\u0900-\u097F]').allMatches(devanagariResult.text).length;
      final latinCharCount =
          latinResult.text.replaceAll(RegExp(r'\s'), '').length;
      final devanagariTotalChars =
          devanagariResult.text.replaceAll(RegExp(r'\s'), '').length;

      if (devanagariCharCount > 0 &&
          devanagariTotalChars >= latinCharCount * 0.8) {
        recognizedText = devanagariResult;
        detectedScript = 'Devanagari';
        print('✅ Using Devanagari script ($devanagariCharCount chars)');
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

      stopwatch.stop();
      final processingTimeMs = stopwatch.elapsedMilliseconds;

      final detectedLanguage =
          _detectLanguageFromText(recognizedText.text, detectedScript);

      print('Extracted text length: ${recognizedText.text.length}');
      print('Detected language: $detectedLanguage');
      print('Detected script: $detectedScript');
      print('Processing time: ${processingTimeMs}ms');

      // ── 5. Compute average confidence score ──────────────────────────────
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
        'text': recognizedText.text,
        'blocks': recognizedText.blocks,
        'language': detectedLanguage,
        'script': detectedScript,
        'canUseOpenDyslexic': _canUseOpenDyslexic(detectedLanguage),
        'processingTimeMs': processingTimeMs,
        'confidenceScore': avgConfidence,
        'fromCache': false,
      };

      // ── 6. Store in caches on miss (SDS DFD 1.4 — store on miss) ────────
      if (imageHash != null) {
        _memCachePut(imageHash, result);
        // Fire-and-forget; do not await to avoid blocking the caller.
        _mongoService.putOcrCache(
          imageHash: imageHash,
          recognizedText: recognizedText.text,
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

  // ── Language detection ───────────────────────────────────────────────────────

  String _detectLanguageFromText(String text, String script) {
    if (text.isEmpty) return 'Unknown';

    if (script == 'Devanagari' || _containsDevanagari(text)) {
      if (_looksLikeMarathi(text)) return 'Marathi';
      if (_looksLikeSanskrit(text)) return 'Sanskrit';
      return 'Hindi';
    }

    final scores = <String, int>{
      'Spanish': _scoreSpanish(text),
      'French': _scoreFrench(text),
      'German': _scoreGerman(text),
      'Italian': _scoreItalian(text),
      'Portuguese': _scorePortuguese(text),
      'Dutch': _scoreDutch(text),
    };

    String best = 'English';
    int bestScore = 2;
    for (final entry in scores.entries) {
      if (entry.value > bestScore) {
        bestScore = entry.value;
        best = entry.key;
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

  // ── Script helpers ───────────────────────────────────────────────────────────

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

  // ── Scored Latin-language detectors ─────────────────────────────────────────

  int _scoreSpanish(String text) {
    int score = 0;
    final lower = text.toLowerCase();
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