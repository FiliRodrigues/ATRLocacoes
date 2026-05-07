// Suite desativada após migração 017 (Supabase Auth + JWT-RLS).
// Isolamento agora é garantido pelas RLS policies usando auth_tenant_id()
// (claim JWT). Reescrever cobrindo o novo caminho.
//
// TODO(security): reescrever testes pós-Supabase Auth.

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('tenant_isolation_test (skipped pós-017)', () {}, skip: true);
}
