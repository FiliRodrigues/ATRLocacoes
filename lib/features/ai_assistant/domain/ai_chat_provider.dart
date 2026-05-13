import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../core/data/fleet_data.dart';
import '../../../core/utils/app_logger.dart';
import '../data/ai_chat_repository.dart';
import '../data/models/ai_message.dart';
import '../data/models/ai_conversation.dart';
import '../data/models/pending_action.dart';
import '../data/models/ai_content_block.dart';

class AiChatProvider extends ChangeNotifier {
  final AiChatRepository _repo;
  bool _disposed = false;

  String? _activeConversationId;
  final List<AiMessage> _messages = [];
  bool _sending = false;
  String? _error;
  bool _initialized = false;
  List<AiConversation> _conversations = [];
  bool _sidebarOpen = false;
  final Map<String, int> _conversationMessageCounts = {};

  AiChatProvider(this._repo);

  // ── Getters ──────────────────────────────────────────────────────────────

  List<AiMessage> get messages => List.unmodifiable(_messages);
  bool get sending => _sending;
  String? get error => _error;
  bool get initialized => _initialized;
  String? get activeConversationId => _activeConversationId;
  List<AiConversation> get conversations => List.unmodifiable(_conversations);
  bool get sidebarOpen => _sidebarOpen;

  int messageCountForConversation(String conversationId) =>
      _conversationMessageCounts[conversationId] ??
      (conversationId == _activeConversationId ? _messages.length : 0);

  int get pendingActionsCount {
    int count = 0;
    for (final msg in _messages) {
      if (msg.pendingActions != null) {
        for (final a in msg.pendingActions!) {
          if (a.status == PendingActionStatus.pendingConfirmation) count++;
        }
      }
    }
    return count;
  }

  // ── Inicialização ────────────────────────────────────────────────────────

  void _syncActiveConversationCount() {
    if (_activeConversationId == null) return;
    _conversationMessageCounts[_activeConversationId!] = _messages.length;
  }

  Future<void> _refreshConversationCounts() async {
    final ids = _conversations.map((c) => c.id).toList();
    for (final id in ids) {
      if (_disposed) return;
      try {
        if (id == _activeConversationId) {
          _conversationMessageCounts[id] = _messages.length;
          continue;
        }
        final msgs = await _repo.loadMessages(id);
        _conversationMessageCounts[id] = msgs.length;
      } catch (_) {
        _conversationMessageCounts.putIfAbsent(id, () => 0);
      }
    }
  }

  Future<void> _loadState() async {
    if (_disposed) return;
    try {
      _conversations = await _repo.listConversations(limit: 20);
      await _refreshConversationCounts();
    } catch (e) { AppLogger.warning('AiChatProvider: $e'); }
    if (!_disposed) {
      _initialized = true;
      notifyListeners();
    }
  }

  Future<void> init() async {
    if (_initialized) return;
    await _loadState();
  }

  // ── Conversas ────────────────────────────────────────────────────────────

  Future<void> loadConversations() async {
    try {
      _conversations = await _repo.listConversations(limit: 20);
      await _refreshConversationCounts();
      if (!_disposed) notifyListeners();
    } catch (e) { AppLogger.warning('AiChatProvider: $e'); }
  }

  Future<void> loadConversation(String id) async {
    try {
      _activeConversationId = id;
      _messages.clear();
      _error = null;
      if (!_disposed) notifyListeners();
      final msgs = await _repo.loadMessages(id);
      if (!_disposed) {
        _messages.addAll(msgs);
        _syncActiveConversationCount();
        _sidebarOpen = false;
        notifyListeners();
      }
    } catch (e) { AppLogger.warning('AiChatProvider: $e'); }
  }

  void prepareNewScreenState() {
    _activeConversationId = null;
    _messages.clear();
    _sidebarOpen = true;
    _error = null;
    if (!_disposed) notifyListeners();
  }

  Future<void> startNewConversation() async {
    _activeConversationId = null;
    _messages.clear();
    _sidebarOpen = false;
    _error = null;
    if (!_disposed) notifyListeners();
  }

