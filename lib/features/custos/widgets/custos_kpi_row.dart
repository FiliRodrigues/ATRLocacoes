import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/data/custos_models.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/bento_card.dart';
import '../custos_provider.dart';

class CustosKpiRow extends StatelessWidget {
  const CustosKpiRow({super.key, required this.provider, this.selectedMonth, this.allTime = false, this.veiculoPlaca});

  final CustosProvider provider;
  final DateTime? selectedMonth;
  final bool allTime;
  final String? veiculoPlaca;

  static final _brl = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
  static final _mesFmt = DateFormat('MMM/yy', 'pt_BR');

  List<ManutencaoItem> _filtrar(List<ManutencaoItem> lista) {
    if (veiculoPlaca == null) return lista;
    return lista.where((m) => m.veiculoPlaca == veiculoPlaca).toList();
  }

  double _totalFiltrado({DateTime? mes}) {
    final manut = _filtrar(provider.concluidos);
    if (mes != null) {
      return manut.where((m) => m.data.year == mes.year && m.data.month == mes.month).fold(0.0, (s, m) => s + m.custo);
    }
    return manut.fold(0.0, (s, m) => s + m.custo);
  }

  @override
  Widget build(BuildContext context) {
    final mes = selectedMonth ?? DateTime.now();
    final total = allTime ? _totalFiltrado() : _totalFiltrado(mes: selectedMonth);
    final pendentes = _filtrar(provider.pendentes);
    final emOficina = _filtrar(provider.emOficina);
    final abertas = pendentes.length + emOficina.length;
    final cpk = provider.cpkGlobal;

    ManutencaoItem? proxima;
    if (veiculoPlaca != null) {
      final pends = provider.pendentes.where((m) => m.veiculoPlaca == veiculoPlaca).toList()
        ..sort((a, b) => a.data.compareTo(b.data));
      proxima = pends.isNotEmpty ? pends.first : null;
    } else {
      proxima = provider.proximaManutencao;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        double itemWidth = (w - 36) / 4;
        if (w < 900) itemWidth = (w - 12) / 2;
        if (w < 500) itemWidth = w;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(
              width: itemWidth,
              child: _Kpi(
                title: allTime ? 'CUSTO · TOTAL' : 'CUSTO · ${_mesFmt.format(mes).toUpperCase()}',
                value: _brl.format(total),
                sub: allTime ? 'histórico completo' : 'manutenções concluídas',
                color: AppColors.statusError,
                icon: LucideIcons.trendingDown,
              ),
            ),
            SizedBox(
              width: itemWidth,
              child: _Kpi(
                title: 'OS EM ABERTO',
                value: '$abertas',
                sub: '${pendentes.length} pendente · ${emOficina.length} em oficina',
                color: AppColors.atrOrange,
                icon: LucideIcons.wrench,
              ),
            ),
            SizedBox(
              width: itemWidth,
              child: _Kpi(
                title: 'CPK MÉDIO',
                value: '${_brl.format(cpk)}/km',
                sub: 'custo por quilômetro rodado',
                color: AppColors.statusInfo,
                icon: LucideIcons.gauge,
              ),
            ),
            SizedBox(
              width: itemWidth,
              child: _Kpi(
                title: 'PRÓXIMA OS',
                value: proxima != null ? proxima.veiculoNome : '—',
                sub: _buildSubtituloProxima(proxima),
                color: AppColors.textPrimaryDark,
                icon: LucideIcons.calendarClock,
              ),
            ),
          ],
        );
      },
    );
  }

  String _buildSubtituloProxima(ManutencaoItem? item) {
    if (item == null) return '—';
    final hoje = DateTime.now();
    final dataItem = DateTime(item.data.year, item.data.month, item.data.day);
    final dataHoje = DateTime(hoje.year, hoje.month, hoje.day);
    final dias = dataItem.difference(dataHoje).inDays;
    if (dias <= 0) return 'Hoje';
    if (dias == 1) return 'Amanhã';
    return 'em $dias dias';
  }
}

class _Kpi extends StatelessWidget {
  final String title;
  final String value;
  final String sub;
  final Color color;
  final IconData icon;

  const _Kpi({
    required this.title,
    required this.value,
    required this.sub,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return BentoCard(
      padding: EdgeInsets.zero,
      child: Container(
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: color, width: 3)),
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    title,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondaryDark),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [color.withValues(alpha: 0.2), color.withValues(alpha: 0.08)],
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 13),
                ),
              ],
            ),
            const SizedBox(height: 10),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: color,
                  letterSpacing: -0.3,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              sub,
              style: const TextStyle(fontSize: 10, color: AppColors.textMutedDark),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
