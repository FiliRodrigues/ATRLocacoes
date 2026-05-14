import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/utils/app_logger.dart';
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
    String? screenContext,
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
      if (screenContext != null) 'screen_context': screenContext,
      if (conversationId != null) 'conversation_id': conversationId,
      if (confirmActionId != null) 'confirm_action_id': confirmActionId,
      if (contentHashes != null && contentHashes.isNotEmpty)
        'content_hashes': contentHashes,
    };

    late final FunctionResponse response;
    try {
      response = await _invokeAiAgentWithRetry(body);
    } catch (e, st) {
      AppLogger.error('AiChatRepository.sendMessage invoke falhou', e, st);
      throw AiChatException(_mapInvokeError(e));
    }

    if (response.status >= 400) {
      final msg = _extractServerError(
        data: response.data,
        status: response.status,
      );
      throw AiChatException(msg);
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
    late final FunctionResponse response;
    try {
      response = await _invokeAiAgentWithRetry({
        'channel': 'web',
        'cancel_action_id': actionId,
        'message': {
          'role': 'user',
          'content': [
            {'type': 'text', 'text': 'cancelar'},
          ],
        },
      });
    } catch (e, st) {
      AppLogger.error('AiChatRepository.cancelAction invoke falhou', e, st);
      throw AiChatException(_mapInvokeError(e));
    }

    if (response.status >= 400) {
      throw AiChatException(
        _extractServerError(
          data: response.data,
          status: response.status,
          fallback: 'Erro ao cancelar ação.',
        ),
      );
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

  Future<FunctionResponse> _invokeAiAgentWithRetry(
    Map<String, dynamic> body,
  ) async {
    const maxAttempts = 3;

    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        return await _supabase.functions.invoke('ai-agent', body: body).timeout(
          const Duration(seconds: 90),
          onTimeout: () => throw const AiChatException('Tempo esgotado. A conexão caiu ou o servidor demorou muito.'),
        );
      } catch (e) {
        final status = _extractStatusFromError(e);
        final isTransient =
            _isTransientStatus(status) || _looksLikeNetworkError(e);

        if (attempt >= maxAttempts || !isTransient) {
          rethrow;
        }

        int delayMs = 1000 * (1 << (attempt - 1));
        
        final retryMatch = RegExp(r'retry.?after[:\s]+(\d+)', caseSensitive: false).firstMatch(e.toString());
        if (retryMatch != null) {
          final retrySecs = int.tryParse(retryMatch.group(1) ?? '0') ?? 0;
          if (retrySecs * 1000 > delayMs) {
            delayMs = retrySecs * 1000;
          }
        }
        
        AppLogger.warning(
          'AiChatRepository: tentativa $attempt/$maxAttempts falhou, '
          'retry em ${delayMs}ms (status=$status).',
        );
        await Future<void>.delayed(Duration(milliseconds: delayMs));
      }
    }

    throw const AiChatException(
      'Não foi possível enviar a mensagem para o serviço de IA. Tente novamente.',
    );
  }
}

String _extractServerError({
  required dynamic data,
  required int status,
  String fallback = 'Erro ao enviar mensagem.',
}) {
  final String? rawMessage;
  if (data is Map<String, dynamic>) {
    rawMessage = (data['error'] ?? data['message'])?.toString();
  } else if (data is String) {
    rawMessage = data;
  } else {
    rawMessage = null;
  }

  final normalized = rawMessage?.trim();
  if (normalized != null && normalized.isNotEmpty) {
    return normalized;
  }

  if (status == 401 || status == 403) {
    return 'Sessão expirada ou sem permissão. Faça login novamente.';
  }
  if (status == 413) {
    return 'Arquivo muito grande para processamento.';
  }
  if (status == 429) {
    return 'Muitas requisições em sequência. Aguarde alguns segundos e tente novamente.';
  }
  if (status >= 500) {
    return 'Serviço de IA indisponível no momento. Tente novamente em instantes.';
  }

  return fallback;
}

String _mapInvokeError(Object error) {
  final status = _extractStatusFromError(error);
  if (status != null) {
    if (status == 401 || status == 403) {
      return 'Sessão expirada ou inválida. Faça login novamente.';
    }
    if (status == 413) {
      return 'Arquivo muito grande para processamento.';
    }
    if (status == 429) {
      return 'Muitas requisições em sequência. Aguarde alguns segundos e tente novamente.';
    }
    if (status >= 500) {
      return 'Serviço de IA indisponível no momento. Tente novamente em instantes.';
    }
  }

  final text = error.toString().toLowerCase();

  if (_looksLikeNetworkError(error)) {
    return 'Falha de conexão com o serviço de IA. Verifique sua internet e tente novamente.';
  }

  if (text.contains('jwt') ||
      text.contains('token') ||
      text.contains('unauthorized') ||
      text.contains('forbidden')) {
    return 'Sessão expirada ou inválida. Faça login novamente.';
  }

  return 'Não foi possível enviar a mensagem para o serviço de IA. Tente novamente.';
}

bool _isTransientStatus(int? status) {
  if (status == null) return false;
  return status == 429 || status >= 500;
}

bool _looksLikeNetworkError(Object error) {
  final text = error.toString().toLowerCase();
  return text.contains('socket') ||
      text.contains('network') ||
      text.contains('connection') ||
      text.contains('dns') ||
      text.contains('timed out') ||
      text.contains('timeout') ||
      text.contains('failed host lookup');
}

int? _extractStatusFromError(Object error) {
  final text = error.toString();

  final directMatch = RegExp(r'\b(4\d\d|5\d\d)\b').firstMatch(text);
  if (directMatch != null) {
    return int.tryParse(directMatch.group(1)!);
  }

  return null;
}

/// Resposta da Edge Function ai-agent.
class AiAgentResponse {
  final String conversationId;
  final AiMessage? assistantMessage;
  final List<PendingAction> pendingActions;
  final ConfirmedActionResult? confirmedAction;

  const AiAgentResponse({
    required this.conversationId,
    this.assistantMessage,
    this.pendingActions = const [],
    this.confirmedAction,
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
            .map(
              (a) => PendingAction.fromJson(a as Map<String, dynamic>),
            )
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
      confirmedAction: json['confirmed_action'] != null
          ? ConfirmedActionResult.fromJson(
              json['confirmed_action'] as Map<String, dynamic>,
            )
          : null,
    );
  }
}

class ConfirmedActionResult {
  final String actionId;
  final bool ok;
  final String? error;

  const ConfirmedActionResult({
    required this.actionId,
    required this.ok,
    this.error,
  });

  factory ConfirmedActionResult.fromJson(Map<String, dynamic> json) {
    return ConfirmedActionResult(
      actionId: json['action_id'] as String,
      ok: json['ok'] as bool? ?? false,
      error: json['error'] as String?,
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
