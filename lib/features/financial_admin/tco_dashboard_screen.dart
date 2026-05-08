import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../../core/data/fleet_data.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/atr_page_background.dart';
import '../../core/widgets/atr_top_bar.dart';
import '../../core/widgets/app_sidebar.dart';
import '../../core/widgets/bento_card.dart';

// ═══════════════════════════════════════════════════════════════════════
// TCO Dashboard — Custo Total de Propriedade por Veículo
//
// Métricas calculadas do modelo VehicleData já existente:
//  • custoAquisicao  = valorEntrada + totalPago (parcelas)
//  • custoManutencao = custoTotalManutencao
//  • custoNaoCiclico = custoTotalGastosNaoCiclicos
//  • custoCpk        = custoTotal / kmAtual
//  • receitaTotal    = receitaTotalAcumulada
//  • lucro           = receitaTotal - (custoAquisicao + custoManutencao + custoNaoCiclico)
// ═══════════════════════════════════════════════════════════════════════

enum _TcoSort {
  maisLucro,
  menosLucro,
  maiorCusto,
  menorCpk,
}

class TcoDashboardScreen extends StatefulWidget {
  const TcoDashboardScreen({super.key});

  @override
  State<TcoDashboardScreen> createState() => _TcoDashboardScreenState();
}

class _TcoDashboardScreenState extends State<TcoDashboardScreen> {
  _TcoSort _sort = _TcoSort.menosLucro;

  static final _brl = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final repo = context.watch<FleetRepository>();
    // Não oculta veículos com KM 0 para evitar percepção de dados faltando.
    final frota = repo.frota.where((v) => v.placa.trim().isNotEmpty).toList();

    // Calcula TCO por veículo
    final itens = frota.map((v) => _TcoEntry.from(v)).toList();

    // Ordena
    switch (_sort) {
      case _TcoSort.maisLucro:
        itens.sort((a, b) => b.lucro.compareTo(a.lucro));
        break;
      case _TcoSort.menosLucro:
        itens.sort((a, b) => a.lucro.compareTo(b.lucro));
        break;
      case _TcoSort.maiorCusto:
        itens.sort((a, b) => b.custoTotal.compareTo(a.custoTotal));
        break;
      case _TcoSort.menorCpk:
        itens.sort((a, b) => a.cpk.compareTo(b.cpk));
        break;
    }

    // Totais da frota
    final totalCustoAquisicao =
        itens.fold(0.0, (s, e) => s + e.custoAquisicao);
    final totalManutencao = itens.fold(0.0, (s, e) => s + e.custoManutencao);
    final totalNaoCiclico = itens.fold(0.0, (s, e) => s + e.custoNaoCiclico);
    final totalReceita = itens.fold(0.0, (s, e) => s + e.receita);
    final totalLucro = itens.fold(0.0, (s, e) => s + e.lucro);
    final kmTotal = frota.fold(0.0, (s, v) => s + v.kmAtual);
    final cpkFlota = kmTotal > 0
        ? (totalCustoAquisicao + totalManutencao + totalNaoCiclico) / kmTotal
        : 0.0;

