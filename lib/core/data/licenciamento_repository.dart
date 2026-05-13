import 'base_repository.dart';

class LicenciamentoRepository extends TenantCrudRepository {
  static const _selectColumns =
      'id, veiculo_id, ano_referencia, mes_vencimento, valor_total, '
      'data_vencimento, data_pagamento, status_pagamento, observacoes, '
      'created_at, tenant_id';

  @override
  String get tableName => 'licenciamento';

  Future<List<Map<String, dynamic>>> fetchByVeiculo(String veiculoId) async {
    return fetchByFieldRows(
      field: 'veiculo_id',
      value: veiculoId,
      selectColumns: _selectColumns,
      orderBy: 'ano_referencia',
      ascending: false,
    );
  }

  Future<List<Map<String, dynamic>>> fetchAll() async {
    return super.fetchAllRows(
      selectColumns: _selectColumns,
      orderBy: 'data_vencimento',
    );
  }
}
