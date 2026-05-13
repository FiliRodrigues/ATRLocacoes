import 'base_repository.dart';

class MultasRepository extends TenantCrudRepository {
  static const _selectColumns =
      'id, veiculo_id, ano_referencia, mes, valor, descricao, '
      'status_pagamento, data_infracao, data_vencimento, data_pagamento, '
      'created_at, tenant_id';

  @override
  String get tableName => 'multas';

  Future<List<Map<String, dynamic>>> fetchByVeiculo(String veiculoId) async {
    return fetchByFieldRows(
      field: 'veiculo_id',
      value: veiculoId,
      selectColumns: _selectColumns,
      orderBy: 'data_infracao',
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
