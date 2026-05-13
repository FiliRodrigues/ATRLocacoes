import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/app_logger.dart';

/// Fila de sincronização offline-first.
///
/// Operações que falham por falta de conexão são armazenadas localmente.
/// Ao reconectar, o worker agrupa inserts do mesmo target em batch (PostgREST
/// bulk upsert) e processa updates/deletes individualmente.
///
/// Idempotência: insert usa upsert (onConflict: 'id') para que retentativas
/// não falhem com duplicate key.
class SyncQueueService extends ChangeNotifier {
  static const String _queueKey = 'becap_offline_queue';
  static const String _syncLockKey = 'becap_sync_lock';
  static const Duration _lockTimeout = Duration(seconds: 30);

  bool _isSyncing = false;
  bool get isSyncing => _isSyncing;

  int _queueLength = 0;
  int get queueLength => _queueLength;

  /// Adiciona uma payload na fila e agenda sincronização.
  Future<void> enqueueRequest({
    required String table,
    required Map<String, dynamic> payload,
    required String action,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final rawQueue = prefs.getStringList(_queueKey) ?? [];

    rawQueue.add(jsonEncode({
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'table': table,
      'payload': payload,
      'action': action,
      'timestamp': DateTime.now().toIso8601String(),
    }));
    await prefs.setStringList(_queueKey, rawQueue);

    _queueLength = rawQueue.length;
    notifyListeners();

    _attemptSync();
  }

  Future<void> _attemptSync() async {
    if (_isSyncing) return;

    final prefs = await SharedPreferences.getInstance();

    // Lock multi-tab: evita que duas abas sincronizem simultaneamente
    final now = DateTime.now().millisecondsSinceEpoch;
    final lockValue = prefs.getInt(_syncLockKey);
    if (lockValue != null && (now - lockValue) < _lockTimeout.inMilliseconds) {
      return; // Outra aba já está sincronizando
    }
    await prefs.setInt(_syncLockKey, now);

    _isSyncing = true;
    notifyListeners();

    try {
      final client = Supabase.instance.client;
      final rawQueue = prefs.getStringList(_queueKey) ?? [];

      if (rawQueue.isEmpty) {
        _queueLength = 0;
        notifyListeners();
        return;
      }

      final decoded = <Map<String, dynamic>>[];
      for (final item in rawQueue) {
        try {
          decoded.add(jsonDecode(item) as Map<String, dynamic>);
        } catch (_) {
          // Item corrompido: descarta silenciosamente
        }
      }

      // Agrupa por (table, action)
      final groups = <String, List<Map<String, dynamic>>>{};
      for (final req in decoded) {
        final key = '${req['table']}|${req['action']}';
        groups.putIfAbsent(key, () => []).add(req);
      }

      final pendingKeys = <String>[];

      for (final entry in groups.entries) {
        final parts = entry.key.split('|');
        final table = parts[0];
        final action = parts[1];
        final items = entry.value;

        try {
          switch (action) {
            case 'insert':
              // Batch upsert: todos os inserts da mesma tabela em uma chamada
              final rows = items
                  .map((r) => Map<String, dynamic>.from(r['payload'] as Map))
                  .toList();
              await client.from(table).upsert(rows, onConflict: 'id');

            case 'update':
              for (final item in items) {
                final payload = Map<String, dynamic>.from(item['payload'] as Map);
                final id = payload.remove('_id') as String?;
                if (id != null) {
                  await client.from(table).update(payload).eq('id', id);
                }
              }

            case 'delete':
              for (final item in items) {
                final payload = item['payload'] as Map<String, dynamic>;
                final id = payload['id'] as String?;
                if (id != null) {
                  await client.from(table).delete().eq('id', id);
                }
              }
          }
        } catch (e) {
          AppLogger.warning('SyncQueue: falha no batch [$table/$action], ${items.length} itens mantidos: $e');
          for (final item in items) {
            pendingKeys.add(item['id'] as String);
          }
        }
      }

      // Reconstrói a fila apenas com os itens que falharam
      final pending = <String>[];
      for (final item in rawQueue) {
        try {
          final req = jsonDecode(item) as Map<String, dynamic>;
          if (pendingKeys.contains(req['id'] as String)) {
            pending.add(item);
          }
        } catch (e) { AppLogger.warning('SyncQueue: item corrompido na limpeza: $e'); }
      }

      _queueLength = pending.length;
      await prefs.setStringList(_queueKey, pending);
    } catch (e) {
      AppLogger.error('SyncQueue: erro no worker de sincronização', e);
    } finally {
      _isSyncing = false;
      await prefs.remove(_syncLockKey);
      notifyListeners();
    }
  }

  void retryPendingQueue() {
    _attemptSync();
  }
}
