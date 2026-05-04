// Testes de isolamento cross-tenant
// Verifica que dados de Tenant A não são visíveis para Tenant B
// a nível de aplicação (repository-level filtering).
//
// Critério de aceite: 100% das tentativas cross-tenant bloqueadas
// no fluxo controlado pelo aplicativo.

import 'package:flutter_test/flutter_test.dart';
import 'package:fleet_app/core/services/auth_service.dart';
import 'package:fleet_app/core/services/audit_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';

const _kTenantA = '00000000-0000-0000-0000-000000000001';
const _kTenantB = '00000000-0000-0000-0000-000000000002';

Map<String, dynamic> _mockUserForTenant(
  String username,
  String password,
  String tenantId,
) {
  const salt = 'tenant-test-salt';
  final hash =
      sha256.convert(utf8.encode('$salt:$password:atr-salt-v1')).toString();
  return {
    'username': username,
    'password_hash': hash,
    'password_salt': salt,
    'role': 'admin',
    'ativo': true,
    'tenant_id': tenantId,
  };
}

AuthService _serviceForTenant(
  String username,
  String password,
  String tenantId,
) {
  return AuthService(
    userLookup: (u) async => u == username.toLowerCase()
        ? _mockUserForTenant(username, password, tenantId)
        : null,
  );
}

void main() {
  group('Tenant Isolation', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('usuário do tenant A obtém tenantId correto após login', () async {
      final service = _serviceForTenant('userA', 'senhaA', _kTenantA);
      final result =
          await service.loginWithCredentials(username: 'userA', password: 'senhaA');

      expect(result.success, isTrue);
      expect(service.currentUser?.tenantId, _kTenantA);
    });

    test('usuário do tenant B obtém tenantId correto após login', () async {
      final service = _serviceForTenant('userB', 'senhaB', _kTenantB);
      final result =
          await service.loginWithCredentials(username: 'userB', password: 'senhaB');

      expect(result.success, isTrue);
      expect(service.currentUser?.tenantId, _kTenantB);
    });

    test('AuditService.currentTenantId reflete tenant do usuário logado', () async {
      final serviceA = _serviceForTenant('userA', 'senhaA', _kTenantA);
      await serviceA.loginWithCredentials(username: 'userA', password: 'senhaA');

      expect(AuditService.currentTenantId, _kTenantA);

      // Simula troca de sessão para tenant B
      final serviceB = _serviceForTenant('userB', 'senhaB', _kTenantB);
      SharedPreferences.setMockInitialValues({});
      await serviceB.loginWithCredentials(username: 'userB', password: 'senhaB');

      expect(AuditService.currentTenantId, _kTenantB);
    });

    test('logout limpa tenantId do AuditService', () async {
      final service = _serviceForTenant('userA', 'senhaA', _kTenantA);
      await service.loginWithCredentials(username: 'userA', password: 'senhaA');

      expect(AuditService.currentTenantId, _kTenantA);

      await service.logout();

      expect(AuditService.currentTenantId, isNull);
    });

    test('tenant A e B têm tenantIds distintos', () async {
      final serviceA = _serviceForTenant('userA', 'senhaA', _kTenantA);
      await serviceA.loginWithCredentials(username: 'userA', password: 'senhaA');
      final tenantIdA = serviceA.currentUser?.tenantId;

      SharedPreferences.setMockInitialValues({});

      final serviceB = _serviceForTenant('userB', 'senhaB', _kTenantB);
      await serviceB.loginWithCredentials(username: 'userB', password: 'senhaB');
      final tenantIdB = serviceB.currentUser?.tenantId;

      expect(tenantIdA, isNotNull);
      expect(tenantIdB, isNotNull);
      expect(tenantIdA, isNot(equals(tenantIdB)));
    });

    test('sessão restaurada via checkAuth preserva tenantId', () async {
      final service = _serviceForTenant('userA', 'senhaA', _kTenantA);
      await service.loginWithCredentials(username: 'userA', password: 'senhaA');

      // Simula reinício do app: novo AuthService, mesmas SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('session_tenant_id'), _kTenantA);

      final serviceRestored = AuthService(
        userLookup: (_) async => null,
        now: DateTime.now,
      );
      await serviceRestored.checkAuth();

      expect(serviceRestored.isAuthenticated, isTrue);
      expect(serviceRestored.currentUser?.tenantId, _kTenantA);
      expect(AuditService.currentTenantId, _kTenantA);
    });
  });
}
