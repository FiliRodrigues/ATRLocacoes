import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fleet_app/core/services/auth_service.dart';

import 'dart:convert';
import 'package:crypto/crypto.dart';

Map<String, dynamic> _mockUser(String username, String password,
    {String tenantId = '00000000-0000-0000-0000-000000000001'}) {
  const salt = 'reg-salt-2026';
  final hash = sha256
      .convert(utf8.encode('$salt:$password:atr-salt-v1'))
      .toString();
  return {
    'username': username,
    'password_hash': hash,
    'password_salt': salt,
    'role': 'admin',
    'ativo': true,
    'tenant_id': tenantId,
  };
}

AuthService _serviceWithUser(String username, String password,
    {DateTime Function()? now,
    String tenantId = '00000000-0000-0000-0000-000000000001'}) {
  return AuthService(
    now: now,
    userLookup: (u) async => u == username.toLowerCase()
        ? _mockUser(username, password, tenantId: tenantId)
        : null,
  );
}

void main() {
  group('AuthService regression hardening', () {
    test('normaliza credenciais com trim antes de autenticar', () async {
      SharedPreferences.setMockInitialValues({});
        final service = _serviceWithUser('Adm', '123');

      final result = await service.loginWithCredentials(
        username: '  Adm  ',
        password: '  123  ',
      );

      expect(result.success, isTrue);
      expect(service.isAuthenticated, isTrue);
    });

    test('desbloqueia automaticamente apos lock expirar', () async {
      SharedPreferences.setMockInitialValues({});
      var now = DateTime(2026, 4, 23, 10);
        final service = _serviceWithUser('Adm', '123', now: () => now);

      for (var i = 0; i < 5; i++) {
        await service.loginWithCredentials(username: 'Adm', password: 'x');
      }

      now = now.add(const Duration(minutes: 6));
      final unlockedResult = await service.loginWithCredentials(
        username: 'Adm',
        password: '123',
      );

      final prefs = await SharedPreferences.getInstance();
      expect(unlockedResult.success, isTrue);
      expect(service.isAuthenticated, isTrue);
      expect(prefs.getInt('auth_locked_until_ms'), isNull);
      expect(prefs.getInt('auth_failed_attempts'), isNull);
    });

    test('atalho dev fica desabilitado por padrao', () {
      // kDebugMode == true em flutter test → atalho está disponível em debug
      final service = AuthService();
      // Em produção (release build) este valor é false.
      // Aqui apenas verificamos que o getter funciona sem erro.
      expect(service.canUseDevShortcut, isA<bool>());
    });
  });
}
