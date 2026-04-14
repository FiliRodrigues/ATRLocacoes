import 'package:go_router/go_router.dart';
import '../services/auth_service.dart';
import '../../features/login/login_screen.dart';
import '../../features/selector/system_selector_screen.dart';
import '../../features/dashboard/dashboard_screen.dart';
import '../../features/vehicles/vehicle_dossier_screen.dart';
import '../../features/drivers/drivers_screen.dart';
import '../../features/maintenance/maintenance_screen.dart';
import '../../features/expenses/expenses_screen.dart';
import '../../features/financial_admin/financial_admin_screen.dart';
import '../../features/obras/obras_screen.dart';
import '../../features/sala_atr/sala_atr_screen.dart';
import '../../features/lazer/lazer_screen.dart';

abstract class AppRoutes {
  static const login = '/login';
  static const selector = '/selector';
  static const home = '/';
  static const obras = '/obras';
  static const salaAtr = '/sala-atr';
  static const lazer = '/lazer';
  static const drivers = 'drivers';
  static const maintenance = 'maintenance';
  static const expenses = 'expenses';
  static const financialAdmin = 'financial-admin';
}

/// Configuração central de rotas da aplicação ATR.
///
/// Recebe [authService] para o guard de redirecionamento reativo.
class AppRouter {
  final AuthService authService;

  AppRouter(this.authService);

  late final GoRouter router = GoRouter(
    initialLocation: AppRoutes.login,
    refreshListenable: authService,
    redirect: (context, state) {
      final loggingIn = state.uri.path == AppRoutes.login;
      final authenticated = authService.isAuthenticated;
      if (!authenticated && !loggingIn) return AppRoutes.login;
      if (authenticated && loggingIn) return AppRoutes.selector;
      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.selector,
        builder: (context, state) => const SystemSelectorScreen(),
      ),
      GoRoute(
        path: AppRoutes.obras,
        builder: (context, state) => const ObrasScreen(),
      ),
      GoRoute(
        path: AppRoutes.salaAtr,
        builder: (context, state) => const SalaAtrScreen(),
      ),
      GoRoute(
        path: AppRoutes.lazer,
        builder: (context, state) => const LazerScreen(),
      ),
      GoRoute(
        path: AppRoutes.home,
        builder: (context, state) => const DashboardScreen(),
        routes: [
          GoRoute(
            path: 'vehicles/:plate',
            builder: (context, state) {
              final plate = state.pathParameters['plate'] ?? '';
              if (plate.isEmpty) return const DashboardScreen();
              return VehicleDossierScreen(plateId: plate);
            },
          ),
          GoRoute(
            path: AppRoutes.drivers,
            builder: (context, state) => const DriversScreen(),
          ),
          GoRoute(
            path: AppRoutes.maintenance,
            builder: (context, state) => const MaintenanceScreen(),
          ),
          GoRoute(
            path: AppRoutes.expenses,
            builder: (context, state) => const ExpensesScreen(),
          ),
          GoRoute(
            path: AppRoutes.financialAdmin,
            builder: (context, state) => const FinancialAdminScreen(),
            routes: [
              GoRoute(
                path: ':plate',
                builder: (context, state) {
                  final plate = state.pathParameters['plate'];
                  if (plate == null || plate.isEmpty) {
                    return const FinancialAdminScreen();
                  }
                  return FinancialAdminScreen(vehiclePlate: plate);
                },
              ),
            ],
          ),
        ],
      ),
    ],
  );
}
