import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/atr_theme_state.dart';
import 'features/login/login_screen.dart';
import 'features/dashboard/dashboard_screen.dart';
import 'features/vehicles/vehicle_dossier_screen.dart';
import 'features/drivers/drivers_screen.dart';
import 'features/maintenance/maintenance_screen.dart';
import 'features/maintenance/maintenance_provider.dart';
import 'features/expenses/expenses_screen.dart';
import 'features/financial_admin/financial_admin_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => MaintenanceProvider()),
      ],
      child: const ATRApp(),
    ),
  );
}

class ATRApp extends StatelessWidget {
  const ATRApp({super.key});

  @override
  Widget build(BuildContext context) {
    final GoRouter router = GoRouter(
      initialLocation: '/login',
      routes: [
        GoRoute(
          path: '/login',
          builder: (context, state) => const LoginScreen(),
        ),
        GoRoute(
          path: '/',
          builder: (context, state) => const DashboardScreen(),
          routes: [
            GoRoute(
              path: 'vehicles/:plate',
              builder: (context, state) {
                final plate = state.pathParameters['plate'] ?? '';
                return VehicleDossierScreen(plateId: plate);
              },
            ),
            GoRoute(
              path: 'drivers',
              builder: (context, state) => const DriversScreen(),
            ),
            GoRoute(
              path: 'maintenance',
              builder: (context, state) => const MaintenanceScreen(),
            ),
            GoRoute(
              path: 'expenses',
              builder: (context, state) => const ExpensesScreen(),
            ),
            GoRoute(
              path: 'financial-admin',
              builder: (context, state) => const FinancialAdminScreen(),
              routes: [
                 GoRoute(
                    path: ':index',
                    builder: (context, state) {
                      final index = int.tryParse(state.pathParameters['index'] ?? '');
                      return FinancialAdminScreen(vehicleIndex: index);
                    },
                  ),
              ],
            ),
          ],
        ),
      ],
    );

    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AtrThemeState.notifier,
      builder: (context, currentMode, _) {
        return MaterialApp.router(
          title: 'ATR Locações',
          debugShowCheckedModeBanner: false,
          themeMode: currentMode,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          routerConfig: router,
        );
      },
    );
  }
}
