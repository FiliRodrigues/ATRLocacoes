import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fleet_app/core/data/fleet_data.dart';
import 'package:fleet_app/core/data/locacao_models.dart';
import 'package:fleet_app/core/data/locacao_repository.dart';
import 'package:fleet_app/core/navigation/app_router.dart';
import 'package:fleet_app/core/services/auth_service.dart';
import 'package:fleet_app/core/data/custos_repository.dart';
import 'package:fleet_app/features/custos/custos_provider.dart';
import 'package:fleet_app/features/locacao/locacao_provider.dart';
import 'package:fleet_app/features/maintenance/maintenance_provider.dart';

class _StubLocacaoRepository extends LocacaoRepository {
  @override
  Future<List<Contrato>> fetchContratos({ContratoStatus? status}) =>
      Future.value([]);
  @override
  Future<Contrato?> fetchContrato(String id) => Future.value(null);
  @override
  Future<List<Ocorrencia>> fetchTodasOcorrencias() => Future.value([]);
  @override
  Future<List<ChecklistEvento>> fetchChecklist(String contratoId) =>
      Future.value([]);
  @override
  Future<List<Ocorrencia>> fetchOcorrencias(String contratoId) =>
      Future.value([]);
}

/// Cria um AuthService com credenciais de usuário frota-only para testes.
AuthService _makeFrotaAuth() {
  const salt = 'frota-test-salt';
  const pass = '123';
  final hash =
      sha256.convert(utf8.encode('$salt:$pass:atr-salt-v1')).toString();
  return AuthService(
    userLookup: (u) async => u == 'frota'
        ? {
            'username': 'Frota',
            'password_hash': hash,
            'password_salt': salt,
            'role': 'fleet',
            'ativo': true,
            'tenant_id': '00000000-0000-0000-0000-000000000001',
          }
        : null,
  );
}

Widget _wrapWithProviders({
  required AuthService auth,
  required Widget router,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: auth),
      ChangeNotifierProvider.value(value: FleetRepository.instance),
      ChangeNotifierProvider(create: (_) => MaintenanceProvider()),
      ChangeNotifierProvider(
        create: (_) => LocacaoProvider(_StubLocacaoRepository()),
      ),
      ChangeNotifierProvider(
        create: (_) => CustosProvider(LocalCustosRepository()),
      ),
    ],
    child: router,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppRouter guards', () {
    testWidgets('nao autenticado e redirecionado para login', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final auth = AuthService();
      final appRouter = AppRouter(auth);

      await tester.pumpWidget(
        _wrapWithProviders(
          auth: auth,
          router: MaterialApp.router(routerConfig: appRouter.router),
        ),
      );
      await tester.pumpAndSettle();

      appRouter.router.go('/drivers');
      await tester.pumpAndSettle();

      expect(find.text('Fazer Login'), findsOneWidget);
    });

    testWidgets('autenticado em login redireciona para seletor', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final auth = AuthService();
      await auth.login();

      final appRouter = AppRouter(auth);

      await tester.pumpWidget(
        _wrapWithProviders(
          auth: auth,
          router: MaterialApp.router(routerConfig: appRouter.router),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Selecione o Sistema'), findsOneWidget);
    });

    testWidgets('usuario frota redireciona direto para dashboard', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      SharedPreferences.setMockInitialValues({});
      final auth = _makeFrotaAuth();
      await auth.loginWithCredentials(username: 'Frota', password: '123');
      final appRouter = AppRouter(auth);

      await tester.pumpWidget(
        _wrapWithProviders(
          auth: auth,
          router: MaterialApp.router(routerConfig: appRouter.router),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Selecione o Sistema'), findsNothing);
    });

    testWidgets('usuario frota nao acessa modulo obras', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      SharedPreferences.setMockInitialValues({});
      final auth = _makeFrotaAuth();
      await auth.loginWithCredentials(username: 'Frota', password: '123');
      final appRouter = AppRouter(auth);

      await tester.pumpWidget(
        _wrapWithProviders(
          auth: auth,
          router: MaterialApp.router(routerConfig: appRouter.router),
        ),
      );
      await tester.pumpAndSettle();

      appRouter.router.go('/obras');
      await tester.pumpAndSettle();

      expect(appRouter.router.routeInformationProvider.value.uri.path, '/');
    });
  });
}
