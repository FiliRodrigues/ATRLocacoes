class AiConversation {
  final String id;
  final String tenantId;
  final String userId;
  final String channel;
  final String? title;
  final DateTime createdAt;
  final DateTime updatedAt;

  const AiConversation({
    required this.id,
    required this.tenantId,
    required this.userId,
    required this.channel,
    this.title,
    required this.createdAt,
    required this.updatedAt,
  });

  factory AiConversation.fromJson(Map<String, dynamic> json) => AiConversation(
    id: json['id'] as String,
    tenantId: json['tenant_id'] as String,
    userId: json['user_id'] as String,
    channel: json['channel'] as String,
    title: json['title'] as String?,
    createdAt: DateTime.parse(json['created_at'] as String),
    updatedAt: DateTime.parse(json['updated_at'] as String),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'tenant_id': tenantId,
    'user_id': userId,
    'channel': channel,
    if (title != null) 'title': title,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };

  String get displayTitle => title ?? 'Nova conversa';
}
