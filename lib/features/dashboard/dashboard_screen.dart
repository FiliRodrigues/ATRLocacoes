import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/widgets/app_sidebar.dart';
import '../../core/widgets/bento_card.dart';
import '../../core/theme/app_colors.dart';
import '../../core/data/fleet_data.dart';
import '../../core/widgets/status_badge.dart';
import '../../core/widgets/bento_shimmer.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _isLoading = true;
  String _selectedMonth = 'Abr/26';

  // State caches para performance
  double lucroMes = 0;
  double receitaReal = 0;
  double parcelasReal = 0;
  double manutencaoMes = 0;

  @override
  void initState() {
    super.initState();
    _updateMetrics();
    _simulateLoading();
  }

  void _updateMetrics() {
    final monthsMap = {'Jan': 1, 'Fev': 2, 'Mar': 3, 'Abr': 4};
    final monthNum = monthsMap[_selectedMonth.split('/').first] ?? 4;

    receitaReal = frota.length * 2000.0;
    parcelasReal = veiculosFinanciados.fold(0.0, (s, v) => s + (v.financiamento?.valorParcela ?? 0));
    manutencaoMes = frota.expand((v) => v.manutencoes)
        .where((m) => m.data.month == monthNum && m.data.year == 2026)
        .fold(0.0, (s, m) => s + m.custo);
        
    lucroMes = receitaReal - parcelasReal - manutencaoMes;
  }

  Future<void> _simulateLoading() async {
    await Future.delayed(const Duration(milliseconds: 1200));
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final alerts = frotaAlertas;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final width = MediaQuery.of(context).size.width;
    final isCompact = width < 1100;

    return AppSidebar(
      child: Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: isDark 
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.backgroundDark, AppColors.atrNavyDarker, AppColors.backgroundDark],
                  stops: const [0, 0.5, 1],
                )
              : null,
            color: isDark ? null : AppColors.backgroundLight,
          ),
          child: SafeArea(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator(color: AppColors.atrOrange))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(context),
                      const SizedBox(height: 32),
                      if (alerts.isNotEmpty) ...[
                        _buildCompactAlerts(context, alerts),
                        const SizedBox(height: 24),
                      ],
                      _buildMetricsGrid(context, width, isDark, _selectedMonth),
                      const SizedBox(height: 32),
                      _buildMainChartCard(context, isDark),
                      const SizedBox(height: 32),
                      
                      // Operacional Cards
                      if (isCompact) ...[
                        _buildRevisionCard(context, isDark),
                        const SizedBox(height: 24),
                        _buildInstallmentCard(context, isDark),
                        const SizedBox(height: 24),
                        _buildExpensesCard(context, isDark, _selectedMonth),
                      ] else ...[
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: _buildRevisionCard(context, isDark)),
                            const SizedBox(width: 24),
                            Expanded(child: _buildInstallmentCard(context, isDark)),
                            const SizedBox(width: 24),
                            Expanded(child: _buildExpensesCard(context, isDark, _selectedMonth)),
                          ],
                        ),
                      ],
                      
                      const SizedBox(height: 32),
                      _buildFleetOverview(context, width, isDark),
                    ],
                  ),
                ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState(double width, bool isCompact) {
    return Column(
      children: [
        const BentoShimmer(height: 80, borderRadius: BorderRadius.all(Radius.circular(16))),
        const SizedBox(height: 32),
        Wrap(
          spacing: 24,
          runSpacing: 24,
          children: List.generate(3, (i) {
            double itemWidth = (width - 64 - 48) / 3;
            if (width < 900) itemWidth = (width - 64 - 24) / 2;
            if (width < 600) itemWidth = width - 32;
            return SizedBox(width: itemWidth, child: const BentoCardShimmer());
          }),
        ),
        const SizedBox(height: 32),
        const BentoShimmer(height: 300, borderRadius: BorderRadius.all(Radius.circular(20))),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Wrap(
      spacing: 16,
      runSpacing: 12,
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Visão Geral', style: Theme.of(context).textTheme.displayLarge?.copyWith(fontSize: 28)),
            const SizedBox(height: 4),
            Text('Acompanhe os custos e disponibilidade da sua frota.', style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
        PopupMenuButton<String>(
          onSelected: (val) {
            setState(() {
              _selectedMonth = val;
              _updateMetrics();
            });
          },
          offset: const Offset(0, 45),
          itemBuilder: (ctx) => dadosMensais.where((d) => d.mes.contains('26')).map((d) => PopupMenuItem(value: d.mes, child: Text(d.mes))).toList(),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: Theme.of(context).dividerTheme.color!)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(LucideIcons.calendar, size: 16, color: AppColors.atrOrange),
                const SizedBox(width: 8),
                Text(_selectedMonth, style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(width: 16),
                const Icon(LucideIcons.chevronDown, size: 16),
              ],
            ),
          ),
        )
      ],
    );
  }

  Widget _buildCompactAlerts(BuildContext context, List<AlertItem> alerts) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: alerts.take(3).map((alert) {
        final color = alert.tipo == 'danger' ? AppColors.statusError : (alert.tipo == 'warning' ? AppColors.statusWarning : AppColors.statusInfo);
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(alert.tipo == 'danger' ? LucideIcons.alertOctagon : LucideIcons.alertTriangle, color: color, size: 14),
              const SizedBox(width: 8),
              Text(
                alert.titulo,
                style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11),
              ),
              const SizedBox(width: 6),
              const Text('|', style: TextStyle(color: Colors.white24, fontSize: 11)),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  alert.mensagem.split(' - ').last, // Resume a mensagem
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color.withOpacity(0.9), fontSize: 11),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack).fadeIn();
      }).toList(),
    );
  }

  Widget _buildMetricsGrid(BuildContext context, double width, bool isDark, String selectedMonth) {
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: [
        _buildMetricCard(context, 'Lucro da Operação', formatCurrency(lucroMes), selectedMonth, LucideIcons.trendingUp, AppColors.statusSuccess, 0, width, isDark: isDark, columns: 6),
        _buildMetricCard(context, 'Receita Bruta', formatCurrency(receitaReal), '4 carros alugados', LucideIcons.wallet, AppColors.statusInfo, 100, width, isDark: isDark, columns: 6),
        _buildMetricCard(context, 'Parcelas no Mês', formatCurrency(parcelasReal), '2 carros financ.', LucideIcons.landmark, AppColors.statusError, 200, width, isDark: isDark, columns: 6),
        _buildMetricCard(context, 'Manut. no Mês', formatCurrency(manutencaoMes), 'Serviços em $selectedMonth', LucideIcons.wrench, AppColors.statusWarning, 300, width, isDark: isDark, columns: 6),
        _buildMetricCard(context, 'Carros ativos', '4', 'Disponibilidade 100%', LucideIcons.checkCircle, AppColors.statusSuccess, 400, width, isDark: isDark, columns: 6),
        _buildMetricCard(context, 'Financiados', '${veiculosFinanciados.length}', 'De 4 totais', LucideIcons.fileText, AppColors.atrOrange, 500, width, isDark: isDark, columns: 6),
      ],
    );
  }

  Widget _buildMetricCard(BuildContext context, String title, String value, String subtitle, IconData icon, Color color, int delay, double width, {required bool isDark, int columns = 3}) {
    double itemWidth = (width - 64 - ((columns - 1) * 16)) / columns;
    if (width < 1200) itemWidth = (width - 64 - 16) / 3;
    if (width < 900) itemWidth = (width - 64 - 16) / 2;
    if (width < 600) itemWidth = width - 32;

    return SizedBox(
      width: itemWidth,
      child: BentoCard(
        animationDelay: delay,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(child: Text(title, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 12, color: isDark ? Colors.white70 : Colors.black87), overflow: TextOverflow.ellipsis)),
                Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: Icon(icon, color: color, size: 16)),
              ],
            ),
            const SizedBox(height: 12),
            FittedBox(fit: BoxFit.scaleDown, child: Text(value, style: Theme.of(context).textTheme.displayLarge?.copyWith(fontSize: 22, color: color, fontWeight: FontWeight.bold))),
            const SizedBox(height: 6),
            Text(subtitle, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 10, color: isDark ? Colors.white38 : Colors.black45)),
          ],
        ),
      ),
    );
  }

  Widget _buildMainChartCard(BuildContext context, bool isDark) {
    final months = dadosMensais.where((d) => d.mes.contains('26')).toList();
    const maxVal = 10000.0;
    
    return BentoCard(
      height: 520,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Evolução 2026', style: Theme.of(context).textTheme.titleLarge),
                  Text('Receita Mensal vs Custos Operacionais', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: isDark ? Colors.white38 : Colors.black45)),
                ],
              ),
              Wrap(
                spacing: 16,
                children: [
                  _chartLegend('Receita Bruta', AppColors.atrOrange),
                  _chartLegend('Custos (Financ. + Manut.)', AppColors.statusError),
                  _chartLegend('Lucro Líquido', AppColors.statusSuccess),
                ],
              ),
            ],
          ),
          const SizedBox(height: 40),
          Expanded(
            child: Stack(
              children: [
                // Grid lines
                Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(4, (i) => Container(height: 1, color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05))),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: months.map((d) {
                      // Calcula valores reais para o gráfico baseando-se na frota para bater com os KPIs
                      final monthsMap = {'Jan': 1, 'Fev': 2, 'Mar': 3, 'Abr': 4};
                      final mNum = monthsMap[d.mes.split('/').first] ?? 4;
                      
                      final rMonth = frota.fold(0.0, (s, v) => s + 2000.0); // 4 * 2000 = 8000
                      final fMonth = veiculosFinanciados.fold(0.0, (s, v) => s + (v.financiamento?.valorParcela ?? 0));
                      final mMonth = frota.expand((v) => v.manutencoes)
                          .where((m) => m.data.month == mNum && m.data.year == 2026)
                          .fold(0.0, (s, m) => s + m.custo);
                      
                      final hRec = (rMonth / maxVal).clamp(0.0, 1.0);
                      final hCusto = ((fMonth + mMonth) / maxVal).clamp(0.0, 1.0);
                      final lMonth = rMonth - fMonth - mMonth;
                      final hLucro = (lMonth / maxVal).clamp(0.0, 1.0);
                      
                      return Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                _bar(hRec, AppColors.atrOrange, rMonth),
                                const SizedBox(width: 4),
                                _bar(hCusto, AppColors.statusError, fMonth + mMonth),
                                const SizedBox(width: 4),
                                _bar(hLucro, AppColors.statusSuccess, lMonth),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Text(d.mes, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : Colors.black87)),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _bar(double factor, Color color, double val) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (factor > 0.05) Text(val > 0 ? 'R\$ ${val.toInt()}' : '', style: TextStyle(fontSize: 8, color: color, fontWeight: FontWeight.w900)),
        const SizedBox(height: 4),
        Container(
          width: 55,
          height: 250 * factor,
          decoration: BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [color, color.withOpacity(0.6)]),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            boxShadow: [BoxShadow(color: color.withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 2))],
          ),
        ).animate().scaleY(begin: 0, end: 1, duration: 600.ms, curve: Curves.easeOutCubic),
      ],
    );
  }

  Widget _chartLegend(String label, Color color) {
    return Row(
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      );
  }

  Widget _buildFleetOverview(BuildContext context, double width, bool isDark) {
    return BentoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
           Text('Resumo da Frota', style: Theme.of(context).textTheme.titleLarge),
           const SizedBox(height: 24),
            if (width > 1100)
              Row(
                children: [
                  for (int i = 0; i < frota.length; i++) ...[
                    Expanded(child: _buildFleetItem(frota[i], isDark)),
                    if (i < frota.length - 1) const SizedBox(width: 16),
                  ]
                ],
              )
            else
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: frota.map((v) {
                  double itemWidth = (width - 64 - 16) / 2;
                  if (width < 600) itemWidth = width - 32;
                  return SizedBox(width: itemWidth, child: _buildFleetItem(v, isDark));
                }).toList(),
              ),
        ],
      ),
    );
  }

  Widget _buildRevisionCard(BuildContext context, bool isDark) {
    final events = proximosEventos;
    final revisions = events.where((e) => e.tipo == 'maintenance').toList();
    return BentoCard(
      height: 300,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(LucideIcons.wrench, color: AppColors.atrOrange, size: 18),
            const SizedBox(width: 10),
            Text('Próximas Revisões', style: Theme.of(context).textTheme.titleMedium),
          ]),
          const SizedBox(height: 20),
          Expanded(child: ListView.separated(
            itemCount: revisions.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (ctx, i) {
              final e = revisions[i];
              return _eventItem(ctx, e.titulo, e.descricao, e.prazo, AppColors.atrOrange, isDark);
            },
          )),
        ],
      ),
    );
  }

  Widget _buildInstallmentCard(BuildContext context, bool isDark) {
    final events = proximosEventos;
    final payments = events.where((e) => e.tipo == 'payment').toList();
    return BentoCard(
      height: 300,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(LucideIcons.landmark, color: AppColors.statusInfo, size: 18),
            const SizedBox(width: 10),
            Text('Próximas Parcelas', style: Theme.of(context).textTheme.titleMedium),
          ]),
          const SizedBox(height: 20),
          Expanded(child: ListView.separated(
            itemCount: payments.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (ctx, i) {
              final e = payments[i];
              return _eventItem(ctx, e.titulo, e.descricao, e.prazo, AppColors.statusInfo, isDark);
            },
          )),
        ],
      ),
    );
  }

  Widget _buildExpensesCard(BuildContext context, bool isDark, String selectedMonth) {
    final monthsMap = {'Jan': 1, 'Fev': 2, 'Mar': 3, 'Abr': 4};
    final monthPart = selectedMonth.split('/').first;
    final monthNum = monthsMap[monthPart] ?? 4;

    final listItems = frota.expand((v) => v.manutencoes.where((m) => m.data.month == monthNum && m.data.year == 2026).map((m) => {'v': v, 'm': m})).toList();

    return BentoCard(
      height: 300,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(LucideIcons.alertCircle, color: AppColors.statusError, size: 18),
            const SizedBox(width: 10),
            Text('Manut. de $selectedMonth', style: Theme.of(context).textTheme.titleMedium),
          ]),
          const SizedBox(height: 20),
          Expanded(child: ListView.separated(
            itemCount: listItems.isEmpty ? 1 : listItems.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (ctx, i) {
              if (listItems.isEmpty) return Text('Nenhuma despesa extra lançada.', style: TextStyle(fontSize: 11, color: isDark ? Colors.white38 : Colors.black45));
              final item = listItems[i];
              final v = item['v'] as VehicleData;
              final m = item['m'] as MaintenanceEvent;
              
              return Row(
                children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(m.descricao, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                    Text('${formatDate(m.data)} - ${v.placa}', style: TextStyle(fontSize: 10, color: isDark ? Colors.white54 : Colors.black54)),
                  ])),
                  Text(formatCurrency(m.custo), style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.statusError, fontSize: 11)),
                ],
              );
            },
          )),
          const Divider(height: 24),
          const Text('+ Lançar despesa', style: TextStyle(color: AppColors.statusInfo, fontSize: 10, fontWeight: FontWeight.bold, decoration: TextDecoration.underline)),
        ],
      ),
    );
  }

  Widget _eventItem(BuildContext context, String title, String desc, String time, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.03), borderRadius: BorderRadius.circular(10)),
      child: Row(
        children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            const SizedBox(height: 2),
            Text(desc, style: TextStyle(fontSize: 10, color: isDark ? Colors.white60 : Colors.black54)),
          ])),
          const SizedBox(width: 10),
          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(6)), child: Text(time, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 9))),
        ],
      ),
    );
  }

  Widget _buildFleetItem(VehicleData v, bool isDark) {
    return BentoCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
      onTap: () => context.go('/vehicles/${v.placa}'),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(gradient: LinearGradient(colors: [v.cor1, v.cor2]), shape: BoxShape.circle, boxShadow: [BoxShadow(color: v.cor1.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))]),
            child: const Icon(LucideIcons.car, color: Colors.white, size: 20),
          ),
          const SizedBox(height: 16),
          Text(v.placa, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
          Text(v.nome, style: TextStyle(fontSize: 10, color: isDark ? Colors.white38 : AppColors.textSecondaryLight), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 12),
          StatusBadge(
            text: v.status, 
            type: v.status == 'EM ROTA' ? BadgeType.success : (v.status == 'EM OFICINA' ? BadgeType.error : BadgeType.warning)
          ),
        ],
      ),
    );
  }
}
