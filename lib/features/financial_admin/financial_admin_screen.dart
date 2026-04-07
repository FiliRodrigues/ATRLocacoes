import 'dart:math';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../core/widgets/app_sidebar.dart';
import '../../core/widgets/bento_card.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/status_badge.dart';
import '../../core/data/fleet_data.dart';

class FinancialAdminScreen extends StatefulWidget {
  final int? vehicleIndex;
  const FinancialAdminScreen({super.key, this.vehicleIndex});

  @override
  State<FinancialAdminScreen> createState() => _FinancialAdminScreenState();
}

class _FinancialAdminScreenState extends State<FinancialAdminScreen> {
  double totalPago = 0, totalRestante = 0, totalManut = 0, totalRecebido = 0, lucroLiquido = 0;

  @override
  void initState() {
    super.initState();
    _calculateTotals();
  }

  void _calculateTotals() {
    final financiados = veiculosFinanciados;
    totalPago = 0; totalRestante = 0; totalManut = 0; totalRecebido = 0;
    for (final v in financiados) {
      final f = v.financiamento!;
      totalPago += f.totalPago + f.valorEntrada;
      totalRestante += f.totalRestante;
      totalRecebido += f.recebimentoMensal * f.parcelasPagas;
    }
    for (final v in frota) { totalManut += v.custoTotalManutencao; }
    lucroLiquido = totalRecebido - totalPago - totalManut;
  }

  @override
  Widget build(BuildContext context) {
    final financiados = veiculosFinanciados;
    return AppSidebar(
      child: Scaffold(
        body: SafeArea(
          child: widget.vehicleIndex == null
            ? _ListView(
                financiados: financiados,
                totalPago: totalPago,
                totalRestante: totalRestante,
                totalManut: totalManut,
                totalRecebido: totalRecebido,
                lucroLiquido: lucroLiquido,
              )
            : _DetailView(veiculo: financiados[widget.vehicleIndex!.clamp(0, financiados.length - 1)]),
        ),
      ),
    );
  }
}

// 
// LISTA
// 

class _ListView extends StatelessWidget {
  final List<VehicleData> financiados;
  final double totalPago;
  final double totalRestante;
  final double totalManut;
  final double totalRecebido;
  final double lucroLiquido;

  const _ListView({
    required this.financiados,
    required this.totalPago,
    required this.totalRestante,
    required this.totalManut,
    required this.totalRecebido,
    required this.lucroLiquido,
  });

