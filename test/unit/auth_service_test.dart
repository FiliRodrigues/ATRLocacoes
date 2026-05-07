// Suite desativada após migração 017 (Supabase Auth + JWT-RLS).
// O AuthService antigo (parâmetro userLookup, hashPassword/verifyPassword)
// foi removido. Reescrever usando mock do GoTrue/SupabaseClient.
//
// TODO(security): reescrever testes pós-Supabase Auth.

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('auth_service_test (skipped pós-017)', () {}, skip: true);
}
