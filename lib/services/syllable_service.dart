// services/syllable_service.dart
class SyllableService {
  static final SyllableService _instance = SyllableService._internal();
  factory SyllableService() => _instance;
  SyllableService._internal();

  // Simple syllable detection algorithm
  List<String> breakIntoSyllables(String word) {
    word = word.toLowerCase().trim();
    
    if (word.length <= 3) {
      return [word];
    }

    // Common syllable patterns
    final syllables = <String>[];
    var remaining = word;
    
    // Handle common prefixes
    final prefixes = ['un', 're', 'in', 'dis', 'en', 'non', 'pre', 'pro', 'anti', 'de', 'mis', 'over', 'out', 'sub', 'super', 'trans', 'under'];
    for (var prefix in prefixes) {
      if (remaining.startsWith(prefix) && remaining.length > prefix.length + 2) {
        syllables.add(prefix);
        remaining = remaining.substring(prefix.length);
        break;
      }
    }
    
    // Handle common suffixes
    final suffixes = ['ing', 'ed', 'tion', 'sion', 'ness', 'ment', 'ly', 'er', 'est', 'ful', 'less', 'able', 'ible'];
    String? suffix;
    for (var suf in suffixes) {
      if (remaining.endsWith(suf) && remaining.length > suf.length + 2) {
        suffix = suf;
        remaining = remaining.substring(0, remaining.length - suf.length);
        break;
      }
    }
    
    // Split the middle part
    final vowels = 'aeiouy';
    var currentSyllable = '';
    var lastWasVowel = false;
    
    for (var i = 0; i < remaining.length; i++) {
      final char = remaining[i];
      final isVowel = vowels.contains(char);
      
      if (isVowel) {
        currentSyllable += char;
        lastWasVowel = true;
      } else {
        if (lastWasVowel && currentSyllable.length >= 2) {
          // Check if we should split here
          if (i < remaining.length - 1) {
            final nextIsVowel = vowels.contains(remaining[i + 1]);
            if (!nextIsVowel) {
              currentSyllable += char;
              syllables.add(currentSyllable);
              currentSyllable = '';
              lastWasVowel = false;
              continue;
            }
          }
        }
        currentSyllable += char;
        lastWasVowel = false;
      }
    }
    
    if (currentSyllable.isNotEmpty) {
      syllables.add(currentSyllable);
    }
    
    if (suffix != null) {
      syllables.add(suffix);
    }
    
    // Fallback: if no syllables detected, return original word
    if (syllables.isEmpty) {
      return [word];
    }
    
    return syllables;
  }

  String formatSyllables(List<String> syllables) {
    return syllables.join('·');
  }
}