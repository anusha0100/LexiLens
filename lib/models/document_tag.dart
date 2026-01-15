class DocumentTag {
  final String? id;
  final String tagName;
  final String userId;
  final String color;
  final DateTime createdAt;

  DocumentTag({
    this.id,
    required this.tagName,
    required this.userId,
    required this.color,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    if (id != null) '_id': id,
    'tag_name': tagName,
    'user_id': userId,
    'color': color,
    'created_at': createdAt.toIso8601String(),
  };

  factory DocumentTag.fromJson(Map<String, dynamic> json) => DocumentTag(
    id: json['_id']?.toString(),
    tagName: json['tag_name'],
    userId: json['user_id'],
    color: json['color'],
    createdAt: DateTime.parse(json['created_at']),
  );
}
