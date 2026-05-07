import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/audit_service.dart';
import 'combustivel_models.dart';

import '../constants.dart';

class CombustivelRepository {
  static final _db = Supabase.instance.client;

  String get _tenantId => AuditService.currentTenantId ?? kDefaultTenantId;

  Future<List<Abastecimento>> fetchAll({String? veiculoPlaca}) async {
    var query = _db
        .from('abastecimentos')
        .select('id, veiculo_placa, data, litros, valor_total, km_odometro, tipo, posto, registrado_por, tenant_id, created_at')
        .eq('tenant_id', _tenantId);

    if (veiculoPlaca != null) {
      query = query.eq('veiculo_placa', veiculoPlaca);
    }

    final rows = await query.order('data', ascending: false);
    return rows.map(Abastecimento.fromRow).toList();
  }

  Future<void> save(Abastecimento a) async {
    await _db.from('abastecimentos').upsert({...a.toRow(), 'tenant_id': _tenantId});
  }

  Future<void> delete(String id) async {
    await _db.from('abastecimentos').delete().eq('id', id).eq('tenant_id', _tenantId);
  }
}
