import 'dart:async';
import 'dart:math';
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

  void _updatePendingActionStatus(
    String actionId,
    PendingActionStatus status,
  ) {
    for (int i = 0; i < _messages.length; i++) {
      final msg = _messages[i];
      if (msg.pendingActions == null) continue;

      final updated = msg.pendingActions!
          .map(
            (a) => a.actionId == actionId ? a.copyWith(status: status) : a,
          )
          .toList();
      _messages[i] = msg.copyWith(pendingActions: updated);
    }
  }

  Future<void> _refreshConversationCounts() async {
    final ids = _conversations.map((c) => c.id).toList();
    await Future.wait(ids.map((id) async {
      if (_disposed) return;
      try {
        if (id == _activeConversationId) {
          _conversationMessageCounts[id] = _messages.length;
          return;
        }
        final msgs = await _repo.loadMessages(id);
        _conversationMessageCounts[id] = msgs.length;
      } catch (_) {
        _conversationMessageCounts.putIfAbsent(id, () => 0);
      }
    }));
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

  Completer<void>? _initCompleter;
  
  Future<void> init() async {
    if (_initialized) return;
    if (_initCompleter != null) return _initCompleter!.future;
    
    _initCompleter = Completer<void>();
    try { 
      await _loadState(); 
      if (!_initCompleter!.isCompleted) _initCompleter!.complete(); 
    } catch (e) { 
      if (!_initCompleter!.isCompleted) _initCompleter!.completeError(e); 
      _initCompleter = null; 
      rethrow; 
    }
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
      _error = null;
      if (!_disposed) notifyListeners();
      final msgs = await _repo.loadMessages(id);
      if (!_disposed) {
        _messages.clear();
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

  String _generateMessageId() {
    final ts = DateTime.now().microsecondsSinceEpoch;
    final r = Random().nextInt(999999);
    return '${ts}_$r';
  }

  // ── Envio de mensagens ───────────────────────────────────────────────────

  Future<void> sendText(String text, {String? screenContext}) async {
    if (_sending) return;
    _sending = true;
    _error = null;

    final conversationSnapshot = _activeConversationId;
    final wasNew = conversationSnapshot == null;
    final userMsg = AiMessage.userText(text, isPending: true);
    _messages.add(userMsg);
    _syncActiveConversationCount();
    if (!_disposed) notifyListeners();

    bool responseReceived = false;
    try {
      final response = await _repo.sendMessage(
        channel: 'web',
        screenContext: screenContext,
        conversationId: conversationSnapshot,
        content: [AiTextBlock(text)],
      );
      
      if (_activeConversationId != conversationSnapshot && !wasNew) {
        return; // Descarta resposta se a conversa mudou durante a espera
      }

      _activeConversationId = response.conversationId;

      final idx = _messages.indexWhere((m) => m.id == userMsg.id);
      if (idx != -1) {
        _messages[idx] = userMsg.copyWith(
          conversationId: response.conversationId,
          isPending: false,
          hasFailed: false,
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
      final idx = _messages.indexWhere((m) => m.id == userMsg.id);
      if (idx != -1) _messages[idx] = userMsg.copyWith(isPending: false, hasFailed: true);
      if (!_disposed) notifyListeners();
    } catch (e, st) {
      AppLogger.error('AiChatProvider.sendText falhou', e, st);
      if (!responseReceived) {
        _error = 'Erro ao enviar mensagem. Tente novamente.';
      }
      final idx = _messages.indexWhere((m) => m.id == userMsg.id);
      if (idx != -1) _messages[idx] = userMsg.copyWith(isPending: false, hasFailed: true);
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
    String? screenContext,
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

    final conversationSnapshot = _activeConversationId;
    final wasNew = conversationSnapshot == null;
    final userMsg = AiMessage(
      id: _generateMessageId(),
      conversationId: conversationSnapshot ?? '',
      role: AiMessageRole.user,
      content: content,
      createdAt: DateTime.now(),
      isPending: true,
    );
    _messages.add(userMsg);
    _syncActiveConversationCount();
    if (!_disposed) notifyListeners();

    bool responseReceived = false;
    try {
      final response = await _repo.sendMessage(
        channel: 'web',
        screenContext: screenContext,
        conversationId: conversationSnapshot,
        content: content,
        contentHashes: contentHashes,
      );

      if (_activeConversationId != conversationSnapshot && !wasNew) {
        return; // Descarta
      }

      _activeConversationId = response.conversationId;

      final idx = _messages.indexWhere((m) => m.id == userMsg.id);
      if (idx != -1) {
        _messages[idx] = userMsg.copyWith(
          conversationId: response.conversationId,
          isPending: false,
          hasFailed: false,
        );
      }

      if (response.assistantMessage != null) {
        _messages.add(response.assistantMessage!);
        responseReceived = true;
      }
      _syncActiveConversationCount();
      if (wasNew) await loadConversations();
    } on AiChatException catch (e) {
      _error = e.message;
      final idx = _messages.indexWhere((m) => m.id == userMsg.id);
      if (idx != -1) _messages[idx] = userMsg.copyWith(isPending: false, hasFailed: true);
      if (!_disposed) notifyListeners();
    } catch (e, st) {
      AppLogger.error('AiChatProvider.sendImages falhou', e, st);
      if (!responseReceived) {
        _error = 'Erro ao processar imagens.';
      }
      final idx = _messages.indexWhere((m) => m.id == userMsg.id);
      if (idx != -1) _messages[idx] = userMsg.copyWith(isPending: false, hasFailed: true);
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
    String? screenContext,
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

    final conversationSnapshot = _activeConversationId;
    final wasNew = conversationSnapshot == null;
    final userMsg = AiMessage(
      id: _generateMessageId(),
      conversationId: conversationSnapshot ?? '',
      role: AiMessageRole.user,
      content: displayContent,
      createdAt: DateTime.now(),
      isPending: true,
    );
    _messages.add(userMsg);
    _syncActiveConversationCount();
    if (!_disposed) notifyListeners();

    bool responseReceived = false;
    try {
      final response = await _repo.sendMessage(
        channel: 'web',
        screenContext: screenContext,
        conversationId: conversationSnapshot,
        content: backendContent,
        contentHashes: contentHashes,
      );
      
      if (_activeConversationId != conversationSnapshot && !wasNew) {
        return; // Descarta
      }

      _activeConversationId = response.conversationId;
      
      final idx = _messages.indexWhere((m) => m.id == userMsg.id);
      if (idx != -1) {
        _messages[idx] = userMsg.copyWith(
          conversationId: response.conversationId,
          isPending: false,
          hasFailed: false,
        );
      }

      if (response.assistantMessage != null) {
        _messages.add(response.assistantMessage!);
        responseReceived = true;
      }
      _syncActiveConversationCount();
      if (wasNew) await loadConversations();
    } on AiChatException catch (e) {
      _error = e.message;
      final idx = _messages.indexWhere((m) => m.id == userMsg.id);
      if (idx != -1) _messages[idx] = userMsg.copyWith(isPending: false, hasFailed: true);
      if (!_disposed) notifyListeners();
    } catch (e, st) {
      AppLogger.error('AiChatProvider.sendPdf falhou', e, st);
      if (!responseReceived) {
        _error = 'Erro ao processar PDF. Tente novamente.';
      }
      final idx = _messages.indexWhere((m) => m.id == userMsg.id);
      if (idx != -1) _messages[idx] = userMsg.copyWith(isPending: false, hasFailed: true);
      if (!_disposed) notifyListeners();
    } finally {
      _sending = false;
      if (!_disposed) notifyListeners();
    }
  }

  // ── Ações pendentes ──────────────────────────────────────────────────────

  Future<void> confirmAction(String actionId) async {
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
      _updatePendingActionStatus(
        actionId,
        response.confirmedAction?.ok == false
            ? PendingActionStatus.failed
            : PendingActionStatus.executed,
      );
      if (response.assistantMessage != null) {
        _messages.add(response.assistantMessage!);
        responseReceived = true;
      }
      _syncActiveConversationCount();
      if (response.confirmedAction?.ok != false) {
        unawaited(FleetRepository.instance.loadFromSupabase());
      }
    } on AiChatException catch (e) {
      _error = e.message;
      if (!_disposed) notifyListeners();
    } catch (e, st) {
      AppLogger.error('AiChatProvider.confirmAction falhou', e, st);
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
    _updatePendingActionStatus(actionId, PendingActionStatus.cancelled);
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

  @override
  void notifyListeners() {
    if (!_disposed) {
      super.notifyListeners();
    }
  }
}