  void _showMaintenanceModal(BuildContext context) {
    // Coleta TODAS as manutenções de TODOS os veículos
    final allEvents = <Map<String, dynamic>>[];
    for (final v in frota) {
      for (final m in v.manutencoes) {
        allEvents.add({'veiculo': v.nome, 'placa': v.placa, 'cor': v.cor1, 'evento': m});
      }
    }
    // Ordena por data (mais recente primeiro)
    allEvents.sort((a, b) {
      final ea = a['evento'] as MaintenanceEvent;
      final eb = b['evento'] as MaintenanceEvent;
      return eb.data.compareTo(ea.data);
    });

    showDialog(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Dialog(
          backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700, maxHeight: 600),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Todas as Manutenções da Frota', style: Theme.of(ctx).textTheme.titleLarge),
                      IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(LucideIcons.x, size: 18)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('${allEvents.length} registros - ${frota.length} veículos', style: Theme.of(ctx).textTheme.bodyMedium),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView.builder(
                      itemCount: allEvents.length,
                      itemBuilder: (c, i) {
                        final item = allEvents[i];
                        final m = item['evento'] as MaintenanceEvent;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.surfaceElevatedDark : AppColors.backgroundLight,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(children: [
                            Container(width: 4, height: 36, decoration: BoxDecoration(color: item['cor'] as Color, borderRadius: BorderRadius.circular(2))),
                            const SizedBox(width: 12),
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(m.descricao, style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontSize: 13)),
                              const SizedBox(height: 2),
                              Text('${item['placa']} - ${formatDate(m.data)} - ${formatKm(m.kmNoServico.toDouble())}', style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(fontSize: 11)),
                            ])),
                            Text(formatCurrency(m.custo), style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.statusError)),
                          ]),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: AppColors.statusError.withOpacity(0.08), borderRadius: BorderRadius.circular(12)),
                    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Text('TOTAL MANUTENÇÃO FROTA', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.textSecondaryLight)),
                      Text(formatCurrency(frota.fold(0.0, (s, v) => s + v.custoTotalManutencao)), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.statusError)),
                    ]),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: LayoutBuilder(builder: (context, constraints) {
        final width = constraints.maxWidth;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Flexible(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Adm Financeiro', style: Theme.of(context).textTheme.displayLarge?.copyWith(fontSize: 28)),
                const SizedBox(height: 4),
                Text('Financiamentos, receitas e manutenção da frota.', style: Theme.of(context).textTheme.bodyMedium),
              ])),
            ]),
            const SizedBox(height: 32),

            // KPIs  todos clicáveis/flutuantes
            Wrap(spacing: 12, runSpacing: 12, children: [
              _kpi(context, 'Financiados', '${financiados.length}', 'em andamento', LucideIcons.car, AppColors.statusInfo, 0, width),
              _kpi(context, 'Total Pago', formatCurrency(totalPago), 'entrada + parcelas', LucideIcons.checkCircle, AppColors.statusSuccess, 80, width),
              _kpi(context, 'Falta Pagar', formatCurrency(totalRestante), 'parcelas restantes', LucideIcons.clock, AppColors.statusWarning, 160, width),
              _kpiClickable(context, 'Manutenção Frota', formatCurrency(totalManut), '${frota.length} veículos', LucideIcons.wrench, AppColors.statusError, 240, width),
              _kpi(context, 'Total Recebido', formatCurrency(totalRecebido), 'desde início das locações', LucideIcons.wallet, AppColors.statusInfo, 320, width),
              _kpi(context, lucroLiquido >= 0 ? 'Lucro Líquido' : 'Prejuízo', formatCurrency(lucroLiquido), 'recebido - parcelas - manutenção', lucroLiquido >= 0 ? LucideIcons.trendingUp : LucideIcons.trendingDown, lucroLiquido >= 0 ? AppColors.statusSuccess : AppColors.statusError, 400, width),
            ]),
            const SizedBox(height: 32),

          Text('Veículos Financiados', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: financiados.asMap().entries.map((e) {
              double itemWidth = (width - ((4 - 1) * 16)) / 4;
              if (width < 1200) itemWidth = (width - 16) / 3;
              if (width < 900) itemWidth = (width - 16) / 2;
              if (width < 600) itemWidth = width;
              return SizedBox(width: itemWidth, child: _vehicleCard(context, e.value, e.key, isDark));
            }).toList(),
          ),
          const SizedBox(height: 32),
          _maintenanceTable(context, isDark),
        ],
      );
      }),
    );
  }

  Widget _kpi(BuildContext ctx, String title, String value, String sub, IconData icon, Color color, int delay, double width) {
    double itemWidth = (width - 80) / 6;
    if (width < 1300) itemWidth = (width - 80) / 4;
    if (width < 900) itemWidth = (width - 40) / 3;
    if (width < 700) itemWidth = (width - 20) / 2;
    if (width < 450) itemWidth = width;

    final isDark = Theme.of(ctx).brightness == Brightness.dark;

    return SizedBox(width: itemWidth, child: BentoCard(animationDelay: delay, padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Flexible(child: Text(title, style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(fontSize: 10, color: isDark ? Colors.white70 : Colors.black87), overflow: TextOverflow.ellipsis)),
        Container(padding: const EdgeInsets.all(4), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(6)), child: Icon(icon, color: color, size: 12)),
      ]),
      const SizedBox(height: 8),
      FittedBox(fit: BoxFit.scaleDown, child: Text(value, style: Theme.of(ctx).textTheme.displayLarge?.copyWith(fontSize: 16, color: color, fontWeight: FontWeight.bold))),
      const SizedBox(height: 2),
      Text(sub, style: Theme.of(ctx).textTheme.bodySmall?.copyWith(fontSize: 9, color: isDark ? Colors.white38 : Colors.black45), overflow: TextOverflow.ellipsis, maxLines: 1),
    ])));
  }

  Widget _kpiClickable(BuildContext ctx, String title, String value, String sub, IconData icon, Color color, int delay, double width) {
    double itemWidth = (width - 80) / 6;
    if (width < 1300) itemWidth = (width - 80) / 4;
    if (width < 900) itemWidth = (width - 40) / 3;
    if (width < 700) itemWidth = (width - 20) / 2;
    if (width < 450) itemWidth = width;

    final isDark = Theme.of(ctx).brightness == Brightness.dark;

    return SizedBox(width: itemWidth, child: BentoCard(animationDelay: delay, padding: const EdgeInsets.all(12), onTap: () => _showMaintenanceModal(ctx), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Flexible(child: Text(title, style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(fontSize: 10, color: isDark ? Colors.white70 : Colors.black87), overflow: TextOverflow.ellipsis)),
        Container(padding: const EdgeInsets.all(4), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(6)), child: Icon(icon, color: color, size: 12)),
      ]),
      const SizedBox(height: 8),
      FittedBox(fit: BoxFit.scaleDown, child: Text(value, style: Theme.of(ctx).textTheme.displayLarge?.copyWith(fontSize: 16, color: color, fontWeight: FontWeight.bold))),
      const SizedBox(height: 2),
      Row(children: [
        Flexible(child: Text(sub, style: Theme.of(ctx).textTheme.bodySmall?.copyWith(fontSize: 9, color: isDark ? Colors.white38 : Colors.black45), overflow: TextOverflow.ellipsis)),
        const SizedBox(width: 4),
        Icon(LucideIcons.externalLink, size: 8, color: color),
      ]),
    ])));
  }

  Widget _vehicleCard(BuildContext ctx, VehicleData v, int index, bool isDark) {
    final f = v.financiamento!;
    return BentoCard(
      animationDelay: 300 + (index * 80),
      onTap: () => ctx.go('/financial-admin/$index'),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(gradient: LinearGradient(colors: [v.cor1, v.cor2]), borderRadius: BorderRadius.circular(10)),
                child: const Icon(LucideIcons.car, color: Colors.white, size: 16),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column( crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(v.placa, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  Text(v.nome, style: TextStyle(fontSize: 10, color: isDark ? Colors.white38 : AppColors.textSecondaryLight), overflow: TextOverflow.ellipsis),
                ]),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Progresso', style: TextStyle(fontSize: 10, color: isDark ? Colors.white70 : Colors.black87)),
              Text('${(f.progressoFinanciamento * 100).toStringAsFixed(0)}%', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: f.progressoFinanciamento > 0.7 ? AppColors.statusSuccess : AppColors.atrOrange)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(
            value: f.progressoFinanciamento, minHeight: 4,
            backgroundColor: isDark ? AppColors.borderDark : AppColors.borderLight,
            valueColor: AlwaysStoppedAnimation(f.progressoFinanciamento > 0.7 ? AppColors.statusSuccess : AppColors.atrOrange),
          )),
          const SizedBox(height: 16),
          _rowInfo('Parcela', formatCurrency(f.valorParcela), AppColors.statusError),
          const SizedBox(height: 4),
          _rowInfo('Manut.', formatCurrency(v.custoTotalManutencao), AppColors.statusWarning),
        ],
      ),
    );
  }

  Widget _rowInfo(String l, String v, Color c) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(l, style: const TextStyle(fontSize: 10, color: AppColors.textSecondaryLight)),
      Text(v, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: c)),
    ],
  );

  Widget _vehicleRow(BuildContext ctx, VehicleData v, int index, bool isDark) {
    final f = v.financiamento!;
    return BentoCard(
      animationDelay: 300 + (index * 80),
      onTap: () => ctx.go('/financial-admin/$index'),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(gradient: LinearGradient(colors: [v.cor1, v.cor2]), borderRadius: BorderRadius.circular(16)),
          child: const Icon(LucideIcons.car, color: Colors.white, size: 24),
        ),
        const SizedBox(width: 20),
        Expanded(flex: 3, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(v.nome, style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontSize: 16)),
          const SizedBox(height: 4),
          Row(children: [
            Text(v.placa, style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600, fontSize: 12)),
            const SizedBox(width: 12),
            Container(width: 1, height: 14, color: AppColors.textSecondaryLight.withOpacity(0.3)),
            const SizedBox(width: 12),
            Icon(LucideIcons.user, size: 12, color: AppColors.textSecondaryLight),
            const SizedBox(width: 4),
            Flexible(child: Text(v.motorista, style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(fontSize: 12))),
          ]),
        ])),
        Expanded(flex: 2, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${f.parcelasPagas}/${f.totalParcelas} parcelas', style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700, fontSize: 13)),
          const SizedBox(height: 6),
          ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(
            value: f.progressoFinanciamento, minHeight: 5,
            backgroundColor: isDark ? AppColors.borderDark : AppColors.borderLight,
            valueColor: AlwaysStoppedAnimation(f.progressoFinanciamento > 0.7 ? AppColors.statusSuccess : AppColors.atrOrange),
          )),
        ])),
        const SizedBox(width: 20),
        Expanded(flex: 2, child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('Parcela', style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(fontSize: 11)),
          Text(formatCurrency(f.valorParcela), style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.statusError)),
        ])),
        const SizedBox(width: 20),
        Expanded(flex: 2, child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('Manutenção', style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(fontSize: 11)),
          Text(formatCurrency(v.custoTotalManutencao), style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.statusWarning)),
        ])),
        const SizedBox(width: 16),
        StatusBadge(text: '${(f.progressoFinanciamento * 100).toStringAsFixed(0)}%', type: f.progressoFinanciamento > 0.7 ? BadgeType.success : BadgeType.info),
        const SizedBox(width: 8),
        Icon(LucideIcons.chevronRight, size: 18, color: AppColors.textSecondaryLight),
      ]),
    );
  }

  Widget _maintenanceTable(BuildContext ctx, bool isDark) {
    final all = <Map<String, dynamic>>[];
    for (final v in frota) {
      all.add({'nome': v.nome, 'placa': v.placa, 'motorista': v.motorista, 'km': v.kmAtual, 'rev': v.totalRevisoes, 'custoRev': v.manutencoes.isEmpty ? 0.0 : v.manutencoes.map((m) => m.custo).reduce((a, b) => a + b) / v.manutencoes.length, 'total': v.custoTotalManutencao, 'fin': v.isFinanciado, 'cor': v.cor1});
    }
    final totalManut = all.fold<double>(0, (s, v) => s + (v['total'] as double));
    final totalRev = all.fold<int>(0, (s, v) => s + (v['rev'] as int));

    return BentoCard(
      animationDelay: 500,
      padding: EdgeInsets.zero,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(padding: const EdgeInsets.fromLTRB(24, 24, 24, 0), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Manutenção - Frota Completa', style: Theme.of(ctx).textTheme.titleLarge),
          Text('Revisão a cada 10.000 km', style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600, color: AppColors.atrOrange)),
        ])),
        const SizedBox(height: 16),
        // Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
          color: isDark ? AppColors.surfaceElevatedDark : AppColors.backgroundLight,
          child: Row(children: [
            Expanded(flex: 3, child: Text('VEÍCULO', style: _hs())),
            Expanded(flex: 2, child: Text('MOTORISTA', style: _hs())),
            Expanded(flex: 2, child: Text('KM RODADOS', style: _hs(), textAlign: TextAlign.right)),
            Expanded(flex: 1, child: Text('REV.', style: _hs(), textAlign: TextAlign.center)),
            Expanded(flex: 2, child: Text('CUSTO MÉD.', style: _hs(), textAlign: TextAlign.right)),
            Expanded(flex: 2, child: Text('TOTAL', style: _hs(), textAlign: TextAlign.right)),
            Expanded(flex: 1, child: Text('TIPO', style: _hs(), textAlign: TextAlign.center)),
          ]),
        ),
        ...all.map((v) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: isDark ? AppColors.borderDark : AppColors.borderLight, width: 0.5))),
          child: Row(children: [
            Expanded(flex: 3, child: Row(children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: v['cor'] as Color)),
              const SizedBox(width: 10),
              Flexible(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(v['nome'] as String, style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontSize: 13)),
                Text(v['placa'] as String, style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(fontSize: 11)),
              ])),
            ])),
            Expanded(flex: 2, child: Text(v['motorista'] as String, style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(fontSize: 12))),
            Expanded(flex: 2, child: Text(formatKm(v['km'] as double), style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontSize: 12, fontWeight: FontWeight.w700), textAlign: TextAlign.right)),
            Expanded(flex: 1, child: Text('${v['rev']}x', style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontSize: 12, fontWeight: FontWeight.w700), textAlign: TextAlign.center)),
            Expanded(flex: 2, child: Text(formatCurrency(v['custoRev'] as double), style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(fontSize: 12), textAlign: TextAlign.right)),
            Expanded(flex: 2, child: Text(formatCurrency(v['total'] as double), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.statusError), textAlign: TextAlign.right)),
            Expanded(flex: 1, child: Center(child: StatusBadge(text: (v['fin'] as bool) ? 'FINANC.' : 'PRÓPRIO', type: (v['fin'] as bool) ? BadgeType.info : BadgeType.success))),
          ]),
        )),
        // Total
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          color: isDark ? AppColors.surfaceElevatedDark : AppColors.backgroundLight,
          child: Row(children: [
            const Expanded(flex: 3, child: SizedBox()),
            const Expanded(flex: 2, child: SizedBox()),
            const Expanded(flex: 2, child: SizedBox()),
            Expanded(flex: 1, child: Text('${totalRev}x', style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontSize: 13, fontWeight: FontWeight.w800), textAlign: TextAlign.center)),
            const Expanded(flex: 2, child: SizedBox()),
            Expanded(flex: 2, child: Text(formatCurrency(totalManut), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: AppColors.statusError), textAlign: TextAlign.right)),
            Expanded(flex: 1, child: Center(child: Text('TOTAL', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.textSecondaryLight)))),
          ]),
        ),
      ]),
    );
  }

  TextStyle _hs() => const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.textSecondaryLight, letterSpacing: 0.5);
}

