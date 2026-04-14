import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fleet_app/core/services/auth_service.dart';

void main() {
  group('AuthService', () {
    test('retorna configurationMissing sem credenciais configuradas', () async {
      SharedPreferences.setMockInitialValues({});
      final service = AuthService(configuredUser: '', configuredPass: '');

      final result = await service.loginWithCredentials(
        username: 'admin',
        password: '1234',
      );

      expect(result.success, isFalse);
      expect(result.failureReason, AuthFailureReason.configurationMissing);
      expect(service.isAuthenticated, isFalse);
    });

    test('autentica com credenciais válidas e persiste sessão', () async {
      final fixedNow = DateTime(2026, 4, 13, 10);
      SharedPreferences.setMockInitialValues({});
      final service = AuthService(
        configuredUser: 'adm',
        configuredPass: '1234',
        now: () => fixedNow,
      );

      final result = await service.loginWithCredentials(
        username: 'adm',
        password: '1234',
      );

      final prefs = await SharedPreferences.getInstance();
      expect(result.success, isTrue);
      expect(service.isAuthenticated, isTrue);
      expect(prefs.getBool('is_authenticated'), isTrue);
      expect(
        prefs.getInt('session_started_at_ms'),
        fixedNow.millisecondsSinceEpoch,
      );
      expect(prefs.getInt('auth_failed_attempts'), isNull);
    });

    test('conta tentativas inválidas e retorna restante', () async {
      SharedPreferences.setMockInitialValues({});
      final service =
          AuthService(configuredUser: 'adm', configuredPass: '1234');

      final result = await service.loginWithCredentials(
        username: 'adm',
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
      final service = AuthService(
        configuredUser: 'adm',
        configuredPass: '1234',
        now: () => fixedNow,
      );

      for (var i = 0; i < 4; i++) {
        await service.loginWithCredentials(username: 'adm', password: 'x');
      }

      final lockResult = await service.loginWithCredentials(
        username: 'adm',
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
        username: 'adm',
        password: '1234',
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
      });
      final service = AuthService(
        configuredUser: 'adm',
        configuredPass: '1234',
        now: () => now,
      );

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
      });
      final service =
          AuthService(configuredUser: 'adm', configuredPass: '1234');
      await service.checkAuth();

      await service.logout();

      final prefs = await SharedPreferences.getInstance();
      expect(service.isAuthenticated, isFalse);
      expect(prefs.getBool('is_authenticated'), isNull);
      expect(prefs.getInt('session_started_at_ms'), isNull);
    });
  });
}
