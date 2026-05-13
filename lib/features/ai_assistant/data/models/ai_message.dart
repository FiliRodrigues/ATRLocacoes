import 'ai_content_block.dart';
import 'pending_action.dart';

enum AiMessageRole { user, assistant, toolResult }

class AiMessage {
  final String id;
  final String conversationId;
  final AiMessageRole role;
  final List<AiContentBlock> content;
  final List<PendingAction>? pendingActions;
  final DateTime createdAt;

  const AiMessage({
    required this.id,
    required this.conversationId,
    required this.role,
    required this.content,
    this.pendingActions,
    required this.createdAt,
  });

  factory AiMessage.userText(String text) => AiMessage(
    id: DateTime.now().microsecondsSinceEpoch.toString(),
    conversationId: '',
    role: AiMessageRole.user,
    content: [AiTextBlock(text)],
    createdAt: DateTime.now(),
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
