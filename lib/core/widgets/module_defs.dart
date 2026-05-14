import 'package:lucide_icons/lucide_icons.dart';

import '../services/auth_service.dart';
import 'sidebar_models.dart';

List<ModuleDef> buildAvailableModules(AuthUser user) {
  return [
    const ModuleDef(
      icon: LucideIcons.truck,
      name: 'Frota & Custos',
      rootRoute: '/',
    ),
    if (user.canAccess('sala_atr'))
      const ModuleDef(
        icon: LucideIcons.building2,
        name: 'Sala ATR',
        rootRoute: '/sala-atr',
        feature: 'sala_atr',
      ),
    if (user.canAccess('lazer'))
      const ModuleDef(
        icon: LucideIcons.dumbbell,
        name: 'Lazer',
        rootRoute: '/lazer',
        feature: 'lazer',
      ),
  ];
}
