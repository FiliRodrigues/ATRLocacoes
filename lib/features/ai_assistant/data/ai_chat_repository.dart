import 'package:supabase_flutter/supabase_flutter.dart';
import 'models/ai_message.dart';
import 'models/ai_conversation.dart';
import 'models/pending_action.dart';
import 'models/ai_content_block.dart';

/// Repository para comunicação com a Edge Function ai-agent e tabelas do chat de IA.
class AiChatRepository {
  final SupabaseClient _supabase;

  AiChatRepository(this._supabase);

  /// Envia mensagem para a Edge Function ai-agent.
  ///
  /// [channel] identifica o canal de origem (ex: 'web').
  /// [conversationId] opcional — se nulo, a Edge Function cria nova conversa.
  /// [content] lista de blocos de conteúdo (texto, imagem, etc.).
  /// [confirmActionId] opcional — ID da ação pendente a confirmar.
  Future<AiAgentResponse> sendMessage({
    required String channel,
    String? conversationId,
    required List<AiContentBlock> content,
    String? confirmActionId,
    List<String>? contentHashes,
  }) async {
    final body = <String, dynamic>{
      'channel': channel,
      'message': {
        'role': 'user',
        'content': content.map((b) => b.toJson()).toList(),
      },
      if (conversationId != null) 'conversation_id': conversationId,
      if (confirmActionId != null) 'confirm_action_id': confirmActionId,
      if (contentHashes != null && contentHashes.isNotEmpty)
        'content_hashes': contentHashes,
    };

    final response = await _supabase.functions.invoke('ai-agent', body: body);

    if (response.status >= 400) {
      throw AiChatException(
        response.data?['error'] as String? ?? 'Erro desconhecido',
      );
    }

    final data = response.data;
    if (data is! Map<String, dynamic>) {
      throw const AiChatException(
        'Resposta inválida do servidor ao processar o anexo. Tente novamente.',
      );
    }

    if (data['conversation_id'] == null) {
      throw const AiChatException(
        'Servidor não retornou conversation_id. Tente novamente.',
      );
    }

    return AiAgentResponse.fromJson(data);
  }

  /// Lista as conversas do usuário autenticado (últimas [limit], ordenadas por updated_at DESC).
  Future<List<AiConversation>> listConversations({int limit = 20}) async {
    final rows = await _supabase
        .from('ai_conversations')
        .select()
        .order('updated_at', ascending: false)
        .limit(limit);

    return rows.map(AiConversation.fromJson).toList();
  }

  /// Cancela uma ação pendente via Edge Function.
  Future<void> cancelAction(String actionId) async {
    final response = await _supabase.functions.invoke('ai-agent', body: {
      'channel': 'web',
      'cancel_action_id': actionId,
      'message': {'role': 'user', 'content': [{'type': 'text', 'text': 'cancelar'}]},
    });

    if (response.status >= 400) {
      throw AiChatException('Erro ao cancelar ação.');
    }
  }

  /// Carrega todas as mensagens de uma conversa (ordenadas por created_at ASC).
  Future<List<AiMessage>> loadMessages(String conversationId) async {
    final rows = await _supabase
        .from('ai_messages')
        .select()
        .eq('conversation_id', conversationId)
        .order('created_at', ascending: true)
        .limit(500);

    return rows.map(AiMessage.fromJson).toList();
  }
}

/// Resposta da Edge Function ai-agent.
class AiAgentResponse {
  final String conversationId;
  final AiMessage? assistantMessage;
  final List<PendingAction> pendingActions;

  const AiAgentResponse({
    required this.conversationId,
    this.assistantMessage,
    this.pendingActions = const [],
  });

  factory AiAgentResponse.fromJson(Map<String, dynamic> json) {
    AiMessage? msg;

    if (json['message'] != null) {
      final m = json['message'] as Map<String, dynamic>;
      msg = AiMessage(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        conversationId: json['conversation_id'] as String,
        role: AiMessageRole.assistant,
        content: (m['content'] as List<dynamic>)
            .map((b) => AiContentBlock.fromJson(b as Map<String, dynamic>))
            .toList(),
        pendingActions: json['pending_actions'] != null
            ? (json['pending_actions'] as List<dynamic>)
                .map((a) =>
                    PendingAction.fromJson(a as Map<String, dynamic>))
                .toList()
            : null,
        createdAt: DateTime.now(),
      );
    }

    return AiAgentResponse(
      conversationId: json['conversation_id'] as String,
      assistantMessage: msg,
      pendingActions: json['pending_actions'] != null
          ? (json['pending_actions'] as List<dynamic>)
              .map((a) => PendingAction.fromJson(a as Map<String, dynamic>))
              .toList()
          : [],
    );
  }
}

/// Exceção tipada para erros do chat de IA.
class AiChatException implements Exception {
  final String message;
  const AiChatException(this.message);

  @override
  String toString() => message;
}
