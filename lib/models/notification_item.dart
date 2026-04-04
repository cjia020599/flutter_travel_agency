class NotificationItem {
  final int id;
  final int? userId;
  final String title;
  final String message;
  final bool isRead;
  final DateTime createdAt;
  final DateTime? readAt;

  NotificationItem({
    required this.id,
    required this.title,
    required this.message,
    required this.isRead,
    required this.createdAt,
    this.userId,
    this.readAt,
  });

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    final readAt = _parseDateNullable(json['readAt'] ?? json['read_at']);
    return NotificationItem(
      id: _parseInt(json['id']) ?? 0,
      userId: _parseInt(json['userId'] ?? json['user_id']),
      title: json['title']?.toString() ?? 'Notification',
      message: json['message']?.toString() ?? '',
      isRead: json['isRead'] == true ||
          json['read'] == true ||
          json['is_read'] == true ||
          readAt != null,
      createdAt: _parseDate(json['createdAt'] ?? json['created_at']),
      readAt: readAt,
    );
  }

  NotificationItem copyWith({
    bool? isRead,
    DateTime? readAt,
  }) {
    return NotificationItem(
      id: id,
      userId: userId,
      title: title,
      message: message,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt,
      readAt: readAt ?? this.readAt,
    );
  }

  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    return int.tryParse(value.toString());
  }

  static DateTime _parseDate(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is DateTime) return value;
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    }
    if (value is num) {
      return DateTime.fromMillisecondsSinceEpoch(value.toInt());
    }
    final parsed = DateTime.tryParse(value.toString());
    return parsed ?? DateTime.now();
  }

  static DateTime? _parseDateNullable(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    }
    if (value is num) {
      return DateTime.fromMillisecondsSinceEpoch(value.toInt());
    }
    return DateTime.tryParse(value.toString());
  }
}
