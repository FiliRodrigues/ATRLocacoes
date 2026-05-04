import 'package:supabase_flutter/supabase_flutter.dart';
import '../enums/kanban_column.dart';
import '../enums/maintenance_priority.dart';
import '../services/audit_service.dart';
import '../utils/app_logger.dart';
import 'custos_models.dart';
import 'custos_repository.dart';

const String _kDefaultTenantId = '00000000-0000-0000-0000-000000000001';

// ═══════════════════════════════════════════════════════
// HELPERS DE SERIALIZAÇÃO
// ═══════════════════════════════════════════════════════

KanbanColumn _kanbamFromString(String? value) {
  return KanbanColumn.values.firstWhere(
    (col) => col.name == value,
    orElse: () => KanbanColumn.pendentes,
  );
}

MaintenancePriority _priorityFromString(String? value) {
  return MaintenancePriority.values.firstWhere(
    (p) => p.name == value,
    orElse: () => MaintenancePriority.media,
  );
}

ManutencaoItem _manutencaoFromRow(Map<String, dynamic> row) {
  return ManutencaoItem(
    id: row['id'] as String,
    veiculoPlaca: row['veiculo_placa'] as String? ?? '',
    veiculoNome: row['veiculo_nome'] as String? ?? '',
    titulo: row['titulo'] as String? ?? '',
    descricao: row['descricao'] as String? ?? '',
    tipo: row['tipo'] as String? ?? '',
    data: DateTime.parse(row['data'] as String),
    kmNoServico: (row['km_no_servico'] as num?)?.toInt() ?? 0,
    odometro: (row['odometro'] as num?)?.toInt() ?? 0,
    custo: (row['custo'] as num?)?.toDouble() ?? 0.0,
    prioridade: _priorityFromString(row['prioridade'] as String?),
    coluna: _kanbamFromString(row['coluna'] as String?),
    fornecedor: row['fornecedor'] as String? ?? '',
    numeroOS: row['numero_os'] as String? ?? '',
    nomeAnexo: row['nome_anexo'] as String? ?? '',
    isPreventiva: row['is_preventiva'] as bool? ?? true,
    dataConclusao: row['data_conclusao'] != null
        ? DateTime.parse(row['data_conclusao'] as String)
        : null,
  );
}

Map<String, dynamic> _manutencaoToRow(ManutencaoItem item) {
  return {
    'id': item.id,
    'veiculo_placa': item.veiculoPlaca,
    'veiculo_nome': item.veiculoNome,
    'titulo': item.titulo,
    'descricao': item.descricao,
    'tipo': item.tipo,
    'data': item.data.toIso8601String(),
    'km_no_servico': item.kmNoServico,
    'odometro': item.odometro,
    'custo': item.custo,
    'prioridade': item.prioridade.name,
    'coluna': item.coluna.name,
    'fornecedor': item.fornecedor,
    'numero_os': item.numeroOS,
    'nome_anexo': item.nomeAnexo,
    'is_preventiva': item.isPreventiva,
    'data_conclusao': item.dataConclusao?.toIso8601String(),
  };
}

DespesaItem _despesaFromRow(Map<String, dynamic> row) {
  return DespesaItem(
    id: row['id'] as String,
    veiculoPlaca: row['veiculo_placa'] as String? ?? '',
    motorista: row['motorista'] as String? ?? '',
    data: DateTime.parse(row['data'] as String),
    tipo: row['tipo'] as String? ?? '',
    descricao: row['descricao'] as String? ?? '',
    odometro: (row['odometro'] as num?)?.toInt() ?? 0,
    litros: (row['litros'] as num?)?.toDouble() ?? 0.0,
    valor: (row['valor'] as num?)?.toDouble() ?? 0.0,
    pago: row['pago'] as bool? ?? false,
    nf: row['nf'] as String? ?? '',
    nomeAnexo: row['nome_anexo'] as String? ?? '',
  );
}

Map<String, dynamic> _despesaToRow(DespesaItem item) {
  return {
    'id': item.id,
    'veiculo_placa': item.veiculoPlaca,
    'motorista': item.motorista,
    'data': item.data.toIso8601String(),
    'tipo': item.tipo,
    'descricao': item.descricao,
    'odometro': item.odometro,
    'litros': item.litros,
    'valor': item.valor,
    'pago': item.pago,
    'nf': item.nf,
    'nome_anexo': item.nomeAnexo,
  };
}

// ═══════════════════════════════════════════════════════
// REPOSITÓRIO
// ═══════════════════════════════════════════════════════

/// Implementação de [ICustosRepository] com persistência real no Supabase.
///
/// Todas as operações fazem upsert para garantir idempotência em reconexões.
class SupabaseCustosRepository implements ICustosRepository {
  SupabaseClient get _client => Supabase.instance.client;

  String get _tenantId =>
      AuditService.currentTenantId ?? _kDefaultTenantId;

  @override
  Future<List<ManutencaoItem>> fetchManutencoes() async {
    try {
      final rows = await _client
          .from('manutencoes')
          .select()
          .eq('tenant_id', _tenantId)
          .order('data', ascending: false);
      return (rows as List<dynamic>)
          .map((row) => _manutencaoFromRow(row as Map<String, dynamic>))
          .toList();
    } catch (error, stackTrace) {
      AppLogger.error('fetchManutencoes falhou', error, stackTrace);
      return [];
    }
  }

  @override
  Future<void> saveManutencao(ManutencaoItem item) async {
    try {
      await _client
          .from('manutencoes')
          .upsert({..._manutencaoToRow(item), 'tenant_id': _tenantId}, onConflict: 'id');
    } catch (error, stackTrace) {
      AppLogger.error('saveManutencao falhou [id=${item.id}]', error, stackTrace);
      rethrow;
    }
  }

  @override
  Future<void> deleteManutencao(String id) async {
    try {
      await _client.from('manutencoes').delete().eq('id', id);
    } catch (error, stackTrace) {
      AppLogger.error('deleteManutencao falhou [id=$id]', error, stackTrace);
      rethrow;
    }
  }

  @override
  Future<List<DespesaItem>> fetchDespesas() async {
    try {
      final rows = await _client
          .from('despesas')
          .select()
          .eq('tenant_id', _tenantId)
          .order('data', ascending: false);
      return (rows as List<dynamic>)
          .map((row) => _despesaFromRow(row as Map<String, dynamic>))
          .toList();
    } catch (error, stackTrace) {
      AppLogger.error('fetchDespesas falhou', error, stackTrace);
      return [];
    }
  }

  @override
  Future<void> saveDespesa(DespesaItem item) async {
    try {
      await _client
          .from('despesas')
          .upsert({..._despesaToRow(item), 'tenant_id': _tenantId}, onConflict: 'id');
    } catch (error, stackTrace) {
      AppLogger.error('saveDespesa falhou [id=${item.id}]', error, stackTrace);
      rethrow;
    }
  }

  @override
  Future<void> deleteDespesa(String id) async {
    try {
      await _client.from('despesas').delete().eq('id', id);
    } catch (error, stackTrace) {
      AppLogger.error('deleteDespesa falhou [id=$id]', error, stackTrace);
      rethrow;
    }
  }
}
