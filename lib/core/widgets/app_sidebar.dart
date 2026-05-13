import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../data/fleet_data.dart';
import '../navigation/app_router.dart';
import '../theme/app_colors.dart';
import '../theme/atr_theme_state.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';


/// Shell de navegação principal da aplicação.
///
/// Renderiza sidebar expansível para desktop e bottom navigation no mobile,
/// mantendo o conteúdo da rota atual em [child].
class AppSidebar extends StatefulWidget {
  final Widget child;

  const AppSidebar({super.key, required this.child});

  @override
  State<AppSidebar> createState() => _AppSidebarState();
}

class _AppSidebarState extends State<AppSidebar> {
  bool _isCollapsed = false;
  bool _showExpandedContent = true;

  void _toggleSidebar() {
    if (_isCollapsed) {
      setState(() => _isCollapsed = false);
      Future.delayed(const Duration(milliseconds: 320), () {
        if (mounted) setState(() => _showExpandedContent = true);
      });
    } else {
      setState(() {
        _isCollapsed = true;
        _showExpandedContent = false;
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final isDesktop = MediaQuery.of(context).size.width >= 800;
    if (!isDesktop && (_isCollapsed || !_showExpandedContent)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _isCollapsed = false;
            _showExpandedContent = true;
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = MediaQuery.of(context).size.width >= 800;

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
                      colors: [
                        Color(0xF01A2332),
                        Color(0xEE0D1420),
                      ],
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
                    padding:
                        EdgeInsets.symmetric(horizontal: _isCollapsed ? 0 : 24),
                    child: Row(
                      mainAxisAlignment: _isCollapsed
                          ? MainAxisAlignment.center
                          : MainAxisAlignment.spaceBetween,
                      children: [
                        if (!_isCollapsed)
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
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    LucideIcons.truck,
                                    size: 20,
                                    color: AppColors.atrOrange,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Flexible(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'ATR',
                                        style: const TextStyle(
                                          fontFamily: 'Plus Jakarta Sans',
                                          color: Colors.white,
                                          fontWeight: FontWeight.w900,
                                          fontSize: 14,
                                          letterSpacing: 3,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        'LOCAÇÕES',
                                        style: const TextStyle(
                                          fontFamily: 'Plus Jakarta Sans',
                                          color: AppColors.textSecondaryDark,
                                          fontSize: 9,
                                          fontWeight: FontWeight.w500,
                                          letterSpacing: 1,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        Semantics(
                          label: _isCollapsed ? 'Expandir menu' : 'Recolher menu',
                          button: true,
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 48,
                              minHeight: 48,
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
                  const SizedBox(height: 48),

                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          Builder(
                            builder: (context) {
                              final uri =
                                  GoRouterState.of(context).uri.toString();
                              final auth = context.read<AuthService>();
                              final nonAdmin = !auth.currentUser!.canAccess('dashboard');

                              return Column(
                                children: [
                                  if (auth.currentUser!.canAccess('dashboard'))
                                    _SidebarItem(
                                      icon: LucideIcons.layoutDashboard,
                                      title: nonAdmin
                                          ? 'Controle de Frota'
                                          : 'Dashboard Executivo',
                                      isCollapsed: _isCollapsed,
                                      isActive: uri == AppRoutes.home,
                                      onTap: () => context.go(AppRoutes.home),
                                    ),
                                  if (!_isCollapsed && (auth.currentUser!.canAccess('frota') || auth.currentUser!.canAccess('vehicles') || auth.currentUser!.canAccess('drivers')))
                                    _SidebarGroupLabel('Gestão'),
                                  if (auth.currentUser!.canAccess('vehicles'))
                                    _SidebarItem(
                                      icon: LucideIcons.car,
                                      title: 'Veículos',
                                      isCollapsed: _isCollapsed,
                                      isActive: uri.startsWith('/frota-revisao') || uri.startsWith('/vehicles'),
                                      onTap: () => context.go('/frota-revisao'),
                                    ),
                                  if (auth.currentUser!.canAccess('drivers'))
                                    _SidebarItem(
                                      icon: LucideIcons.users,
                                      title: 'Motoristas',
                                      isCollapsed: _isCollapsed,
                                      isActive:
                                          uri.startsWith('/${AppRoutes.drivers}'),
                                      onTap: () =>
                                          context.go('/${AppRoutes.drivers}'),
                                    ),
                                  if (!_isCollapsed && (auth.currentUser!.canAccess('custos') || auth.currentUser!.canAccess('contratos') || auth.currentUser!.canAccess('vencimentos') || auth.currentUser!.canAccess('relatorios')))
                                    _SidebarGroupLabel('Financeiro'),
                                  if (auth.currentUser!.canAccess('custos'))
                                    _SidebarItem(
                                      icon: LucideIcons.wrench,
                                      title: 'Custos da Frota',
                                      isCollapsed: _isCollapsed,
                                      isActive:
                                          uri.startsWith(AppRoutes.custosRoot),
                                      onTap: () =>
                                          context.go(AppRoutes.custosRoot),
                                    ),
                                  if (auth.currentUser!.canAccess('contratos'))
                                    _SidebarItem(
                                      icon: LucideIcons.fileText,
                                      title: 'Contratos B2B',
                                      isCollapsed: _isCollapsed,
                                      isActive:
                                          uri.startsWith(AppRoutes.contratos),
                                      onTap: () =>
                                          context.go(AppRoutes.contratos),
                                    ),
                                  if (auth.currentUser!.canAccess('vencimentos'))
                                    _SidebarItem(
                                      icon: LucideIcons.calendarClock,
                                      title: 'Vencimentos',
                                      isCollapsed: _isCollapsed,
                                      isActive:
                                          uri.startsWith(AppRoutes.vencimentos),
                                      onTap: () =>
                                          context.go(AppRoutes.vencimentos),
                                    ),
                                  if (auth.currentUser!.canAccess('relatorios'))
                                    _SidebarItem(
                                      icon: LucideIcons.fileDown,
                                      title: 'Relatórios',
                                      isCollapsed: _isCollapsed,
                                      isActive: uri == AppRoutes.relatorios,
                                      onTap: () => context.go(AppRoutes.relatorios),
                                    ),
                                  if (auth.currentUser!.canAccess('financial_admin'))
                                    _SidebarItem(
                                      icon: LucideIcons.landmark,
                                      title: 'Adm Financeiro',
                                      isCollapsed: _isCollapsed,
                                      isActive: uri.startsWith(
                                          '/${AppRoutes.financialAdmin}'),
                                      onTap: () => context
                                          .go('/${AppRoutes.financialAdmin}'),
                                    ),
                                  if (!_isCollapsed) _SidebarGroupLabel('Sistema'),
                                  if (auth.currentUser!.canAccess('ai_assistant'))
                                    _SidebarItem(
                                      icon: LucideIcons.bot,
                                      title: 'Assistente IA',
                                      isCollapsed: _isCollapsed,
                                      isActive: false,
                                      onTap: () => context.push('/ai-chat'),
                                    ),
                                  if (auth.currentUser!.canAccess('configuracoes') || auth.currentUser!.canAccess('settings'))
                                    _SidebarItem(
                                      icon: LucideIcons.settings,
                                      title: 'Configurações',
                                      isCollapsed: _isCollapsed,
                                      isActive: false,
                                      onTap: () => context.push('/configuracoes'),
                                    ),
                                  _SidebarItem(
                                    icon: LucideIcons.bell,
                                    title: 'Notificações',
                                    isCollapsed: _isCollapsed,
                                    isActive: false,
                                    badgeCount: context.watch<NotificationService>().unreadCount,
                                    onTap: () => context.push('/notifications'),
                                  ),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Theme Toggle
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

                  _SidebarItem(
                    icon: LucideIcons.logOut,
                    title: 'Sair do Sistema',
                    isCollapsed: _isCollapsed,
                    isActive: false,
                    onTap: () async {
                      final authService = context.read<AuthService>();
                      await authService.logout();
                      if (!mounted) return;
                      context.go(AppRoutes.login);
                    },
                  ),
                  const SizedBox(height: 8),
                  Builder(
                    builder: (context) {
                      final user = context.watch<AuthService>().currentUser;
                      final initials = (user?.username ?? 'ATR')
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
                                gradient: const LinearGradient(colors: AppColors.warmGradient),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Center(
                                child: Text(
                                  initials,
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
                                      user?.username ?? 'ATR',
                                      style: const TextStyle(
                                        fontFamily: 'Plus Jakarta Sans',
                                        color: AppColors.textPrimaryDark,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      user?.role.name ?? '',
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
                  const SizedBox(height: 24),
                ],
              ),
            ),
          Expanded(child: widget.child),
        ],
      ),
    ],
  ),
  bottomNavigationBar: (!isDesktop && !context.read<AuthService>().isFleetOnlyUser)
          ? BottomNavigationBar(
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
            )
          : null,
    );
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
                            constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
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
    final isHover = _hovering || widget.isActive;
    final dotColor = widget.isActive
        ? AppColors.atrOrange
        : (isHover ? AppColors.textPrimaryDark : AppColors.textSecondaryDark.withValues(alpha: 0.3));

    return RepaintBoundary(
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovering = true),
        onExit: (_) => setState(() => _hovering = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: _hovering
                  ? Colors.white.withValues(alpha: 0.04)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: widget.isActive ? 6 : 5,
                  height: widget.isActive ? 6 : 5,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: dotColor,
                    boxShadow: widget.isActive
                        ? [
                            BoxShadow(
                              color: AppColors.atrOrange.withValues(alpha: 0.4),
                              blurRadius: 6,
                            ),
                          ]
                        : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.title,
                    style: TextStyle(
                      color: widget.isActive
                          ? AppColors.textPrimaryDark
                          : (isHover ? AppColors.textPrimaryDark : AppColors.textSecondaryDark),
                      fontSize: 12,
                      fontWeight:
                          widget.isActive ? FontWeight.w600 : FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

