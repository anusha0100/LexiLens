import 'dart:async';
import 'dart:collection';
import 'package:flutter_tts/flutter_tts.dart';

class VoiceSettings {
  double  speechRate;
  double  volume;
  double  pitch;
  String  languageCode;
  String? voiceName;

  VoiceSettings({
    this.speechRate   = 0.5,
    this.volume       = 1.0,
    this.pitch        = 1.0,
    this.languageCode = 'en-US',
    this.voiceName,
  });
}

class _SpeechItem {
  final String  text;
  final String? detectedLanguage;
  final Completer<void> completer;

  _SpeechItem({required this.text, this.detectedLanguage})
      : completer = Completer<void>();
}

class TTSService {
  static final TTSService _instance = TTSService._internal();
  factory TTSService() => _instance;
  TTSService._internal();

  final FlutterTts _flutterTts = FlutterTts();
  List<dynamic>?   _availableVoices;

  bool   _isPlaying       = false;
  bool   _isPaused        = false;
  String _currentText     = '';
  int    _currentWordIndex = 0;
  List<String> _words     = [];

  final VoiceSettings _voiceSettings = VoiceSettings();
  final Queue<_SpeechItem> _queue    = Queue<_SpeechItem>();
  bool _processingQueue = false;

  Function(int)? onWordHighlight;
  Function()?    onComplete;
  Function()?    onStart;

  bool get isPlaying        => _isPlaying;
  bool get isPaused         => _isPaused;
  int  get currentWordIndex => _currentWordIndex;
  VoiceSettings get voiceSettings => _voiceSettings;

  // ── Init ──────────────────────────────────────────────────────────────────

  Future<void> initialize() async {
    try {
      _availableVoices = await _flutterTts.getVoices;
    } catch (_) {
      _availableVoices = [];
    }

    await _applyVoiceSettings();

    _flutterTts.setStartHandler(() {
      _isPlaying       = true;
      _isPaused        = false;
      _currentWordIndex = 0;
      onStart?.call();
      onWordHighlight?.call(0);
    });

    _flutterTts.setCompletionHandler(() {
      _isPlaying        = false;
      _isPaused         = false;
      _currentWordIndex = 0;
      onComplete?.call();
      _advanceQueue();
    });

    _flutterTts.setProgressHandler((text, start, end, word) {
      if (_currentText.isNotEmpty && _words.isNotEmpty) {
        final upToNow   = _currentText.substring(0, start);
        final wordsSoFar = upToNow.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
        if (wordsSoFar < _words.length) {
          _currentWordIndex = wordsSoFar;
          onWordHighlight?.call(_currentWordIndex);
        }
      }
    });

    _flutterTts.setErrorHandler((msg) {
      print('TTS Error: $msg');
      _isPlaying = false;
      _isPaused  = false;
      _advanceQueue();
    });

    _flutterTts.setCancelHandler(() {
      _isPlaying = false;
      _isPaused  = false;
    });
  }

  // ── Settings ──────────────────────────────────────────────────────────────

  Future<void> setSpeechRate(double rate) async {
    _voiceSettings.speechRate = rate;
    await _flutterTts.setSpeechRate(rate);
  }

  Future<void> setVolume(double volume) async {
    _voiceSettings.volume = volume;
    await _flutterTts.setVolume(volume);
  }

  Future<void> setPitch(double pitch) async {
    _voiceSettings.pitch = pitch;
    await _flutterTts.setPitch(pitch);
  }

  Future<void> setLanguage(String lang) async {
    _voiceSettings.languageCode = lang;
    await _flutterTts.setLanguage(lang);
  }

  Future<void> setVoiceByName(String name) async {
    _voiceSettings.voiceName = name;
    await _flutterTts.setVoice({'name': name});
  }

  Future<void> applySettingsFromMap(Map<String, dynamic> prefs) async {
    if (prefs['speechRate']        != null) _voiceSettings.speechRate   = (prefs['speechRate'] as num).toDouble();
    if (prefs['preferredLanguage'] != null) _voiceSettings.languageCode = prefs['preferredLanguage'].toString();
    if (prefs['preferredVoice']    != null) _voiceSettings.voiceName    = prefs['preferredVoice']?.toString();
    await _applyVoiceSettings();
  }

  Future<void> _applyVoiceSettings() async {
    await _flutterTts.setLanguage(_voiceSettings.languageCode);
    await _flutterTts.setSpeechRate(_voiceSettings.speechRate);
    await _flutterTts.setVolume(_voiceSettings.volume);
    await _flutterTts.setPitch(_voiceSettings.pitch);
    if (_voiceSettings.voiceName != null) {
      await _flutterTts.setVoice({'name': _voiceSettings.voiceName!});
    }
  }

  // ── Speak ─────────────────────────────────────────────────────────────────

  /// FIX: [interrupt] now defaults to TRUE.
  /// Every new speak() call (word tap, play button, back-to-back sentences)
  /// immediately stops the previous utterance so audio is always responsive.
  /// Pass interrupt:false only if you explicitly want serialised playback.
  Future<void> speak(
    String text, {
    String? detectedLanguage,
    bool interrupt = true,
  }) async {
    if (text.trim().isEmpty) return;

    if (interrupt) {
      _queue.clear();
      await stop();
    }

    final item = _SpeechItem(text: text, detectedLanguage: detectedLanguage);
    _queue.addLast(item);

    if (!_processingQueue) _advanceQueue();

    return item.completer.future;
  }

