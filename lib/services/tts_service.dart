import 'package:flutter_tts/flutter_tts.dart';

class TTSService {
  static final TTSService _instance = TTSService._internal();
  factory TTSService() => _instance;
  TTSService._internal();

  final FlutterTts _flutterTts = FlutterTts();
  bool _isPlaying = false;
  bool _isPaused = false;
  String _currentText = '';
  int _currentWordIndex = 0;
  List<String> _words = [];
  
  // Callbacks
  Function(int)? onWordHighlight;
  Function()? onComplete;
  Function()? onStart;

  bool get isPlaying => _isPlaying;
  bool get isPaused => _isPaused;
  int get currentWordIndex => _currentWordIndex;

  Future<void> initialize() async {
    await _flutterTts.setLanguage("en-US");
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);

    // Set up handlers
    _flutterTts.setStartHandler(() {
      _isPlaying = true;
      _isPaused = false;
      _currentWordIndex = 0;
      onStart?.call();
      onWordHighlight?.call(0); // Highlight first word immediately
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

  Future<void> speak(String text) async {
    if (text.isEmpty) return;
    await stop();
    _currentText = text;
    _words = text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    _currentWordIndex = 0;
    
    await _flutterTts.speak(text);
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
    await _flutterTts.stop();
    _isPlaying = false;
    _isPaused = false;
    _currentWordIndex = 0;
  }

  Future<void> setSpeed(double speed) async {
    await _flutterTts.setSpeechRate(speed);
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