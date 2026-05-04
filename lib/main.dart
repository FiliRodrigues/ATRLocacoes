import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/navigation/app_router.dart';
import 'core/data/fleet_data.dart';
import 'core/services/auth_service.dart';
import 'core/services/supabase_service.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/atr_theme_state.dart';
import 'features/custos/custos_provider.dart';
import 'core/data/supabase_custos_repository.dart';
import 'core/utils/error_tracker.dart';
import 'core/data/locacao_repository.dart';
import 'features/locacao/locacao_provider.dart';

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

  // Inicializa o cliente Supabase
  await Supabase.initialize(
    url: kSupabaseUrl,
    anonKey: kSupabaseAnonKey,
  );

  // Carrega a frota real em background (não bloqueia o app)
  FleetRepository.instance.loadFromSupabase();

  // ══════════════════════════════════════════════════════════════════
  // SISTEMA GLOBAL DE BLINDAGEM DE ERROS (Failsafe)
  // ══════════════════════════════════════════════════════════════════

  // 1. Sobrescreve a famosa "Tela Vermelha da Morte" por algo gracioso e calmo
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
          decoration: TextDecoration
              .none, // Opcional para não quebrar sem um Scaffold pai
        ),
      ),
    );
  };

  // 2. Interceptador de Erros do Flutter (Fronteira Gráfica / Layout)
  FlutterError.onError = (FlutterErrorDetails details) {
    saveErrorLog(
        'Flutter Error: ${details.exceptionAsString()}\nTrace:\n${details.stack}');
    FlutterError.presentError(
        details); // Despeja no console para o desenvolvedor ver
  };

  // 3. Interceptador de Erros Assíncronos Não-Tratados (O que fecha/trava a janela do OS)
  PlatformDispatcher.instance.onError = (error, stack) {
    saveErrorLog('Async Crash Prevented: $error\nTrace:\n$stack');
    return true; // Retorna true para o Flutter indicando: "Nós contemos a bomba, não feche o app."
  };

  final authService = AuthService();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => CustosProvider(SupabaseCustosRepository()),
        ),
        ChangeNotifierProvider(
          create: (_) => LocacaoProvider(LocacaoRepository()),
        ),
        ChangeNotifierProvider.value(value: FleetRepository.instance),
        ChangeNotifierProvider.value(value: authService),
      ],
      child: ATRApp(authService: authService),
    ),
  );
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
            return EscapeKeyGuard(child: child ?? const SizedBox.shrink());
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
        child: Focus(autofocus: true, child: child),
      ),
    );
  }
}
