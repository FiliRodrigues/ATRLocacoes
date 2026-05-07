// Suite desativada após migração 017 (Supabase Auth + JWT-RLS).
// O guard agora baseia-se no estado da sessão Supabase + role do JWT.
// Reescrever cobrindo o novo fluxo.
//
// TODO(security): reescrever testes pós-Supabase Auth.

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('app_router_guard_test (skipped pós-017)', () {}, skip: true);
}
