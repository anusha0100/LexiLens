import 'dart:async';
import 'dart:collection';
import 'package:flutter_tts/flutter_tts.dart';

// ── Voice Settings (SDS DFD D1 — Voice Settings datastore) ───────────────────
// In-memory store for the current TTS configuration.  Values are populated
// from AppSetting / UserPreferences on startup and kept in sync whenever the
// settings screen writes a change.
class VoiceSettings {
  double speechRate;
  double volume;
  double pitch;
  String languageCode;
  String? voiceName;

  VoiceSettings({
    this.speechRate = 0.5,
    this.volume = 1.0,
    this.pitch = 1.0,
    this.languageCode = 'en-US',
    this.voiceName,
  });
}

// ── Speech Queue entry (SDS DFD D2 — Speech Queue) ────────────────────────────
class _SpeechItem {
  final String text;
  final String? detectedLanguage;
  final Completer<void> completer;

  _SpeechItem({
    required this.text,
    this.detectedLanguage,
  }) : completer = Completer<void>();
}

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

  // ── Voice Settings datastore (D1) ─────────────────────────────────────────
  final VoiceSettings _voiceSettings = VoiceSettings();

  // ── Speech Queue (D2) ──────────────────────────────────────────────────────
  // A FIFO queue of pending speech items.  Each enqueued item waits for the
  // currently playing utterance to finish before it starts, so tapping a new
  // word while speech is playing no longer just stops the previous one —
  // instead the new request is serialised behind it (or inserted at the front
  // if _interrupt is true on the speak() call).
  final Queue<_SpeechItem> _queue = Queue<_SpeechItem>();
  bool _processingQueue = false;

  Function(int)? onWordHighlight;
  Function()? onComplete;
  Function()? onStart;

  bool get isPlaying => _isPlaying;
  bool get isPaused => _isPaused;
  int get currentWordIndex => _currentWordIndex;

  /// Expose a copy of the current voice settings so the UI can reflect them.
  VoiceSettings get voiceSettings => _voiceSettings;

  Future<void> initialize() async {
    try {
      _availableVoices = await _flutterTts.getVoices;
    } catch (_) {
      _availableVoices = [];
    }

    // Apply the stored voice settings (D1) to the engine.
    await _applyVoiceSettings();

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
      // Advance the queue when an utterance finishes.
      _advanceQueue();
    });

    _flutterTts.setProgressHandler((text, start, end, word) {
      if (_currentText.isNotEmpty && _words.isNotEmpty) {
        final textUpToNow = _currentText.substring(0, start);
        final wordsSoFar = textUpToNow
            .split(RegExp(r'\s+'))
            .where((w) => w.isNotEmpty)
            .length;
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
      _advanceQueue(); // Don't stall the queue on error.
    });

    _flutterTts.setCancelHandler(() {
      _isPlaying = false;
      _isPaused = false;
    });
  }

  // ── Voice Settings (D1) mutations ─────────────────────────────────────────

  /// Update speech rate in D1 and immediately apply to the engine.
  Future<void> setSpeechRate(double rate) async {
    _voiceSettings.speechRate = rate;
    await _flutterTts.setSpeechRate(rate);
  }

  /// Update volume in D1 and immediately apply to the engine.
  Future<void> setVolume(double volume) async {
    _voiceSettings.volume = volume;
    await _flutterTts.setVolume(volume);
  }

  /// Update pitch in D1 and immediately apply to the engine.
  Future<void> setPitch(double pitch) async {
    _voiceSettings.pitch = pitch;
    await _flutterTts.setPitch(pitch);
  }

  /// Update the preferred language in D1 and apply to the engine.
  Future<void> setLanguage(String lang) async {
    _voiceSettings.languageCode = lang;
    await _flutterTts.setLanguage(lang);
  }

  /// Update the preferred voice name in D1 and apply to the engine.
  Future<void> setVoiceByName(String name) async {
    _voiceSettings.voiceName = name;
    await _flutterTts.setVoice({'name': name});
  }

  /// Bulk-load all voice settings from a map (e.g. from UserPreferences).
  Future<void> applySettingsFromMap(Map<String, dynamic> prefs) async {
    if (prefs['speechRate'] != null) {
      _voiceSettings.speechRate = (prefs['speechRate'] as num).toDouble();
    }
    if (prefs['preferredLanguage'] != null) {
      _voiceSettings.languageCode = prefs['preferredLanguage'].toString();
    }
    if (prefs['preferredVoice'] != null) {
      _voiceSettings.voiceName = prefs['preferredVoice']?.toString();
    }
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

  // ── Speech Queue (D2) operations ──────────────────────────────────────────

  /// Enqueue a speech request.
  ///
  /// [interrupt]: when true, clear the queue and stop the current utterance
  ///   so the new text plays immediately (previous SDS-review behaviour was
  ///   always interrupt; this is now the explicit opt-in).
  /// [interrupt] defaults to false so that multiple tap-to-speak events are
  ///   serialised rather than cancelling each other.
  Future<void> speak(
    String text, {
    String? detectedLanguage,
    bool interrupt = false,
  }) async {
    if (text.isEmpty) return;

    if (interrupt) {
      // Clear the queue and stop the current utterance.
      _queue.clear();
      await stop();
    }

    final item = _SpeechItem(text: text, detectedLanguage: detectedLanguage);
    _queue.addLast(item);

    if (!_processingQueue) {
      _advanceQueue();
    }

    // Return a future that resolves when this item's utterance completes.
    return item.completer.future;
  }

  /// Pull the next item off the queue and speak it.
  Future<void> _advanceQueue() async {
    if (_queue.isEmpty) {
      _processingQueue = false;
      return;
    }

    _processingQueue = true;
    final item = _queue.removeFirst();

    _currentText = item.text;
    _words = item.text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    _currentWordIndex = 0;

    // Determine the language to use, consulting D1 (VoiceSettings) as the
    // persistent store — mirrors SDS DFD process 4.2 "Prepare Speech".
    String languageCode = _voiceSettings.languageCode;
    if (item.detectedLanguage != null) {
      languageCode = _getLanguageCodeFromName(item.detectedLanguage!);
    } else {
      // Content-based fallback.
      if (_containsDevanagari(item.text)) {
        languageCode = 'hi-IN';
      } else if (_looksLikeFrench(item.text)) {
        languageCode = 'fr-FR';
      } else if (_looksLikeGerman(item.text)) {
        languageCode = 'de-DE';
      } else if (_looksLikeSpanish(item.text)) {
        languageCode = 'es-ES';
      }
    }

    await _setTtsLanguageAndVoice(languageCode);
    await _flutterTts.speak(item.text);
    item.completer.complete();
  }

  Future<void> _setTtsLanguageAndVoice(String languageCode) async {
    await _flutterTts.setLanguage(languageCode);

    _availableVoices ??= await _flutterTts.getVoices;

    if (_availableVoices != null && _availableVoices!.isNotEmpty) {
      // Prefer the user's saved voice (D1) if it matches this language;
      // otherwise fall back to engine preference.
      final preferred =
          _voiceSettings.voiceName != null
              ? {'name': _voiceSettings.voiceName!}
              : _findPreferredVoice(languageCode);
      if (preferred != null) {
        await _flutterTts.setVoice(preferred);
      }
    }
  }

  Map<String, String>? _findPreferredVoice(String languageCode) {
    if (_availableVoices == null) return null;

    final code = languageCode.split('-').first.toLowerCase();

    for (final voice in _availableVoices!) {
      if (voice is Map && voice['locale'] != null) {
        final locale = voice['locale'].toString().toLowerCase();
        if (locale.startsWith(code)) {
          return {'name': voice['name']?.toString() ?? ''};
        }
      }
    }

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

  Future<void> stop() async {
    _queue.clear();
    await _flutterTts.stop();
    _isPlaying = false;
    _isPaused = false;
    _currentWordIndex = 0;
    _processingQueue = false;
  }

  // ── Deprecated shims kept for call-site compatibility ─────────────────────

  /// @deprecated Use [setSpeechRate] instead.
  Future<void> setSpeed(double speed) => setSpeechRate(speed);

  Future<List<dynamic>?> getAvailableVoices() async {
    _availableVoices ??= await _flutterTts.getVoices;
    return _availableVoices;
  }

  // ── Language helpers ────────────────────────────────────────────────────────

  bool _containsDevanagari(String text) =>
      RegExp(r'[\u0900-\u097F]').hasMatch(text);

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
    final frenchPatterns = [
      'le ', 'la ', 'les ', 'de ', 'du ', 'des ', 'et ', 'est ', 'pour '
    ];
    final lowerText = text.toLowerCase();
    return frenchPatterns.any((p) => lowerText.contains(p)) ||
        RegExp(r'[àâæçéèêëïîôùûüÿœ]').hasMatch(text);
  }

  bool _looksLikeGerman(String text) {
    final germanPatterns = [
      'der ', 'die ', 'das ', 'den ', 'dem ', 'des ', 'und ', 'ist ', 'nicht '
    ];
    final lowerText = text.toLowerCase();
    return germanPatterns.any((p) => lowerText.contains(p)) ||
        RegExp(r'[äöüß]').hasMatch(text);
  }

  bool _looksLikeSpanish(String text) {
    final spanishPatterns = [
      'el ', 'la ', 'los ', 'las ', 'que ', 'de ', 'para ', 'con '
    ];
    final lowerText = text.toLowerCase();
    return spanishPatterns.any((p) => lowerText.contains(p)) ||
        RegExp(r'[áéíóúñü]').hasMatch(text);
  }

  void dispose() {
    _flutterTts.stop();
  }
}