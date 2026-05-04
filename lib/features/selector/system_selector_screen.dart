import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/services/auth_service.dart';

class SystemSelectorScreen extends StatelessWidget {
  const SystemSelectorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();
    final cards = _buildCards(context, authService);
    final crossAxisCount = cards.length == 1 ? 1 : 2;

    return Scaffold(
      body: Stack(
        children: [
          // Background gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF0B0F19),
                  Color(0xFF111827),
                  Color(0xFF0B0F19),
                ],
              ),
            ),
          ),

          // Glow central
          Center(
            child: Container(
              width: 700,
              height: 700,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.atrOrange.withValues(alpha: 0.05),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 48),

                // Header
                Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: AppColors.atrOrange.withValues(alpha: 0.4),
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.atrOrange.withValues(alpha: 0.1),
                            blurRadius: 30,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                      child: const Icon(
                        LucideIcons.layoutGrid,
                        size: 32,
                        color: AppColors.atrOrange,
                      ),
                    )
                        .animate()
                        .scale(
                          begin: const Offset(0.5, 0.5),
                          duration: 500.ms,
                          curve: Curves.easeOutBack,
                        )
                        .fadeIn(duration: 400.ms),
                    const SizedBox(height: 20),
                    Text(
                      'ATR',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 38,
                        letterSpacing: 6,
                        shadows: [
                          Shadow(
                            color: AppColors.atrOrange.withValues(alpha: 0.3),
                            blurRadius: 24,
                          ),
                        ],
                      ),
                    ).animate(delay: 150.ms).fadeIn(duration: 400.ms),
                    const SizedBox(height: 4),
                    Text(
                      'Selecione o Sistema',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.45),
                        fontSize: 13,
                        letterSpacing: 3,
                        fontWeight: FontWeight.w400,
                      ),
                    ).animate(delay: 250.ms).fadeIn(duration: 400.ms),
                    const SizedBox(height: 8),
                    Container(
                      width: 50,
                      height: 2,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.transparent,
                            AppColors.atrOrange.withValues(alpha: 0.5),
                            Colors.transparent,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(1),
                      ),
                    )
                        .animate(delay: 300.ms)
                        .fadeIn(duration: 400.ms)
                        .scaleX(begin: 0, duration: 400.ms),
                  ],
                ),

                const SizedBox(height: 52),

                // Cards grid
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 720),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: GridView.count(
                          crossAxisCount: crossAxisCount,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisSpacing: 20,
                          mainAxisSpacing: 20,
                          childAspectRatio: 1.35,
                          children: cards,
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildCards(BuildContext context, AuthService authService) {
    final fleetCard = _SystemCard(
      index: 0,
      icon: LucideIcons.truck,
      title: 'Frota de Carros',
      subtitle: 'Gestão de veículos e motoristas',
      available: true,
      onTap: () => context.go('/'),
    );

    if (authService.isFleetOnlyUser) {
      return [fleetCard];
    }

    return [
      fleetCard,
      _SystemCard(
        index: 1,
        icon: LucideIcons.hardHat,
        title: 'Gestão de Obras',
        subtitle: 'Produtividade e sinalização viária',
        available: true,
        onTap: () => context.go('/obras'),
      ),
      _SystemCard(
        index: 2,
        icon: LucideIcons.building2,
        title: 'Sala ATR Locações',
        subtitle: 'Controle de salas e locatários',
        available: true,
        onTap: () => context.go('/sala-atr'),
      ),
      _SystemCard(
        index: 3,
        icon: LucideIcons.palmtree,
        title: 'ATR Área de Lazer',
        subtitle: 'Reservas, eventos e manutenção',
        available: true,
        onTap: () => context.go('/lazer'),
      ),
    ];
  }
}

class _SystemCard extends StatefulWidget {
  final int index;
  final IconData icon;
  final String title;
  final String subtitle;
  final bool available;
  final VoidCallback? onTap;

  const _SystemCard({
    required this.index,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.available,
    required this.onTap,
  });

  @override
  State<_SystemCard> createState() => _SystemCardState();
}

class _SystemCardState extends State<_SystemCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final Color accentColor =
        widget.available ? AppColors.atrOrange : AppColors.textSecondaryDark;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: widget.available
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            color: _hovered && widget.available
                ? AppColors.surfaceHoverDark
                : AppColors.surfaceDark,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _hovered && widget.available
                  ? AppColors.atrOrange.withValues(alpha: 0.5)
                  : AppColors.borderDark,
              width: 1.5,
            ),
            boxShadow: _hovered && widget.available
                ? [
                    BoxShadow(
                      color: AppColors.atrOrange.withValues(alpha: 0.12),
                      blurRadius: 24,
                      spreadRadius: 2,
                    ),
                  ]
                : [],
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: accentColor.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Icon(widget.icon, size: 22, color: accentColor),
                    ),
                    if (!widget.available)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceElevatedDark,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: AppColors.borderDark,
                          ),
                        ),
                        child: const Text(
                          'Em breve',
                          style: TextStyle(
                            color: AppColors.textSecondaryDark,
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    if (widget.available)
                      Icon(
                        LucideIcons.arrowRight,
                        size: 18,
                        color: _hovered
                            ? AppColors.atrOrange
                            : AppColors.textSecondaryDark,
                      ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: TextStyle(
                        color: widget.available
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.45),
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.subtitle,
                      style: TextStyle(
                        color: AppColors.textSecondaryDark.withValues(
                          alpha: widget.available ? 0.9 : 0.6,
                        ),
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        )
            .animate(delay: Duration(milliseconds: 400 + widget.index * 80))
            .fadeIn(duration: 400.ms)
            .moveY(begin: 20, end: 0, duration: 400.ms, curve: Curves.easeOut),
      ),
    );
  }
}
