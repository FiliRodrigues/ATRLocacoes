import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import '../../core/data/fleet_data.dart';
import '../../core/providers/combustivel_provider.dart';
import '../../core/services/relatorio_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_sidebar.dart';
import '../../core/widgets/bento_card.dart';
import '../custos/custos_provider.dart';

// ═══════════════════════════════════════════════════════════════════════
// Tela de Relatórios Exportáveis (PDF)
// ═══════════════════════════════════════════════════════════════════════

class RelatoriosScreen extends StatefulWidget {
  const RelatoriosScreen({super.key});

  @override
  State<RelatoriosScreen> createState() => _RelatoriosScreenState();
}

class _RelatoriosScreenState extends State<RelatoriosScreen> {
  DateTime _de = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _ate = DateTime.now();
  bool _gerando = false;

  static final _brl = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
  static final _dateFmt = DateFormat('dd/MM/yyyy', 'pt_BR');

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final custos = context.watch<CustosProvider>();
    final combustivel = context.watch<CombustivelProvider>();
    final fleet = context.watch<FleetRepository>();

    final data = _buildData(custos, combustivel, fleet);

    return AppSidebar(
      child: Scaffold(
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(32, 32, 32, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(context, isDark),
                const SizedBox(height: 28),
                _buildFiltros(context, isDark),
                const SizedBox(height: 28),
                _buildKpiRow(isDark, data),
                const SizedBox(height: 24),
                _buildTabelaPreview(isDark, data),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Cabeçalho ──────────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Relatórios',
          style: Theme.of(context).textTheme.displayLarge?.copyWith(fontSize: 28),
        ),
        const SizedBox(height: 4),
        Text(
          'Exporte os dados da frota em PDF por período',
          style: TextStyle(
            fontSize: 14,
            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
          ),
        ),
      ],
    );
  }

  // ── Seção de filtros e botão ───────────────────────────────────────

  Widget _buildFiltros(BuildContext context, bool isDark) {
    return BentoCard(
      padding: const EdgeInsets.all(20),
      child: Wrap(
        spacing: 16,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _buildDateChip(context, isDark, label: 'De', date: _de, onPick: (d) {
            setState(() => _de = d);
          }),
          _buildDateChip(context, isDark, label: 'Até', date: _ate, onPick: (d) {
            setState(() => _ate = d);
          }),
          const SizedBox(width: 8),
          SizedBox(
            height: 44,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.atrOrange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20),
              ),
              onPressed: _gerando ? null : () => _onGerar(context),
              icon: _gerando
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(LucideIcons.fileDown, size: 16),
              label: Text(_gerando ? 'Gerando…' : 'Gerar e Baixar PDF'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateChip(
    BuildContext context,
    bool isDark, {
    required String label,
    required DateTime date,
    required void Function(DateTime) onPick,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date,
          firstDate: DateTime(2020),
          lastDate: DateTime.now(),
        );
        if (picked != null) onPick(picked);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isDark
                ? AppColors.borderDark
                : AppColors.borderLight,
          ),
          color: isDark
              ? AppColors.surfaceElevatedDark
              : AppColors.surfaceElevatedLight,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$label: ',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
              ),
            ),
            Text(
              _dateFmt.format(date),
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
            const SizedBox(width: 6),
            Icon(LucideIcons.calendar, size: 14,
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
          ],
        ),
      ),
    );
  }

  // ── KPI preview ────────────────────────────────────────────────────

  Widget _buildKpiRow(bool isDark, RelatorioFrotaData data) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _KpiCard(label: 'Manutenção', value: _brl.format(data.totalManutencao), color: AppColors.statusError, icon: LucideIcons.wrench),
        _KpiCard(label: 'Despesas', value: _brl.format(data.totalDespesas), color: AppColors.statusWarning, icon: LucideIcons.receipt),
        _KpiCard(label: 'Combustível', value: _brl.format(data.totalCombustivel), color: AppColors.atrOrange, icon: LucideIcons.fuel),
        _KpiCard(label: 'Total Geral', value: _brl.format(data.totalGeral), color: AppColors.statusInfo, icon: LucideIcons.circleDollarSign),
      ],
    );
  }

  // ── Tabela preview ─────────────────────────────────────────────────

  Widget _buildTabelaPreview(bool isDark, RelatorioFrotaData data) {
    if (data.veiculos.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              Icon(LucideIcons.fileSearch, size: 40,
                  color: isDark ? Colors.white24 : Colors.black26),
              const SizedBox(height: 12),
              Text(
                'Nenhum dado no período selecionado',
                style: TextStyle(
                  color: isDark ? Colors.white54 : Colors.black54,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return BentoCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Text(
              'Resumo por Veículo (${data.veiculos.length})',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 14,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowHeight: 40,
              dataRowMinHeight: 36,
              dataRowMaxHeight: 44,
              columnSpacing: 24,
              headingTextStyle: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 12,
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
              ),
              columns: const [
                DataColumn(label: Text('Veículo')),
                DataColumn(label: Text('Placa')),
                DataColumn(label: Text('Manutenção'), numeric: true),
                DataColumn(label: Text('Despesas'), numeric: true),
                DataColumn(label: Text('Combustível'), numeric: true),
                DataColumn(label: Text('Total'), numeric: true),
                DataColumn(label: Text('km/l'), numeric: true),
              ],
              rows: data.veiculos.map((v) {
                return DataRow(cells: [
                  DataCell(Text(v.nome, style: const TextStyle(fontWeight: FontWeight.w600))),
                  DataCell(Text(v.placa)),
                  DataCell(Text(_brl.format(v.custoManutencao))),
                  DataCell(Text(_brl.format(v.custoDespesas))),
                  DataCell(Text(_brl.format(v.custoCombustivel))),
                  DataCell(Text(
                    _brl.format(v.totalVeiculo),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  )),
                  DataCell(Text(v.kmMedia > 0 ? v.kmMedia.toStringAsFixed(1) : '—')),
                ]);
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  // ── Lógica de dados ────────────────────────────────────────────────

  RelatorioFrotaData _buildData(
    CustosProvider custos,
    CombustivelProvider combustivel,
    FleetRepository fleet,
  ) {
    final deInicio = DateTime(_de.year, _de.month, _de.day);
    final ateFim = DateTime(_ate.year, _ate.month, _ate.day, 23, 59, 59);

    bool noPeriodo(DateTime d) =>
        !d.isBefore(deInicio) && !d.isAfter(ateFim);

    // Manutenções
    final manutencoes = [
      ...custos.pendentes,
      ...custos.emOficina,
      ...custos.concluidos,
    ].where((m) => noPeriodo(m.data)).toList();

    // Despesas
    final despesas = custos.despesas.where((d) => noPeriodo(d.data)).toList();

    // Abastecimentos
    final abastecimentos = combustivel.abastecimentos
        .where((a) => noPeriodo(a.data))
        .toList();

    // KPIs por veículo (para km/l)
    final kpisCombustivel = combustivel.kpisPorVeiculo(fleet);

    // Agrupar por placa
    final Map<String, _AgregadoVeiculo> map = {};

    for (final v in fleet.frota) {
      map[v.placa] = _AgregadoVeiculo(placa: v.placa, nome: v.nome);
    }

    for (final m in manutencoes) {
      map.putIfAbsent(m.veiculoPlaca, () => _AgregadoVeiculo(placa: m.veiculoPlaca, nome: m.veiculoPlaca));
      map[m.veiculoPlaca]!.custoManutencao += m.custo;
    }

    for (final d in despesas) {
      map.putIfAbsent(d.veiculoPlaca, () => _AgregadoVeiculo(placa: d.veiculoPlaca, nome: d.veiculoPlaca));
      map[d.veiculoPlaca]!.custoDespesas += d.valor;
    }

    for (final a in abastecimentos) {
      map.putIfAbsent(a.veiculoPlaca, () => _AgregadoVeiculo(placa: a.veiculoPlaca, nome: a.veiculoPlaca));
      map[a.veiculoPlaca]!.custoCombustivel += a.valorTotal;
      map[a.veiculoPlaca]!.abastecimentos++;
    }

    final veiculos = map.values
        .where((v) => v.total > 0)
        .map((v) {
          final kpi = kpisCombustivel
              .where((k) => k.veiculoPlaca == v.placa)
              .firstOrNull;
          return RelatorioVeiculoRow(
            placa: v.placa,
            nome: v.nome,
            custoManutencao: v.custoManutencao,
            custoDespesas: v.custoDespesas,
            custoCombustivel: v.custoCombustivel,
            totalVeiculo: v.total,
            abastecimentos: v.abastecimentos,
            kmMedia: kpi?.kmMedia ?? 0.0,
          );
        })
        .toList()
      ..sort((a, b) => b.totalVeiculo.compareTo(a.totalVeiculo));

    final totalManutencao = manutencoes.fold(0.0, (s, m) => s + m.custo);
    final totalDespesas = despesas.fold(0.0, (s, d) => s + d.valor);
    final totalCombustivel = abastecimentos.fold(0.0, (s, a) => s + a.valorTotal);

    return RelatorioFrotaData(
      de: _de,
      ate: _ate,
      veiculos: veiculos,
      totalManutencao: totalManutencao,
      totalDespesas: totalDespesas,
      totalCombustivel: totalCombustivel,
      totalGeral: totalManutencao + totalDespesas + totalCombustivel,
    );
  }

  // ── Ação gerar PDF ─────────────────────────────────────────────────

  Future<void> _onGerar(BuildContext context) async {
    final custos = context.read<CustosProvider>();
    final combustivel = context.read<CombustivelProvider>();
    final fleet = context.read<FleetRepository>();

    final data = _buildData(custos, combustivel, fleet);

    setState(() => _gerando = true);
    try {
      final bytes = await RelatorioService.gerarRelatorioPDF(data);
      await Printing.layoutPdf(onLayout: (_) async => bytes);
    } finally {
      if (mounted) setState(() => _gerando = false);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────
// Widgets privados
// ─────────────────────────────────────────────────────────────────────

class _KpiCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const _KpiCard({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      width: 180,
      child: BentoCard(
        padding: EdgeInsets.zero,
        child: Container(
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: color, width: 3)),
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.all(16),
          child: Row(
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
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                      ),
                    ),
                    Text(
                      value,
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                        color: color,
                      ),
                      overflow: TextOverflow.ellipsis,
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
}

// ── Helper de agregação (privado ao arquivo) ───────────────────────────

class _AgregadoVeiculo {
  final String placa;
  final String nome;
  double custoManutencao = 0;
  double custoDespesas = 0;
  double custoCombustivel = 0;
  int abastecimentos = 0;

  _AgregadoVeiculo({required this.placa, required this.nome});

  double get total => custoManutencao + custoDespesas + custoCombustivel;
}
