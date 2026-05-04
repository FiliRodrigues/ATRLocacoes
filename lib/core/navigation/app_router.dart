import 'package:go_router/go_router.dart';
import '../services/auth_service.dart';
import '../../features/login/login_screen.dart';
import '../../features/selector/system_selector_screen.dart';
import '../../features/dashboard/dashboard_screen.dart';
import '../../features/frota/frota_dashboard_screen.dart';
import '../../features/frota/frota_revisao_screen.dart';
import '../../features/vehicles/vehicle_dossier_screen.dart';
import '../../features/drivers/drivers_screen.dart';
import '../../features/custos/custos_screen.dart';
import '../../features/financial_admin/financial_admin_screen.dart';
import '../../features/obras/obras_screen.dart';
import '../../features/sala_atr/sala_atr_screen.dart';
import '../../features/lazer/lazer_screen.dart';
import '../../features/locacao/contratos_screen.dart';
import '../../features/locacao/contrato_detalhe_screen.dart';

abstract class AppRoutes {
  static const login = '/login';
  static const selector = '/selector';
  static const home = '/';
  static const frotaRevisao = '/frota-revisao';
  static const vehiclesRoot = '/vehicles';
  static const driversRoot = '/drivers';
  static const custosRoot = '/custos';
  static const maintenanceRoot = '/maintenance';
  static const expensesRoot = '/expenses';
  static const financialAdminRoot = '/financial-admin';
  static const obras = '/obras';
  static const salaAtr = '/sala-atr';
  static const lazer = '/lazer';
  static const contratos = '/contratos';
  static const drivers = 'drivers';
  static const custos = 'custos';
  static const maintenance = 'maintenance';
  static const expenses = 'expenses';
  static const financialAdmin = 'financial-admin';

  static bool isFleetRoute(String path) {
    // Frota users are restricted to the fleet dashboard and review control.
    return path == home || path == frotaRevisao;
  }
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
      final path = state.uri.path;
      final loggingIn = path == AppRoutes.login;
      final authenticated = authService.isAuthenticated;
      if (!authenticated && !loggingIn) return AppRoutes.login;
      if (authenticated && loggingIn) {
        return _defaultRouteFor(authService);
      }
      if (authenticated && !_canAccessPath(authService, path)) {
        return _defaultRouteFor(authService);
      }
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
        path: AppRoutes.contratos,
        builder: (context, state) => const ContratosScreen(),
        routes: [
          GoRoute(
            path: ':id',
            builder: (context, state) {
              final id = state.pathParameters['id'] ?? '';
              return ContratoDetalheScreen(contratoId: id);
            },
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.home,
        builder: (context, state) => authService.isFleetOnlyUser
            ? const FrotaDashboardScreen()
            : const DashboardScreen(),
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
            redirect: (_, __) => AppRoutes.custosRoot,
          ),
          GoRoute(
            path: AppRoutes.expenses,
            redirect: (_, __) => AppRoutes.custosRoot,
          ),
          GoRoute(
            path: AppRoutes.custos,
            builder: (context, state) => const CustosScreen(),
          ),
          GoRoute(
            path: 'manutencao',
            redirect: (_, __) => AppRoutes.custosRoot,
          ),
          GoRoute(
            path: 'despesas',
            redirect: (_, __) => AppRoutes.custosRoot,
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
      GoRoute(
        path: AppRoutes.frotaRevisao,
        builder: (context, state) => const FrotaRevisaoScreen(),
      ),
    ],
  );

  String _defaultRouteFor(AuthService authService) {
    return authService.isFleetOnlyUser ? AppRoutes.home : AppRoutes.selector;
  }

  bool _canAccessPath(AuthService authService, String path) {
    if (!authService.isFleetOnlyUser) {
      return true;
    }

    return AppRoutes.isFleetRoute(path);
  }
}
