import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_colors.dart';

class BentoCard extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double? width;
  final double? height;
  final VoidCallback? onTap;
  final int animationDelay;

  final bool blur;

  const BentoCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(24.0),
    this.width,
    this.height,
    this.onTap,
    this.animationDelay = 0,
    this.blur = false,
  });

  @override
  State<BentoCard> createState() => _BentoCardState();
}

class _BentoCardState extends State<BentoCard> {
  bool _isHovering = false;

  // Pre-computed color constants to avoid per-build allocations
  static final _surfaceHoverDark = AppColors.surfaceHoverDark.withValues(alpha: 0.4);
  static final _surfaceHoverLight = AppColors.surfaceHoverLight.withValues(alpha: 0.6);
  static final _surfaceDark = AppColors.surfaceDark.withValues(alpha: 0.3);
  static final _surfaceLight = AppColors.surfaceLight.withValues(alpha: 0.5);
  static final _borderHover = AppColors.atrOrange.withValues(alpha: 0.4);
  static final _borderDark = Colors.white.withValues(alpha: 0.05);
  static final _borderLight = Colors.black.withValues(alpha: 0.05);
  static final _shadowHover = AppColors.atrOrange.withValues(alpha: 0.12);
  static final _shadowBaseDark = Colors.black.withValues(alpha: 0.2);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final surfaceColor = _isHovering
        ? (isDark ? _surfaceHoverDark : _surfaceHoverLight)
        : (isDark ? _surfaceDark : _surfaceLight);

    final animatedContent = AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      width: widget.width,
      height: widget.height,
      padding: widget.padding,
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: _isHovering
              ? _borderHover
              : (isDark ? _borderDark : _borderLight),
          width: _isHovering ? 1.5 : 1,
        ),
        boxShadow: [
          if (_isHovering)
            BoxShadow(
              color: _shadowHover,
              blurRadius: 28,
              spreadRadius: 2,
            ),
          BoxShadow(
            color: isDark ? _shadowBaseDark : _borderLight,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: widget.child,
    );

    // Otimização: Uso de RepaintBoundary isola o card do restante da árvore durante o build do hover.
    final card = RepaintBoundary(
      child: MouseRegion(
        cursor: widget.onTap != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
        onEnter: (_) => setState(() => _isHovering = true),
        onExit: (_) => setState(() => _isHovering = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedScale(
            scale: _isHovering ? 1.015 : 1.0,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: widget.blur
                  ? BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                      child: animatedContent,
                    )
                  : animatedContent,
            ),
          ),
        ),
      ),
    );

    if (widget.animationDelay < 0) return card;

    // Otimização: Usar RepaintBoundary em volta da animação inicial também.
    return RepaintBoundary(
      child: card.animate(delay: widget.animationDelay.ms)
          .fadeIn(duration: 300.ms, curve: Curves.easeOut)
          ..moveY(begin: 10, end: 0, duration: 300.ms, curve: Curves.easeOutCubic),
    );
  }
}
