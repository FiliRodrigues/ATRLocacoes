import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/app_logger.dart';

/// Categorias de ação para auditoria de operações críticas.
enum AuditAction {
  criar,
  atualizar,
  deletar,
  moverKanban,
  login,
  logout,
  atualizarKm,
  atualizarStatus,
}

/// Entidades auditáveis do sistema.
enum AuditEntity {
  manutencao,
  despesa,
  veiculo,
  usuario,
}

/// Serviço de auditoria: registra ações críticas na tabela [audit_log] do Supabase.
///
/// Falhas de auditoria NÃO interrompem o fluxo principal — são logadas localmente.
class AuditService {
  static String? _currentUsername;
  static String? _currentTenantId;

  /// Tenant ID do usuário ativo — usado automaticamente em todos os logs.
  static String? get currentTenantId => _currentTenantId;

  /// Define o usuário e tenant ativos para todos os registros de auditoria.
  static void setCurrentUser(String? username, {String? tenantId}) {
    _currentUsername = username;
    _currentTenantId = tenantId;
  }

  /// Registra uma ação de auditoria de forma assíncrona e não-bloqueante.
  ///
  /// Campos opcionais:
  /// - [beforeState]: estado completo do objeto antes da ação.
  /// - [afterState]: estado completo do objeto após a ação.
  /// - [origin]: origem da requisição ('web', 'mobile', 'api').
  static Future<void> log({
    required AuditAction action,
    required AuditEntity entity,
    String? entityId,
    Map<String, dynamic>? payload,
    Map<String, dynamic>? beforeState,
    Map<String, dynamic>? afterState,
    String origin = 'web',
  }) async {
    try {
      await Supabase.instance.client.from('audit_log').insert({
        'username':       _currentUsername ?? 'desconhecido',
        'effective_user': _currentUsername ?? 'desconhecido',
        'tenant_id':      _currentTenantId,
        'action':         action.name,
        'entity':         entity.name,
        'entity_id':      entityId,
        'payload':        payload,
        'before_state':   beforeState,
        'after_state':    afterState,
        'origin':         origin,
        'created_at':     DateTime.now().toIso8601String(),
      });
    } catch (error, stackTrace) {
      // Auditoria nunca deve derrubar o fluxo — somente log local.
      AppLogger.warning(
        'AuditService.log falhou [action=${action.name}, entity=${entity.name}]: $error',
      );
      AppLogger.error('AuditService stack', error, stackTrace);
    }
  }
}
