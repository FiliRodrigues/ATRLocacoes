import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../theme/app_colors.dart';

// ═══════════════════════════════════════════════════════════════════════════
// WIDGETS COMPARTILHADOS — Lazer e Sala ATR
// Elimina a duplicação de layout entre as duas features.
// ═══════════════════════════════════════════════════════════════════════════

/// Sidebar parametrizada compartilhada entre Lazer e Sala ATR.
/// Difere apenas em [icon], [title], [subtitle] e [titleFontSize].
class BookableAreaSidebar extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final double titleFontSize;
  final int tabIndex;
  final ValueChanged<int> onTabChange;
  final VoidCallback onBack;
  final bool isDark;
  final bool showConsolidado;

  const BookableAreaSidebar({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.titleFontSize = 14,
    required this.tabIndex,
    required this.onTabChange,
    required this.onBack,
    required this.isDark,
    this.showConsolidado = false,
  });

  @override
  Widget build(BuildContext context) {
    final tabs = [
      (icon: LucideIcons.layoutDashboard, label: 'Dashboard'),
      (icon: LucideIcons.receipt, label: 'Despesas'),
      (icon: LucideIcons.calendarDays, label: 'Agendamentos'),
      if (showConsolidado)
        (icon: LucideIcons.barChart2, label: 'Consolidado'),
    ];
    final bg = isDark ? AppColors.surfaceDark : AppColors.surfaceLight;
    final border = isDark ? AppColors.borderDark : AppColors.borderLight;
    const activeColor = AppColors.atrOrange;
    final inactiveColor =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    return Container(
      width: 200,
      decoration: BoxDecoration(
        color: bg,
        border: Border(right: BorderSide(color: border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.atrOrange.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        icon,
                        color: AppColors.atrOrange,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          color: isDark
                              ? Colors.white
                              : AppColors.textPrimaryLight,
                          fontSize: titleFontSize,
                          fontWeight: FontWeight.w800,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              'NAVEGAÇÃO',
              style: TextStyle(
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
                fontSize: 10,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 8),
          ...List.generate(tabs.length, (i) {
            final tab = tabs[i];
            final active = i == tabIndex;
            return GestureDetector(
              onTap: () => onTabChange(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: active
                      ? AppColors.atrOrange.withValues(alpha: 0.12)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: active
                        ? AppColors.atrOrange.withValues(alpha: 0.3)
                        : Colors.transparent,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      tab.icon,
                      size: 16,
                      color: active ? activeColor : inactiveColor,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      tab.label,
                      style: TextStyle(
                        color: active ? activeColor : inactiveColor,
                        fontSize: 13,
                        fontWeight:
                            active ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.all(12),
            child: GestureDetector(
              onTap: onBack,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.surfaceElevatedDark
                      : AppColors.surfaceElevatedLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      LucideIcons.arrowLeft,
                      size: 15,
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Voltar',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Header com seletor de mês — idêntico em Lazer e Sala ATR.
class BookableAreaHeader extends StatelessWidget {
  final DateTime mesFiltro;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final bool isDark;

  const BookableAreaHeader({
    super.key,
    required this.mesFiltro,
    required this.onPrev,
    required this.onNext,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? AppColors.surfaceDark : AppColors.surfaceLight;
    final border = isDark ? AppColors.borderDark : AppColors.borderLight;
    final mesLabel = DateFormat('MMMM yyyy', 'pt_BR').format(mesFiltro);

    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: bg,
        border: Border(bottom: BorderSide(color: border)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          Text(
            mesLabel[0].toUpperCase() + mesLabel.substring(1),
            style: TextStyle(
              color: isDark ? Colors.white : AppColors.textPrimaryLight,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 12),
          _AreaNavBtn(
            icon: LucideIcons.chevronLeft,
            onTap: onPrev,
            isDark: isDark,
          ),
          const SizedBox(width: 4),
          _AreaNavBtn(
            icon: LucideIcons.chevronRight,
            onTap: onNext,
            isDark: isDark,
          ),
          const Spacer(),
        ],
      ),
    );
  }
}

class _AreaNavBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool isDark;
  const _AreaNavBtn({
    required this.icon,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: isDark
              ? AppColors.surfaceElevatedDark
              : AppColors.surfaceElevatedLight,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(
          icon,
          size: 14,
          color: isDark ? Colors.white70 : AppColors.textSecondaryLight,
        ),
      ),
    );
  }
}

/// Card de KPI — idêntico em Lazer e Sala ATR.
class BookableAreaKpiCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color iconColor;
  final bool isDark;

  const BookableAreaKpiCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.iconColor,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? AppColors.surfaceDark : AppColors.surfaceLight;
    final border = isDark ? AppColors.borderDark : AppColors.borderLight;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: iconColor),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              color: isDark ? Colors.white : AppColors.textPrimaryLight,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

/// Empty state — idêntico em Lazer e Sala ATR.
class BookableAreaEmptyState extends StatelessWidget {
  final String message;
  final IconData icon;
  final bool isDark;
  const BookableAreaEmptyState({
    super.key,
    required this.message,
    required this.icon,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          Icon(
            icon,
            size: 36,
            color: isDark
                ? AppColors.textSecondaryDark
                : AppColors.textSecondaryLight,
          ),
          const SizedBox(height: 12),
          Text(
            message,
            style: TextStyle(
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

/// Filter chip — idêntico em Lazer e Sala ATR.
class BookableAreaFilterChip extends StatelessWidget {
  final String label;
  final bool active;
  final bool isDark;
  final VoidCallback onTap;
  const BookableAreaFilterChip({
    super.key,
    required this.label,
    required this.active,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: active
              ? AppColors.atrOrange
              : (isDark
                  ? AppColors.surfaceElevatedDark
                  : AppColors.surfaceElevatedLight),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active
                ? AppColors.atrOrange
                : (isDark ? AppColors.borderDark : AppColors.borderLight),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active
                ? Colors.white
                : (isDark ? Colors.white70 : AppColors.textSecondaryLight),
            fontSize: 12,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

/// Coluna de tabela — idêntica em Lazer e Sala ATR.
class BookableAreaTableCol extends StatelessWidget {
  final String label;
  final int flex;
  const BookableAreaTableCol(this.label, {super.key, this.flex = 1});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.textSecondaryDark,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
