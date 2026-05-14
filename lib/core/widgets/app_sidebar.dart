import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../data/fleet_data.dart';
import '../navigation/app_router.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../theme/app_colors.dart';
import '../theme/atr_theme_state.dart';
import 'frota_sidebar_items.dart';
import 'module_defs.dart';
import 'sidebar_models.dart';

/// Shell de navegação principal da aplicação.
///
/// Renderiza sidebar expansível para desktop e bottom navigation no mobile,
/// mantendo o conteúdo da rota atual em [child].
class AppSidebar extends StatefulWidget {
  final Widget child;
  final String moduleName;
  final IconData moduleIcon;
  final List<SidebarItemDef>? items;
  final List<ModuleDef>? availableModules;

  const AppSidebar({
    super.key,
    required this.child,
    this.moduleName = 'Frota & Custos',
    this.moduleIcon = LucideIcons.truck,
    this.items,
    this.availableModules,
  });

  @override
  State<AppSidebar> createState() => _AppSidebarState();
}

class _AppSidebarState extends State<AppSidebar> {
  bool _isCollapsed = false;

  void _toggleSidebar() {
    setState(() => _isCollapsed = !_isCollapsed);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final isDesktop = MediaQuery.of(context).size.width >= 800;
    if (!isDesktop && _isCollapsed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() => _isCollapsed = false);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 800;
    final authService = context.watch<AuthService>();
    final currentUser = authService.currentUser;

    if (currentUser == null) {
      return Scaffold(body: widget.child);
    }

    final unreadCount = context.watch<NotificationService>().unreadCount;
    final items = widget.items ?? buildFrotaItems(currentUser, notificationCount: unreadCount);
    final modules = widget.availableModules ?? buildAvailableModules(currentUser);
    final currentUri = GoRouterState.of(context).uri.toString();
    final moduleSwitcherModules = modules.isEmpty
        ? [
            ModuleDef(
              icon: widget.moduleIcon,
              name: widget.moduleName,
              rootRoute: currentUri,
            ),
          ]
        : modules;
    final hasCustomItems = widget.items != null;

    return Scaffold(
      body: Stack(
        children: [
          Row(
            children: [
              if (isDesktop)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  width: _isCollapsed ? 80 : 260,
                  clipBehavior: Clip.hardEdge,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xF01A2332), Color(0xEE0D1420)],
                    ),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.035),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.38),
                        blurRadius: 16,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      const SizedBox(height: 24),
                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: _isCollapsed ? 12 : 16,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: _buildModuleSwitcher(
                                context,
                                moduleSwitcherModules,
                                currentUri,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Semantics(
                              label: _isCollapsed ? 'Expandir menu' : 'Recolher menu',
                              button: true,
                              child: IconButton(
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(
                                  minWidth: 40,
                                  minHeight: 40,
                                ),
                                icon: Icon(
                                  _isCollapsed
                                      ? LucideIcons.chevronRight
                                      : LucideIcons.chevronLeft,
                                  color: AppColors.textSecondaryDark,
                                  size: 18,
                                ),
                                onPressed: _toggleSidebar,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Expanded(
                        child: SingleChildScrollView(
                          child: Column(
                            children: [
                              if (hasCustomItems)
                                _buildFlatItems(context, items, currentUri)
                              else
                                _buildDefaultFrotaMenu(context, items, currentUri),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildFooter(context, currentUser, currentUri),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              Expanded(child: widget.child),
            ],
          ),
        ],
      ),
      bottomNavigationBar:
          isDesktop || hasCustomItems || authService.isFleetOnlyUser
              ? null
              : BottomNavigationBar(
                  currentIndex: _getBottomNavIndex(context),
                  selectedItemColor: AppColors.atrOrange,
                  unselectedItemColor: AppColors.textSecondaryLight,
                  type: BottomNavigationBarType.fixed,
                  onTap: (index) {
                    if (index == 0) context.go(AppRoutes.home);
                    if (index == 1) {
                      final frota = context.read<FleetRepository>().frota;
                      if (frota.isNotEmpty && frota.first.placa.isNotEmpty) {
                        context.go('/vehicles/${frota.first.placa}');
                      }
                    }
                    if (index == 2) {
                      context.go(AppRoutes.custosRoot);
                    }
                  },
                  items: const [
                    BottomNavigationBarItem(
                      icon: Icon(LucideIcons.layoutDashboard),
                      label: 'Resumo',
                    ),
                    BottomNavigationBarItem(
                      icon: Icon(LucideIcons.car),
                      label: 'Veículos',
                    ),
                    BottomNavigationBarItem(
                      icon: Icon(LucideIcons.wrench),
                      label: 'Custos',
                    ),
                  ],
                ),
    );
  }

  Widget _buildModuleSwitcher(
    BuildContext context,
    List<ModuleDef> modules,
    String currentUri,
  ) {
    final selectedModule = modules.firstWhere(
      (module) => _isModuleActive(module.rootRoute, currentUri),
      orElse: () => modules.first,
    );

    return PopupMenuButton<ModuleDef>(
      tooltip: 'Trocar módulo',
      position: PopupMenuPosition.under,
      offset: const Offset(0, 12),
      color: const Color(0xFF111827),
      onSelected: (module) {
        if (GoRouterState.of(context).uri.toString() != module.rootRoute) {
          context.go(module.rootRoute);
        }
      },
      itemBuilder: (context) => [
        for (final module in modules)
          PopupMenuItem<ModuleDef>(
            value: module,
            child: Row(
              children: [
                Icon(module.icon, size: 18, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    module.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
      ],
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.symmetric(
          horizontal: _isCollapsed ? 0 : 14,
          vertical: 12,
        ),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: _isCollapsed
            ? Icon(selectedModule.icon, color: AppColors.atrOrange, size: 20)
            : Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: AppColors.atrOrange,
                              width: 1.4,
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            selectedModule.icon,
                            size: 18,
                            color: AppColors.atrOrange,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                selectedModule.name,
                                style: const TextStyle(
                                  fontFamily: 'Plus Jakarta Sans',
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                  letterSpacing: 0.4,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const Text(
                                'Selecionar módulo',
                                style: TextStyle(
                                  fontFamily: 'Plus Jakarta Sans',
                                  color: AppColors.textSecondaryDark,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: 0.6,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    LucideIcons.chevronDown,
                    size: 16,
                    color: AppColors.textSecondaryDark,
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildDefaultFrotaMenu(
    BuildContext context,
    List<SidebarItemDef> items,
    String uri,
  ) {
    final byTitle = <String, SidebarItemDef>{
      for (final item in items) item.title: item,
    };

    final managementItems = [
      byTitle['Dashboard Executivo'],
      byTitle['Veículos'],
      byTitle['Motoristas'],
    ].whereType<SidebarItemDef>().toList();
    final financialItems = [
      byTitle['Custos da Frota'],
      byTitle['Contratos B2B'],
      byTitle['Vencimentos'],
      byTitle['Relatórios'],
      byTitle['Adm Financeiro'],
    ].whereType<SidebarItemDef>().toList();
    final systemItems = [
      byTitle['Notificações'],
    ].whereType<SidebarItemDef>().toList();

    return Column(
      children: [
        if (managementItems.isNotEmpty && !_isCollapsed)
          const _SidebarGroupLabel('Gestão'),
        for (final item in managementItems)
          _buildSidebarEntry(context, item, uri),
        if (financialItems.isNotEmpty && !_isCollapsed)
          const _SidebarGroupLabel('Financeiro'),
        for (final item in financialItems)
          _buildSidebarEntry(context, item, uri),
        if (systemItems.isNotEmpty && !_isCollapsed)
          const _SidebarGroupLabel('Sistema'),
        for (final item in systemItems)
          _buildSidebarEntry(context, item, uri),
      ],
    );
  }

  Widget _buildFlatItems(
    BuildContext context,
    List<SidebarItemDef> items,
    String uri,
  ) {
    return Column(
      children: [
        for (final item in items)
          _buildSidebarEntry(context, item, uri),
      ],
    );
  }

  Widget _buildSidebarEntry(
    BuildContext context,
    SidebarItemDef item,
    String uri,
  ) {
    final currentUser = context.read<AuthService>().currentUser;
    if (item.feature != null && currentUser != null && !currentUser.canAccess(item.feature!)) {
      return const SizedBox.shrink();
    }

    final isActive = item.isActiveOverride ?? _isItemActive(item.route, uri);
    return _SidebarItem(
      icon: item.icon,
      title: item.title,
      isCollapsed: _isCollapsed,
      isActive: isActive,
      badgeCount: item.badgeCount,
      onTap: item.onTap ?? () => context.go(item.route),
    );
  }

  Widget _buildFooter(
    BuildContext context,
    AuthUser user,
    String uri,
  ) {
    final defaultBottomItems = _defaultBottomItems(context, user);

    return Column(
      children: [
        for (final item in defaultBottomItems)
          _buildSidebarEntry(context, item, uri),
        ValueListenableBuilder<ThemeMode>(
          valueListenable: AtrThemeState.notifier,
          builder: (context, mode, _) {
            final isDark = mode == ThemeMode.dark;
            return _SidebarItem(
              icon: isDark ? LucideIcons.moon : LucideIcons.sun,
              title: isDark ? 'Modo Escuro' : 'Modo Claro',
              isCollapsed: _isCollapsed,
              isActive: false,
              onTap: () {
                AtrThemeState.notifier.value =
                    isDark ? ThemeMode.light : ThemeMode.dark;
              },
            );
          },
        ),
        const SizedBox(height: 8),
        Builder(
          builder: (context) {
            final initials = user.username
                .split(' ')
                .take(2)
                .map((s) => s.isNotEmpty ? s[0].toUpperCase() : '')
                .join();
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.06),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: AppColors.warmGradient,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text(
                        initials.isEmpty ? 'A' : initials,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  if (!_isCollapsed)
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            user.username,
                            style: const TextStyle(
                              fontFamily: 'Plus Jakarta Sans',
                              color: AppColors.textPrimaryDark,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            user.role.name,
                            style: const TextStyle(
                              fontFamily: 'Plus Jakarta Sans',
                              color: AppColors.textSecondaryDark,
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  List<SidebarItemDef> _defaultBottomItems(
    BuildContext context,
    AuthUser user,
  ) {
    return [
      if (user.canAccess('ai_assistant'))
        SidebarItemDef(
          icon: LucideIcons.bot,
          title: 'Assistente IA',
          route: AppRoutes.aiChat,
          feature: 'ai_assistant',
        ),
      if (user.canAccess('configuracoes') || user.canAccess('settings'))
        SidebarItemDef(
          icon: LucideIcons.settings,
          title: 'Configurações',
          route: AppRoutes.configuracoes,
          feature: 'configuracoes',
        ),
      SidebarItemDef(
        icon: LucideIcons.logOut,
        title: 'Sair do Sistema',
        route: AppRoutes.login,
        onTap: () async {
          final authService = context.read<AuthService>();
          await authService.logout();
          if (!mounted) return;
          context.go(AppRoutes.login);
        },
      ),
    ];
  }

  bool _isItemActive(String route, String uri) {
    if (route == AppRoutes.home || route == '/') {
      return uri == AppRoutes.home || uri == '/';
    }
    return uri.startsWith(route);
  }

  bool _isModuleActive(String route, String uri) {
    if (route == AppRoutes.home || route == '/') {
      return uri == AppRoutes.home || uri == '/';
    }
    return uri == route || uri.startsWith('$route/');
  }

  int _getBottomNavIndex(BuildContext context) {
    final uri = GoRouterState.of(context).uri.toString();
    if (uri == AppRoutes.home) return 0;
    if (uri.startsWith('/vehicles')) return 1;
    if (uri.startsWith(AppRoutes.custosRoot) ||
        uri.startsWith('/${AppRoutes.maintenance}') ||
        uri.startsWith('/${AppRoutes.expenses}') ||
        uri.startsWith('/manutencao') ||
        uri.startsWith('/despesas')) {
      return 2;
    }
    return 0;
  }
}

class _SidebarGroupLabel extends StatelessWidget {
  final String label;
  const _SidebarGroupLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 14, 28, 6),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          fontFamily: 'Plus Jakarta Sans',
          fontSize: 9,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.0,
          color: Color(0xFF66728A),
        ),
      ),
    );
  }
}

class _SidebarItem extends StatefulWidget {
  final IconData icon;
  final String title;
  final bool isActive;
  final bool isCollapsed;
  final VoidCallback onTap;
  final int badgeCount;

  const _SidebarItem({
    required this.icon,
    required this.title,
    required this.isActive,
    this.isCollapsed = false,
    required this.onTap,
    this.badgeCount = 0,
  });

  @override
  State<_SidebarItem> createState() => _SidebarItemState();
}

class _SidebarItemState extends State<_SidebarItem> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final isHover = _hovering || widget.isActive;
    final iconColor = widget.isActive
        ? AppColors.atrOrange
        : (isHover ? AppColors.textPrimaryDark : AppColors.textSecondaryDark);
    final textColor = widget.isActive
        ? AppColors.atrOrange
        : (isHover ? AppColors.textPrimaryDark : AppColors.textSecondaryDark);

    return RepaintBoundary(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: widget.isCollapsed ? 8 : 16,
          vertical: 3,
        ),
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _hovering = true),
          onExit: (_) => setState(() => _hovering = false),
          child: Semantics(
            button: true,
            label: widget.title,
            child: GestureDetector(
              onTap: widget.onTap,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                padding: EdgeInsets.symmetric(
                  horizontal: widget.isCollapsed ? 0 : 16,
                  vertical: 11,
                ),
                decoration: BoxDecoration(
                  color: widget.isActive
                      ? AppColors.atrOrange.withValues(alpha: 0.09)
                      : (_hovering
                          ? Colors.white.withValues(alpha: 0.03)
                          : Colors.transparent),
                  borderRadius: BorderRadius.circular(12),
                  border: widget.isActive
                      ? Border.all(
                          color: AppColors.atrOrange.withValues(alpha: 0.16),
                        )
                      : null,
                  boxShadow: widget.isActive
                      ? [
                          BoxShadow(
                            color: AppColors.glowOrange.withValues(alpha: 0.45),
                            blurRadius: 8,
                            spreadRadius: 0,
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: widget.isCollapsed
                      ? MainAxisAlignment.center
                      : MainAxisAlignment.start,
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Icon(widget.icon, color: iconColor, size: 20),
                        if (widget.badgeCount > 0)
                          Positioned(
                            top: -5,
                            right: -5,
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              decoration: const BoxDecoration(
                                color: AppColors.statusError,
                                shape: BoxShape.circle,
                              ),
                              constraints: const BoxConstraints(
                                minWidth: 16,
                                minHeight: 16,
                              ),
                              child: Text(
                                widget.badgeCount > 9 ? '9+' : '${widget.badgeCount}',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 8,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    if (!widget.isCollapsed) ...[
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          widget.title,
                          style: TextStyle(
                            color: textColor,
                            fontWeight: widget.isActive
                                ? FontWeight.w600
                                : FontWeight.w500,
                            fontSize: 12.5,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SubSidebarItem extends StatefulWidget {
  final String title;
  final bool isActive;
  final VoidCallback onTap;

  const _SubSidebarItem({
    required this.title,
    required this.isActive,
    required this.onTap,
  });

  @override
  State<_SubSidebarItem> createState() => _SubSidebarItemState();
}

class _SubSidebarItemState extends State<_SubSidebarItem> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final dotColor = widget.isActive
        ? AppColors.atrOrange
        : (_hovering ? AppColors.textPrimaryDark : AppColors.textSecondaryDark);

    return RepaintBoundary(
      child: Padding(
        padding: const EdgeInsets.only(left: 18, right: 16, top: 1, bottom: 1),
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _hovering = true),
          onExit: (_) => setState(() => _hovering = false),
          child: GestureDetector(
            onTap: widget.onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: widget.isActive
                    ? AppColors.atrOrange.withValues(alpha: 0.08)
                    : (_hovering
                        ? Colors.white.withValues(alpha: 0.02)
                        : Colors.transparent),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: dotColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.title,
                      style: TextStyle(
                        color: dotColor,
                        fontSize: 11.5,
                        fontWeight: widget.isActive
                            ? FontWeight.w600
                            : FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}