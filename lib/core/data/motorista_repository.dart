import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/audit_service.dart';
import '../constants.dart';

class MotoristaRepository {
  static final _db = Supabase.instance.client;

  String get _tenantId => AuditService.currentTenantId ?? kDefaultTenantId;

  Future<List<Map<String, dynamic>>> fetchAll() async {
    final rows = await _db
        .from('motoristas')
        .select()
        .eq('tenant_id', _tenantId)
        .order('nome', ascending: true)
        .limit(500);
    return rows;
  }

  Future<Map<String, dynamic>?> fetchById(String id) async {
    try {
      final row = await _db
          .from('motoristas')
          .select()
          .eq('id', id)
          .eq('tenant_id', _tenantId)
          .single();
      return row;
    } catch (_) {
      return null;
    }
  }

  Future<void> save(Map<String, dynamic> data) async {
    await _db.from('motoristas').upsert({...data, 'tenant_id': _tenantId});
  }

  Future<void> delete(String id) async {
    await _db.from('motoristas').delete().eq('id', id).eq('tenant_id', _tenantId);
  }
}
