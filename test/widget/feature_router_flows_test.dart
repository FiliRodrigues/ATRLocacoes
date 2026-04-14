import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:fleet_app/core/data/fleet_data.dart';
import 'package:fleet_app/core/theme/app_theme.dart';
import 'package:fleet_app/features/dashboard/dashboard_screen.dart';
import 'package:fleet_app/features/drivers/drivers_screen.dart';
import 'package:fleet_app/features/expenses/expenses_screen.dart';
import 'package:fleet_app/features/maintenance/maintenance_provider.dart';
import 'package:fleet_app/features/maintenance/maintenance_screen.dart';
import 'package:fleet_app/features/vehicles/vehicle_dossier_screen.dart';

void main() {
  void setLargeViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Widget buildAppAt(String initialLocation) {
    final router = GoRouter(
      initialLocation: initialLocation,
      routes: [
        GoRoute(path: '/', builder: (_, __) => const DashboardScreen()),
        GoRoute(
          path: '/drivers',
          builder: (_, __) => const DriversScreen(),
        ),
        GoRoute(
          path: '/expenses',
          builder: (_, __) => const ExpensesScreen(),
        ),
        GoRoute(
          path: '/maintenance',
          builder: (_, __) => const MaintenanceScreen(),
        ),
        GoRoute(
          path: '/vehicles/:plate',
          builder: (_, state) =>
              VehicleDossierScreen(plateId: state.pathParameters['plate']!),
        ),
        GoRoute(
          path: '/login',
          builder: (_, __) => const SizedBox.shrink(),
        ),
        GoRoute(
            path: '/financial-admin',
            builder: (_, __) => const SizedBox.shrink(),),
      ],
    );

    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: FleetRepository.instance),
        ChangeNotifierProvider(create: (_) => MaintenanceProvider()),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        theme: AppTheme.lightTheme,
      ),
    );
  }

  testWidgets('dashboard renderiza resumo principal', (tester) async {
    setLargeViewport(tester);
    await tester.pumpWidget(buildAppAt('/'));
    await tester.pump(const Duration(milliseconds: 1300));
    await tester.pumpAndSettle();

    expect(find.text('Visão Geral'), findsOneWidget);
    expect(find.text('Resumo da Frota'), findsOneWidget);
  });

  testWidgets('drivers renderiza e filtra por busca', (tester) async {
    setLargeViewport(tester);
    await tester.pumpWidget(buildAppAt('/drivers'));
    await tester.pumpAndSettle();

    expect(find.text('Motoristas Ativos'), findsWidgets);
    expect(find.text('João Silva'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'nome-inexistente');
    await tester.pumpAndSettle();

    expect(find.text('João Silva'), findsNothing);
  });

  testWidgets('expenses renderiza e responde a busca', (tester) async {
    setLargeViewport(tester);
    await tester.pumpWidget(buildAppAt('/expenses'));
    await tester.pumpAndSettle();

    expect(find.text('Controle de Despesas'), findsWidgets);
    expect(find.text('João Silva'), findsWidgets);

    await tester.enterText(find.byType(TextField).first, 'placa-impossivel');
    await tester.pumpAndSettle();

    expect(find.text('João Silva'), findsNothing);
  });

  testWidgets('maintenance renderiza colunas do kanban', (tester) async {
    setLargeViewport(tester);
    await tester.pumpWidget(buildAppAt('/maintenance'));
    await tester.pumpAndSettle();

    expect(find.text('Quadro de Manutenções'), findsOneWidget);
    expect(find.text('Pendentes'), findsOneWidget);
    expect(find.text('Em Oficina'), findsOneWidget);
    expect(find.text('Concluídos'), findsOneWidget);
  });

  testWidgets('vehicle dossier renderiza dados do veículo', (tester) async {
    setLargeViewport(tester);
    await tester.pumpWidget(buildAppAt('/vehicles/VD-1234'));
    await tester.pumpAndSettle();

    expect(find.text('VD-1234'), findsWidgets);
    expect(find.text('Inteligência de Ativos'), findsOneWidget);
  });
}