    return AppSidebar(
      child: Scaffold(
        body: AtrPageBackground(
          grid: true,
          child: Column(
            children: [
              const AtrTopBar(
                title: 'TCO — Custo Total de Propriedade',
                subtitle: 'Análise completa de aquisição, manutenção, receita e lucro por veículo',
              ),
              Expanded(
                child: frota.isEmpty
                    ? _buildEmpty(isDark)
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
                        children: [
                          _buildSummary(
                            isDark,
                            totalCustoAquisicao: totalCustoAquisicao,
                            totalManutencao: totalManutencao,
                            totalNaoCiclico: totalNaoCiclico,
                            totalReceita: totalReceita,
                            totalLucro: totalLucro,
                            cpkFrota: cpkFlota,
                            nVeiculos: frota.length,
                          ),
                          const SizedBox(height: 20),
                          _buildSortBar(isDark),
                          const SizedBox(height: 12),
                          ...itens.map(
                            (item) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _VehicleTcoCard(
                                item: item,
                                isDark: isDark,
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummary(
    bool isDark, {
    required double totalCustoAquisicao,
    required double totalManutencao,
    required double totalNaoCiclico,
    required double totalReceita,
    required double totalLucro,
    required double cpkFrota,
    required int nVeiculos,
  }) {
    return BentoCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.layers, size: 16, color: AppColors.atrOrange),
              const SizedBox(width: 8),
              Text(
                'Resumo da Frota — $nVeiculos veículo(s)',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 24,
            runSpacing: 12,
            children: [
              _summaryKpi(
                isDark,
                label: 'Total Aquisição',
                value: _brl.format(totalCustoAquisicao),
                icon: LucideIcons.landmark,
                color: AppColors.statusInfo,
              ),
              _summaryKpi(
                isDark,
                label: 'Total Manutenção',
                value: _brl.format(totalManutencao),
                icon: LucideIcons.wrench,
                color: AppColors.statusWarning,
              ),
              _summaryKpi(
                isDark,
                label: 'Custos Extras',
                value: _brl.format(totalNaoCiclico),
                icon: LucideIcons.receipt,
                color: Colors.purple,
              ),
              _summaryKpi(
                isDark,
                label: 'Receita Total',
                value: _brl.format(totalReceita),
                icon: LucideIcons.trendingUp,
                color: AppColors.statusSuccess,
              ),
              _summaryKpi(
                isDark,
                label: 'Lucro Líquido',
                value: _brl.format(totalLucro),
                icon: LucideIcons.circleDollarSign,
                color: totalLucro >= 0
                    ? AppColors.statusSuccess
                    : AppColors.statusError,
              ),
              _summaryKpi(
                isDark,
                label: 'CPK Médio',
                value: 'R\$ ${cpkFrota.toStringAsFixed(2)}/km',
                icon: LucideIcons.gauge,
                color: AppColors.atrOrange,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryKpi(
    bool isDark, {
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                color.withValues(alpha: 0.2),
                color.withValues(alpha: 0.08),
              ],
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: isDark ? AppColors.textSecondaryDark : Colors.black54,
              ),
            ),
            Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSortBar(bool isDark) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          Text(
            'Ordenar por:',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? AppColors.textSecondaryDark : Colors.black54,
            ),
          ),
          const SizedBox(width: 10),
          ..._TcoSort.values.map((s) {
            final selected = _sort == s;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(_sortLabel(s), style: const TextStyle(fontSize: 12)),
                selected: selected,
                selectedColor: AppColors.atrOrange,
                onSelected: (_) => setState(() => _sort = s),
                labelStyle: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : null,
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  String _sortLabel(_TcoSort s) => switch (s) {
        _TcoSort.maisLucro => 'Mais Lucrativo',
        _TcoSort.menosLucro => 'Menos Lucrativo',
        _TcoSort.maiorCusto => 'Maior Custo',
        _TcoSort.menorCpk => 'Menor CPK',
      };

  Widget _buildEmpty(bool isDark) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.pieChart,
              size: 48, color: isDark ? Colors.white24 : Colors.black26),
          const SizedBox(height: 12),
          Text(
            'Sem dados de frota',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.textSecondaryDark : Colors.black54,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Os veículos aparecerão aqui após carregar do Supabase',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white38 : Colors.black38,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Modelo calculado de TCO por veículo
// ─────────────────────────────────────────────────────────────────────

class _TcoEntry {
  final VehicleData veiculo;
  final double custoAquisicao;
  final double custoManutencao;
  final double custoNaoCiclico;
  final double receita;

  double get custoTotal => custoAquisicao + custoManutencao + custoNaoCiclico;
  double get lucro => receita - custoTotal;
  double get cpk => veiculo.kmAtual > 0 ? custoTotal / veiculo.kmAtual : 0.0;
  double get margemPct =>
      receita > 0 ? (lucro / receita) * 100 : 0.0;

  _TcoEntry._({
    required this.veiculo,
    required this.custoAquisicao,
    required this.custoManutencao,
    required this.custoNaoCiclico,
    required this.receita,
  });

  factory _TcoEntry.from(VehicleData v) {
    final f = v.financiamento;
    final custoAquisicao = f != null
        ? f.valorEntrada + f.totalPago
        : v.valorAquisicao;

    return _TcoEntry._(
      veiculo: v,
      custoAquisicao: custoAquisicao,
      custoManutencao: v.custoTotalManutencao,
      custoNaoCiclico: v.custoTotalGastosNaoCiclicos,
      receita: v.receitaTotalAcumulada,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Card de TCO por veículo
// ─────────────────────────────────────────────────────────────────────

class _VehicleTcoCard extends StatelessWidget {
  final _TcoEntry item;
  final bool isDark;

  const _VehicleTcoCard({required this.item, required this.isDark});

  static final _brl = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
  static final _km = NumberFormat('#,###', 'pt_BR');

  @override
  Widget build(BuildContext context) {
    final v = item.veiculo;
    final lucroPositivo = item.lucro >= 0;
    final lucroColor =
        lucroPositivo ? AppColors.statusSuccess : AppColors.statusError;

    return BentoCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: v.cor1.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(LucideIcons.truck, color: v.cor1, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${v.placa} — ${v.nome}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      '${_km.format(v.kmAtual.toInt())} km rodados · '
                      '${v.mesesEmServico} meses em serviço',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppColors.textSecondaryDark : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              // Lucro badge
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: lucroColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: lucroColor.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _brl.format(item.lucro),
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                        color: lucroColor,
                      ),
                    ),
                    Text(
                      '${item.margemPct.toStringAsFixed(1)}% margem',
                      style: TextStyle(
                        fontSize: 10,
                        color: lucroColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 12),

          // Barras de custo
          _costBar(
            'Aquisição',
            item.custoAquisicao,
            item.custoTotal,
            AppColors.statusInfo,
          ),
          const SizedBox(height: 6),
          _costBar(
            'Manutenção',
            item.custoManutencao,
            item.custoTotal,
            AppColors.statusWarning,
          ),
          const SizedBox(height: 6),
          _costBar(
            'Extras',
            item.custoNaoCiclico,
            item.custoTotal,
            Colors.purple,
          ),
          const SizedBox(height: 12),

          // KPIs compactos
          Wrap(
            spacing: 20,
            runSpacing: 8,
            children: [
              _kpiChip('Custo Total', _brl.format(item.custoTotal),
                  AppColors.statusError),
              _kpiChip(
                  'Receita', _brl.format(item.receita), AppColors.statusSuccess),
              _kpiChip(
                  'CPK',
                  'R\$ ${item.cpk.toStringAsFixed(2)}/km',
                  AppColors.atrOrange),
              _kpiChip('Revisões', '${v.totalRevisoes}', AppColors.statusInfo),
            ],
          ),
          const SizedBox(height: 10),

          // Sugestão de venda
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.04)
                  : Colors.black.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  LucideIcons.lightbulb,
                  size: 14,
                  color: AppColors.atrOrange,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    v.sugestaoVenda,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _costBar(String label, double valor, double total, Color cor) {
    final pct = total > 0 ? (valor / total).clamp(0.0, 1.0) : 0.0;
    return Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: isDark ? AppColors.textSecondaryDark : Colors.black54,
            ),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              backgroundColor:
                  isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.08),
              color: cor,
              minHeight: 6,
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 110,
          child: Text(
            _brl.format(valor),
            textAlign: TextAlign.end,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: cor,
            ),
          ),
        ),
      ],
    );
  }

  Widget _kpiChip(String label, String value, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: isDark ? Colors.white38 : Colors.black38,
              ),
            ),
            Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
