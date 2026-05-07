import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../core/widgets/app_sidebar.dart';
import '../../core/widgets/bento_card.dart';
import '../../core/theme/app_colors.dart';
import '../../core/data/fleet_data.dart';
import '../../core/widgets/status_badge.dart';

// Record tipado para itens de despesa, eliminando casts via Map<String, dynamic>.
typedef _ExpenseItem = ({VehicleData v, MaintenanceEvent m});

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String _selectedMonth = (() {
    final now = DateTime.now();
    const m = ['Jan', 'Fev', 'Mar', 'Abr', 'Mai', 'Jun', 'Jul', 'Ago', 'Set', 'Out', 'Nov', 'Dez'];
    return '${m[now.month - 1]}/${(now.year % 100).toString().padLeft(2, '0')}';
  })();

  _Metrics _computeMetrics(FleetRepository repo) {
    const monthsMap = {
      'Jan': 1, 'Fev': 2, 'Mar': 3, 'Abr': 4, 'Mai': 5, 'Jun': 6,
      'Jul': 7, 'Ago': 8, 'Set': 9, 'Out': 10, 'Nov': 11, 'Dez': 12,
    };
    final parts = _selectedMonth.split('/');
    if (parts.length < 2) return const _Metrics();
    final monthNum = monthsMap[parts[0]] ?? DateTime.now().month;
    final yearNum = 2000 + (int.tryParse(parts[1]) ?? 26);

    double receita = 0;
    double parcelas = 0;
    final frota = repo.frota;
    int comFin = 0;
    int comRecMes = 0;
    int comRecReal = 0;
    for (final v in frota) {
      final f = v.financiamento;
      if (f == null) continue;
      comFin++;
      final realDoMes = f.recebidoNoMes(yearNum, monthNum);
      if (realDoMes != null && realDoMes > 0) {
        receita += realDoMes;
        comRecReal++;
      } else if (f.recebimentoMensal > 0) {
        receita += f.recebimentoMensal;
        comRecMes++;
      }
      parcelas += f.valorParcela;
    }
    debugPrint('[DASH] _computeMetrics: frota=${frota.length} comFin=$comFin comRecReal=$comRecReal comRecMes=$comRecMes receita=$receita mes=$_selectedMonth');
    double manutencao = 0;
    for (final v in frota) {
      for (final m in v.manutencoes) {
        if (m.data.month == monthNum && m.data.year == yearNum) {
          manutencao += m.custo;
        }
      }
    }
    return _Metrics(
      receita: receita,
      parcelas: parcelas,
      manutencao: manutencao,
      lucro: receita - parcelas - manutencao,
    );
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<FleetRepository>();
    final metrics = _computeMetrics(repo);
    final alerts = repo.isLoading ? const <AlertItem>[] : repo.frotaAlertas;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final width = MediaQuery.of(context).size.width;
    final isCompact = width < 1100;

    return AppSidebar(
      child: Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: isDark
                ? const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.backgroundDark,
                      AppColors.atrNavyDarker,
                      AppColors.backgroundDark,
                    ],
                    stops: [0, 0.5, 1],
                  )
                : null,
            color: isDark ? null : AppColors.backgroundLight,
          ),
          child: SafeArea(
            child: repo.isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.atrOrange),)
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
                        _buildMetricsGrid(context, width, isDark, metrics),
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

  void _navMonth(int delta) {
    const m = ['Jan', 'Fev', 'Mar', 'Abr', 'Mai', 'Jun', 'Jul', 'Ago', 'Set', 'Out', 'Nov', 'Dez'];
    final parts = _selectedMonth.split('/');
    final mIdx = m.indexOf(parts[0]);
    final ano = int.tryParse(parts.length > 1 ? parts[1] : '26') ?? 26;
    if (mIdx < 0) return;
    final newDate = DateTime(2000 + ano, mIdx + 1 + delta);
    setState(() => _selectedMonth = '${m[newDate.month - 1]}/${(newDate.year % 100).toString().padLeft(2, '0')}');
  }

  Widget _buildHeader(BuildContext context) {
    final parts = _selectedMonth.split('/');
    final selMes = parts[0];
    final selAno = '20${parts.length > 1 ? parts[1] : '26'}';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Wrap(
      spacing: 16,
      runSpacing: 12,
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Visão Geral',
                style: Theme.of(context).textTheme.displayLarge?.copyWith(fontSize: 28)),
            const SizedBox(height: 4),
            Text('Acompanhe os custos e disponibilidade da sua frota.',
                style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _FilterBtn(icon: LucideIcons.chevronLeft, onTap: () => _navMonth(-1)),
              const SizedBox(width: 2),
              _MonthDropdown(value: selMes, onChanged: (m) => setState(() => _selectedMonth = '$m/$selAno')),
              const SizedBox(width: 4),
              _YearDropdown(value: selAno, onChanged: (a) => setState(() => _selectedMonth = '$selMes/${a.substring(2)}')),
              const SizedBox(width: 2),
              _FilterBtn(icon: LucideIcons.chevronRight, onTap: () => _navMonth(1)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCompactAlerts(BuildContext context, List<AlertItem> alerts) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: alerts.take(3).map((alert) {
        final color = alert.tipo == AlertType.danger
            ? AppColors.statusError
            : (alert.tipo == AlertType.warning
                ? AppColors.statusWarning
                : AppColors.statusInfo);
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                  alert.tipo == AlertType.danger
                      ? LucideIcons.alertOctagon
                      : LucideIcons.alertTriangle,
                  color: color,
                  size: 14,),
              const SizedBox(width: 8),
              Text(
                alert.titulo,
                style: TextStyle(
                    color: color, fontWeight: FontWeight.bold, fontSize: 11,),
              ),
              const SizedBox(width: 6),
              const Text('|',
                  style: TextStyle(color: Colors.white24, fontSize: 11),),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  alert.mensagem.split(' - ').last, // Resume a mensagem
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: color.withValues(alpha: 0.9), fontSize: 11,),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack).fadeIn();
      }).toList(),
    );
  }

  Widget _buildMetricsGrid(
      BuildContext context, double width, bool isDark, _Metrics metrics) {
    final repo = context.read<FleetRepository>();
    final totalVeiculos = repo.frota.length;
    final ativos = repo.frota
      .where((v) => v.status != VehicleStatus.emOficina)
      .length;
    final disponibilidade =
        totalVeiculos == 0 ? 0 : ((ativos / totalVeiculos) * 100).round();

    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: [
        _buildMetricCard(
            context,
            'Lucro da Operação',
            formatCurrency(metrics.lucro),
            _selectedMonth,
            LucideIcons.trendingUp,
            AppColors.statusSuccess,
            0,
            width,
            isDark: isDark,
            columns: 6,),
        _buildMetricCard(
            context,
            'Receita Bruta',
            formatCurrency(metrics.receita),
            '${repo.frota.length} carros alugados',
            LucideIcons.wallet,
            AppColors.statusInfo,
            100,
            width,
            isDark: isDark,
            columns: 6,),
        _buildMetricCard(
            context,
            'Parcelas no Mês',
            formatCurrency(metrics.parcelas),
            '${repo.veiculosFinanciados.length} carros financ.',
            LucideIcons.landmark,
            AppColors.statusError,
            200,
            width,
            isDark: isDark,
            columns: 6,),
        _buildMetricCard(
            context,
            'Manut. no Mês',
            formatCurrency(metrics.manutencao),
            'Serviços em $_selectedMonth',
            LucideIcons.wrench,
            AppColors.statusWarning,
            300,
            width,
            isDark: isDark,
            columns: 6,),
        _buildMetricCard(
            context,
            'Carros ativos',
            '$ativos',
            'Disponibilidade $disponibilidade%',
            LucideIcons.checkCircle,
            AppColors.statusSuccess,
            400,
            width,
            isDark: isDark,
            columns: 6,),
        _buildMetricCard(
            context,
            'Financiados',
            '${repo.veiculosFinanciados.length}',
            'De $totalVeiculos totais',
            LucideIcons.fileText,
            AppColors.atrOrange,
            500,
            width,
            isDark: isDark,
            columns: 6,),
      ],
    );
  }

  Widget _buildMetricCard(BuildContext context, String title, String value,
      String subtitle, IconData icon, Color color, int delay, double width,
      {required bool isDark, int columns = 6, VoidCallback? onTap}) {
    double itemWidth = (width - 80) / columns;
    if (width < 1300) itemWidth = (width - 80) / 4;
    if (width < 900) itemWidth = (width - 40) / 3;
    if (width < 700) itemWidth = (width - 20) / 2;
    if (width < 450) itemWidth = width;

    return SizedBox(
      width: itemWidth,
      child: BentoCard(
        animationDelay: delay,
        padding: EdgeInsets.zero,
        onTap: onTap,
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
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          color.withValues(alpha: 0.2),
                          color.withValues(alpha: 0.08),
                        ],
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
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: color,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Flexible(
                    child: Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 10,
                        color: isDark ? Colors.white38 : AppColors.textSecondaryLight,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (onTap != null) ...[
                    const SizedBox(width: 4),
                    Icon(LucideIcons.externalLink, size: 9, color: color),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMainChartCard(BuildContext context, bool isDark) {
    final repo = context.read<FleetRepository>();
    final months = repo.dadosMensais.where((d) => d.mes.contains('26')).toList();
    final maxVal = repo.frota.fold(0.0, (s, v) {
          final f = v.financiamento;
          if (f == null) return s;
          double best = f.recebimentoMensal;
          for (final val in f.recebidoPorMes.values) {
            if (val > best) best = val;
          }
          if (best > 0) return s + best;
          return s;
        }) * 1.25;

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
                  Text('Evolução 2026',
                      style: Theme.of(context).textTheme.titleLarge,),
                  Text('Receita Mensal vs Custos Operacionais',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: isDark ? Colors.white38 : Colors.black45,),),
                ],
              ),
              Flexible(
                child: Wrap(
                  spacing: 16,
                  alignment: WrapAlignment.end,
                  children: [
                    _chartLegend('Receita Bruta', AppColors.atrOrange),
                    _chartLegend(
                        'Custos (Financ. + Manut.)', AppColors.statusError,),
                    _chartLegend('Lucro Líquido', AppColors.statusSuccess),
                  ],
                ),
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
                  children: List.generate(
                      4,
                      (i) => Container(
                          height: 1,
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.05)
                              : Colors.black.withValues(alpha: 0.05),),),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: months.map((d) {
                      const monthsMap = {
                        'Jan': 1, 'Fev': 2, 'Mar': 3, 'Abr': 4,
                        'Mai': 5, 'Jun': 6, 'Jul': 7, 'Ago': 8,
                        'Set': 9, 'Out': 10, 'Nov': 11, 'Dez': 12,
                      };
                      final parts = d.mes.split('/');
                      final mNum = monthsMap[parts[0]] ?? 4;
                      final yNum = 2000 + (int.tryParse(parts[1]) ?? 26);

                        final rMonth = repo.frota.fold(0.0, (s, v) {
                        final f = v.financiamento;
                        if (f == null) return s;
                        final realDoMes = f.recebidoNoMes(yNum, mNum);
                        if (realDoMes != null && realDoMes > 0) return s + realDoMes;
                        if (f.recebimentoMensal > 0) return s + f.recebimentoMensal;
                        return s;
                      });
                        final fMonth = repo.veiculosFinanciados.fold(0.0,
                          (s, v) => s + (v.financiamento?.valorParcela ?? 0),);
                        final mMonth = repo.frota
                          .expand((v) => v.manutencoes)
                          .where((m) =>
                              m.data.month == mNum && m.data.year == yNum,)
                          .fold(0.0, (s, m) => s + m.custo);

                      final hRec = (rMonth / maxVal).clamp(0.0, 1.0);
                      final hCusto =
                          ((fMonth + mMonth) / maxVal).clamp(0.0, 1.0);
                      final lMonth = rMonth - fMonth - mMonth;
                      final hLucro = (lMonth / maxVal).clamp(0.0, 1.0);

                      return Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  _bar(hRec, AppColors.atrOrange, rMonth),
                                  const SizedBox(width: 4),
                                  _bar(hCusto, AppColors.statusError,
                                      fMonth + mMonth,),
                                  const SizedBox(width: 4),
                                  _bar(hLucro, AppColors.statusSuccess, lMonth),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(d.mes,
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: isDark
                                        ? Colors.white70
                                        : Colors.black87,),),
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
        if (factor > 0.05)
          Text(val > 0 ? 'R\$ ${val.toInt()}' : '',
              style: TextStyle(
                  fontSize: 8, color: color, fontWeight: FontWeight.w900,),),
        const SizedBox(height: 4),
        Container(
          width: 55,
          height: 250 * factor,
          decoration: BoxDecoration(
            gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [color, color.withValues(alpha: 0.6)],),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            boxShadow: [
              BoxShadow(
                  color: color.withValues(alpha: 0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 2),),
            ],
          ),
        ).animate().scaleY(
            begin: 0, end: 1, duration: 600.ms, curve: Curves.easeOutCubic,),
      ],
    );
  }

  Widget _chartLegend(String label, Color color) {
    return Row(
      children: [
        Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
                color: color, borderRadius: BorderRadius.circular(2),),),
        const SizedBox(width: 6),
        Text(label,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),),
      ],
    );
  }

  Widget _buildFleetOverview(BuildContext context, double width, bool isDark) {
    final vehicles = context.read<FleetRepository>().frota;
    final grouped = _groupVehiclesByEmpresa(vehicles);
    final sections = <Widget>[];

    sections.add(Text('Resumo da Frota',
        style: Theme.of(context).textTheme.titleLarge,));
    sections.add(const SizedBox(height: 24));

    for (final group in grouped.entries) {
      final sectionTitle = group.key == 'Não Locados'
          ? 'Não Locados'
          : 'Empresa ${group.key}';

      sections.add(
        Text(
          sectionTitle,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
      );
      sections.add(const SizedBox(height: 12));
      sections.add(
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: group.value.asMap().entries.map((entry) {
            double itemWidth = (width - ((4 - 1) * 16)) / 4;
            if (width < 1200) itemWidth = (width - 16) / 3;
            if (width < 900) itemWidth = (width - 16) / 2;
            if (width < 600) itemWidth = width;
            return SizedBox(
              width: itemWidth,
              child: _buildFleetItem(entry.value, isDark),
            );
          }).toList(),
        ),
      );
      sections.add(const SizedBox(height: 24));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: sections,
    );
  }

  String _resolveEmpresaGroup(VehicleData veiculo) {
    final origem = veiculo.motorista.trim().toUpperCase();
    final bool mencionaNew = origem.contains('NEW');
    final bool mencionaTesc = origem.contains('TESC');
    final bool mencionaAtr = origem.contains('ATR');
    final bool mencionaEnsin = origem.contains('ENSIN');

    final bool isLocado =
        origem.contains('LOCADO') ||
        mencionaNew ||
        mencionaTesc ||
        mencionaAtr ||
        mencionaEnsin ||
        veiculo.status == VehicleStatus.reserva;

    if (!isLocado) return 'Não Locados';
    if (mencionaNew && mencionaTesc) return 'New Tesc';
    if (mencionaAtr) return 'ATR';
    if (mencionaEnsin) return 'Ensin';
    if (mencionaNew) return 'New';
    if (mencionaTesc) return 'Tesc';
    return 'Outras Locadoras';
  }

  Map<String, List<VehicleData>> _groupVehiclesByEmpresa(
    List<VehicleData> vehicles,
  ) {
    final grouped = <String, List<VehicleData>>{};
    for (final v in vehicles) {
      final groupKey = _resolveEmpresaGroup(v);
      grouped.putIfAbsent(groupKey, () => <VehicleData>[]).add(v);
    }

    final ordered = <String, List<VehicleData>>{};
    const orderedKeys = <String>[
      'New Tesc',
      'ATR',
      'Ensin',
      'New',
      'Tesc',
      'Outras Locadoras',
      'Não Locados',
    ];

    for (final key in orderedKeys) {
      final items = grouped[key];
      if (items == null || items.isEmpty) continue;
      items.sort((a, b) => a.placa.compareTo(b.placa));
      ordered[key] = items;
    }

    return ordered;
  }

  Widget _buildRevisionCard(BuildContext context, bool isDark) {
    final events = proximosEventos;
    final revisions =
        events.where((e) => e.tipo == EventType.maintenance).toList();
    return BentoCard(
      height: 300,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(LucideIcons.wrench,
                color: AppColors.atrOrange, size: 18,),
            const SizedBox(width: 10),
            Text('Próximas Revisões',
                style: Theme.of(context).textTheme.titleMedium,),
          ],),
          const SizedBox(height: 20),
          Expanded(
              child: ListView.separated(
            itemCount: revisions.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (ctx, i) {
              final e = revisions[i];
              return _eventItem(ctx, e.titulo, e.descricao, e.prazo,
                  AppColors.atrOrange, isDark,);
            },
          ),),
        ],
      ),
    );
  }

  Widget _buildInstallmentCard(BuildContext context, bool isDark) {
    final events = proximosEventos;
    final payments = events.where((e) => e.tipo == EventType.payment).toList();
    return BentoCard(
      height: 300,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(LucideIcons.landmark,
                color: AppColors.statusInfo, size: 18,),
            const SizedBox(width: 10),
            Text('Próximas Parcelas',
                style: Theme.of(context).textTheme.titleMedium,),
          ],),
          const SizedBox(height: 20),
          Expanded(
              child: ListView.separated(
            itemCount: payments.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (ctx, i) {
              final e = payments[i];
              return _eventItem(ctx, e.titulo, e.descricao, e.prazo,
                  AppColors.statusInfo, isDark,);
            },
          ),),
        ],
      ),
    );
  }

  Widget _buildExpensesCard(
      BuildContext context, bool isDark, String selectedMonth,) {
    final repo = context.read<FleetRepository>();
    final monthsMap = {'Jan': 1, 'Fev': 2, 'Mar': 3, 'Abr': 4};
    final monthPart = selectedMonth.split('/').first;
    final monthNum = monthsMap[monthPart] ?? 4;

    final listItems = repo.frota
        .expand((v) => v.manutencoes
            .where((m) => m.data.month == monthNum && m.data.year == 2026)
            .map<_ExpenseItem>((m) => (v: v, m: m)),)
        .toList();

    return BentoCard(
      height: 300,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(LucideIcons.alertCircle,
                color: AppColors.statusError, size: 18,),
            const SizedBox(width: 10),
            Text('Manut. de $selectedMonth',
                style: Theme.of(context).textTheme.titleMedium,),
          ],),
          const SizedBox(height: 20),
          Expanded(
              child: ListView.separated(
            itemCount: listItems.isEmpty ? 1 : listItems.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (ctx, i) {
              if (listItems.isEmpty) {
                return Text('Nenhuma despesa extra lançada.',
                    style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white38 : Colors.black45,),);
              }
              final item = listItems[i];
              final v = item.v;
              final m = item.m;

              return Row(
                children: [
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(m.descricao,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 11,),),
                        Text('${formatDate(m.data)} - ${v.placa}',
                            style: TextStyle(
                                fontSize: 10,
                                color:
                                    isDark ? Colors.white54 : Colors.black54,),),
                      ],),),
                  Text(formatCurrency(m.custo),
                      style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          color: AppColors.statusError,
                          fontSize: 11,),),
                ],
              );
            },
          ),),
          const Divider(height: 24),
          const Text('+ Lançar despesa',
              style: TextStyle(
                  color: AppColors.statusInfo,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  decoration: TextDecoration.underline,),),
        ],
      ),
    );
  }

  Widget _eventItem(BuildContext context, String title, String desc,
      String time, Color color, bool isDark,) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.03)
              : Colors.black.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(10),),
      child: Row(
        children: [
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 12,),),
                const SizedBox(height: 2),
                Text(desc,
                    style: TextStyle(
                        fontSize: 10,
                        color: isDark ? Colors.white60 : Colors.black54,),),
              ],),),
          const SizedBox(width: 10),
          Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),),
              child: Text(time,
                  style: TextStyle(
                      color: color, fontWeight: FontWeight.bold, fontSize: 9,),),),
        ],
      ),
    );
  }

  Widget _buildFleetItem(VehicleData v, bool isDark) {
    final f = v.financiamento;
    final Color statusColor = v.status == VehicleStatus.emRota
        ? AppColors.statusSuccess
        : (v.status == VehicleStatus.emOficina
            ? AppColors.statusError
            : AppColors.statusWarning);

    return BentoCard(
      padding: EdgeInsets.zero,
      onTap: () => context.go('/vehicles/${v.placa}'),
      child: Container(
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: statusColor, width: 3)),
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [v.cor1, v.cor2]),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(LucideIcons.car, color: Colors.white, size: 16),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(v.placa,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),),
                      Text(v.nome,
                          style: TextStyle(fontSize: 10, color: isDark ? Colors.white38 : AppColors.textSecondaryLight,),
                          overflow: TextOverflow.ellipsis,),
                    ],
                  ),
                ),
                StatusBadge(
                  text: v.status.label,
                  type: v.status == VehicleStatus.emRota
                      ? BadgeType.success
                      : (v.status == VehicleStatus.emOficina
                          ? BadgeType.error
                          : BadgeType.warning),
                ),
              ],
            ),
            if (f != null) ...[
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Recebido', style: TextStyle(fontSize: 10, color: isDark ? Colors.white70 : Colors.black87)),
                  Text(formatCurrency(f.totalRecebido),
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.statusSuccess)),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Parcela/mês', style: TextStyle(fontSize: 10, color: isDark ? Colors.white70 : Colors.black87)),
                  Text(formatCurrency(f.valorParcela),
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.statusError)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Metrics {
  final double receita;
  final double parcelas;
  final double manutencao;
  final double lucro;
  const _Metrics({this.receita = 0, this.parcelas = 0, this.manutencao = 0, this.lucro = 0});
}

