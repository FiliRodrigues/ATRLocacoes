import 'package:supabase_flutter/supabase_flutter.dart';

import '../constants.dart';
import '../services/audit_service.dart';

abstract class TenantCrudRepository {
  TenantCrudRepository({SupabaseClient? client})
      : _db = client ?? Supabase.instance.client;

  final SupabaseClient _db;

  String get tableName;

  String get tenantId => AuditService.currentTenantId ?? kDefaultTenantId;

  Future<List<Map<String, dynamic>>> fetchAllRows({
    required String selectColumns,
    required String orderBy,
    bool ascending = true,
    int limit = 500,
  }) async {
    final rows = await _db
        .from(tableName)
        .select(selectColumns)
        .eq('tenant_id', tenantId)
        .order(orderBy, ascending: ascending)
        .limit(limit);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<List<Map<String, dynamic>>> fetchByFieldRows({
    required String field,
    required Object value,
    required String selectColumns,
    required String orderBy,
    bool ascending = true,
    int limit = 500,
  }) async {
    final rows = await _db
        .from(tableName)
        .select(selectColumns)
        .eq(field, value)
        .eq('tenant_id', tenantId)
        .order(orderBy, ascending: ascending)
        .limit(limit);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<void> save(Map<String, dynamic> data) async {
    await _db.from(tableName).upsert({...data, 'tenant_id': tenantId});
  }

  Future<void> delete(String id) async {
    await _db.from(tableName).delete().eq('id', id).eq('tenant_id', tenantId);
  }
}
