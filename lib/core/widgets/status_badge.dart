import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

enum BadgeType { success, warning, error, info }

/// Premium Glass Pill Badge com dot luminoso.
class StatusBadge extends StatelessWidget {
  final String text;
  final BadgeType type;

  const StatusBadge({super.key, required this.text, required this.type});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    Color color;

    switch (type) {
      case BadgeType.success: color = AppColors.statusSuccess; break;
      case BadgeType.warning: color = AppColors.statusWarning; break;
      case BadgeType.error: color = AppColors.statusError; break;
      case BadgeType.info: color = AppColors.statusInfo; break;
    }

    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: isDark ? 0.12 : 0.10),
          borderRadius: BorderRadius.circular(100),
          border: Border.all(
            color: color.withValues(alpha: isDark ? 0.25 : 0.20),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.08),
              blurRadius: 8,
              spreadRadius: 0,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color,
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.6),
                    blurRadius: 4,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 5),
            Text(
              text,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w700,
                fontSize: 10,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
