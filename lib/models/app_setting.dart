class AppSetting {
  final String? id;
  final String userId;
  final String settingKey;
  final dynamic value;
  final DateTime updatedAt;

  AppSetting({
    this.id,
    required this.userId,
    required this.settingKey,
    required this.value,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
    if (id != null) '_id': id,
    'userId': userId,
    'settingKey': settingKey,
    'value': value,
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory AppSetting.fromJson(Map<String, dynamic> json) => AppSetting(
    id: json['_id']?.toString(),
    userId: json['userId'] ?? '',
    settingKey: json['settingKey'] ?? '',
    value: json['value'],
    updatedAt: json['updatedAt'] != null 
        ? DateTime.parse(json['updatedAt']) 
        : DateTime.now(),
  );
}