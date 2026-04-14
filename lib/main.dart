import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'core/navigation/app_router.dart';
import 'core/data/fleet_data.dart';
import 'core/services/auth_service.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/atr_theme_state.dart';
import 'features/maintenance/maintenance_provider.dart';

export 'core/services/auth_service.dart' show AuthService;

bool _envFlag(String key) {
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
  final authService = AuthService();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => MaintenanceProvider()),
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
          themeMode: currentMode,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          routerConfig: _appRouter.router,
        );
      },
    );
  }
}
