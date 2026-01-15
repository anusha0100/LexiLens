class AppSetting {
  final String? id;
  final String settingKey;
  final dynamic settingValue;
  final String description;
  final DateTime updatedAt;

  AppSetting({
    this.id,
    required this.settingKey,
    required this.settingValue,
    required this.description,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
    if (id != null) '_id': id,
    'setting_key': settingKey,
    'setting_value': settingValue,
    'description': description,
    'updated_at': updatedAt.toIso8601String(),
  };

  factory AppSetting.fromJson(Map<String, dynamic> json) => AppSetting(
    id: json['_id']?.toString(),
    settingKey: json['setting_key'],
    settingValue: json['setting_value'],
    description: json['description'],
    updatedAt: DateTime.parse(json['updated_at']),
  );
}