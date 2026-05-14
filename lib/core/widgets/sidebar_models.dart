import 'package:flutter/material.dart';

class SidebarItemDef {
  final IconData icon;
  final String title;
  final String route;
  final String? feature;
  final int badgeCount;
  final VoidCallback? onTap;
  final bool? isActiveOverride;

  const SidebarItemDef({
    required this.icon,
    required this.title,
    required this.route,
    this.feature,
    this.badgeCount = 0,
    this.onTap,
    this.isActiveOverride,
  });
}

class ModuleDef {
  final IconData icon;
  final String name;
  final String rootRoute;
  final String? feature;

  const ModuleDef({
    required this.icon,
    required this.name,
    required this.rootRoute,
    this.feature,
  });
}
