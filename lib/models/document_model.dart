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
    'user_id': userId,
    'name': name,
    'content': content,
    if (filePath != null) 'file_path': filePath,
    'uploaded_date': uploadedDate.toIso8601String(),
    if (lastReadDate != null) 'last_read_date': lastReadDate!.toIso8601String(),
    'tags': tags,
    'is_favorite': isFavorite,
  };

  factory DocumentModel.fromJson(Map<String, dynamic> json) => DocumentModel(
    id: json['_id']?.toString(),
    userId: json['user_id'],
    name: json['name'],
    content: json['content'],
    filePath: json['file_path'],
    uploadedDate: DateTime.parse(json['uploaded_date']),
    lastReadDate: json['last_read_date'] != null 
        ? DateTime.parse(json['last_read_date']) 
        : null,
    tags: List<String>.from(json['tags'] ?? []),
    isFavorite: json['is_favorite'] ?? false,
  );
}