  void toggleSidebar() {
    _sidebarOpen = !_sidebarOpen;
    if (!_disposed) notifyListeners();
  }

  void closeSidebar() {
    _sidebarOpen = false;
    if (!_disposed) notifyListeners();
  }

  // ── Envio de mensagens ───────────────────────────────────────────────────

  Future<void> sendText(String text) async {
    if (_sending) return;
    _sending = true;
    _error = null;

    final wasNew = _activeConversationId == null;
    final userMsg = AiMessage.userText(text);
    _messages.add(userMsg);
    _syncActiveConversationCount();
    if (!_disposed) notifyListeners();

    bool responseReceived = false;
    try {
      final response = await _repo.sendMessage(
        channel: 'web',
        conversationId: _activeConversationId,
        content: [AiTextBlock(text)],
      );
      _activeConversationId = response.conversationId;

      final idx = _messages.indexWhere((m) => m.id == userMsg.id);
      if (idx != -1) {
        _messages[idx] = AiMessage(
          id: userMsg.id,
          conversationId: response.conversationId,
          role: AiMessageRole.user,
          content: userMsg.content,
          createdAt: userMsg.createdAt,
        );
      }

      if (response.assistantMessage != null) {
        _messages.add(response.assistantMessage!);
        responseReceived = true;
        final txt = response.assistantMessage!.content
            .whereType<AiTextBlock>()
            .map((b) => b.text)
            .join();
        if (txt.contains('✅')) {
          unawaited(FleetRepository.instance.loadFromSupabase());
        }
      }
      _syncActiveConversationCount();
      if (wasNew) await loadConversations();
    } on AiChatException catch (e) {
      _error = e.message;
      if (!_disposed) notifyListeners();
    } catch (e) {
      if (!responseReceived) {
        _error = 'Erro ao enviar mensagem. Tente novamente.';
      }
      if (!_disposed) notifyListeners();
    } finally {
      _sending = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<void> sendImages(
    List<({String mimeType, String base64})> images,
    String? caption, {
    List<String>? contentHashes,
  }) async {
    if (_sending) return;
    _sending = true;
    _error = null;

    final content = <AiContentBlock>[];
    if (caption != null && caption.isNotEmpty) {
      content.add(AiTextBlock(caption));
    }
    for (final img in images) {
      content.add(AiImageBlock(mediaType: img.mimeType, data: img.base64));
    }

    final wasNew = _activeConversationId == null;
    final userMsg = AiMessage(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      conversationId: _activeConversationId ?? '',
      role: AiMessageRole.user,
      content: content,
      createdAt: DateTime.now(),
    );
    _messages.add(userMsg);
    _syncActiveConversationCount();
    if (!_disposed) notifyListeners();

    bool responseReceived = false;
    try {
      final response = await _repo.sendMessage(
        channel: 'web',
        conversationId: _activeConversationId,
        content: content,
        contentHashes: contentHashes,
      );
      _activeConversationId = response.conversationId;
      if (response.assistantMessage != null) {
        _messages.add(response.assistantMessage!);
        responseReceived = true;
      }
      _syncActiveConversationCount();
      if (wasNew) await loadConversations();
    } on AiChatException catch (e) {
      _error = e.message;
      if (!_disposed) notifyListeners();
    } catch (e) {
      debugPrint('[sendImages] erro: $e');
      if (!responseReceived) {
        _error = 'Erro ao processar imagens.';
      }
      if (!_disposed) notifyListeners();
    } finally {
      _sending = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<void> sendPdf(
    List<({String mimeType, String base64})> images,
    String pdfLabel,
    String? caption, {
    List<String>? contentHashes,
  }) async {
    if (_sending) return;
    _sending = true;
    _error = null;

    final backendContent = <AiContentBlock>[];
    if (caption != null && caption.isNotEmpty) {
      backendContent.add(AiTextBlock(caption));
    }
    for (final img in images) {
      backendContent.add(AiImageBlock(mediaType: img.mimeType, data: img.base64));
    }

    final displayContent = <AiContentBlock>[
      if (caption != null && caption.isNotEmpty) AiTextBlock(caption),
      AiTextBlock(pdfLabel),
    ];

    final wasNew = _activeConversationId == null;
    final userMsg = AiMessage(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      conversationId: _activeConversationId ?? '',
      role: AiMessageRole.user,
      content: displayContent,
      createdAt: DateTime.now(),
    );
    _messages.add(userMsg);
    _syncActiveConversationCount();
    if (!_disposed) notifyListeners();

    bool responseReceived = false;
    try {
      final response = await _repo.sendMessage(
        channel: 'web',
        conversationId: _activeConversationId,
        content: backendContent,
        contentHashes: contentHashes,
      );
      _activeConversationId = response.conversationId;
      if (response.assistantMessage != null) {
        _messages.add(response.assistantMessage!);
        responseReceived = true;
      }
      _syncActiveConversationCount();
      if (wasNew) await loadConversations();
    } on AiChatException catch (e) {
      _error = e.message;
      if (!_disposed) notifyListeners();
    } catch (e) {
      debugPrint('[sendPdf] erro: $e');
      if (!responseReceived) {
        _error = 'Erro ao processar PDF. Tente novamente.';
      }
      if (!_disposed) notifyListeners();
    } finally {
      _sending = false;
      if (!_disposed) notifyListeners();
    }
  }

  // ── Ações pendentes ──────────────────────────────────────────────────────

  Future<void> confirmAction(String actionId) async {
    // Marca localmente como confirmado imediatamente para sumir o botão
    for (int i = 0; i < _messages.length; i++) {
      final msg = _messages[i];
      if (msg.pendingActions != null) {
        final updated = msg.pendingActions!
            .map((a) => a.actionId == actionId
                ? a.copyWith(status: PendingActionStatus.confirmed)
                : a)
            .toList();
        _messages[i] = AiMessage(
          id: msg.id,
          conversationId: msg.conversationId,
          role: msg.role,
          content: msg.content,
          pendingActions: updated,
          createdAt: msg.createdAt,
        );
      }
    }

    _sending = true;
    _error = null;
    if (!_disposed) notifyListeners();

    bool responseReceived = false;
    try {
      final response = await _repo.sendMessage(
        channel: 'web',
        conversationId: _activeConversationId,
        content: [const AiTextBlock('confirmar')],
        confirmActionId: actionId,
      );
      if (response.assistantMessage != null) {
        _messages.add(response.assistantMessage!);
        responseReceived = true;
      }
      _syncActiveConversationCount();
      unawaited(FleetRepository.instance.loadFromSupabase());
    } on AiChatException catch (e) {
      _error = e.message;
      if (!_disposed) notifyListeners();
    } catch (e) {
      debugPrint('[confirmAction] erro: $e');
      if (!responseReceived) {
        _error = 'Erro ao confirmar ação.';
      }
      if (!_disposed) notifyListeners();
    } finally {
      _sending = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<void> cancelAction(String actionId) async {
    for (int i = 0; i < _messages.length; i++) {
      final msg = _messages[i];
      if (msg.pendingActions != null) {
        final updated = msg.pendingActions!
            .map((a) => a.actionId == actionId
                ? a.copyWith(status: PendingActionStatus.cancelled)
                : a)
            .toList();
        _messages[i] = AiMessage(
          id: msg.id,
          conversationId: msg.conversationId,
          role: msg.role,
          content: msg.content,
          pendingActions: updated,
          createdAt: msg.createdAt,
        );
      }
    }
    _syncActiveConversationCount();
    if (!_disposed) notifyListeners();

    try {
      await _repo.cancelAction(actionId);
    } catch (e) { AppLogger.warning('AiChatProvider: $e'); }
  }

  // ── Utilidades ───────────────────────────────────────────────────────────

  void clearError() {
    _error = null;
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
