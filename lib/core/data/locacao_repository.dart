import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/audit_service.dart';
import '../utils/app_logger.dart';
import 'locacao_models.dart';

/// UUID do tenant padrão — espelho do `kDefaultTenantId` em auth_service.dart.
import '../constants.dart';

/// Repositório de contratos, checklist e ocorrências via Supabase.
///
/// Todas as queries incluem filtro explícito por [tenantId] (isolamento
/// de aplicação). A RLS do banco adiciona uma segunda camada quando o JWT
/// contém o claim `tenant_id`.
class LocacaoRepository {
  SupabaseClient get _db => Supabase.instance.client;

  /// Retorna o tenant_id ativo do usuário logado.
  String get _tenantId => AuditService.currentTenantId ?? kDefaultTenantId;

  // ────────────────────────────────────────────────────
  // CONTRATOS
  // ────────────────────────────────────────────────────

  Future<List<Contrato>> fetchContratos({ContratoStatus? status}) async {
    var query = _db
        .from('contratos')
        .select('id, numero, cliente_nome, cliente_cnpj, cliente_contato, veiculo_placa, data_inicio, data_fim, sla_km_mes, valor_mensal, status, observacoes, criado_por, created_at, updated_at')
        .eq('tenant_id', _tenantId);
    
    if (status != null) {
      query = query.eq('status', status.name);
    }
    
    final rows = await query.order('created_at', ascending: false).limit(500);
    return rows
        .map((r) => Contrato.fromRow(r))
        .toList();
  }

  Future<Contrato?> fetchContrato(String id) async {
    try {
      final row = await _db
          .from('contratos')
          .select('id, numero, cliente_nome, cliente_cnpj, cliente_contato, veiculo_placa, data_inicio, data_fim, sla_km_mes, valor_mensal, status, observacoes, criado_por, created_at, updated_at')
          .eq('id', id)
          .eq('tenant_id', _tenantId)
          .single();
      return Contrato.fromRow(row);
    } catch (e, s) {
      AppLogger.error('fetchContrato falhou [id=$id]', e, s);
      return null;
    }
  }

  Future<Contrato> createContrato(Contrato contrato) async {
    final row = await _db
        .from('contratos')
        .insert({...contrato.toRow(), 'tenant_id': _tenantId})
        .select('id, numero, cliente_nome, cliente_cnpj, cliente_contato, veiculo_placa, data_inicio, data_fim, sla_km_mes, valor_mensal, status, observacoes, criado_por, created_at, updated_at')
        .single();
    return Contrato.fromRow(row);
  }

  Future<Contrato> updateContrato(Contrato contrato) async {
    final row = await _db
        .from('contratos')
        .update(contrato.toRow())
        .eq('id', contrato.id)
        .eq('tenant_id', _tenantId)
        .select('id, numero, cliente_nome, cliente_cnpj, cliente_contato, veiculo_placa, data_inicio, data_fim, sla_km_mes, valor_mensal, status, observacoes, criado_por, created_at, updated_at')
        .single();
    return Contrato.fromRow(row);
  }

  Future<void> deleteContrato(String id) async {
    await _db
        .from('contratos')
        .delete()
        .eq('id', id)
        .eq('tenant_id', _tenantId);
  }

  // ────────────────────────────────────────────────────
  // CHECKLIST
  // ────────────────────────────────────────────────────

  Future<List<ChecklistEvento>> fetchChecklist(String contratoId) async {
    final rows = await _db
        .from('checklist_eventos')
        .select('id, contrato_id, tipo, km_odometro, km_percorridos, combustivel_pct, observacoes, fotos, doc_url, assinatura_url, realizado_por, created_at, itens')
        .eq('contrato_id', contratoId)
        .eq('tenant_id', _tenantId)
        .order('created_at', ascending: false)
        .limit(500);
    return rows
        .map((r) => ChecklistEvento.fromRow(r))
        .toList();
  }

  Future<ChecklistEvento> createChecklist(ChecklistEvento evento) async {
    final row = await _db
        .from('checklist_eventos')
        .insert({...evento.toRow(), 'tenant_id': _tenantId})
        .select('id, contrato_id, tipo, km_odometro, km_percorridos, combustivel_pct, observacoes, fotos, doc_url, assinatura_url, realizado_por, created_at, itens')
        .single();
    return ChecklistEvento.fromRow(row);
  }

