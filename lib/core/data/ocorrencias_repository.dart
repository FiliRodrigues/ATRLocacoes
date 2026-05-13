import 'base_repository.dart';

class OcorrenciasRepository extends TenantCrudRepository {
  static const _selectColumns =
      'id, contrato_id, tipo, status, descricao, data_ocorrencia, '
      'valor_estimado, valor_final, impacto_financeiro, responsavel_pagamento, '
      'fotos, observacoes, registrado_por, resolvido_por, data_resolucao, '
      'created_at, updated_at, tenant_id';

  @override
  String get tableName => 'ocorrencias';

  Future<List<Map<String, dynamic>>> fetchByContrato(String contratoId) async {
    return fetchByFieldRows(
      field: 'contrato_id',
      value: contratoId,
      selectColumns: _selectColumns,
      orderBy: 'data_ocorrencia',
      ascending: false,
    );
  }

  Future<List<Map<String, dynamic>>> fetchAll() async {
    return super.fetchAllRows(
      selectColumns: _selectColumns,
      orderBy: 'data_ocorrencia',
      ascending: false,
    );
  }
}
