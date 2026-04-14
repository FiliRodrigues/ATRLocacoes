import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../theme/app_colors.dart';

class BentoShimmer extends StatelessWidget {
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;

  const BentoShimmer({
    super.key,
    this.width,
    this.height,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Shimmer.fromColors(
      baseColor: isDark ? AppColors.surfaceElevatedDark : Colors.grey[200]!,
      highlightColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white.withValues(alpha: 0.5),
      child: Container(
        width: width ?? double.infinity,
        height: height ?? double.infinity,
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : Colors.white,
          borderRadius: borderRadius ?? BorderRadius.circular(20),
        ),
      ),
    );
  }
}

class BentoCardShimmer extends StatelessWidget {
  const BentoCardShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).dividerTheme.color!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const BentoShimmer(width: 100, height: 16),
              BentoShimmer(width: 32, height: 32, borderRadius: BorderRadius.circular(8)),
            ],
          ),
          const SizedBox(height: 12),
          const BentoShimmer(width: 150, height: 32),
          const SizedBox(height: 8),
          const BentoShimmer(width: 80, height: 14),
        ],
      ),
    );
  }
}
