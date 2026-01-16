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
    'tagName': tagName,
    'userId': userId,
    'color': color,
    'createdAt': createdAt.toIso8601String(),
  };

  factory DocumentTag.fromJson(Map<String, dynamic> json) => DocumentTag(
    id: json['_id']?.toString(),
    tagName: json['tagName'] ?? '',
    userId: json['userId'] ?? '',
    color: json['color'] ?? '#FF0000',
    createdAt: json['createdAt'] != null 
        ? DateTime.parse(json['createdAt']) 
        : DateTime.now(),
  );
}
