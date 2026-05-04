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
    return BentoCard(
      padding: const EdgeInsets.all(20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondaryLight,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  valor,
                  style: TextStyle(
                    color: corValor,
                    fontSize: tamanhoValor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (subtitulo != null)
                  Text(
                    subtitulo,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondaryLight,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: corIcone.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icone, color: corIcone, size: 20),
          ),
        ],
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
