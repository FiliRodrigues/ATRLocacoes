import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../data/fleet_data.dart';
import '../navigation/app_router.dart';
import '../theme/app_colors.dart';
import '../theme/atr_theme_state.dart';

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
      body: Row(
        children: [
          if (isDesktop)
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              width: _isCollapsed ? 80 : 260,
              clipBehavior: Clip.hardEdge,
              decoration: const BoxDecoration(
                color: AppColors.atrNavyBlue,
                border: Border(
                  right: BorderSide(color: AppColors.atrNavyDarker),
                ),
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
                                      width: 2,
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
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w900,
                                          fontSize: 20,
                                          letterSpacing: 1.2,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        '(Locações)',
                                        style: TextStyle(
                                          color: Colors.white70,
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
                          ),
                        IconButton(
                          icon: Icon(
                            _isCollapsed
                                ? LucideIcons.chevronRight
                                : LucideIcons.chevronLeft,
                            color: Colors.white54,
                          ),
                          onPressed: _toggleSidebar,
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
                              final repo = context.read<FleetRepository>();
                              final frota = repo.frota;
                              final veiculosFinanciados =
                                  repo.veiculosFinanciados;
                              return Column(
                                children: [
                                  _SidebarItem(
                                    icon: LucideIcons.layoutDashboard,
                                    title: 'Dashboard Executivo',
                                    isCollapsed: _isCollapsed,
                                    isActive: uri == AppRoutes.home,
                                    onTap: () => context.go(AppRoutes.home),
                                  ),
                                  if (_showExpandedContent)
                                    _buildVehicleExpansionTile(
                                      context,
                                      uri,
                                      frota,
                                    )
                                  else
                                    _SidebarItem(
                                      icon: LucideIcons.car,
                                      title: 'Veículos',
                                      isCollapsed: _isCollapsed,
                                      isActive: uri.startsWith('/vehicles'),
                                      onTap: () {
                                        if (frota.isNotEmpty) {
                                          context.go('/vehicles/${frota.first.placa}');
                                        }
                                      },
                                    ),
                                  _SidebarItem(
                                    icon: LucideIcons.users,
                                    title: 'Motoristas',
                                    isCollapsed: _isCollapsed,
                                    isActive: uri.startsWith('/${AppRoutes.drivers}'),
                                    onTap: () => context.go('/${AppRoutes.drivers}'),
                                  ),
                                  _SidebarItem(
                                    icon: LucideIcons.wrench,
                                    title: 'Manutenções',
                                    isCollapsed: _isCollapsed,
                                    isActive: uri.startsWith('/${AppRoutes.maintenance}'),
                                    onTap: () => context.go('/${AppRoutes.maintenance}'),
                                  ),
                                  _SidebarItem(
                                    icon: LucideIcons.fileText,
                                    title: 'Despesas',
                                    isCollapsed: _isCollapsed,
                                    isActive: uri.startsWith('/${AppRoutes.expenses}'),
                                    onTap: () => context.go('/${AppRoutes.expenses}'),
                                  ),
                                  if (_showExpandedContent)
                                    _buildFinancialExpansionTile(
                                      context,
                                      uri,
                                      veiculosFinanciados,
                                    )
                                  else
                                    _SidebarItem(
                                      icon: LucideIcons.landmark,
                                      title: 'Adm Financeiro',
                                      isCollapsed: _isCollapsed,
                                      isActive:
                                          uri.startsWith('/${AppRoutes.financialAdmin}'),
                                      onTap: () =>
                                          context.go('/${AppRoutes.financialAdmin}'),
                                    ),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),

                  const Divider(color: AppColors.atrNavyDarker),
                  _SidebarItem(
                    icon: LucideIcons.settings,
                    title: 'Configurações',
                    isCollapsed: _isCollapsed,
                    isActive: false,
                    onTap: () {},
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
                    onTap: () => context.go(AppRoutes.login),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          Expanded(child: widget.child),
        ],
      ),
      bottomNavigationBar: !isDesktop
          ? BottomNavigationBar(
              currentIndex: _getBottomNavIndex(context),
              selectedItemColor: AppColors.atrOrange,
              unselectedItemColor: AppColors.textSecondaryLight,
              type: BottomNavigationBarType.fixed,
              onTap: (index) {
                if (index == 0) context.go(AppRoutes.home);
                if (index == 1) {
                  final frota = context.read<FleetRepository>().frota;
                  if (frota.isNotEmpty) context.go('/vehicles/${frota.first.placa}');
                }
                if (index == 2) context.go('/${AppRoutes.maintenance}');
                if (index == 3) context.go('/${AppRoutes.expenses}');
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
                  label: 'Serviços',
                ),
                BottomNavigationBarItem(
                  icon: Icon(LucideIcons.wallet),
                  label: 'Lanc.',
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
    if (uri.startsWith('/${AppRoutes.maintenance}')) return 2;
    if (uri.startsWith('/${AppRoutes.expenses}')) return 3;
    return 0;
  }

  Widget _buildVehicleExpansionTile(
    BuildContext context,
    String uri,
    List<VehicleData> frota,
  ) {
    final isVehiclesActive = uri.startsWith('/vehicles');

    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        initiallyExpanded: isVehiclesActive,
        iconColor: Colors.white,
        collapsedIconColor: Colors.white54,
        title: Row(
          children: [
            Icon(
              LucideIcons.car,
              color: isVehiclesActive ? AppColors.atrOrange : Colors.white54,
              size: 20,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                'Acessar Veículos',
                style: TextStyle(
                  color: isVehiclesActive ? Colors.white : Colors.white70,
                  fontWeight:
                      isVehiclesActive ? FontWeight.w600 : FontWeight.w500,
                  fontSize: 13,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        childrenPadding: const EdgeInsets.only(left: 32, bottom: 8),
        children: [
          for (final v in frota) ...[
            _SubSidebarItem(
              title: '${v.placa} (${v.nome})',
              isActive: uri == '/vehicles/${v.placa}',
              onTap: () => context.go('/vehicles/${v.placa}'),
            ),
            const SizedBox(height: 4),
          ],
        ],
      ),
    );
  }

  Widget _buildFinancialExpansionTile(
    BuildContext context,
    String uri,
    List<VehicleData> veiculosFinanciados,
  ) {
    final isFinActive = uri.startsWith('/${AppRoutes.financialAdmin}');

    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        initiallyExpanded: isFinActive,
        iconColor: Colors.white,
        collapsedIconColor: Colors.white54,
        title: Row(
          children: [
            Icon(
              LucideIcons.landmark,
              color: isFinActive ? AppColors.atrOrange : Colors.white54,
              size: 20,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                'Adm Financeiro',
                style: TextStyle(
                  color: isFinActive ? Colors.white : Colors.white70,
                  fontWeight: isFinActive ? FontWeight.w600 : FontWeight.w500,
                  fontSize: 13,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        childrenPadding: const EdgeInsets.only(left: 32, bottom: 8),
        children: [
          _SubSidebarItem(
            title: 'Visão Geral',
            isActive: uri == '/${AppRoutes.financialAdmin}',
            onTap: () => context.go('/${AppRoutes.financialAdmin}'),
          ),
          for (final v in veiculosFinanciados) ...[
            const SizedBox(height: 4),
            _SubSidebarItem(
              title: '${v.nome} (${v.placa})',
              isActive: uri == '/${AppRoutes.financialAdmin}/${v.placa}',
              onTap: () => context.go('/${AppRoutes.financialAdmin}/${v.placa}'),
            ),
          ],
        ],
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

  const _SidebarItem({
    required this.icon,
    required this.title,
    required this.isActive,
    this.isCollapsed = false,
    required this.onTap,
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
        : (isHover ? Colors.white : Colors.white54);
    final textColor = isHover ? Colors.white : Colors.white54;

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
                    ? AppColors.atrOrange.withValues(alpha: 0.12)
                    : (_hovering
                        ? Colors.white.withValues(alpha: 0.04)
                        : Colors.transparent),
                borderRadius: BorderRadius.circular(12),
                border: widget.isActive
                    ? Border.all(
                        color: AppColors.atrOrange.withValues(alpha: 0.2),
                      )
                    : null,
              ),
              child: Row(
                mainAxisAlignment: widget.isCollapsed
                    ? MainAxisAlignment.center
                    : MainAxisAlignment.start,
                children: [
                  Icon(widget.icon, color: iconColor, size: 20),
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
                          fontSize: 13,
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
        : (isHover ? Colors.white70 : Colors.white30);

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
                  ? Colors.white.withValues(alpha: 0.03)
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
                          ? Colors.white
                          : (isHover ? Colors.white70 : Colors.white54),
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
