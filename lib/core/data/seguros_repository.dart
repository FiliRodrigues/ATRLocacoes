import 'base_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SegurosRepository extends TenantCrudRepository {
  static const _selectColumns =
      'id, veiculo_id, ano_referencia, empresa, numero_apolice, valor_apolice, '
      'num_parcelas, data_inicio, data_renovacao, valor_total_pago, '
      'status_pagamento, observacoes, created_at, updated_at, tenant_id';

  @override
  String get tableName => 'seguros';

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
      orderBy: 'data_renovacao',
    );
  }

  Future<List<Map<String, dynamic>>> fetchAllComVeiculo() async {
    final rows = await Supabase.instance.client
        .from('seguros')
        .select('id, veiculo_id, ano_referencia, empresa, numero_apolice, valor_apolice, num_parcelas, data_inicio, data_renovacao, valor_total_pago, status_pagamento, veiculos(placa, marca, modelo)')
        .eq('tenant_id', tenantId)
        .order('data_renovacao', ascending: true)
        .limit(500);
    return List<Map<String, dynamic>>.from(rows);
  }
}
