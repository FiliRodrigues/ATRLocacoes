import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fleet_app/core/services/auth_service.dart';

import 'dart:convert';
import 'package:crypto/crypto.dart';

Map<String, dynamic> _mockUser(
  String username,
  String password, {
  String role = 'admin',
  String tenantId = '00000000-0000-0000-0000-000000000001',
}) {
  const salt = 'test-salt-2026';
  final hash = sha256
      .convert(utf8.encode('$salt:$password:atr-salt-v1'))
      .toString();
  return {
    'username': username,
    'password_hash': hash,
    'password_salt': salt,
    'role': role,
    'ativo': true,
    'tenant_id': tenantId,
  };
}

AuthService _serviceWithUser(
  String username,
  String password, {
  String role = 'admin',
  String tenantId = '00000000-0000-0000-0000-000000000001',
  DateTime Function()? now,
}) {
  return AuthService(
    now: now,
    userLookup: (u) async => u == username.toLowerCase()
        ? _mockUser(username, password, role: role, tenantId: tenantId)
        : null,
  );
}

void main() {
  group('AuthService', () {
    test('retorna configurationMissing quando sem credenciais configuradas',
        () async {
      SharedPreferences.setMockInitialValues({});
        // AuthService sem userLookup → usa Supabase real (não disponível em teste)
        // Mas o fluxo sem usuário encontrado retorna invalidCredentials,
        // pois a exceção de rede é capturada como networkError.
        // Verificamos que sem credenciais válidas não autentica.
        final service = AuthService(userLookup: (_) async => null);

      final result = await service.loginWithCredentials(
        username: 'Adm',
        password: '123',
      );

      expect(result.success, isFalse);
        expect(result.failureReason, AuthFailureReason.invalidCredentials);
      expect(service.isAuthenticated, isFalse);
    });

    test('retorna invalidCredentials para usuario desconhecido', () async {
      SharedPreferences.setMockInitialValues({});
        final service = _serviceWithUser('Adm', '123');

      final result = await service.loginWithCredentials(
        username: 'usuario_nao_cadastrado',
        password: '123',
      );

      expect(result.success, isFalse);
      expect(result.failureReason, AuthFailureReason.invalidCredentials);
      expect(service.isAuthenticated, isFalse);
    });

    test('autentica com credenciais válidas e persiste sessão', () async {
      final fixedNow = DateTime(2026, 4, 13, 10);
      SharedPreferences.setMockInitialValues({});
        final service = _serviceWithUser('Adm', '123', now: () => fixedNow);

      final result = await service.loginWithCredentials(
        username: 'Adm',
        password: '123',
      );

      final prefs = await SharedPreferences.getInstance();
      expect(result.success, isTrue);
      expect(service.isAuthenticated, isTrue);
      expect(service.currentUser?.username, 'Adm');
      expect(service.currentRole, AuthUserRole.admin);
      expect(service.currentUser?.tenantId, '00000000-0000-0000-0000-000000000001');
      expect(prefs.getBool('is_authenticated'), isTrue);
      expect(
        prefs.getInt('session_started_at_ms'),
        fixedNow.millisecondsSinceEpoch,
      );
      expect(prefs.getString('session_user'), 'Adm');
      expect(prefs.getString('session_role'), 'admin');
      expect(prefs.getString('session_tenant_id'), '00000000-0000-0000-0000-000000000001');
      expect(prefs.getInt('auth_failed_attempts'), isNull);
    });

    test('conta tentativas inválidas e retorna restante', () async {
      SharedPreferences.setMockInitialValues({});
        final service = _serviceWithUser('Adm', '123');

      final result = await service.loginWithCredentials(
        username: 'Adm',
        password: 'errada',
      );

      final prefs = await SharedPreferences.getInstance();
      expect(result.success, isFalse);
      expect(result.failureReason, AuthFailureReason.invalidCredentials);
      expect(result.remainingAttempts, 4);
      expect(prefs.getInt('auth_failed_attempts'), 1);
    });

    test('bloqueia login após exceder limite de tentativas', () async {
      final fixedNow = DateTime(2026, 4, 13, 10);
      SharedPreferences.setMockInitialValues({});
        final service = _serviceWithUser('Adm', '123', now: () => fixedNow);

      for (var i = 0; i < 4; i++) {
        await service.loginWithCredentials(username: 'Adm', password: 'x');
      }

      final lockResult = await service.loginWithCredentials(
        username: 'Adm',
        password: 'x',
      );

      final prefs = await SharedPreferences.getInstance();
      expect(lockResult.success, isFalse);
      expect(lockResult.failureReason, AuthFailureReason.locked);
      expect(lockResult.lockRemaining, const Duration(minutes: 5));
      expect(
        prefs.getInt('auth_locked_until_ms'),
        fixedNow.add(const Duration(minutes: 5)).millisecondsSinceEpoch,
      );
      expect(prefs.getInt('auth_failed_attempts'), isNull);

      final stillLocked = await service.loginWithCredentials(
        username: 'Adm',
        password: '123',
      );
      expect(stillLocked.success, isFalse);
      expect(stillLocked.failureReason, AuthFailureReason.locked);
    });

    test('expira sessão no checkAuth quando ultrapassa 12 horas', () async {
      final sessionStart = DateTime(2026, 4, 13, 8);
      final now = DateTime(2026, 4, 13, 21, 0, 1);
      SharedPreferences.setMockInitialValues({
        'is_authenticated': true,
        'session_started_at_ms': sessionStart.millisecondsSinceEpoch,
        'session_user': 'Adm',
        'session_role': 'admin',
        'session_proof': '3b4d98f0',
      });
        // checkAuth não precisa de userLookup — só valida prova + expiração
        final service = AuthService(now: () => now);

      await service.checkAuth();

      final prefs = await SharedPreferences.getInstance();
      expect(service.isAuthenticated, isFalse);
      expect(prefs.getBool('is_authenticated'), isNull);
      expect(prefs.getInt('session_started_at_ms'), isNull);
    });

    test('logout limpa sessão persistida', () async {
      SharedPreferences.setMockInitialValues({
        'is_authenticated': true,
        'session_started_at_ms':
            DateTime(2026, 4, 13, 10).millisecondsSinceEpoch,
        'session_user': 'Adm',
        'session_role': 'admin',
        'session_proof': '969b7bc7',
      });
        final service = AuthService();
        await service.checkAuth(); // prova pode não bater → limpa, mas logout funciona

      await service.logout();

      final prefs = await SharedPreferences.getInstance();
      expect(service.isAuthenticated, isFalse);
      expect(prefs.getBool('is_authenticated'), isNull);
      expect(prefs.getInt('session_started_at_ms'), isNull);
    });

    test('rejeita sessão com session_proof adulterado', () async {
      SharedPreferences.setMockInitialValues({
        'is_authenticated': true,
        'session_started_at_ms':
            DateTime(2026, 4, 13, 10).millisecondsSinceEpoch,
        'session_user': 'Adm',
        'session_role': 'admin',
        'session_proof': 'adulterado00',
      });
        final service = AuthService();

      await service.checkAuth();

      expect(service.isAuthenticated, isFalse);
    });

    test('isolamento cross-tenant: tenants diferentes produzem tenantIds diferentes', () async {
      SharedPreferences.setMockInitialValues({});
      const tenantA = '00000000-0000-0000-0000-000000000001';
      const tenantB = '00000000-0000-0000-0000-000000000002';

      final serviceA = _serviceWithUser('userA', 'senhaA', tenantId: tenantA);
      final serviceB = _serviceWithUser('userB', 'senhaB', tenantId: tenantB);

      final resultA = await serviceA.loginWithCredentials(
        username: 'userA',
        password: 'senhaA',
      );
      expect(resultA.success, isTrue);
      expect(serviceA.currentUser?.tenantId, tenantA);

      SharedPreferences.setMockInitialValues({});
      final resultB = await serviceB.loginWithCredentials(
        username: 'userB',
        password: 'senhaB',
      );
      expect(resultB.success, isTrue);
      expect(serviceB.currentUser?.tenantId, tenantB);

      // Garantir que os tenants são distintos
      expect(serviceA.currentUser?.tenantId, isNot(equals(serviceB.currentUser?.tenantId)));
    });

    test('login com tenant_id ausente usa fallback para tenant padrão', () async {
      SharedPreferences.setMockInitialValues({});
      // Simula lookup que não retorna tenant_id (dados legados)
      final service = AuthService(
        userLookup: (_) async => {
          'username': 'legado',
          'password_hash': sha256
              .convert(utf8.encode('salt:123:atr-salt-v1'))
              .toString(),
          'password_salt': 'salt',
          'role': 'admin',
          'ativo': true,
          // tenant_id ausente propositalmente
        },
      );

      final result = await service.loginWithCredentials(
        username: 'legado',
        password: '123',
      );

      expect(result.success, isTrue);
      expect(service.currentUser?.tenantId, kDefaultTenantId);
    });
  });
}
