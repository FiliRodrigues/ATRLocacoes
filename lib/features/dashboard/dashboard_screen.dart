import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/widgets/app_sidebar.dart';
import '../../core/widgets/bento_card.dart';
import '../../core/widgets/atr_kpi_card.dart';
import '../../core/widgets/atr_page_background.dart';
import '../../core/theme/app_colors.dart';
import '../../core/data/fleet_data.dart';
import '../../core/utils/app_logger.dart';
import '../ai_assistant/presentation/widgets/ai_dashboard_search_bar.dart';
import '../vehicles/vehicle_form_modal.dart';


class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _pendentesCount = 0;

  String _selectedMonth = (() {
    final now = DateTime.now();
    const m = ['Jan', 'Fev', 'Mar', 'Abr', 'Mai', 'Jun', 'Jul', 'Ago', 'Set', 'Out', 'Nov', 'Dez'];
    return '${m[now.month - 1]}/${(now.year % 100).toString().padLeft(2, '0')}';
  })();

  @override
  void initState() {
    super.initState();
    _fetchPendingCount();
  }

  Future<void> _fetchPendingCount() async {
    final tenantId = Supabase.instance.client.auth.currentUser
        ?.appMetadata['tenant_id'] as String?;
    if (tenantId == null) return;
    try {
      final rows = await Supabase.instance.client
          .from('manutencoes')
          .select('id')
          .eq('coluna', 'pendentes')
          .eq('tenant_id', tenantId);
      if (mounted) setState(() => _pendentesCount = rows.length);
    } catch (e) {
      AppLogger.warning('Dashboard: falha ao carregar pendencias de manutencao: $e');
    }
  }

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
    assert(() { debugPrint('[DASH] _computeMetrics: frota=${frota.length} comFin=$comFin comRecReal=$comRecReal comRecMes=$comRecMes receita=$receita mes=$_selectedMonth'); return true; }());
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
        body: AtrPageBackground(
          grid: true,
          child: SafeArea(
            child: repo.isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.atrOrange),)
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const AiDashboardSearchBar(),
                        const SizedBox(height: 24),
                        _buildHeader(context),
                        const SizedBox(height: 20),
                        if (alerts.isNotEmpty) ...[
                          _buildCompactAlerts(context, alerts),
                          const SizedBox(height: 20),
                        ],
                        _buildKpiRow(context, metrics),
                        const SizedBox(height: 16),
                        if (isCompact) ...[
                          _buildRevenueLineChart(context),
                          const SizedBox(height: 16),
                          _buildRevisionCard(context, isDark),
                          const SizedBox(height: 16),
                          _buildFleetStatusDonut(context),
                          const SizedBox(height: 16),
                          _buildActivityList(context),
                        ] else ...[
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(flex: 14, child: _buildRevenueLineChart(context)),
                              const SizedBox(width: 16),
                              Expanded(flex: 10, child: _buildRevisionCard(context, isDark)),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(flex: 10, child: _buildFleetStatusDonut(context)),
                              const SizedBox(width: 16),
                              Expanded(flex: 14, child: _buildActivityList(context)),
                            ],
                          ),
                        ],
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
            Text('VisÃ£o Geral',
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
        FilledButton.icon(
          onPressed: () => VehicleFormModal.show(context),
          icon: const Icon(LucideIcons.plus, size: 16),
          label: const Text('Novo VeÃ­culo'),
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
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: color, fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 6),
              Text('Â·',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.24), fontSize: 11),),
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

  Widget _buildKpiRow(BuildContext context, _Metrics metrics) {
    final repo = context.read<FleetRepository>();
    final totalVeiculos = repo.frota.length;
    final emRota = repo.frota.where((v) => v.status == VehicleStatus.emRota).length;
    final ativos = repo.frota.where((v) => v.status == VehicleStatus.emRota || v.status == VehicleStatus.parado || v.status == VehicleStatus.reserva).length;
    final width = MediaQuery.of(context).size.width;
    final isCompact = width < 900;

    if (isCompact) {
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          SizedBox(width: (width - 52) / 2, child: AtrKpiCard(label: 'Frota Ativa', value: '$ativos / $totalVeiculos', icon: LucideIcons.truck, tone: KpiTone.orange)),
          SizedBox(width: (width - 52) / 2, child: AtrKpiCard(label: 'Receita Mensal', value: formatCurrency(metrics.receita), icon: LucideIcons.wallet, tone: KpiTone.success)),
          SizedBox(width: (width - 52) / 2, child: AtrKpiCard(label: 'Parcelas (mÃªs)', value: formatCurrency(metrics.parcelas), icon: LucideIcons.landmark, tone: KpiTone.error)),
          SizedBox(width: (width - 52) / 2, child: AtrKpiCard(label: 'Manut. (mÃªs)', value: formatCurrency(metrics.manutencao), icon: LucideIcons.wrench, tone: KpiTone.warning)),
          SizedBox(width: (width - 52) / 2, child: AtrKpiCard(label: 'Pendentes', value: '$_pendentesCount', icon: LucideIcons.alertCircle, tone: _pendentesCount > 0 ? KpiTone.warning : KpiTone.success)),
        ],
      );
    }
    return Row(
      children: [
        Expanded(child: AtrKpiCard(label: 'Frota Ativa', value: '$ativos / $totalVeiculos', icon: LucideIcons.truck, tone: KpiTone.orange, delta: '$emRota em rota', trend: KpiTrend.neutral)),
        const SizedBox(width: 14),
        Expanded(child: AtrKpiCard(label: 'Receita Mensal', value: formatCurrency(metrics.receita), icon: LucideIcons.wallet, tone: KpiTone.success)),
        const SizedBox(width: 14),
        Expanded(child: AtrKpiCard(label: 'Parcelas (mÃªs)', value: formatCurrency(metrics.parcelas), icon: LucideIcons.landmark, tone: KpiTone.error)),
        const SizedBox(width: 14),
        Expanded(child: AtrKpiCard(label: 'Manut. (mÃªs)', value: formatCurrency(metrics.manutencao), icon: LucideIcons.wrench, tone: KpiTone.warning)),
        const SizedBox(width: 14),
        Expanded(child: AtrKpiCard(label: 'ManutenÃ§Ãµes Pendentes', value: '$_pendentesCount', icon: LucideIcons.alertCircle, tone: _pendentesCount > 0 ? KpiTone.warning : KpiTone.success)),
      ],
    );
  }

  Widget _buildRevenueLineChart(BuildContext context) {
    final repo = context.read<FleetRepository>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const monthsMap = {
      'Jan': 1, 'Fev': 2, 'Mar': 3, 'Abr': 4,
      'Mai': 5, 'Jun': 6, 'Jul': 7, 'Ago': 8,
      'Set': 9, 'Out': 10, 'Nov': 11, 'Dez': 12,
    };
    final now = DateTime.now();
    final labels = <String>[];
    final values = <double>[];
    for (var i = 5; i >= 0; i--) {
      final d = DateTime(now.year, now.month - i);
      final mNum = d.month;
      final yNum = d.year;
      final label = '${monthsMap.entries.firstWhere((e) => e.value == mNum).key}/${(yNum % 100).toString().padLeft(2, '0')}';
      labels.add(label.split('/').first);
      final r = repo.frota.fold(0.0, (s, v) {
        final f = v.financiamento;
        if (f == null) return s;
        final real = f.recebidoNoMes(yNum, mNum);
        if (real != null && real > 0) return s + real;
        if (f.recebimentoMensal > 0) return s + f.recebimentoMensal;
        return s;
      });
      values.add(r);
    }
    final maxVal = values.fold(0.0, (a, b) => a > b ? a : b);

    return BentoCard(
      height: 280,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Receita por mÃªs', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 2),
                Text('Ãšltimos 6 meses', style: TextStyle(fontSize: 11, color: isDark ? Colors.white38 : Colors.black45)),
              ]),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.atrOrange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.atrOrange.withValues(alpha: 0.2)),
                ),
                child: Text(formatCurrency(values.isNotEmpty ? values.last : 0),
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.atrOrange)),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: CustomPaint(
              painter: _LineChartPainter(values: values, labels: labels, maxVal: maxVal),
              child: const SizedBox.expand(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFleetStatusDonut(BuildContext context) {
    final repo = context.read<FleetRepository>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final frota = repo.frota;
    final emRota = frota.where((v) => v.status == VehicleStatus.emRota).length;
    final parado = frota.where((v) => v.status == VehicleStatus.parado).length;
    final reservado = frota.where((v) => v.status == VehicleStatus.reserva).length;
    final oficina = frota.where((v) => v.status == VehicleStatus.emOficina).length;
    final total = frota.length;

    final segments = [
      (label: 'Em rota', count: emRota, color: AppColors.statusSuccess),
      (label: 'Parado', count: parado, color: AppColors.statusInfo),
      (label: 'Reserva', count: reservado, color: AppColors.statusWarning),
      (label: 'Oficina', count: oficina, color: AppColors.statusError),
    ];

    return BentoCard(
      height: 280,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Status da Frota', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text('$total veÃ­culos cadastrados', style: TextStyle(fontSize: 11, color: isDark ? Colors.white38 : Colors.black45)),
          const SizedBox(height: 16),
          Expanded(
            child: Row(
              children: [
                SizedBox(
                  width: 140,
                  child: CustomPaint(
                    painter: _DonutPainter(segments: segments.map((s) => (count: s.count, total: total, color: s.color)).toList()),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('$total', style: const TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrimaryDark)),
                          const Text('VEÃC.', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w700, letterSpacing: 1.2, color: AppColors.textSecondaryDark)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: segments.map((s) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Row(children: [
                        Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: s.color)),
                        const SizedBox(width: 8),
                        Expanded(child: Text(s.label, style: TextStyle(fontSize: 12, color: isDark ? AppColors.textSecondaryDark : Colors.black54))),
                        Text('${s.count}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimaryDark)),
                      ]),
                    )).toList(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityList(BuildContext context) {
    final repo = context.read<FleetRepository>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final allEvents = repo.frota
        .expand((v) => v.manutencoes.map((m) => (v: v, m: m)))
        .toList()
      ..sort((a, b) => b.m.data.compareTo(a.m.data));
    final recent = allEvents.take(6).toList();

    return BentoCard(
      height: 280,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Atividade Recente', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text('Ãšltimas manutenÃ§Ãµes registradas', style: TextStyle(fontSize: 11, color: isDark ? Colors.white38 : Colors.black45)),
          const SizedBox(height: 16),
          Expanded(
            child: recent.isEmpty
                ? Center(child: Text('Nenhuma atividade recente.', style: TextStyle(color: isDark ? Colors.white38 : Colors.black38, fontSize: 12)))
                : ListView.separated(
                    itemCount: recent.length,
                    separatorBuilder: (_, __) => Divider(height: 1, color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05)),
                    itemBuilder: (ctx, i) {
                      final item = recent[i];
                      final v = item.v;
                      final m = item.m;
                      final daysAgo = DateTime.now().difference(m.data).inDays;
                      final timeLabel = daysAgo == 0 ? 'Hoje' : daysAgo == 1 ? 'Ontem' : 'hÃ¡ ${daysAgo}d';
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(children: [
                          Container(
                            width: 32, height: 32,
                            decoration: BoxDecoration(
                              color: AppColors.atrOrange.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(LucideIcons.wrench, size: 14, color: AppColors.atrOrange),
                          ),
                          const SizedBox(width: 10),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(m.descricao.isNotEmpty ? (m.descricao.length > 40 ? '${m.descricao.substring(0, 40)}â€¦' : m.descricao) : m.tipo,
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimaryDark), overflow: TextOverflow.ellipsis),
                            Text('${v.placa} Â· ${v.nome}', style: TextStyle(fontSize: 10, color: isDark ? Colors.white38 : Colors.black45)),
                          ])),
                          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                            Text(timeLabel, style: TextStyle(fontSize: 10, color: isDark ? Colors.white38 : Colors.black45)),
                            if (m.custo > 0)
                              Text(formatCurrency(m.custo), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.statusSuccess)),
                          ]),
                        ]),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
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
            Text('PrÃ³ximas RevisÃµes',
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

}

class _LineChartPainter extends CustomPainter {
  final List<double> values;
  final List<String> labels;
  final double maxVal;

  const _LineChartPainter({required this.values, required this.labels, required this.maxVal});

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty || maxVal <= 0) return;
    final n = values.length;
    final xStep = size.width / (n - 1);
    final labelH = 20.0;
    final chartH = size.height - labelH;

    double x(int i) => i * xStep;
    double y(double v) => chartH - (v / maxVal * chartH).clamp(0.0, chartH);

    final path = Path();
    path.moveTo(x(0), y(values[0]));
    for (var i = 1; i < n; i++) {
      final cp1x = x(i - 1) + xStep / 2;
      final cp2x = x(i) - xStep / 2;
      path.cubicTo(cp1x, y(values[i - 1]), cp2x, y(values[i]), x(i), y(values[i]));
    }

    final areaPath = Path.from(path)
      ..lineTo(x(n - 1), chartH)
      ..lineTo(x(0), chartH)
      ..close();

    final areaGrad = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [AppColors.atrOrange.withValues(alpha: 0.18), AppColors.atrOrange.withValues(alpha: 0.0)],
    );
    canvas.drawPath(areaPath, Paint()..shader = areaGrad.createShader(Rect.fromLTWH(0, 0, size.width, chartH))..style = PaintingStyle.fill);

    canvas.drawPath(path, Paint()
      ..color = AppColors.atrOrange
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round);

    for (var i = 0; i < n; i++) {
      canvas.drawCircle(Offset(x(i), y(values[i])), i == n - 1 ? 4.5 : 3.0,
          Paint()..color = AppColors.atrOrange);
      canvas.drawCircle(Offset(x(i), y(values[i])), i == n - 1 ? 2.5 : 1.5,
          Paint()..color = const Color(0xFF0B0F19));

      final tp = TextPainter(
        text: TextSpan(text: labels[i], style: const TextStyle(fontSize: 10, color: Color(0xFF8B9CC0))),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(x(i) - tp.width / 2, chartH + 4));
    }
  }

  @override
  bool shouldRepaint(_LineChartPainter old) => old.values != values || old.maxVal != maxVal;
}

class _DonutPainter extends CustomPainter {
  final List<({int count, int total, Color color})> segments;

  const _DonutPainter({required this.segments});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 4;
    const strokeWidth = 20.0;
    const gap = 0.04;
    final total = segments.fold(0, (s, e) => s + e.count);
    if (total == 0) return;

    double startAngle = -math.pi / 2;
    for (final seg in segments) {
      if (seg.count == 0) continue;
      final sweep = (seg.count / total) * (2 * math.pi) - gap;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweep,
        false,
        Paint()
          ..color = seg.color
          ..strokeWidth = strokeWidth
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round,
      );
      startAngle += sweep + gap;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter old) => old.segments != segments;
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