  Future<void> _advanceQueue() async {
    if (_queue.isEmpty) {
      _processingQueue = false;
      return;
    }

    _processingQueue  = true;
    final item        = _queue.removeFirst();
    _currentText      = item.text;
    _words            = item.text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    _currentWordIndex = 0;

    String langCode = _voiceSettings.languageCode;
    if (item.detectedLanguage != null) {
      langCode = _getLanguageCodeFromName(item.detectedLanguage!);
    } else {
      if (_containsDevanagari(item.text))  langCode = 'hi-IN';
      else if (_looksLikeFrench(item.text))  langCode = 'fr-FR';
      else if (_looksLikeGerman(item.text))  langCode = 'de-DE';
      else if (_looksLikeSpanish(item.text)) langCode = 'es-ES';
    }

    await _setTtsLanguageAndVoice(langCode);
    await _flutterTts.speak(item.text);

    // Resolve the completer immediately after handing off to the engine —
    // the engine calls the completion handler when audio actually finishes.
    if (!item.completer.isCompleted) item.completer.complete();
  }

  Future<void> _setTtsLanguageAndVoice(String languageCode) async {
    await _flutterTts.setLanguage(languageCode);
    _availableVoices ??= await _flutterTts.getVoices;
    if (_availableVoices != null && _availableVoices!.isNotEmpty) {
      final preferred = _voiceSettings.voiceName != null
          ? {'name': _voiceSettings.voiceName!}
          : _findPreferredVoice(languageCode);
      if (preferred != null) await _flutterTts.setVoice(preferred);
    }
  }

  Map<String, String>? _findPreferredVoice(String languageCode) {
    if (_availableVoices == null) return null;
    final code = languageCode.split('-').first.toLowerCase();
    for (final voice in _availableVoices!) {
      if (voice is Map && voice['locale'] != null) {
        if (voice['locale'].toString().toLowerCase().startsWith(code)) {
          return {'name': voice['name']?.toString() ?? ''};
        }
      }
    }
    return null;
  }

  // ── Pause / Resume / Stop ─────────────────────────────────────────────────

  Future<void> pause() async {
    if (_isPlaying && !_isPaused) {
      await _flutterTts.pause();
      _isPaused  = true;
      _isPlaying = false;
    }
  }

  Future<void> resume() async {
    if (!_isPaused || _currentText.isEmpty) return;

    // FIX: Rebuild the remaining text from the word list so we don't resume
    // mid-word from a stale byte-offset, and avoid calling speak() recursively.
    final remaining = _currentWordIndex < _words.length
        ? _words.sublist(_currentWordIndex).join(' ')
        : _currentText;

    _isPaused  = false;
    _isPlaying = true;

    await _setTtsLanguageAndVoice(_voiceSettings.languageCode);
    await _flutterTts.speak(remaining);
  }

  String getCurrentText() => _currentText;

  Future<void> stop() async {
    _queue.clear();
    await _flutterTts.stop();
    _isPlaying        = false;
    _isPaused         = false;
    _currentWordIndex = 0;
    _processingQueue  = false;
  }

  // ── Compat shim ───────────────────────────────────────────────────────────

  Future<void> setSpeed(double speed) => setSpeechRate(speed);

  Future<List<dynamic>?> getAvailableVoices() async {
    _availableVoices ??= await _flutterTts.getVoices;
    return _availableVoices;
  }

  // ── Language helpers ──────────────────────────────────────────────────────

  bool _containsDevanagari(String text) =>
      RegExp(r'[\u0900-\u097F]').hasMatch(text);

  String _getLanguageCodeFromName(String language) {
    switch (language.toLowerCase()) {
      case 'hindi':      return 'hi-IN';
      case 'marathi':    return 'mr-IN';
      case 'french':     return 'fr-FR';
      case 'german':     return 'de-DE';
      case 'spanish':    return 'es-ES';
      case 'italian':    return 'it-IT';
      case 'portuguese': return 'pt-PT';
      case 'dutch':      return 'nl-NL';
      case 'english':
      default:           return 'en-US';
    }
  }

  bool _looksLikeFrench(String text) {
    final lower = text.toLowerCase();
    return [' les ', ' des ', ' est ', ' vous ', ' nous ']
            .any(lower.contains) ||
        RegExp(r'[àâæçéèêëïîôùûüÿœ]').hasMatch(text);
  }

  bool _looksLikeGerman(String text) {
    final lower = text.toLowerCase();
    return [' der ', ' die ', ' das ', ' nicht ', ' werden ']
            .any(lower.contains) ||
        RegExp(r'[äöüß]').hasMatch(text);
  }

  bool _looksLikeSpanish(String text) {
    final lower = text.toLowerCase();
    return ['¿', '¡'].any(lower.contains) ||
        [' usted ', ' también ', ' están '].any(lower.contains) ||
        RegExp(r'[áéíóúñ]').hasMatch(text);
  }

  void dispose() => _flutterTts.stop();
}