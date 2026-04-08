import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fleet_app/core/services/auth_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AuthService', () {
    late AuthService authService;

    setUp(() {
      authService = AuthService();
      SharedPreferences.setMockInitialValues({});
    });

    test('inicialmente não autenticado', () {
      expect(authService.isAuthenticated, false);
    });

    test('login define como autenticado', () async {
      await authService.login();
      expect(authService.isAuthenticated, true);
    });

    test('logout define como não autenticado', () async {
      await authService.login();
      expect(authService.isAuthenticated, true);

      await authService.logout();
      expect(authService.isAuthenticated, false);
    });

    test('checkAuth carrega estado salvo', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_authenticated', true);

      await authService.checkAuth();
      expect(authService.isAuthenticated, true);
    });

    test('checkAuth retorna false se não há valor salvo', () async {
      await authService.checkAuth();
      expect(authService.isAuthenticated, false);
    });
  });
}