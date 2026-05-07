import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';
import 'package:fleet_app/core/data/fleet_data.dart';
import 'package:fleet_app/core/navigation/app_router.dart';
import 'package:fleet_app/core/services/auth_service.dart';
import 'package:fleet_app/core/theme/app_theme.dart';
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Widget buildApp(AuthService authService) {
    final appRouter = AppRouter(authService);
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: FleetRepository.instance),
        ChangeNotifierProvider.value(value: authService),
      ],
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        routerConfig: appRouter.router,
      ),
    );
  }

  testWidgets('fluxo completo: login -> seletor -> frota', (tester) async {
    // TODO(security): após migração 017 (Supabase Auth + JWT-RLS), o AuthService
    // usa Supabase.instance.client.auth.signInWithPassword. Reescrever este
    // teste com mock de GoTrue (ex.: SupabaseClient com servidor fake) ou
    // converter em widget test cobrindo apenas a UI sem rede.
    final auth = AuthService();

    await tester.pumpWidget(buildApp(auth));
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Fazer Login'), findsOneWidget);

    await tester.tap(find.text('Fazer Login'));
    await tester.pump(const Duration(milliseconds: 700));

    await tester.enterText(find.byType(TextField).first, 'adm');
    await tester.enterText(find.byType(TextField).last, 'senhaforte');
    await tester.tap(find.text('Entrar no Sistema'));
    await tester.pump(const Duration(seconds: 2));

    expect(find.text('Selecione o Sistema'), findsOneWidget);

    await tester.tap(find.text('Frota de Carros'));
    await tester.pump(const Duration(milliseconds: 1300));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Visão Geral'), findsOneWidget);
    expect(find.text('Resumo da Frota'), findsOneWidget);
    // TODO(security): Pendente reescrita pós-migração 017 (Supabase Auth + JWT).
  }, skip: true);
}
