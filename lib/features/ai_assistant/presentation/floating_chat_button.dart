import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/services/auth_service.dart';
import '../../../core/utils/app_logger.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../domain/ai_chat_provider.dart';

class FloatingChatButton extends StatefulWidget {
  const FloatingChatButton({super.key});

  @override
  State<FloatingChatButton> createState() => _FloatingChatButtonState();
}

class _FloatingChatButtonState extends State<FloatingChatButton> {
  bool _revealed = false;
  bool _hovered = false;

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(milliseconds: 800), () {
      if (!mounted) return;
      setState(() => _revealed = true);
    });
  }

  bool _shouldShow(BuildContext context) {
    final auth = context.read<AuthService>();
    if (!auth.isAuthenticated) return false;

    try {
      final routeName = GoRouterState.of(context).uri.path;
      const hiddenRoutes = ['/login', '/selector', '/trocar-senha', '/ai-chat'];
      return !hiddenRoutes.contains(routeName);
    } catch (_) {
      return false;
    }
  }

  int _pendingActionsCount(BuildContext context) {
    try {
      return context.watch<AiChatProvider>().pendingActionsCount;
    } catch (_) {
      return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_shouldShow(context)) return const SizedBox.shrink();

    final pendingCount = _pendingActionsCount(context);

    return Positioned(
      right: 24,
      bottom: 24,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: AnimatedScale(
          scale: !_revealed
              ? 0.0
              : _hovered
                  ? 1.05
                  : 1.0,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutBack,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  gradient: const LinearGradient(
                    colors: AppColors.warmGradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    AppShadows.ctaGlow,
                    if (_hovered)
                      const BoxShadow(
                        color: AppColors.glowOrange,
                        blurRadius: 18,
                        spreadRadius: 1,
                        offset: Offset(0, 2),
                      ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(28),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(28),
                    onTap: () {
                      try {
                        context.push('/ai-chat');
                      } catch (e) { AppLogger.warning('FloatingChatButton: $e'); }
                    },
                    child: const Center(
                      child: Icon(
                        LucideIcons.messageCircle,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                ),
              ),
              if (pendingCount > 0)
                Positioned(
                  right: -3,
                  top: -3,
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: const BoxDecoration(
                      color: AppColors.statusError,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        pendingCount > 99 ? '99+' : '$pendingCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          height: 1,
                        ),
                      ),
                    ),
                  )
                      .animate(onPlay: (controller) => controller.repeat(reverse: true))
                      .scale(begin: const Offset(1, 1), end: const Offset(1.1, 1.1), duration: 700.ms),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
