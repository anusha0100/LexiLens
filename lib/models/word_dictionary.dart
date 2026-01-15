class WordDictionary {
  final String? id;
  final String word;
  final List<String> syllables;
  final String language;
  final String phonetic;

  WordDictionary({
    this.id,
    required this.word,
    required this.syllables,
    required this.language,
    required this.phonetic,
  });

  Map<String, dynamic> toJson() => {
    if (id != null) '_id': id,
    'word': word,
    'syllables': syllables,
    'language': language,
    'phonetic': phonetic,
  };

  factory WordDictionary.fromJson(Map<String, dynamic> json) => WordDictionary(
    id: json['_id']?.toString(),
    word: json['word'],
    syllables: List<String>.from(json['syllables'] ?? []),
    language: json['language'],
    phonetic: json['phonetic'],
  );
}