  Future<ChecklistEvento> updateChecklist(ChecklistEvento evento) async {
    final row = await _db
        .from('checklist_eventos')
        .update(evento.toRow())
        .eq('id', evento.id)
        .eq('tenant_id', _tenantId)
        .select('id, contrato_id, tipo, km_odometro, km_percorridos, combustivel_pct, observacoes, fotos, doc_url, assinatura_url, realizado_por, created_at, itens')
        .single();
    return ChecklistEvento.fromRow(row);
  }

  // ────────────────────────────────────────────────────
  // OCORRÊNCIAS
  // ────────────────────────────────────────────────────

  Future<List<Ocorrencia>> fetchOcorrencias(String contratoId) async {
    final rows = await _db
        .from('ocorrencias')
        .select('id, contrato_id, tipo, status, descricao, data_ocorrencia, valor_estimado, valor_final, impacto_financeiro, responsavel_pagamento, fotos, observacoes, registrado_por, resolvido_por, data_resolucao, created_at, updated_at')
        .eq('contrato_id', contratoId)
        .eq('tenant_id', _tenantId)
        .order('data_ocorrencia', ascending: false)
        .limit(500);
    return rows
        .map((r) => Ocorrencia.fromRow(r))
        .toList();
  }

  Future<List<Ocorrencia>> fetchTodasOcorrencias() async {
    final rows = await _db
        .from('ocorrencias')
        .select('id, contrato_id, tipo, status, descricao, data_ocorrencia, valor_estimado, valor_final, impacto_financeiro, responsavel_pagamento, fotos, observacoes, registrado_por, resolvido_por, data_resolucao, created_at, updated_at')
        .eq('tenant_id', _tenantId)
        .order('data_ocorrencia', ascending: false)
        .limit(500);
    return rows
        .map((r) => Ocorrencia.fromRow(r))
        .toList();
  }

  Future<Ocorrencia> createOcorrencia(Ocorrencia ocorrencia) async {
    final row = await _db
        .from('ocorrencias')
        .insert({...ocorrencia.toInsertRow(), 'tenant_id': _tenantId})
        .select('id, contrato_id, tipo, status, descricao, data_ocorrencia, valor_estimado, valor_final, impacto_financeiro, responsavel_pagamento, fotos, observacoes, registrado_por, resolvido_por, data_resolucao, created_at, updated_at')
        .single();
    return Ocorrencia.fromRow(row);
  }

  Future<Ocorrencia> updateOcorrencia(Ocorrencia ocorrencia) async {
    final updatePayload = {
      ...ocorrencia.toInsertRow(),
      'resolvido_por': ocorrencia.resolvidoPor,
      'data_resolucao': ocorrencia.dataResolucao
          ?.toIso8601String()
          .split('T')
          .first,
      'updated_at': ocorrencia.updatedAt.toIso8601String(),
    };
    final row = await _db
        .from('ocorrencias')
        .update(updatePayload)
        .eq('id', ocorrencia.id)
        .eq('tenant_id', _tenantId)
        .select('id, contrato_id, tipo, status, descricao, data_ocorrencia, valor_estimado, valor_final, impacto_financeiro, responsavel_pagamento, fotos, observacoes, registrado_por, resolvido_por, data_resolucao, created_at, updated_at')
        .single();
    return Ocorrencia.fromRow(row);
  }

  // ────────────────────────────────────────────────
  // STORAGE
  // ────────────────────────────────────────────────

  /// Realiza upload de um arquivo para o bucket [atr-attachments] do Supabase Storage.
  ///
  /// Retorna a URL pública persistida.
  /// [category] deve ser 'checklist' ou 'ocorrencia'.
  Future<String> uploadAnexo({
    required String category,
    required String entityId,
    required String fileName,
    required Uint8List bytes,
    String contentType = 'application/octet-stream',
  }) async {
    final path =
        '$_tenantId/$category/$entityId/${DateTime.now().millisecondsSinceEpoch}_$fileName';
    await _db.storage
        .from('atr-attachments')
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: contentType, upsert: false),
        );
    return _db.storage.from('atr-attachments').getPublicUrl(path);
  }
}
