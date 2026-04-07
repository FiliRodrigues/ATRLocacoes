import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/atr_theme_state.dart';
import 'core/data/fleet_data.dart';
import 'features/login/login_screen.dart';
import 'features/dashboard/dashboard_screen.dart';
import 'features/vehicles/vehicle_dossier_screen.dart';
import 'features/drivers/drivers_screen.dart';
import 'features/maintenance/maintenance_screen.dart';
import 'features/expenses/expenses_screen.dart';
import 'features/financial_admin/financial_admin_screen.dart';

void main() {
  runApp(const FleetApp());
}

class FleetApp extends StatelessWidget {
  const FleetApp({super.key});

  @override
  Widget build(BuildContext context) {
    final GoRouter router = GoRouter(
      initialLocation: '/login',
      routes: [
        GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
        GoRoute(path: '/', builder: (context, state) => const DashboardScreen()),
        GoRoute(path: '/vehicles/:id', builder: (context, state) => VehicleDossierScreen(plateId: state.pathParameters['id'] ?? '')),
        GoRoute(path: '/drivers', builder: (context, state) => const DriversScreen()),
        GoRoute(path: '/maintenance', builder: (context, state) => const MaintenanceScreen()),
        GoRoute(path: '/expenses', builder: (context, state) => const ExpensesScreen()),
        GoRoute(path: '/financial-admin', builder: (context, state) => const FinancialAdminScreen()),
        GoRoute(path: '/financial-admin/:index', builder: (context, state) => FinancialAdminScreen(vehicleIndex: int.tryParse(state.pathParameters['index'] ?? '') ?? 0)),
      ],
    );

    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AtrThemeState.notifier,
      builder: (context, mode, _) {
        return MaterialApp.router(
          title: 'ATR Locações - Gestão de Frotas',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: mode,
          routerConfig: router,
        );
      },
    );
  }
}
