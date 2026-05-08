import 'dart:async';
import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/navigation/app_router.dart';
import 'core/data/fleet_data.dart';
import 'core/services/auth_service.dart';
import 'core/services/supabase_service.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/atr_theme_state.dart';
import 'features/custos/custos_provider.dart';
import 'core/data/supabase_custos_repository.dart';
import 'core/data/regras_manutencao_repository.dart';
import 'core/providers/regras_manutencao_provider.dart';
import 'core/utils/error_tracker.dart';
import 'core/data/locacao_repository.dart';
import 'features/locacao/locacao_provider.dart';
import 'core/data/combustivel_repository.dart';
import 'core/providers/combustivel_provider.dart';
import 'core/providers/score_motorista_provider.dart';

export 'core/services/auth_service.dart' show AuthService;

bool _envFlag(String key) {
  if (kIsWeb) return false;
  final value = String.fromEnvironment(key, defaultValue: 'false');
  return value.toLowerCase() == 'true' || value == '1';
}

final bool _kShowPerfOverlay = _envFlag('ATR_SHOW_PERF_OVERLAY');
final bool _kCheckerboardRasterCacheImages =
    _envFlag('ATR_CHECKERBOARD_RASTER_CACHE_IMAGES');
final bool _kCheckerboardOffscreenLayers =
    _envFlag('ATR_CHECKERBOARD_OFFSCREEN_LAYERS');

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('pt_BR');

  if (!kSupabaseConfigured) {
    throw StateError(
      'SUPABASE_URL e SUPABASE_ANON_KEY são obrigatórias. '
      'Forneça-as via --dart-define no build/run (ex.: run_atr.local.bat).',
    );
  }

  // ── Blindagem de erros antes de qualquer widget ──
  ErrorWidget.builder = (FlutterErrorDetails details) {
    saveErrorLog(
        'UI Build Error: ${details.exceptionAsString()}\nTrace:\n${details.stack}');
    return Container(
      padding: const EdgeInsets.all(16),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Text(
        '⚠️ Algo não carregou como esperado.\n\nMas não se preocupe, o sistema continuou rodando e a falha já foi guardada no arquivo local.',
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
        style: TextStyle(
          color: Colors.redAccent,
          fontSize: 14,
          fontWeight: FontWeight.bold,
          decoration: TextDecoration.none,
        ),
      ),
    );
  };

  FlutterError.onError = (FlutterErrorDetails details) {
    saveErrorLog(
        'Flutter Error: ${details.exceptionAsString()}\nTrace:\n${details.stack}');
    FlutterError.presentError(details);
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    saveErrorLog('Async Crash Prevented: $error\nTrace:\n$stack');
    return true;
  };

  // ── Mostra splash instantaneamente enquanto Supabase conecta ──
  runApp(const _SplashApp());

  await Supabase.initialize(
    url: kSupabaseUrl,
    anonKey: kSupabaseAnonKey,
  );

  unawaited(FleetRepository.instance.loadFromSupabase());

  final authService = AuthService();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => CustosProvider(SupabaseCustosRepository()),
        ),
        ChangeNotifierProvider(
          create: (ctx) => RegrasManutencaoProvider(
            repo: RegrasManutencaoRepository(),
            custosProvider: ctx.read<CustosProvider>(),
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => LocacaoProvider(LocacaoRepository()),
        ),
        ChangeNotifierProvider(
          create: (_) => CombustivelProvider(CombustivelRepository()),
        ),
        ChangeNotifierProvider(
          create: (_) => ScoreMotoristaProvider(),
        ),
        ChangeNotifierProvider.value(value: FleetRepository.instance),
        ChangeNotifierProvider.value(value: authService),
      ],
      child: ATRApp(authService: authService),
    ),
  );
}

/// Splash mínimo que aparece enquanto o Supabase conecta.
class _SplashApp extends StatelessWidget {
  const _SplashApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: const Scaffold(
        backgroundColor: AppColors.backgroundDark,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                color: AppColors.atrOrange,
                strokeWidth: 2.5,
              ),
              SizedBox(height: 20),
              Text(
                'Carregando...',
                style: TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  color: AppColors.textSecondaryDark,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ATRApp extends StatefulWidget {
  final AuthService authService;
  const ATRApp({super.key, required this.authService});

  @override
  State<ATRApp> createState() => _ATRAppState();
}

class _ATRAppState extends State<ATRApp> {
  late final AppRouter _appRouter;

  @override
  void initState() {
    super.initState();
    widget.authService.checkAuth();
    _appRouter = AppRouter(widget.authService);
  }

  @override
  void dispose() {
    _appRouter.router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AtrThemeState.notifier,
      builder: (context, currentMode, _) {
        return MaterialApp.router(
          title: 'ATR Locações',
          debugShowCheckedModeBanner: false,
          showPerformanceOverlay: _kShowPerfOverlay,
          checkerboardRasterCacheImages: _kCheckerboardRasterCacheImages,
          checkerboardOffscreenLayers: _kCheckerboardOffscreenLayers,
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale('pt', 'BR'),
          ],
          themeMode: currentMode,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          builder: (context, child) {
            return Stack(
              children: [
                EscapeKeyGuard(child: child ?? const SizedBox.shrink()),
                _AdminCircleButton(authService: widget.authService),
              ],
            );
          },
          routerConfig: _appRouter.router,
        );
      },
    );
  }
}

class _IgnoreEscapeIntent extends Intent {
  const _IgnoreEscapeIntent();
}

/// Intercepta ESC globalmente para evitar que o Flutter tente fechar
/// a rota raiz e cause um crash (tela vermelha) quando não há rota anterior.
class EscapeKeyGuard extends StatelessWidget {
  final Widget child;

  const EscapeKeyGuard({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: const <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.escape): _IgnoreEscapeIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          _IgnoreEscapeIntent: CallbackAction<_IgnoreEscapeIntent>(
            onInvoke: (_) {
              FocusManager.instance.primaryFocus?.unfocus();
              return null;
            },
          ),
        },
        child: Focus(child: child),
      ),
    );
  }
}

class _AdminCircleButton extends StatelessWidget {
  final AuthService authService;
  const _AdminCircleButton({required this.authService});

  @override
  Widget build(BuildContext context) {
    if (authService.currentRole != AuthUserRole.admin) return const SizedBox.shrink();
    return Positioned(
      bottom: 28,
      right: 28,
      child: GestureDetector(
        onTap: () => GoRouter.of(context).go('/admin/users'),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.surfaceDarkAlt.withValues(alpha: 0.55),
            border: Border.all(
              color: AppColors.atrOrange.withValues(alpha: 0.18),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.atrOrange.withValues(alpha: 0.08),
                blurRadius: 16,
              ),
            ],
          ),
          child: const Icon(
            LucideIcons.users,
            color: AppColors.textSecondaryDark,
            size: 18,
          ),
        ),
      ),
    );
  }
}
