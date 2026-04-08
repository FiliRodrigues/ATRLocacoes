import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme/app_colors.dart';
import '../../core/services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  bool _loading = false;

  void _login() async {
    setState(() => _loading = true);
    await Future.delayed(const Duration(milliseconds: 800));
    if (mounted) {
      context.read<AuthService>().login();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF0B0F19), Color(0xFF111827), Color(0xFF0B0F19)],
              ),
            ),
          ),

          // Sutil grid pattern
          CustomPaint(painter: _GridPainter(), size: MediaQuery.of(context).size),

          // Glow central
          Center(
            child: Container(
              width: 500, height: 500,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [AppColors.atrOrange.withOpacity(0.06), Colors.transparent]),
              ),
            ),
          ),

          // Content
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Spacer(flex: 3),

                // Logo
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.atrOrange.withOpacity(0.4), width: 2),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: AppColors.atrOrange.withOpacity(0.1), blurRadius: 40, spreadRadius: 5)],
                  ),
                  child: const Icon(LucideIcons.truck, size: 44, color: AppColors.atrOrange),
                ).animate().scale(begin: const Offset(0.5, 0.5), duration: 600.ms, curve: Curves.easeOutBack).fadeIn(duration: 500.ms),

                const SizedBox(height: 24),

                // Nome
                Text('ATR', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 48, letterSpacing: 6, shadows: [Shadow(color: AppColors.atrOrange.withOpacity(0.3), blurRadius: 30)]))
                    .animate(delay: 200.ms).fadeIn(duration: 500.ms).moveY(begin: 10, end: 0),

                const SizedBox(height: 6),
                Text('Locações', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 16, fontWeight: FontWeight.w400, letterSpacing: 8))
                    .animate(delay: 300.ms).fadeIn(duration: 500.ms),

                const SizedBox(height: 8),
                Container(width: 60, height: 2, decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.transparent, AppColors.atrOrange.withOpacity(0.5), Colors.transparent]), borderRadius: BorderRadius.circular(1)))
                    .animate(delay: 400.ms).fadeIn(duration: 500.ms).scaleX(begin: 0, duration: 500.ms),

                const SizedBox(height: 20),
                Text('Gestão Inteligente de Frotas', style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 13, fontWeight: FontWeight.w500, letterSpacing: 2))
                    .animate(delay: 500.ms).fadeIn(duration: 500.ms),

                const Spacer(flex: 3),

                // Botão
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: SizedBox(
                    width: 280,
                    height: 52,
                    child: _LoginButton(loading: _loading, onTap: _login),
                  ),
                ).animate(delay: 600.ms).fadeIn(duration: 500.ms).moveY(begin: 20, end: 0),

                const SizedBox(height: 40),

                // Footer
                Text('v1.0.0 • ATR Locações © 2026', style: TextStyle(color: Colors.white.withOpacity(0.15), fontSize: 11))
                    .animate(delay: 700.ms).fadeIn(duration: 500.ms),

                const Spacer(flex: 1),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LoginButton extends StatefulWidget {
  final bool loading;
  final VoidCallback onTap;
  const _LoginButton({required this.loading, required this.onTap});
  @override
  State<_LoginButton> createState() => _LoginButtonState();
}

class _LoginButtonState extends State<_LoginButton> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: widget.loading ? null : widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: _hovering
                  ? [AppColors.atrOrange, const Color(0xFFFF5F6D)]
                  : [AppColors.atrOrange.withOpacity(0.9), AppColors.atrOrange],
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: AppColors.atrOrange.withValues(alpha: _hovering ? 0.4 : 0.15),
                blurRadius: _hovering ? 32 : 16,
                spreadRadius: _hovering ? 2 : 0,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Center(
            child: widget.loading
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, valueColor: AlwaysStoppedAnimation(Colors.white)))
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Entrar no Sistema', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15, letterSpacing: 0.5)),
                      const SizedBox(width: 10),
                      AnimatedSlide(
                        offset: Offset(_hovering ? 0.3 : 0, 0),
                        duration: const Duration(milliseconds: 200),
                        child: const Icon(LucideIcons.arrowRight, color: Colors.white, size: 18),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withOpacity(0.015)..strokeWidth = 0.5;
    const spacing = 60.0;
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
