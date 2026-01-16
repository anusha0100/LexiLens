class DocumentModel {
  final String? id;
  final String userId;
  final String name;
  final String content;
  final String? filePath;
  final DateTime uploadedDate;
  final DateTime? lastReadDate;
  final List<String> tags;
  final bool isFavorite;

  DocumentModel({
    this.id,
    required this.userId,
    required this.name,
    required this.content,
    this.filePath,
    required this.uploadedDate,
    this.lastReadDate,
    this.tags = const [],
    this.isFavorite = false,
  });

  Map<String, dynamic> toJson() => {
    if (id != null) '_id': id,
    'userId': userId,
    'fileName': name,
    'documentText': content,
    if (filePath != null) 'filePath': filePath,
    'uploadedDate': uploadedDate.toIso8601String(),
    if (lastReadDate != null) 'lastReadDate': lastReadDate!.toIso8601String(),
    'tags': tags,
    'isFavorite': isFavorite,
  };

  factory DocumentModel.fromJson(Map<String, dynamic> json) => DocumentModel(
    id: json['_id']?.toString(),
    userId: json['userId'] ?? '',
    name: json['fileName'] ?? 'Untitled',
    content: json['documentText'] ?? '',
    filePath: json['filePath'],
    uploadedDate: json['uploadedDate'] != null 
        ? DateTime.parse(json['uploadedDate']) 
        : DateTime.now(),
    lastReadDate: json['lastReadDate'] != null 
        ? DateTime.parse(json['lastReadDate']) 
        : null,
    tags: List<String>.from(json['tags'] ?? []),
    isFavorite: json['isFavorite'] ?? false,
  );
}

