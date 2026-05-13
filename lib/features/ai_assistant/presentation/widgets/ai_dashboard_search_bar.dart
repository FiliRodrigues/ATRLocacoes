import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/theme/app_colors.dart';

class AiDashboardSearchBar extends StatefulWidget {
  const AiDashboardSearchBar({super.key});

  @override
  State<AiDashboardSearchBar> createState() => _AiDashboardSearchBarState();
}

class _AiDashboardSearchBarState extends State<AiDashboardSearchBar> {
  final _controller = TextEditingController();
  bool _focused = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final query = _controller.text.trim();
    _controller.clear();
    context.push('/ai-chat', extra: query.isEmpty ? null : query);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: AppColors.warmGradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: const Center(
                  child: Icon(LucideIcons.bot, color: Colors.white, size: 12),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Assistente ATR',
                style: TextStyle(
                  fontFamily: 'Syne',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondaryDark,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Focus(
            onFocusChange: (v) => setState(() => _focused = v),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              decoration: BoxDecoration(
                color: _focused
                    ? AppColors.surfaceElevatedDark
                    : AppColors.surfaceDark,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _focused
                      ? AppColors.atrOrange.withValues(alpha: 0.5)
                      : AppColors.borderDark,
                  width: _focused ? 1.5 : 1,
                ),
                boxShadow: _focused
                    ? [
                        BoxShadow(
                          color: AppColors.atrOrange.withValues(alpha: 0.12),
                          blurRadius: 20,
                          spreadRadius: 0,
                        ),
                      ]
                    : null,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  Icon(
                    LucideIcons.sparkles,
                    size: 18,
                    color: _focused
                        ? AppColors.atrOrange
                        : AppColors.textMutedDark,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      style: const TextStyle(
                        fontSize: 15,
                        color: AppColors.textPrimaryDark,
                        fontFamily: 'PlusJakartaSans',
                        fontWeight: FontWeight.w400,
                      ),
                      decoration: const InputDecoration(
                        hintText: 'Pergunte sobre a frota, custos, manutenções...',
                        hintStyle: TextStyle(
                          fontSize: 15,
                          color: AppColors.textMutedDark,
                          fontFamily: 'PlusJakartaSans',
                        ),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 14),
                        isDense: true,
                      ),
                      onSubmitted: (_) => _submit(),
                      textInputAction: TextInputAction.search,
                    ),
                  ),
                  const SizedBox(width: 8),
                  ListenableBuilder(
                    listenable: _controller,
                    builder: (context, _) {
                      final hasText = _controller.text.trim().isNotEmpty;
                      return AnimatedOpacity(
                        duration: const Duration(milliseconds: 150),
                        opacity: hasText ? 1.0 : 0.4,
                        child: GestureDetector(
                          onTap: hasText ? _submit : null,
                          child: Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: hasText
                                  ? AppColors.atrOrange
                                  : AppColors.surfaceDarkAlt,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Center(
                              child: Icon(
                                LucideIcons.arrowRight,
                                size: 17,
                                color: hasText
                                    ? Colors.white
                                    : AppColors.textMutedDark,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          _QuickChips(onChipTap: (q) {
            context.push('/ai-chat', extra: q);
          }),
        ],
      ),
    );
  }
}

class _QuickChips extends StatelessWidget {
  final void Function(String query) onChipTap;
  const _QuickChips({required this.onChipTap});

  static const _chips = [
    'Resumo da frota',
    'Alertas pendentes',
    'Gastos do mês',
    'Criar veículo novo',
    'Despesas não pagas',
    'Marcar IPVA como pago',
    'Última manutenção',
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: _chips.map((label) {
        return GestureDetector(
          onTap: () => onChipTap(label),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.surfaceDark,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.borderDark),
            ),
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondaryDark,
                fontFamily: 'PlusJakartaSans',
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
