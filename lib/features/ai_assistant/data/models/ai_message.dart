import 'ai_content_block.dart';
import 'pending_action.dart';
import 'dart:math';

enum AiMessageRole { user, assistant, toolResult }

String _generateMessageId() {
  final ts = DateTime.now().microsecondsSinceEpoch;
  final r = Random().nextInt(999999);
  return '${ts}_$r';
}

class AiMessage {
  final String id;
  final String conversationId;
  final AiMessageRole role;
  final List<AiContentBlock> content;
  final List<PendingAction>? pendingActions;
  final DateTime createdAt;
  final bool isPending;
  final bool hasFailed;

  const AiMessage({
    required this.id,
    required this.conversationId,
    required this.role,
    required this.content,
    this.pendingActions,
    required this.createdAt,
    this.isPending = false,
    this.hasFailed = false,
  });

  AiMessage copyWith({
    String? id,
    String? conversationId,
    AiMessageRole? role,
    List<AiContentBlock>? content,
    List<PendingAction>? pendingActions,
    DateTime? createdAt,
    bool? isPending,
    bool? hasFailed,
  }) {
    return AiMessage(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      role: role ?? this.role,
      content: content ?? this.content,
      pendingActions: pendingActions ?? this.pendingActions,
      createdAt: createdAt ?? this.createdAt,
      isPending: isPending ?? this.isPending,
      hasFailed: hasFailed ?? this.hasFailed,
    );
  }

  factory AiMessage.userText(String text, {bool isPending = false, bool hasFailed = false}) => AiMessage(
    id: _generateMessageId(),
    conversationId: '',
    role: AiMessageRole.user,
    content: [AiTextBlock(text)],
    createdAt: DateTime.now(),
    isPending: isPending,
    hasFailed: hasFailed,
  );

  factory AiMessage.fromJson(Map<String, dynamic> json) => AiMessage(
    id: json['id'] as String,
    conversationId: json['conversation_id'] as String,
    role: switch (json['role'] as String) {
      'user' => AiMessageRole.user,
      'assistant' => AiMessageRole.assistant,
      _ => AiMessageRole.toolResult,
    },
    content: (json['content'] as List<dynamic>)
        .map((b) => AiContentBlock.fromJson(b as Map<String, dynamic>))
        .toList(),
    pendingActions: json['pending_actions'] != null
        ? (json['pending_actions'] as List<dynamic>)
            .map((a) => PendingAction.fromJson(a as Map<String, dynamic>))
            .toList()
        : null,
    createdAt: DateTime.parse(json['created_at'] as String),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'conversation_id': conversationId,
    'role': role.name,
    'content': content.map((b) => b.toJson()).toList(),
    if (pendingActions != null)
      'pending_actions': pendingActions!.map((a) => a.toJson()).toList(),
    'created_at': createdAt.toIso8601String(),
  };

  String get plainText =>
      content.whereType<AiTextBlock>().map((b) => b.text).join(' ');
}
