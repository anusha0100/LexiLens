// lib/services/text_selection_service.dart
class TextSelectionService {
  static final TextSelectionService _instance = TextSelectionService._internal();
  factory TextSelectionService() => _instance;
  TextSelectionService._internal();

  // Improved word extraction with better boundaries
  List<String> extractWords(String text) {
    if (text.isEmpty) return [];
    
    // Remove extra whitespace and normalize
    text = text.trim().replaceAll(RegExp(r'\s+'), ' ');
    
    // Split by spaces but keep punctuation with words
    final words = <String>[];
    final buffer = StringBuffer();
    
    for (int i = 0; i < text.length; i++) {
      final char = text[i];
      
      if (char == ' ' || char == '\n' || char == '\t') {
        if (buffer.isNotEmpty) {
          words.add(buffer.toString());
          buffer.clear();
        }
      } else {
        buffer.write(char);
      }
    }
    
    if (buffer.isNotEmpty) {
      words.add(buffer.toString());
    }
    
    return words;
  }

  // Clean word for display (remove punctuation)
  String cleanWord(String word) {
    return word.replaceAll(RegExp(r'[^\w\s]'), '');
  }

  // Get word boundaries for precise highlighting
  List<WordBoundary> getWordBoundaries(String text) {
    final boundaries = <WordBoundary>[];
    final words = extractWords(text);
    int currentPosition = 0;
    
    for (int i = 0; i < words.length; i++) {
      final word = words[i];
      final startIndex = text.indexOf(word, currentPosition);
      
      if (startIndex != -1) {
        boundaries.add(WordBoundary(
          word: word,
          startIndex: startIndex,
          endIndex: startIndex + word.length,
          wordIndex: i,
        ));
        currentPosition = startIndex + word.length;
      }
    }
    
    return boundaries;
  }
}

class WordBoundary {
  final String word;
  final int startIndex;
  final int endIndex;
  final int wordIndex;

  WordBoundary({
    required this.word,
    required this.startIndex,
    required this.endIndex,
    required this.wordIndex,
  });
}