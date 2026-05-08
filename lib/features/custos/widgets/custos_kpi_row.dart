import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/data/custos_models.dart';
import '../../../core/data/fleet_data.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/atr_kpi_card.dart';
import '../custos_provider.dart';

class CustosKpiRow extends StatelessWidget {
  const CustosKpiRow({super.key, required this.provider});

  final CustosProvider provider;

  @override
  Widget build(BuildContext context) {
    final ManutencaoItem? proxima = provider.proximaManutencao;
    final subtituloProxima = _buildSubtituloProxima(proxima);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return LayoutBuilder(
      builder: (context, constraints) {
        final cards = <Widget>[
          AtrKpiCard(
            label: 'Total do Mes',
            value: formatCurrency(provider.totalGeralMes),
            icon: LucideIcons.trendingDown,
            tone: KpiTone.error,
          ),
          AtrKpiCard(
            label: 'OSs em Aberto',
            value: provider.totalOsAbertas.toString(),
            icon: LucideIcons.wrench,
            tone: KpiTone.orange,
          ),
          AtrKpiCard(
            label: 'Custo Medio / Km (CPK)',
            value: '${formatCurrency(provider.cpkGlobal)} / km',
            icon: LucideIcons.gauge,
            tone: KpiTone.info,
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Flexible(
                child: AtrKpiCard(
                  label: 'Proxima Manutencao',
                  value: proxima == null ? 'Nenhuma agendada' : proxima.veiculoNome,
                  icon: LucideIcons.calendarClock,
                  tone: KpiTone.info,
                ),
              ),
              if (subtituloProxima != null)
                Padding(
                  padding: const EdgeInsets.only(left: 8, top: 4),
                  child: Text(
                    subtituloProxima,
                    style: TextStyle(
                      fontSize: 10,
                      color: isDark ? Colors.white38 : AppColors.textSecondaryLight,
                    ),
                  ),
                ),
            ],
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
