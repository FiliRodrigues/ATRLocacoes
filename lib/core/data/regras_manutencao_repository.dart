import 'package:supabase_flutter/supabase_flutter.dart';
import '../enums/maintenance_priority.dart';
import '../utils/app_logger.dart';
import 'regras_manutencao_models.dart';

import '../constants.dart';
const String _kTable = 'regras_manutencao';

// ─────────────────────────────────────────────────────────────────────
// SERIALIZAÇÃO
// ─────────────────────────────────────────────────────────────────────

RegraManutencao _fromRow(Map<String, dynamic> row) {
  return RegraManutencao(
    id: row['id'] as String,
    titulo: row['titulo'] as String? ?? '',
    tipo: row['tipo'] as String? ?? '',
    veiculoPlaca: row['veiculo_placa'] as String?,
    intervaloKm: (row['intervalo_km'] as num?)?.toInt(),
    intervaloDias: (row['intervalo_dias'] as num?)?.toInt(),
    custoEstimado: (row['custo_estimado'] as num?)?.toDouble() ?? 0.0,
    prioridade: MaintenancePriority.values.firstWhere(
      (p) => p.name == (row['prioridade'] as String?),
      orElse: () => MaintenancePriority.media,
    ),
    isAtiva: row['is_ativa'] as bool? ?? true,
    kmUltimaExecucao: (row['km_ultima_execucao'] as num?)?.toInt(),
    dataUltimaExecucao: row['data_ultima_execucao'] != null
        ? DateTime.tryParse(row['data_ultima_execucao']?.toString() ?? '')
        : null,
  );
}

Map<String, dynamic> _toRow(RegraManutencao r, String tenantId) {
  return {
    'id': r.id,
    'titulo': r.titulo,
    'tipo': r.tipo,
    'veiculo_placa': r.veiculoPlaca,
    'intervalo_km': r.intervaloKm,
    'intervalo_dias': r.intervaloDias,
    'custo_estimado': r.custoEstimado,
    'prioridade': r.prioridade.name,
    'is_ativa': r.isAtiva,
    'km_ultima_execucao': r.kmUltimaExecucao,
    'data_ultima_execucao': r.dataUltimaExecucao?.toIso8601String(),
    'tenant_id': tenantId,
  };
}

// ─────────────────────────────────────────────────────────────────────
// REPOSITÓRIO
// ─────────────────────────────────────────────────────────────────────

class RegrasManutencaoRepository {
  SupabaseClient get _client => Supabase.instance.client;

  final String tenantId;
  RegrasManutencaoRepository({this.tenantId = kDefaultTenantId});

  Future<List<RegraManutencao>> fetchAll() async {
    try {
      final rows = await _client
          .from(_kTable)
          .select('id, titulo, tipo, veiculo_placa, intervalo_km, intervalo_dias, custo_estimado, prioridade, is_ativa, km_ultima_execucao, data_ultima_execucao, tenant_id')
          .eq('tenant_id', tenantId)
          .order('titulo', ascending: true);
      return (rows as List<dynamic>)
          .map((r) => _fromRow(r as Map<String, dynamic>))
          .toList();
    } catch (e, st) {
      AppLogger.error('RegrasManutencaoRepository.fetchAll falhou', e, st);
      return [];
    }
  }

  Future<void> save(RegraManutencao regra) async {
    try {
      await _client.from(_kTable).upsert(
        _toRow(regra, tenantId),
        onConflict: 'id',
      );
    } catch (e, st) {
      AppLogger.error(
          'RegrasManutencaoRepository.save falhou [id=${regra.id}]', e, st);
      rethrow;
    }
  }

  Future<void> delete(String id) async {
    try {
      await _client.from(_kTable).delete().eq('id', id).eq('tenant_id', tenantId);
    } catch (e, st) {
      AppLogger.error(
          'RegrasManutencaoRepository.delete falhou [id=$id]', e, st);
      rethrow;
    }
  }

  /// Atualiza os campos de última execução após gerar uma OS.
  Future<void> marcarExecucao({
    required String id,
    required int kmExecucao,
    required DateTime dataExecucao,
  }) async {
    try {
      await _client.from(_kTable).update({
        'km_ultima_execucao': kmExecucao,
        'data_ultima_execucao': dataExecucao.toIso8601String(),
      }).eq('id', id).eq('tenant_id', tenantId);
    } catch (e, st) {
      AppLogger.error(
          'RegrasManutencaoRepository.marcarExecucao falhou [id=$id]', e, st);
    }
  }
}
