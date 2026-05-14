import 'package:lucide_icons/lucide_icons.dart';

import '../navigation/app_router.dart';
import '../services/auth_service.dart';
import 'sidebar_models.dart';

List<SidebarItemDef> buildFrotaItems(
  AuthUser user, {
  int notificationCount = 0,
}) {
  final items = <SidebarItemDef>[
    if (user.canAccess('dashboard'))
      const SidebarItemDef(
        icon: LucideIcons.layoutDashboard,
        title: 'Dashboard Executivo',
        route: AppRoutes.home,
        feature: 'dashboard',
      ),
    if (user.canAccess('vehicles'))
      const SidebarItemDef(
        icon: LucideIcons.car,
        title: 'Veículos',
        route: AppRoutes.frotaRevisao,
        feature: 'vehicles',
      ),
    if (user.canAccess('drivers'))
      const SidebarItemDef(
        icon: LucideIcons.users,
        title: 'Motoristas',
        route: AppRoutes.driversRoot,
        feature: 'drivers',
      ),
    if (user.canAccess('custos'))
      const SidebarItemDef(
        icon: LucideIcons.wrench,
        title: 'Custos da Frota',
        route: AppRoutes.custosRoot,
        feature: 'custos',
      ),
    if (user.canAccess('contratos'))
      const SidebarItemDef(
        icon: LucideIcons.fileText,
        title: 'Contratos B2B',
        route: AppRoutes.contratos,
        feature: 'contratos',
      ),
    if (user.canAccess('vencimentos'))
      const SidebarItemDef(
        icon: LucideIcons.calendarClock,
        title: 'Vencimentos',
        route: AppRoutes.vencimentos,
        feature: 'vencimentos',
      ),
    if (user.canAccess('relatorios'))
      const SidebarItemDef(
        icon: LucideIcons.fileDown,
        title: 'Relatórios',
        route: AppRoutes.relatorios,
        feature: 'relatorios',
      ),
    if (user.canAccess('financial_admin'))
      const SidebarItemDef(
        icon: LucideIcons.landmark,
        title: 'Adm Financeiro',
        route: AppRoutes.financialAdminRoot,
        feature: 'financial_admin',
      ),
    SidebarItemDef(
      icon: LucideIcons.bell,
      title: 'Notificações',
      route: AppRoutes.notifications,
      badgeCount: notificationCount,
    ),
  ];

  return items;
}