const _meses = ['Jan', 'Fev', 'Mar', 'Abr', 'Mai', 'Jun', 'Jul', 'Ago', 'Set', 'Out', 'Nov', 'Dez'];

class _FilterBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _FilterBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, size: 16, color: AppColors.atrOrange),
        ),
      ),
    );
  }
}

class _MonthDropdown extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  const _MonthDropdown({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      initialValue: value,
      onSelected: onChanged,
      offset: const Offset(0, 40),
      itemBuilder: (ctx) => _meses
          .map((m) => PopupMenuItem(value: m, child: Text(m, style: const TextStyle(fontWeight: FontWeight.w600))))
          .toList(),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(width: 4),
          const Icon(LucideIcons.chevronDown, size: 12),
        ],
      ),
    );
  }
}

class _YearDropdown extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  const _YearDropdown({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final currentYear = DateTime.now().year;
    final years = List.generate(5, (i) => (currentYear - i).toString());

    return PopupMenuButton<String>(
      initialValue: value,
      onSelected: onChanged,
      offset: const Offset(0, 40),
      itemBuilder: (ctx) => years
          .map((y) => PopupMenuItem(value: y, child: Text(y, style: const TextStyle(fontWeight: FontWeight.w600))))
          .toList(),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(width: 4),
          const Icon(LucideIcons.chevronDown, size: 12),
        ],
      ),
    );
  }
}
