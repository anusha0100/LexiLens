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
    'userId': userId,
    'token': token,
    'deviceInfo': deviceInfo,
    'ipAddress': ipAddress,
    'createdAt': createdAt.toIso8601String(),
    'expiresAt': expiresAt.toIso8601String(),
    'isActive': isActive,
  };

  factory UserSession.fromJson(Map<String, dynamic> json) => UserSession(
    id: json['_id']?.toString(),
    userId: json['userId'] ?? '',
    token: json['token'] ?? '',
    deviceInfo: json['deviceInfo'] ?? 'Unknown',
    ipAddress: json['ipAddress'] ?? 'N/A',
    createdAt: json['createdAt'] != null 
        ? DateTime.parse(json['createdAt']) 
        : DateTime.now(),
    expiresAt: json['expiresAt'] != null 
        ? DateTime.parse(json['expiresAt']) 
        : DateTime.now().add(const Duration(days: 30)),
    isActive: json['isActive'] ?? true,
  );
}
