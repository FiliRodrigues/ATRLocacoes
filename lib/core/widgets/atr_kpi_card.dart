import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'bento_card.dart';

enum KpiTone { orange, success, info, warning, error }

enum KpiTrend { up, down, neutral }

class AtrKpiCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final KpiTone tone;
  final String? delta;
  final KpiTrend? trend;
  final VoidCallback? onTap;

  const AtrKpiCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.tone = KpiTone.orange,
    this.delta,
    this.trend,
    this.onTap,
  });

  Color _color() {
    switch (tone) {
      case KpiTone.orange:
        return AppColors.atrOrange;
      case KpiTone.success:
        return AppColors.statusSuccess;
      case KpiTone.info:
        return AppColors.statusInfo;
      case KpiTone.warning:
        return AppColors.statusWarning;
      case KpiTone.error:
        return AppColors.statusError;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final c = _color();

    return BentoCard(
      onTap: onTap,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: c.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, size: 16, color: c),
              ),
              const Spacer(),
              if (delta != null && trend != null)
                _DeltaBadge(delta: delta!, trend: trend!, tone: tone),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: AppColors.textMutedDark,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'Syne',
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
              letterSpacing: -0.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _DeltaBadge extends StatelessWidget {
  final String delta;
  final KpiTrend trend;
  final KpiTone tone;

  const _DeltaBadge({
    required this.delta,
    required this.trend,
    required this.tone,
  });

  @override
  Widget build(BuildContext context) {
    final Color c;
    final IconData icon;
    switch (trend) {
      case KpiTrend.up:
        c = AppColors.statusSuccess;
        icon = Icons.trending_up;
        break;
      case KpiTrend.down:
        c = AppColors.statusError;
        icon = Icons.trending_down;
        break;
      case KpiTrend.neutral:
        c = AppColors.textSecondaryDark;
        icon = Icons.trending_flat;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: c),
          const SizedBox(width: 3),
          Text(
            delta,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: c,
            ),
          ),
        ],
      ),
    );
  }
}
