import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/auth_service.dart';
import '../utils/app_logger.dart';
import '../../features/login/login_screen.dart';
import '../../features/selector/system_selector_screen.dart';
import '../../features/dashboard/dashboard_screen.dart';
import '../../features/frota/frota_dashboard_screen.dart';
import '../../features/frota/frota_revisao_screen.dart';
import '../../features/vehicles/vehicle_dossier_screen.dart';
import '../../features/drivers/drivers_screen.dart';
import '../../features/custos/custos_screen.dart';
import '../../features/financial_admin/financial_admin_screen.dart';
import '../../features/financial_admin/tco_dashboard_screen.dart';
import '../../features/vencimentos/vencimentos_screen.dart';
import '../../features/relatorios/relatorios_screen.dart';
import '../../features/drivers/score_motoristas_screen.dart';
import '../../features/obras/obras_screen.dart';
import '../../features/sala_atr/sala_atr_screen.dart';
import '../../features/lazer/lazer_screen.dart';
import '../../features/locacao/contratos_screen.dart';
import '../../features/locacao/contrato_detalhe_screen.dart';
import '../../features/admin/users_screen.dart';
import '../../features/auth/change_password_screen.dart';
import '../../features/ai_assistant/presentation/ai_chat_screen.dart';
import '../../features/settings/settings_screen.dart';

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
  static const tco = '/tco';
  static const vencimentos = '/vencimentos';
  static const relatorios = '/relatorios';
  static const scoreMoto = '/score-motoristas';
  static const adminUsers = '/admin/users';
  static const trocarSenha = '/trocar-senha';
  static const aiChat = '/ai-chat';
  static const configuracoes = '/configuracoes';
  static const notifications = '/notifications';

  static bool isFleetRoute(String path) {
    return path == home || path == frotaRevisao;
  }

  static String? featureForPath(String path) {
    if (path == home || path == selector) return 'dashboard';
    if (path == frotaRevisao) return 'frota';
    if (path.startsWith('/vehicles')) return 'vehicles';
    if (path.startsWith('/drivers') || path == scoreMoto) return 'drivers';
    if (path.startsWith(custosRoot)) return 'custos';
    if (path.startsWith(contratos)) return 'contratos';
    if (path == vencimentos) return 'vencimentos';
    if (path == relatorios) return 'relatorios';
    if (path.startsWith('/$financialAdminRoot') || path == tco) return 'financial_admin';
    if (path == obras) return 'obras';
    if (path == salaAtr) return 'sala_atr';
    if (path == lazer) return 'lazer';
    if (path == '/ai-chat') return 'ai_assistant';
    if (path.startsWith('/admin')) return 'users_admin';
    return null;
  }
}

/// Configuração central de rotas da aplicação ATR.
///
/// Recebe [authService] para o guard de redirecionamento reativo.
class AppRouter {
  final AuthService authService;

  AppRouter(this.authService);

  late final GoRouter router = GoRouter(
    initialLocation: _parseInitialLocation() ?? AppRoutes.login,
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
        AppLogger.warning('Acesso negado à rota $path para ${authService.currentUser?.username}');
        return _defaultRouteFor(authService);
      }
      if (authenticated &&
          authService.currentUser?.mustChangePassword == true &&
          path != AppRoutes.trocarSenha) {
        return AppRoutes.trocarSenha;
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
      GoRoute(
        path: AppRoutes.tco,
        builder: (context, state) => const TcoDashboardScreen(),
      ),
      GoRoute(
        path: AppRoutes.vencimentos,
        builder: (context, state) => const VencimentosScreen(),
      ),
      GoRoute(
        path: AppRoutes.relatorios,
        builder: (context, state) => const RelatoriosScreen(),
      ),
      GoRoute(
        path: AppRoutes.scoreMoto,
        builder: (context, state) => const ScoreMotoristaScreen(),
      ),
      GoRoute(
        path: AppRoutes.adminUsers,
        builder: (context, state) => const UsersScreen(),
      ),
      GoRoute(
        path: AppRoutes.trocarSenha,
        builder: (context, state) => const ChangePasswordScreen(),
      ),
      GoRoute(
        path: AppRoutes.configuracoes,
        builder: (_, __) => const SettingsScreen(),
      ),
      GoRoute(
        path: AppRoutes.notifications,
        builder: (_, __) => const _NotificationsPlaceholderScreen(),
      ),
      GoRoute(
        path: AppRoutes.aiChat,
        pageBuilder: (context, state) {
          final query = state.extra as String?;
          return CustomTransitionPage<void>(
            key: state.pageKey,
            child: AiChatScreen(initialQuery: query),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(1.0, 0.0),
                  end: Offset.zero,
                ).animate(
                  CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                  ),
                ),
                child: FadeTransition(
                  opacity: Tween<double>(begin: 0.0, end: 1.0).animate(
                    CurvedAnimation(
                      parent: animation,
                      curve: const Interval(0.0, 0.6),
                    ),
                  ),
                  child: child,
                ),
              );
            },
            transitionDuration: const Duration(milliseconds: 380),
          );
        },
      ),
    ],
  );

  String _defaultRouteFor(AuthService authService) {
    return authService.isFleetOnlyUser ? AppRoutes.home : AppRoutes.selector;
  }

  bool _canAccessPath(AuthService authService, String path) {
    if (authService.currentRole == AuthUserRole.admin) return true;
    final featureId = AppRoutes.featureForPath(path);
    if (featureId == null) return true;
    return authService.currentUser?.canAccess(featureId) ?? false;
  }

  /// Tenta extrair a rota inicial de um deep link (scheme atr://).
  /// Exemplo: atr://vehicles/ABC1234 -> /vehicles/ABC1234
  static String? _parseInitialLocation() {
    try {
      final uri = WidgetsBinding.instance.platformDispatcher.defaultRouteName;
      if (uri.isEmpty || uri == '/') return null;
      final parsed = Uri.tryParse(uri);
      if (parsed == null || !parsed.hasScheme) {
        return uri.startsWith('/') ? uri : '/$uri';
      }
      if (parsed.scheme == 'atr' || parsed.scheme == 'https') {
        return parsed.hasAuthority
            ? '${parsed.path}${parsed.hasQuery ? '?${parsed.query}' : ''}'
            : parsed.path;
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}

class _NotificationsPlaceholderScreen extends StatelessWidget {
  const _NotificationsPlaceholderScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text('Notificacoes em breve'),
      ),
    );
  }
}