// 
// DETALHE DO VEÍCULO
// 

class _DetailView extends StatefulWidget {
  final VehicleData veiculo;
  const _DetailView({required this.veiculo});

  @override
  State<_DetailView> createState() => _DetailViewState();
}

class _DetailViewState extends State<_DetailView> {
  bool _maintenanceExpanded = false;

  @override
  Widget build(BuildContext context) {
    final v = widget.veiculo;
    final f = v.financiamento!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lucro = f.totalRecebido - f.totalPago - f.valorEntrada - v.custoTotalManutencao;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(context, v, f),
          const SizedBox(height: 32),
          _kpis(context, v, f, lucro),
          const SizedBox(height: 32),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(flex: 3, child: _financingCard(context, v, f, isDark)),
            const SizedBox(width: 24),
            Expanded(flex: 2, child: _progressCard(context, f, isDark)),
          ]),
          const SizedBox(height: 32),
          _maintenanceCard(context, v, isDark),
          const SizedBox(height: 32),
          _installmentTimeline(context, f, isDark),
          const SizedBox(height: 32),
          _revenueBreakdown(context, v, f, lucro, isDark),
        ],
      ),
    );
  }

  Widget _header(BuildContext ctx, VehicleData v, FinancingData f) {
    return Row(children: [
      InkWell(
        onTap: () => ctx.go('/financial-admin'),
        borderRadius: BorderRadius.circular(12),
        child: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Theme.of(ctx).colorScheme.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: Theme.of(ctx).dividerTheme.color!)), child: const Icon(LucideIcons.arrowLeft, size: 18)),
      ),
      const SizedBox(width: 16),
      Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(gradient: LinearGradient(colors: [v.cor1, v.cor2]), borderRadius: BorderRadius.circular(12)), child: const Icon(LucideIcons.car, color: Colors.white, size: 22)),
      const SizedBox(width: 16),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Flexible(child: Text(v.nome, style: Theme.of(ctx).textTheme.displayLarge?.copyWith(fontSize: 22))),
          const SizedBox(width: 12),
          Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: Theme.of(ctx).colorScheme.surface, borderRadius: BorderRadius.circular(8), border: Border.all(color: Theme.of(ctx).dividerTheme.color!)), child: Text(v.placa, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, letterSpacing: 1))),
        ]),
        const SizedBox(height: 4),
        Row(children: [
          Icon(LucideIcons.user, size: 13, color: AppColors.textSecondaryLight), const SizedBox(width: 4),
          Text(v.motorista, style: Theme.of(ctx).textTheme.bodyMedium),
          const SizedBox(width: 16),
          Icon(LucideIcons.gauge, size: 13, color: AppColors.textSecondaryLight), const SizedBox(width: 4),
          Text(formatKm(v.kmAtual), style: Theme.of(ctx).textTheme.bodyMedium),
        ]),
      ])),
      InkWell(
        onTap: () => ctx.go('/vehicles/${v.placa}'),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(color: AppColors.atrOrange.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.atrOrange.withOpacity(0.2))),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(LucideIcons.car, size: 14, color: AppColors.atrOrange),
            const SizedBox(width: 6),
            Text('Ver Dossiê', style: TextStyle(color: AppColors.atrOrange, fontSize: 12, fontWeight: FontWeight.w700)),
          ]),
        ),
      ),
      const SizedBox(width: 12),
      StatusBadge(text: '${(f.progressoFinanciamento * 100).toStringAsFixed(0)}% QUITADO', type: f.progressoFinanciamento > 0.7 ? BadgeType.success : BadgeType.info),
    ]);
  }

  Widget _kpis(BuildContext ctx, VehicleData v, FinancingData f, double lucro) {
    return Row(children: [
      _kd(ctx, 'Parcelas Pagas', '${f.parcelasPagas}', '/ ${f.totalParcelas}', formatCurrency(f.totalPago), LucideIcons.checkCircle, AppColors.statusSuccess, 0),
      const SizedBox(width: 20),
      _kd(ctx, 'Parcelas Restantes', '${f.parcelasRestantes}', ' parcelas', formatCurrency(f.totalRestante), LucideIcons.clock, AppColors.statusWarning, 80),
      const SizedBox(width: 20),
      _kd(ctx, 'Total Recebido', '', '', formatCurrency(f.totalRecebido), LucideIcons.wallet, AppColors.statusInfo, 160, main: formatCurrency(f.totalRecebido), sub2: '${formatCurrency(f.recebimentoMensal)}/mês'),
      const SizedBox(width: 20),
      _kd(ctx, 'Lucro Líquido', '', '', '', LucideIcons.trendingUp, lucro >= 0 ? AppColors.statusSuccess : AppColors.statusError, 240, main: formatCurrency(lucro), sub2: 'inclui manutenção'),
    ]);
  }

  Widget _kd(BuildContext ctx, String title, String big, String small, String sub, IconData icon, Color color, int delay, {String? main, String? sub2}) {
    return Expanded(child: BentoCard(animationDelay: delay, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Flexible(child: Text(title, style: Theme.of(ctx).textTheme.bodyMedium)),
        Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: Icon(icon, color: color, size: 18)),
      ]),
      const SizedBox(height: 12),
      if (main != null) Text(main, style: Theme.of(ctx).textTheme.displayLarge?.copyWith(fontSize: 24, color: color))
      else RichText(text: TextSpan(children: [
        TextSpan(text: big, style: Theme.of(ctx).textTheme.displayLarge?.copyWith(fontSize: 28, color: color)),
        TextSpan(text: small, style: Theme.of(ctx).textTheme.displayLarge?.copyWith(fontSize: 14, color: AppColors.textSecondaryLight)),
      ])),
      const SizedBox(height: 4),
      Text(sub2 ?? sub, style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
    ])));
  }

  Widget _financingCard(BuildContext ctx, VehicleData v, FinancingData f, bool isDark) {
    return BentoCard(animationDelay: 320, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Detalhes do Financiamento', style: Theme.of(ctx).textTheme.titleLarge),
      const SizedBox(height: 20),
      Container(padding: const EdgeInsets.all(18), decoration: BoxDecoration(color: isDark ? AppColors.surfaceElevatedDark : AppColors.backgroundLight, borderRadius: BorderRadius.circular(14)), child: Column(children: [
        _r(ctx, 'Valor do Veículo', formatCurrency(f.valorTotal), LucideIcons.tag),
        _r(ctx, 'Entrada (${(f.percentualEntrada * 100).toStringAsFixed(0)}%)', formatCurrency(f.valorEntrada), LucideIcons.banknote),
        _r(ctx, 'Valor Financiado', formatCurrency(f.valorFinanciado), LucideIcons.building2),
        Divider(color: isDark ? AppColors.borderDark : AppColors.borderLight, height: 24),
        _r(ctx, 'Juros', '${(f.taxaJurosMensal * 100).toStringAsFixed(1)}% a.m.', LucideIcons.percent, c: AppColors.statusWarning),
        _r(ctx, 'Parcela (Price)', formatCurrency(f.valorParcela), LucideIcons.receipt, c: AppColors.statusError),
        _r(ctx, 'Prazo', '${f.totalParcelas} meses', LucideIcons.calendar),
        _r(ctx, 'Total Juros', formatCurrency(f.totalJuros), LucideIcons.alertTriangle, c: AppColors.statusError),
        _r(ctx, 'Custo Total', formatCurrency(f.custoTotalVeiculo), LucideIcons.calculator),
        Divider(color: isDark ? AppColors.borderDark : AppColors.borderLight, height: 24),
        _r(ctx, 'Alocação', formatCurrency(f.recebimentoMensal), LucideIcons.arrowDownCircle, c: AppColors.statusSuccess),
        _r(ctx, 'Saldo Mensal', formatCurrency(f.saldoMensal), LucideIcons.trendingUp, c: f.saldoMensal >= 0 ? AppColors.statusSuccess : AppColors.statusError),
      ])),
    ]));
  }

  Widget _r(BuildContext ctx, String l, String v, IconData i, {Color? c}) {
    return Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Row(children: [
      Icon(i, size: 14, color: AppColors.textSecondaryLight), const SizedBox(width: 10),
      Expanded(child: Text(l, style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(fontSize: 13))),
      Flexible(child: Text(v, style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700, color: c, fontSize: 13), textAlign: TextAlign.right, overflow: TextOverflow.ellipsis)),
    ]));
  }

  Widget _maintenanceCard(BuildContext ctx, VehicleData v, bool isDark) {
    return BentoCard(
      animationDelay: -1,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        InkWell(
          onTap: () => setState(() => _maintenanceExpanded = !_maintenanceExpanded),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('Custos de Manutenção', style: Theme.of(ctx).textTheme.titleLarge),
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: AppColors.statusWarning.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: Text('${v.totalRevisoes} rev. - ${formatCurrency(v.custoTotalManutencao)}', style: TextStyle(color: AppColors.statusWarning, fontSize: 11, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 8),
              AnimatedRotation(
                turns: _maintenanceExpanded ? 0.5 : 0,
                duration: const Duration(milliseconds: 200),
                child: Icon(LucideIcons.chevronDown, size: 18, color: AppColors.textSecondaryLight),
              ),
            ]),
          ]),
        ),
        const SizedBox(height: 16),
        // Stats
        Row(children: [
          _ms(ctx, LucideIcons.gauge, 'KM Rodados', formatKm(v.kmAtual), AppColors.statusInfo, isDark),
          const SizedBox(width: 16),
          _ms(ctx, LucideIcons.wrench, 'Revisões', '${v.totalRevisoes} realizadas', AppColors.atrOrange, isDark),
          const SizedBox(width: 16),
          _ms(ctx, LucideIcons.calendarClock, 'Próxima em', formatKm(10000 - (v.kmAtual % 10000)), AppColors.statusSuccess, isDark),
        ]),
        // Expandable history
        AnimatedCrossFade(
          firstChild: const SizedBox.shrink(),
          secondChild: Column(children: [
            const SizedBox(height: 20),
            ...v.manutencoes.reversed.map((m) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: isDark ? AppColors.surfaceElevatedDark : AppColors.backgroundLight, borderRadius: BorderRadius.circular(12)),
              child: Row(children: [
                Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: AppColors.atrOrange.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: const Icon(LucideIcons.wrench, size: 14, color: AppColors.atrOrange)),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(m.descricao, style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontSize: 12)),
                  const SizedBox(height: 2),
                  Text('${formatDate(m.data)} - ${m.kmNoServico.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (mt) => '${mt[1]}.')} km', style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(fontSize: 11)),
                ])),
                Text(formatCurrency(m.custo), style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.statusError)),
              ]),
            )),
          ]),
          crossFadeState: _maintenanceExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 300),
        ),
      ]),
    );
  }

  Widget _ms(BuildContext ctx, IconData icon, String label, String value, Color color, bool isDark) {
    return Expanded(child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: isDark ? AppColors.surfaceElevatedDark : AppColors.backgroundLight, borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: Icon(icon, size: 16, color: color)),
        const SizedBox(width: 10),
        Expanded(child: Text(label, style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(fontSize: 12))),
        Flexible(child: Text(value, style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontSize: 12, fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis)),
      ]),
    ));
  }

  Widget _progressCard(BuildContext ctx, FinancingData f, bool isDark) {
    return BentoCard(animationDelay: 400, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Progresso', style: Theme.of(ctx).textTheme.titleLarge),
      const SizedBox(height: 24),
      Center(child: SizedBox(width: 180, height: 180, child: CustomPaint(
        painter: _RingPainter(progress: f.progressoFinanciamento, bg: isDark ? AppColors.borderDark : AppColors.borderLight, fg: f.progressoFinanciamento > 0.7 ? AppColors.statusSuccess : AppColors.atrOrange),
        child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('${(f.progressoFinanciamento * 100).toStringAsFixed(1)}%', style: Theme.of(ctx).textTheme.displayLarge?.copyWith(fontSize: 32, color: f.progressoFinanciamento > 0.7 ? AppColors.statusSuccess : AppColors.atrOrange)),
          Text('quitado', style: Theme.of(ctx).textTheme.bodyMedium),
        ])),
      ))),
      const SizedBox(height: 24),
      Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: isDark ? AppColors.surfaceElevatedDark : AppColors.backgroundLight, borderRadius: BorderRadius.circular(12)), child: Column(children: [
        _mini(ctx, 'Restam', '${f.parcelasRestantes} meses', LucideIcons.hourglass),
        const SizedBox(height: 10),
        _mini(ctx, 'Quitação', f.previsaoQuitacao, LucideIcons.calendarCheck),
        const SizedBox(height: 10),
        _mini(ctx, 'Falta', formatCurrency(f.totalRestante), LucideIcons.alertCircle),
      ])),
    ]));
  }

  Widget _mini(BuildContext ctx, String l, String v, IconData i) => Row(children: [
    Container(padding: const EdgeInsets.all(5), decoration: BoxDecoration(color: AppColors.atrOrange.withOpacity(0.1), borderRadius: BorderRadius.circular(6)), child: Icon(i, size: 12, color: AppColors.atrOrange)),
    const SizedBox(width: 8),
    Expanded(child: Text(l, style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(fontSize: 11))),
    Flexible(child: Text(v, style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontSize: 12, fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis)),
  ]);

  Widget _installmentTimeline(BuildContext ctx, FinancingData f, bool isDark) {
    return BentoCard(animationDelay: -1, padding: EdgeInsets.zero, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(padding: const EdgeInsets.fromLTRB(24, 24, 24, 0), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text('Parcelas', style: Theme.of(ctx).textTheme.titleLarge),
        Row(children: [_lg(AppColors.statusSuccess, 'Paga'), const SizedBox(width: 14), _lg(AppColors.atrOrange, 'Atual'), const SizedBox(width: 14), _lg(AppColors.textSecondaryLight.withOpacity(0.3), 'Futura')]),
      ])),
      const SizedBox(height: 14),
      Padding(padding: const EdgeInsets.fromLTRB(24, 0, 24, 24), child: Wrap(spacing: 5, runSpacing: 5, children: List.generate(f.totalParcelas, (i) {
        final n = i + 1;
        final paid = n <= f.parcelasPagas;
        final curr = n == f.parcelasPagas + 1;
        Color bg, txt; Border? b;
        if (paid) { bg = AppColors.statusSuccess.withOpacity(0.15); txt = AppColors.statusSuccess; }
        else if (curr) { bg = AppColors.atrOrange.withOpacity(0.2); txt = AppColors.atrOrange; b = Border.all(color: AppColors.atrOrange, width: 2); }
        else { bg = isDark ? AppColors.surfaceElevatedDark : AppColors.backgroundLight; txt = AppColors.textSecondaryLight.withOpacity(0.4); }
        return Tooltip(
          message: paid ? 'Parcela $n - PAGA' : curr ? 'Parcela $n - ATUAL' : 'Parcela $n - PENDENTE',
          child: Container(width: 48, height: 36, alignment: Alignment.center, decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8), border: b),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (paid) Icon(LucideIcons.check, size: 9, color: txt),
              if (paid) const SizedBox(width: 2),
              Text('$n', style: TextStyle(fontSize: 10, fontWeight: curr ? FontWeight.w800 : FontWeight.w600, color: txt)),
            ]),
          ),
        );
      }))),
    ]));
  }

  Widget _lg(Color c, String t) => Row(mainAxisSize: MainAxisSize.min, children: [Container(width: 8, height: 8, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(3))), const SizedBox(width: 5), Text(t, style: TextStyle(color: AppColors.textSecondaryLight, fontSize: 11, fontWeight: FontWeight.w600))]);

  Widget _revenueBreakdown(BuildContext ctx, VehicleData v, FinancingData f, double lucro, bool isDark) {
    return BentoCard(animationDelay: -1, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Resumo Consolidado', style: Theme.of(ctx).textTheme.titleLarge),
      const SizedBox(height: 20),
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: _fb(ctx, isDark, LucideIcons.arrowDownCircle, AppColors.statusSuccess, 'Receitas', 'Total recebido do locatario ate hoje.\n- Recebidos: recebimentoMensal x parcelasPagas\n- Projecao restante: recebimentoMensal x parcelasRestantes\n- Projecao total: recebimentoMensal x totalParcelas', [
          _FI('Recebidos (${f.parcelasPagas} meses)', formatCurrency(f.totalRecebido), AppColors.statusSuccess),
          _FI('Projeção restante', formatCurrency(f.recebimentoMensal * f.parcelasRestantes), AppColors.statusInfo),
          _FI('Projeção total', formatCurrency(f.recebimentoMensal * f.totalParcelas), AppColors.textSecondaryLight),
        ])),
        const SizedBox(width: 20),
        Expanded(child: _fb(ctx, isDark, LucideIcons.arrowUpCircle, AppColors.statusError, 'Custos', 'Todos os gastos do veiculo.\n- Entrada: valorTotal x percentualEntrada\n- Parcelas pagas: valorParcela x parcelasPagas\n- Restantes: valorParcela x parcelasRestantes\n- Juros total: totalParcelas - valorFinanciado\n- Manutencao: soma de todos os servicos', [
          _FI('Entrada', formatCurrency(f.valorEntrada), AppColors.statusWarning),
          _FI('Parcelas (${f.parcelasPagas}x)', formatCurrency(f.totalPago), AppColors.statusError),
          _FI('Restantes (${f.parcelasRestantes}x)', formatCurrency(f.totalRestante), AppColors.textSecondaryLight),
          _FI('Juros total', formatCurrency(f.totalJuros), AppColors.statusWarning),
          _FI('Manutenção (${v.totalRevisoes} rev.)', formatCurrency(v.custoTotalManutencao), AppColors.statusWarning),
        ])),
        const SizedBox(width: 20),
        Expanded(child: _fb(ctx, isDark, LucideIcons.trendingUp, lucro >= 0 ? AppColors.statusSuccess : AppColors.statusError, 'Balanco', 'Resultado financeiro do veiculo.\n- Saldo mensal: recebimentoMensal - valorParcela\n- Lucro acumulado: recebido - entrada - parcelas - manutencao\n  (negativo no inicio e normal ate recuperar a entrada)\n- Projecao lucro total: recebimento total - custo total - manutencao', [
          _FI('Saldo mensal', formatCurrency(f.saldoMensal), f.saldoMensal >= 0 ? AppColors.statusSuccess : AppColors.statusError),
          _FI('Lucro acumulado', formatCurrency(lucro), lucro >= 0 ? AppColors.statusSuccess : AppColors.statusError),
          _FI('Projeção lucro total', formatCurrency((f.recebimentoMensal * f.totalParcelas) - f.custoTotalVeiculo - v.custoTotalManutencao), AppColors.statusInfo),
        ])),
      ]),
    ]));
  }

  Widget _fb(BuildContext ctx, bool isDark, IconData icon, Color color, String title, String tooltipMsg, List<_FI> items) {
    return Container(padding: const EdgeInsets.all(18), decoration: BoxDecoration(color: isDark ? AppColors.surfaceElevatedDark : AppColors.backgroundLight, borderRadius: BorderRadius.circular(14)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(padding: const EdgeInsets.all(7), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: Icon(icon, size: 16, color: color)),
        const SizedBox(width: 10),
        Flexible(child: Text(title, style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontSize: 13))),
        const SizedBox(width: 6),
        Tooltip(
          message: tooltipMsg,
          preferBelow: false,
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceElevatedDark : const Color(0xFF1E2435),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          textStyle: const TextStyle(color: Colors.white, fontSize: 12, height: 1.6),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Icon(LucideIcons.info, size: 14, color: AppColors.textSecondaryLight.withOpacity(0.6)),
        ),
      ]),
      const SizedBox(height: 16),
      ...items.map((i) => Padding(padding: const EdgeInsets.only(bottom: 12), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Flexible(child: Text(i.l, style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(fontSize: 12))), const SizedBox(width: 6), Text(i.v, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: i.c))]))),
    ]));
  }
}

class _FI { final String l, v; final Color c; _FI(this.l, this.v, this.c); }

class _RingPainter extends CustomPainter {
  final double progress; final Color bg, fg;
  _RingPainter({required this.progress, required this.bg, required this.fg});

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = (size.width - 14) / 2;
    canvas.drawCircle(c, r, Paint()..color = bg..style = PaintingStyle.stroke..strokeWidth = 14..strokeCap = StrokeCap.round);
    canvas.drawArc(Rect.fromCircle(center: c, radius: r), -pi / 2, 2 * pi * progress, false, Paint()..color = fg..style = PaintingStyle.stroke..strokeWidth = 14..strokeCap = StrokeCap.round);
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) => old.progress != progress;
}
