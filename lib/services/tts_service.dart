import 'package:flutter_tts/flutter_tts.dart';

class TTSService {
  static final TTSService _instance = TTSService._internal();
  factory TTSService() => _instance;
  TTSService._internal();

  final FlutterTts _flutterTts = FlutterTts();
  List<dynamic>? _availableVoices;
  bool _isPlaying = false;
  bool _isPaused = false;
  String _currentText = '';
  int _currentWordIndex = 0;
  List<String> _words = [];
  
  Function(int)? onWordHighlight;
  Function()? onComplete;
  Function()? onStart;

  bool get isPlaying => _isPlaying;
  bool get isPaused => _isPaused;
  int get currentWordIndex => _currentWordIndex;

  Future<void> initialize() async {
    // fetch voices early so that they are available for language switching
    try {
      _availableVoices = await _flutterTts.getVoices;
    } catch (_) {
      _availableVoices = [];
    }

    await _flutterTts.setLanguage("en-US");
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);
    _flutterTts.setStartHandler(() {
      _isPlaying = true;
      _isPaused = false;
      _currentWordIndex = 0;
      onStart?.call();
      onWordHighlight?.call(0); 
    });
    _flutterTts.setCompletionHandler(() {
      _isPlaying = false;
      _isPaused = false;
      _currentWordIndex = 0;
      onComplete?.call();
    });

    _flutterTts.setProgressHandler((text, start, end, word) {
      if (_currentText.isNotEmpty && _words.isNotEmpty) {
        String textUpToNow = _currentText.substring(0, start);
        int wordsSoFar = textUpToNow.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
        if (wordsSoFar < _words.length) {
          _currentWordIndex = wordsSoFar;
          onWordHighlight?.call(_currentWordIndex);
        }
      }
    });

    _flutterTts.setErrorHandler((msg) {
      print('TTS Error: $msg');
      _isPlaying = false;
      _isPaused = false;
    });

    _flutterTts.setCancelHandler(() {
      _isPlaying = false;
      _isPaused = false;
    });
  }

  Future<void> speak(String text, {String? detectedLanguage}) async {
    if (text.isEmpty) return;
    await stop();
    _currentText = text;
    _words = text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    _currentWordIndex = 0;

    // choose language/voice based on detected language or text content
    String languageCode = 'en-US'; // default
    if (detectedLanguage != null) {
      languageCode = _getLanguageCodeFromName(detectedLanguage);
    } else {
      // fallback to text-based detection
      if (_containsDevanagari(text)) {
        languageCode = 'hi-IN';
      } else if (_looksLikeFrench(text)) {
        languageCode = 'fr-FR';
      } else if (_looksLikeGerman(text)) {
        languageCode = 'de-DE';
      } else if (_looksLikeSpanish(text)) {
        languageCode = 'es-ES';
      }
    }

    await _setTtsLanguageAndVoice(languageCode);

    await _flutterTts.speak(text);
  }

  Future<void> _setTtsLanguageAndVoice(String languageCode) async {
    await _flutterTts.setLanguage(languageCode);

    if (_availableVoices == null) {
      _availableVoices = await _flutterTts.getVoices;
    }

    if (_availableVoices != null && _availableVoices!.isNotEmpty) {
      final preferredVoice = _findPreferredVoice(languageCode);
      if (preferredVoice != null) {
        await _flutterTts.setVoice(preferredVoice);
      }
    }
  }

  Map<String, String>? _findPreferredVoice(String languageCode) {
    if (_availableVoices == null) return null;

    final code = languageCode.split('-').first.toLowerCase();

    // 1) exact locale match (hi-IN or hi)
    for (final voice in _availableVoices!) {
      if (voice is Map && voice['locale'] != null) {
        final locale = voice['locale'].toString().toLowerCase();
        if (locale.startsWith(code)) {
          return {'name': voice['name']?.toString() ?? ''};
        }
      }
    }

    // 2) fallback on named voice hints
    for (final voice in _availableVoices!) {
      if (voice is Map && voice['name'] != null) {
        final name = voice['name'].toString().toLowerCase();
        if (code == 'hi' && name.contains('hindi')) {
          return {'name': voice['name'].toString()};
        }
        if (code == 'en' && name.contains('english')) {
          return {'name': voice['name'].toString()};
        }
        if (code == 'fr' && name.contains('french')) {
          return {'name': voice['name'].toString()};
        }
        if (code == 'de' && name.contains('german')) {
          return {'name': voice['name'].toString()};
        }
        if (code == 'es' && name.contains('spanish')) {
          return {'name': voice['name'].toString()};
        }
      }
    }

    return null;
  }

  Future<void> pause() async {
    if (_isPlaying && !_isPaused) {
      await _flutterTts.pause();
      _isPaused = true;
      _isPlaying = false;
    }
  }

  Future<void> resume() async {
    if (_isPaused && _currentText.isNotEmpty) {
      if (_currentWordIndex < _words.length) {
        final remainingText = _words.sublist(_currentWordIndex).join(' ');
        _isPaused = false;
        _isPlaying = true;
        await _flutterTts.speak(remainingText);
      } else {
        await speak(_currentText);
      }
    }
  }
  String getCurrentText() => _currentText;

  bool _containsDevanagari(String text) {
    return RegExp(r'[\u0900-\u097F]').hasMatch(text);
  }

  String _getLanguageCodeFromName(String language) {
    switch (language.toLowerCase()) {
      case 'hindi':
        return 'hi-IN';
      case 'french':
        return 'fr-FR';
      case 'german':
        return 'de-DE';
      case 'spanish':
        return 'es-ES';
      case 'english':
      default:
        return 'en-US';
    }
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

  bool _looksLikeSpanish(String text) {
    final spanishPatterns = ['el ', 'la ', 'los ', 'las ', 'que ', 'de ', 'para ', 'con '];
    final lowerText = text.toLowerCase();
    return spanishPatterns.any((pattern) => lowerText.contains(pattern)) ||
           RegExp(r'[áéíóúñü]').hasMatch(text);
  }

  Future<void> stop() async {
    await _flutterTts.stop();
    _isPlaying = false;
    _isPaused = false;
    _currentWordIndex = 0;
  }

  Future<void> setSpeed(double speed) async {
    await _flutterTts.setSpeechRate(speed);
  }

  /// Returns the list of voices provided by the platform TTS engine.
  Future<List<dynamic>?> getAvailableVoices() async {
    _availableVoices ??= await _flutterTts.getVoices;
    return _availableVoices;
  }

  /// Manually set the TTS language (e.g. 'en-US', 'hi-IN').
  Future<void> setLanguage(String lang) async {
    await _flutterTts.setLanguage(lang);
  }

  /// Manually set a specific voice by name (platform-dependent).
  Future<void> setVoiceByName(String name) async {
    await _flutterTts.setVoice({'name': name});
  }

  Future<void> setVolume(double volume) async {
    await _flutterTts.setVolume(volume);
  }

  Future<void> setPitch(double pitch) async {
    await _flutterTts.setPitch(pitch);
  }

  void dispose() {
    _flutterTts.stop();
  }
}