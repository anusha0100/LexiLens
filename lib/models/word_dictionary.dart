class WordDictionary {
  final String? id;
  final String word;
  final String? definition;
  final String? pronunciation;
  final String? partOfSpeech;
  final List<String> examples;
  final List<String> synonyms;
  final DateTime addedDate;

  WordDictionary({
    this.id,
    required this.word,
    this.definition,
    this.pronunciation,
    this.partOfSpeech,
    this.examples = const [],
    this.synonyms = const [],
    required this.addedDate,
  });

  Map<String, dynamic> toJson() => {
    if (id != null) '_id': id,
    'word': word,
    if (definition != null) 'definition': definition,
    if (pronunciation != null) 'pronunciation': pronunciation,
    if (partOfSpeech != null) 'partOfSpeech': partOfSpeech,
    'examples': examples,
    'synonyms': synonyms,
    'addedDate': addedDate.toIso8601String(),
  };

  factory WordDictionary.fromJson(Map<String, dynamic> json) => WordDictionary(
    id: json['_id']?.toString(),
    word: json['word'] ?? '',
    definition: json['definition'],
    pronunciation: json['pronunciation'],
    partOfSpeech: json['partOfSpeech'],
    examples: List<String>.from(json['examples'] ?? []),
    synonyms: List<String>.from(json['synonyms'] ?? []),
    addedDate: json['addedDate'] != null 
        ? DateTime.parse(json['addedDate']) 
        : DateTime.now(),
  );
}
