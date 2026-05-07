import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/data/custos_models.dart';
import '../../../core/data/fleet_data.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/bento_card.dart';
import '../custos_provider.dart';

class CustosKpiRow extends StatelessWidget {
  const CustosKpiRow({super.key, required this.provider});

  final CustosProvider provider;

  @override
  Widget build(BuildContext context) {
    final ManutencaoItem? proxima = provider.proximaManutencao;
    final subtituloProxima = _buildSubtituloProxima(proxima);

    return LayoutBuilder(
      builder: (context, constraints) {
        final cards = [
          _buildCard(
            context,
            titulo: 'Total do Mes',
            valor: formatCurrency(provider.totalGeralMes),
            corValor: AppColors.statusError,
            tamanhoValor: 22,
            icone: LucideIcons.trendingDown,
            corIcone: AppColors.statusError,
          ),
          _buildCard(
            context,
            titulo: 'OSs em Aberto',
            valor: provider.totalOsAbertas.toString(),
            corValor: AppColors.atrOrange,
            tamanhoValor: 22,
            icone: LucideIcons.wrench,
            corIcone: AppColors.atrOrange,
          ),
          _buildCard(
            context,
            titulo: 'Custo Medio / Km (CPK)',
            valor: '${formatCurrency(provider.cpkGlobal)} / km',
            corValor: AppColors.statusInfo,
            tamanhoValor: 22,
            icone: LucideIcons.gauge,
            corIcone: AppColors.statusInfo,
          ),
          _buildCard(
            context,
            titulo: 'Proxima Manutencao',
            valor: proxima == null ? 'Nenhuma agendada' : proxima.veiculoNome,
            subtitulo: subtituloProxima,
            corValor: AppColors.statusInfo,
            tamanhoValor: 18,
            icone: LucideIcons.calendarClock,
            corIcone: AppColors.statusInfo,
          ),
        ];

        if (constraints.maxWidth >= 800) {
          return Row(
            children: [
              for (var i = 0; i < cards.length; i++) ...[
                Expanded(child: cards[i]),
                if (i != cards.length - 1) const SizedBox(width: 12),
              ],
            ],
          );
        }

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: cards
              .map((card) => SizedBox(
                    width: constraints.maxWidth >= 520
                        ? (constraints.maxWidth - 12) / 2
                        : constraints.maxWidth,
                    child: card,
                ),)
              .toList(),
        );
      },
    );
  }

  Widget _buildCard(
    BuildContext context, {
    required String titulo,
    required String valor,
    String? subtitulo,
    required Color corValor,
    required double tamanhoValor,
    required IconData icone,
    required Color corIcone,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return BentoCard(
      padding: EdgeInsets.zero,
      child: Container(
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: corIcone, width: 3)),
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    valor,
                    style: TextStyle(
                      color: corValor,
                      fontSize: tamanhoValor,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                  ),
                  if (subtitulo != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitulo,
                      style: TextStyle(
                        fontSize: 10,
                        color: isDark
                            ? Colors.white38
                            : AppColors.textSecondaryLight,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    corIcone.withValues(alpha: 0.2),
                    corIcone.withValues(alpha: 0.08),
                  ],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icone, color: corIcone, size: 16),
            ),
          ],
        ),
      ),
    );
  }

  String? _buildSubtituloProxima(ManutencaoItem? item) {
    if (item == null) return null;
    final hoje = DateTime.now();
    final dataItem = DateTime(item.data.year, item.data.month, item.data.day);
    final dataHoje = DateTime(hoje.year, hoje.month, hoje.day);
    final dias = dataItem.difference(dataHoje).inDays;
    if (dias <= 0) return 'Hoje';
    if (dias == 1) return 'Amanha';
    return 'em $dias dias';
  }
}
