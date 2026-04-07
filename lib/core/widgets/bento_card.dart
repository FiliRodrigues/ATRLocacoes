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

  const BentoCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(24.0),
    this.width,
    this.height,
    this.onTap,
    this.animationDelay = 0,
  });

  @override
  State<BentoCard> createState() => _BentoCardState();
}

class _BentoCardState extends State<BentoCard> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final borderColor = _isHovering
        ? AppColors.atrOrange.withValues(alpha: isDark ? 0.3 : 0.15)
        : (isDark ? AppColors.borderDark : AppColors.borderLight);

    final surfaceColor = _isHovering
        ? (isDark ? AppColors.surfaceHoverDark.withOpacity(0.4) : AppColors.surfaceHoverLight.withOpacity(0.6))
        : (isDark ? AppColors.surfaceDark.withOpacity(0.3) : AppColors.surfaceLight.withOpacity(0.5));

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
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: AnimatedContainer(
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
                      ? AppColors.atrOrange.withOpacity(0.4) 
                      : (isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05)), 
                    width: _isHovering ? 1.5 : 1
                  ),
                  boxShadow: [
                    if (_isHovering)
                      BoxShadow(
                        color: AppColors.atrOrange.withOpacity(0.12),
                        blurRadius: 28,
                        spreadRadius: 2,
                      ),
                    BoxShadow(
                      color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: widget.child,
              ),
            ),
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
