import 'package:supabase_flutter/supabase_flutter.dart';
import '../enums/kanban_column.dart';
import '../enums/maintenance_priority.dart';
import '../services/audit_service.dart';
import '../utils/app_logger.dart';
import 'custos_models.dart';
import 'custos_repository.dart';

import '../constants.dart';

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
    data: DateTime.tryParse(row['data']?.toString() ?? '') ?? DateTime.now(),
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
        ? DateTime.tryParse(row['data_conclusao']?.toString() ?? '')
        : null,
  );
}

Map<String, dynamic> _manutencaoToRow(ManutencaoItem item) {
  final row = <String, dynamic>{
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
  // Só inclui id se for UUID (tem hífen) — senão Supabase gera via DEFAULT
  if (item.id.contains('-')) row['id'] = item.id;
  return row;
}

DespesaItem _despesaFromRow(Map<String, dynamic> row) {
  return DespesaItem(
    id: row['id'] as String,
    veiculoPlaca: row['veiculo_placa'] as String? ?? '',
    motorista: row['motorista'] as String? ?? '',
    data: DateTime.tryParse(row['data']?.toString() ?? '') ?? DateTime.now(),
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
  final row = <String, dynamic>{
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
  // Só inclui id se for UUID (tem hífen) — senão Supabase gera via DEFAULT
  if (item.id.contains('-')) row['id'] = item.id;
  return row;
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
      AuditService.currentTenantId ?? kDefaultTenantId;

  @override
  Future<List<ManutencaoItem>> fetchManutencoes({
    int page = 0,
    int pageSize = 50,
  }) async {
    try {
      // skill:query — colunas explícitas reduzem payload de rede.
      // skill:data  — paginação via .range() delega o corte ao Postgres (O(1))
      //               em vez de filtrar a lista no Dart (O(N)).
      final from = page * pageSize;
      final to = from + pageSize - 1;

      final rows = await _client
          .from('manutencoes')
          .select(
            'id, veiculo_placa, veiculo_nome, titulo, descricao, tipo, '
            'data, km_no_servico, odometro, custo, prioridade, coluna, '
            'fornecedor, numero_os, nome_anexo, is_preventiva, data_conclusao',
          )
          .eq('tenant_id', _tenantId)
          .order('data', ascending: false)
          .range(from, to);
      return (rows as List<dynamic>)
          .map((row) => _manutencaoFromRow(row as Map<String, dynamic>))
          .toList();
    } catch (error, stackTrace) {
      AppLogger.error(
        'fetchManutencoes falhou [page=$page]',
        error,
        stackTrace,
      );
      return [];
    }
  }

  @override
  Future<String> saveManutencao(ManutencaoItem item) async {
    try {
      final row = {..._manutencaoToRow(item), 'tenant_id': _tenantId};
      final isNew = !item.id.contains('-'); // UUID tem hífen, timestamp não
      if (isNew) {
        final result = await _client.from('manutencoes').insert(row).select('id').single();
        return result['id'] as String;
      } else {
        await _client.from('manutencoes').update(row).eq('id', item.id);
        return item.id;
      }
    } catch (error, stackTrace) {
      AppLogger.error('saveManutencao falhou [id=${item.id}]', error, stackTrace);
      rethrow;
    }
  }

  @override
  Future<void> deleteManutencao(String id) async {
    try {
      await _client.from('manutencoes').delete().eq('id', id).eq('tenant_id', _tenantId);
    } catch (error, stackTrace) {
      AppLogger.error('deleteManutencao falhou [id=$id]', error, stackTrace);
      rethrow;
    }
  }

  @override
  Future<List<DespesaItem>> fetchDespesas({
    int page = 0,
    int pageSize = 50,
  }) async {
    try {
      // skill:query — colunas explícitas; skill:data — paginação via .range()
      final from = page * pageSize;
      final to = from + pageSize - 1;

      final rows = await _client
          .from('despesas')
          .select(
            'id, veiculo_placa, motorista, data, tipo, descricao, '
            'odometro, litros, valor, pago, nf, nome_anexo',
          )
          .eq('tenant_id', _tenantId)
          .order('data', ascending: false)
          .range(from, to);
      return (rows as List<dynamic>)
          .map((row) => _despesaFromRow(row as Map<String, dynamic>))
          .toList();
    } catch (error, stackTrace) {
      AppLogger.error(
        'fetchDespesas falhou [page=$page]',
        error,
        stackTrace,
      );
      return [];
    }
  }

  @override
  Future<String> saveDespesa(DespesaItem item) async {
    try {
      final row = {..._despesaToRow(item), 'tenant_id': _tenantId};
      final isNew = !item.id.contains('-'); // UUID tem hífen, timestamp não
      if (isNew) {
        final result = await _client.from('despesas').insert(row).select('id').single();
        return result['id'] as String;
      } else {
        await _client.from('despesas').update(row).eq('id', item.id);
        return item.id;
      }
    } catch (error, stackTrace) {
      AppLogger.error('saveDespesa falhou [id=${item.id}]', error, stackTrace);
      rethrow;
    }
  }

  @override
  Future<void> deleteDespesa(String id) async {
    try {
      await _client.from('despesas').delete().eq('id', id).eq('tenant_id', _tenantId);
    } catch (error, stackTrace) {
      AppLogger.error('deleteDespesa falhou [id=$id]', error, stackTrace);
      rethrow;
    }
  }
}
