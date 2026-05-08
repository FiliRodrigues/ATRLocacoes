import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';

enum AtrButtonVariant { primary, secondary, ghost }

class AtrButton extends StatefulWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool loading;
  final AtrButtonVariant variant;
  final double? width;

  const AtrButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.loading = false,
    this.variant = AtrButtonVariant.primary,
    this.width,
  });

  factory AtrButton.primary({
    Key? key,
    required String label,
    IconData? icon,
    VoidCallback? onPressed,
    bool loading = false,
    double? width,
  }) =>
      AtrButton(
        key: key,
        label: label,
        icon: icon,
        onPressed: onPressed,
        loading: loading,
        variant: AtrButtonVariant.primary,
        width: width,
      );

  factory AtrButton.secondary({
    Key? key,
    required String label,
    IconData? icon,
    VoidCallback? onPressed,
    bool loading = false,
    double? width,
  }) =>
      AtrButton(
        key: key,
        label: label,
        icon: icon,
        onPressed: onPressed,
        loading: loading,
        variant: AtrButtonVariant.secondary,
        width: width,
      );

  factory AtrButton.ghost({
    Key? key,
    required String label,
    IconData? icon,
    VoidCallback? onPressed,
    bool loading = false,
    double? width,
  }) =>
      AtrButton(
        key: key,
        label: label,
        icon: icon,
        onPressed: onPressed,
        loading: loading,
        variant: AtrButtonVariant.ghost,
        width: width,
      );

  @override
  State<AtrButton> createState() => _AtrButtonState();
}

class _AtrButtonState extends State<AtrButton> {
  bool _isHovering = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final effectiveOnPressed = widget.loading ? null : widget.onPressed;

    final Decoration decoration;
    final Color fgColor;

    switch (widget.variant) {
      case AtrButtonVariant.primary:
        fgColor = const Color(0xFF1A1208);
        decoration = BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFF9252), AppColors.atrOrange],
          ),
          borderRadius: BorderRadius.circular(AppRadii.btn),
          boxShadow: const [AppShadows.ctaGlow],
        );
        break;
      case AtrButtonVariant.secondary:
        fgColor = AppColors.atrOrange;
        decoration = BoxDecoration(
          color: AppColors.atrOrange.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(AppRadii.btn),
          border: Border.all(
            color: AppColors.atrOrange.withValues(alpha: 0.40),
            width: 1.5,
          ),
        );
        break;
      case AtrButtonVariant.ghost:
        fgColor = AppColors.textSecondaryDark;
        decoration = BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadii.btn),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.08),
            width: 1,
          ),
        );
        break;
    }

    return MouseRegion(
      cursor: effectiveOnPressed != null
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: GestureDetector(
        onTap: effectiveOnPressed,
        onTapDown: effectiveOnPressed != null
            ? (_) => setState(() => _isPressed = true)
            : null,
        onTapUp: effectiveOnPressed != null
            ? (_) => setState(() => _isPressed = false)
            : null,
        onTapCancel:
            effectiveOnPressed != null ? () => setState(() => _isPressed = false) : null,
        child: AnimatedScale(
          scale: _isPressed ? 0.98 : (_isHovering ? 1.02 : 1.0),
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOutCubic,
          child: AnimatedOpacity(
            opacity: effectiveOnPressed != null ? 1.0 : 0.5,
            duration: const Duration(milliseconds: 200),
            child: Container(
              width: widget.width,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
              decoration: decoration,
              child: Row(
                mainAxisSize: widget.width != null ? MainAxisSize.max : MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (widget.loading)
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: fgColor,
                      ),
                    )
                  else if (widget.icon != null) ...[
                    Icon(widget.icon, size: 16, color: fgColor),
                    const SizedBox(width: 6),
                  ],
                  Flexible(
                    child: Text(
                      widget.label,
                      style: TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: fgColor,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AtrPrimaryButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool loading;
  final double? width;

  const AtrPrimaryButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.loading = false,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    return AtrButton(
      label: label,
      icon: icon,
      onPressed: onPressed,
      loading: loading,
      variant: AtrButtonVariant.primary,
      width: width,
    );
  }
}

class AtrSecondaryButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool loading;
  final double? width;

  const AtrSecondaryButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.loading = false,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    return AtrButton(
      label: label,
      icon: icon,
      onPressed: onPressed,
      loading: loading,
      variant: AtrButtonVariant.secondary,
      width: width,
    );
  }
}

class AtrGhostButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool loading;
  final double? width;

  const AtrGhostButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.loading = false,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    return AtrButton(
      label: label,
      icon: icon,
      onPressed: onPressed,
      loading: loading,
      variant: AtrButtonVariant.ghost,
      width: width,
    );
  }
}
