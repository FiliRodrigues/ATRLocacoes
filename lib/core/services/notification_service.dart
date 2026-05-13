import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/app_logger.dart';

/// Modelo imutável de uma notificação.
class AppNotification {
  final String id;
  final String tenantId;
  final String userId;
  final String title;
  final String body;
  final String type;
  final String? entityId;
  final String? route;
  final bool read;
  final DateTime createdAt;

  const AppNotification({
    required this.id,
    required this.tenantId,
    required this.userId,
    required this.title,
    required this.body,
    required this.type,
    this.entityId,
    this.route,
    required this.read,
    required this.createdAt,
  });

  factory AppNotification.fromMap(Map<String, dynamic> map) {
    return AppNotification(
      id: map['id'] as String,
      tenantId: map['tenant_id'] as String,
      userId: map['user_id'] as String,
      title: map['title'] as String? ?? '',
      body: map['body'] as String? ?? '',
      type: map['type'] as String? ?? 'info',
      entityId: map['entity_id'] as String?,
      route: map['route'] as String?,
      read: map['read'] as bool? ?? false,
      createdAt: DateTime.tryParse(map['created_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}

/// Serviço de notificações com Realtime.
///
/// - Assina o canal `user_notifications` no Supabase Realtime.
/// - Mantém lista local de notificações não lidas.
/// - Expõe [unreadCount] para badges reativos.
class NotificationService extends ChangeNotifier {
  final SupabaseClient _client;
  RealtimeChannel? _channel;
  StreamSubscription? _insertSubscription;

  final List<AppNotification> _unreadNotifications = [];
  bool _initialized = false;

  NotificationService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  /// Notificações não lidas (ordenadas da mais recente para a mais antiga).
  List<AppNotification> get unreadNotifications =>
      List.unmodifiable(_unreadNotifications);

  int get unreadCount => _unreadNotifications.length;

  bool get isInitialized => _initialized;

  /// Inicializa o serviço: busca notificações não lidas e assina Realtime.
  /// Deve ser chamado após o usuário estar autenticado.
  Future<void> initialize(String userId) async {
    if (_initialized) return;

    try {
      await fetchUnread(userId);
      _subscribeToRealtime(userId);
      _initialized = true;
      AppLogger.info('NotificationService inicializado para user_id=$userId');
    } catch (e, stack) {
      AppLogger.error('Falha ao inicializar NotificationService', e, stack);
    }
  }

  /// Busca notificações não lidas do banco.
  Future<void> fetchUnread(String userId) async {
    try {
      final data = await _client
          .from('notifications')
          .select()
          .eq('user_id', userId)
          .eq('read', false)
          .order('created_at', ascending: false)
          .limit(50);

      _unreadNotifications.clear();
      for (final row in data) {
        _unreadNotifications.add(AppNotification.fromMap(row));
      }
      notifyListeners();
    } catch (e, stack) {
      AppLogger.error('Erro ao buscar notificações não lidas', e, stack);
    }
  }

  /// Marca uma notificação como lida e remove da lista local.
  Future<void> markAsRead(String id) async {
    try {
      await _client
          .from('notifications')
          .update({'read': true})
          .eq('id', id);

      _unreadNotifications.removeWhere((n) => n.id == id);
      notifyListeners();
      AppLogger.info('Notificação $id marcada como lida');
    } catch (e, stack) {
      AppLogger.error('Erro ao marcar notificação como lida', e, stack);
    }
  }

  /// Marca todas as notificações como lidas.
  Future<void> markAllAsRead(String userId) async {
    try {
      await _client
          .from('notifications')
          .update({'read': true})
          .eq('user_id', userId)
          .eq('read', false);

      _unreadNotifications.clear();
      notifyListeners();
      AppLogger.info('Todas as notificações marcadas como lidas');
    } catch (e, stack) {
      AppLogger.error('Erro ao marcar todas como lidas', e, stack);
    }
  }

  /// Assina o canal Realtime para novas notificações do usuário.
  void _subscribeToRealtime(String userId) {
    _channel = _client.channel('user_notifications');

    _channel!.onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'notifications',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'user_id',
        value: userId,
      ),
      callback: (payload) {
        try {
          final row = payload.newRecord;
          final notification = AppNotification.fromMap(row);
          if (!notification.read) {
            _unreadNotifications.insert(0, notification);
            notifyListeners();
            AppLogger.info('Nova notificação recebida: ${notification.title}');
          }
        } catch (e, stack) {
          AppLogger.error('Erro ao processar notificação Realtime', e, stack);
        }
      },
    );

    _channel!.subscribe((status, _) {
      if (status == RealtimeSubscribeStatus.subscribed) {
        AppLogger.info('NotificationService: inscrito no canal Realtime');
      } else if (status == RealtimeSubscribeStatus.closed) {
        AppLogger.warning('NotificationService: canal Realtime fechado');
      }
    });
  }

  @override
  void dispose() {
    _insertSubscription?.cancel();
    _channel?.unsubscribe();
    _channel = null;
    _initialized = false;
    _unreadNotifications.clear();
    super.dispose();
  }
}
