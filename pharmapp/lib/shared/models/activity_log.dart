/// User activity log entry returned by GET /auth/activity-log/
class ActivityLog {
  final int id;
  final int userId;
  final String username;
  final String role;
  final String action;
  final String category; // auth | sales | inventory | customers | users | settings | reports | other
  final String description;
  final DateTime timestamp;
  final String? ipAddress;

  const ActivityLog({
    required this.id,
    required this.userId,
    required this.username,
    required this.role,
    required this.action,
    required this.category,
    required this.description,
    required this.timestamp,
    this.ipAddress,
  });

  factory ActivityLog.fromJson(Map<String, dynamic> json) {
    return ActivityLog(
      id: (json['id'] as num).toInt(),
      userId: (json['user_id'] as num? ?? 0).toInt(),
      username: json['username'] as String? ?? 'Unknown',
      role: json['role'] as String? ?? '',
      action: json['action'] as String? ?? '',
      category: json['category'] as String? ?? 'other',
      description: json['description'] as String? ?? '',
      timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ?? DateTime.now(),
      ipAddress: json['ip_address'] as String?,
    );
  }
}
