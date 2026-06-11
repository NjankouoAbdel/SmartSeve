class ToolNotice {
  const ToolNotice({
    required this.id,
    required this.title,
    required this.message,
    required this.tool,
    required this.createdAt,
    required this.isRead,
  });

  final String id;
  final String title;
  final String message;
  final String tool;
  final DateTime createdAt;
  final bool isRead;

  ToolNotice copyWith({
    String? id,
    String? title,
    String? message,
    String? tool,
    DateTime? createdAt,
    bool? isRead,
  }) {
    return ToolNotice(
      id: id ?? this.id,
      title: title ?? this.title,
      message: message ?? this.message,
      tool: tool ?? this.tool,
      createdAt: createdAt ?? this.createdAt,
      isRead: isRead ?? this.isRead,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'title': title,
      'message': message,
      'tool': tool,
      'createdAt': createdAt.toIso8601String(),
      'isRead': isRead,
    };
  }

  factory ToolNotice.fromMap(Map<dynamic, dynamic> map) {
    return ToolNotice(
      id: (map['id'] as String?) ?? '',
      title: (map['title'] as String?) ?? '',
      message: (map['message'] as String?) ?? '',
      tool: (map['tool'] as String?) ?? 'general',
      createdAt:
          DateTime.tryParse((map['createdAt'] as String?) ?? '') ??
          DateTime.now(),
      isRead: (map['isRead'] as bool?) ?? false,
    );
  }
}
