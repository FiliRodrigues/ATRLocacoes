import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/atr_theme_state.dart';
import 'core/utils/app_logger.dart';
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
        ChangeNotifierProvider(create: (_) => AuthService()),
      ],
      child: const ATRApp(),
    ),
  );
}

class AuthService extends ChangeNotifier {
  static bool _isAuthenticated = false;
  bool get isAuthenticated => _isAuthenticated;

  Future<void> checkAuth() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isAuthenticated = prefs.getBool('is_authenticated') ?? false;
      AppLogger.info('Verificação de sessão: ${_isAuthenticated ? 'Autenticado' : 'Visitante'}');
      notifyListeners();
    } catch (e) {
      AppLogger.error('Falha ao verificar sessão', e);
    }
  }

  Future<void> login() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isAuthenticated = true;
      await prefs.setBool('is_authenticated', true);
      AppLogger.success('Usuário logado com sucesso (Sessão Persistida)');
      notifyListeners();
    } catch (e) {
      AppLogger.error('Erro no processo de login', e);
    }
  }

  Future<void> logout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isAuthenticated = false;
      await prefs.setBool('is_authenticated', false);
      AppLogger.warning('Usuário realizou logout');
      notifyListeners();
    } catch (e) {
      AppLogger.error('Erro ao encerrar sessão', e);
    }
  }
}

class ATRApp extends StatefulWidget {
  const ATRApp({super.key});

  @override
  State<ATRApp> createState() => _ATRAppState();
}

class _ATRAppState extends State<ATRApp> {
  @override
  void initState() {
    super.initState();
    // Carrega o login persistente
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AuthService>(context, listen: false).checkAuth();
    });
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);

    final GoRouter router = GoRouter(
      initialLocation: '/login',
      refreshListenable: authService,
      redirect: (context, state) {
        final loggingIn = state.uri.path == '/login';
        final authenticated = AuthService._isAuthenticated;

        if (!authenticated && !loggingIn) return '/login';
        if (authenticated && loggingIn) return '/';
        return null;
      },
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
