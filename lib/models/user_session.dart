class UserSession {
  final String? id;
  final String userId;
  final String token;
  final String deviceInfo;
  final String ipAddress;
  final DateTime createdAt;
  final DateTime expiresAt;
  final bool isActive;

  UserSession({
    this.id,
    required this.userId,
    required this.token,
    required this.deviceInfo,
    required this.ipAddress,
    required this.createdAt,
    required this.expiresAt,
    this.isActive = true,
  });

  Map<String, dynamic> toJson() => {
    if (id != null) '_id': id,
    'user_id': userId,
    'token': token,
    'device_info': deviceInfo,
    'ip_address': ipAddress,
    'created_at': createdAt.toIso8601String(),
    'expires_at': expiresAt.toIso8601String(),
    'is_active': isActive,
  };

  factory UserSession.fromJson(Map<String, dynamic> json) => UserSession(
    id: json['_id']?.toString(),
    userId: json['user_id'],
    token: json['token'],
    deviceInfo: json['device_info'],
    ipAddress: json['ip_address'],
    createdAt: DateTime.parse(json['created_at']),
    expiresAt: DateTime.parse(json['expires_at']),
    isActive: json['is_active'] ?? true,
  );
}
