import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/widgets/app_sidebar.dart';
import '../../core/widgets/bento_card.dart';
import '../../core/theme/app_colors.dart';
import '../../core/data/fleet_data.dart';
import '../../core/widgets/status_badge.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final alerts = frotaAlertas;
    final events = proximosEventos;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AppSidebar(
      child: Scaffold(
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildBreadcrumbs(context),
                const SizedBox(height: 8),
                _buildHeader(context),
                const SizedBox(height: 32),
                
                // Alertas Críticos (Item 2)
                if (alerts.isNotEmpty) ...[
                  _buildAlertsBanner(context, alerts),
                  const SizedBox(height: 32),
                ],

                _buildMetricsRow(context),
                const SizedBox(height: 32),
                
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Gráfico Principal (Item 1 & 4)
                    Expanded(
                      flex: 5,
                      child: _buildMainChartCard(context, isDark),
                    ),
                    const SizedBox(width: 24),
                    // Próximos Eventos (Item 7)
                    Expanded(
                      flex: 3,
                      child: _buildUpcomingEventsCard(context, events, isDark),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                _buildFleetOverview(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBreadcrumbs(BuildContext context) {
    return Row(
      children: [
        Text('Home', style: TextStyle(color: AppColors.textSecondaryLight.withOpacity(0.6), fontSize: 12)),
        Icon(LucideIcons.chevronRight, size: 12, color: AppColors.textSecondaryLight.withOpacity(0.4)),
        const Text('Dashboard Executivo', style: TextStyle(color: AppColors.atrOrange, fontSize: 12, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Visão Geral', style: Theme.of(context).textTheme.displayLarge?.copyWith(fontSize: 28)),
              const SizedBox(height: 4),
              Text('Acompanhe os custos e disponibilidade da sua frota.', style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Theme.of(context).dividerTheme.color!),
          ),
          child: Row(
            children: [
              const Icon(LucideIcons.calendar, size: 16, color: AppColors.atrOrange),
              const SizedBox(width: 8),
              const Text('Abril 2026', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(width: 16),
              Container(width: 1, height: 16, color: AppColors.borderLight),
              const SizedBox(width: 16),
              const Icon(LucideIcons.chevronDown, size: 16),
            ],
          ),
        )
      ],
    );
  }

  Widget _buildAlertsBanner(BuildContext context, List<AlertItem> alerts) {
    return Column(
      children: alerts.take(2).map((alert) {
        final color = alert.tipo == 'danger' ? AppColors.statusError : (alert.tipo == 'warning' ? AppColors.statusWarning : AppColors.statusInfo);
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              Icon(alert.tipo == 'danger' ? LucideIcons.alertOctagon : LucideIcons.alertTriangle, color: color, size: 20),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(alert.titulo, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
                    Text(alert.mensagem, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color.withOpacity(0.8))),
                  ],
                ),
              ),
              TextButton(onPressed: () {}, child: Text('Ver Detalhes', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12))),
            ],
          ),
        ).animate().slideX(begin: 0.1, end: 0, duration: 400.ms, curve: Curves.easeOutCubic).fadeIn();
      }).toList(),
    );
  }

  Widget _buildMetricsRow(BuildContext context) {
    double totalManut = frota.fold(0, (s, v) => s + v.custoTotalManutencao);
    int emOficina = frota.where((v) => v.status == 'EM OFICINA').length;

    return Row(
      children: [
        Expanded(child: _buildMetricCard(context, 'Custo Manut. Total', formatCurrency(totalManut), 'Acumulado frota', LucideIcons.wrench, AppColors.statusError, 0)),
        const SizedBox(width: 24),
        Expanded(child: _buildMetricCard(context, 'Veículos Ativos', '${frota.length - emOficina}', 'De ${frota.length} totais', LucideIcons.car, AppColors.statusSuccess, 100)),
        const SizedBox(width: 24),
        Expanded(child: _buildMetricCard(context, 'Veículos em Oficina', '$emOficina', '${frotaAlertas.where((a)=>a.tipo=='danger').length} avisos críticos', LucideIcons.alertTriangle, AppColors.statusWarning, 200)),
      ],
    );
  }

  Widget _buildMetricCard(BuildContext context, String title, String value, String subtitle, IconData icon, Color color, int delay) {
    return BentoCard(
      animationDelay: delay,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: Theme.of(context).textTheme.bodyMedium),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: Icon(icon, color: color, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(value, style: Theme.of(context).textTheme.displayLarge?.copyWith(fontSize: 28, color: color)),
          const SizedBox(height: 8),
          Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 16),
          // Sparkline placeholder
          _buildMiniSparkline(color),
        ],
      ),
    );
  }

  Widget _buildMiniSparkline(Color color) {
    return SizedBox(
      height: 20,
      width: double.infinity,
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _SparklinePainter(color: color),
        ),
      ),
    );
  }

  Widget _buildMainChartCard(BuildContext context, bool isDark) {
    return BentoCard(
      height: 400,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Evolução Financeira (TCO)', style: Theme.of(context).textTheme.titleLarge),
                  Text('Custos de manutenção e Parcelas vs Receita', style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
              Row(
                children: [
                  _chartLegend('Manutenção', AppColors.statusError),
                  const SizedBox(width: 16),
                  _chartLegend('Parcelas', AppColors.statusWarning),
                  const SizedBox(width: 16),
                  _chartLegend('Receita', AppColors.statusSuccess),
                ],
              ),
            ],
          ),
          const Expanded(
            child: Padding(
              padding: EdgeInsets.only(top: 32, bottom: 8),
              child: RepaintBoundary(child: _FullDashboardChart()),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: dadosMensais.map((d) => Text(d.mes, style: const TextStyle(fontSize: 10, color: AppColors.textSecondaryLight))).toList(),
          ),
        ],
      ),
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

  Widget _buildUpcomingEventsCard(BuildContext context, List<UpcomingEvent> events, bool isDark) {
    return BentoCard(
      height: 400,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Próximos Eventos', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 20),
          Expanded(
            child: ListView.separated(
              itemCount: events.length,
              separatorBuilder: (_, __) => Divider(color: isDark ? AppColors.borderDark : AppColors.borderLight, height: 24),
              itemBuilder: (context, index) {
                final event = events[index];
                IconData icon;
                Color color;
                if (event.tipo == 'maintenance') { icon = LucideIcons.wrench; color = AppColors.atrOrange; }
                else if (event.tipo == 'payment') { icon = LucideIcons.landmark; color = AppColors.statusInfo; }
                else { icon = LucideIcons.alertCircle; color = AppColors.statusWarning; }

                return Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                      child: Icon(icon, color: color, size: 16),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(event.titulo, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          Text(event.descricao, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11)),
                        ],
                      ),
                    ),
                    Text(event.prazo, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11)),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () {},
              style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: const Text('Ver Calendário Completo', style: TextStyle(fontSize: 12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFleetOverview(BuildContext context) {
    return BentoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
           Text('Resumo da Frota', style: Theme.of(context).textTheme.titleLarge),
           const SizedBox(height: 24),
           Row(
             children: frota.map((v) => Expanded(
               child: Container(
                 margin: const EdgeInsets.only(right: 16),
                 padding: const EdgeInsets.all(16),
                 decoration: BoxDecoration(
                   color: AppColors.surfaceElevatedDark.withOpacity(0.05),
                   borderRadius: BorderRadius.circular(16),
                   border: Border.all(color: AppColors.borderDark.withOpacity(0.1)),
                 ),
                 child: Column(
                   children: [
                     Container(
                       padding: const EdgeInsets.all(10),
                       decoration: BoxDecoration(gradient: LinearGradient(colors: [v.cor1, v.cor2]), shape: BoxShape.circle),
                       child: const Icon(LucideIcons.car, color: Colors.white, size: 16),
                     ),
                     const SizedBox(height: 12),
                     Text(v.placa, style: const TextStyle(fontWeight: FontWeight.bold)),
                     Text(v.nome.split(' ')[0], style: const TextStyle(fontSize: 10, color: AppColors.textSecondaryLight)),
                     const SizedBox(height: 8),
                     StatusBadge(text: v.status, type: BadgeType.success),
                   ],
                 ),
               ),
             )).toList(),
           ),
        ],
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final Color color;
  _SparklinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    final path = Path();
    path.moveTo(0, size.height * 0.8);
    path.lineTo(size.width * 0.2, size.height * 0.4);
    path.lineTo(size.width * 0.4, size.height * 0.6);
    path.lineTo(size.width * 0.6, size.height * 0.2);
    path.lineTo(size.width * 0.8, size.height * 0.5);
    path.lineTo(size.width, size.height * 0.1);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _FullDashboardChart extends StatelessWidget {
  const _FullDashboardChart();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _ChartPainter(),
      size: Size.infinite,
    );
  }
}

class _ChartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final maxVal = 8000.0;
    final w = size.width / dadosMensais.length;
    final h = size.height;

    for (int i = 0; i < dadosMensais.length; i++) {
        final d = dadosMensais[i];
        final x = i * w + w * 0.2;
        final barW = w * 0.2;

        // Manutenção
        final mH = (d.manutencao / maxVal) * h;
        canvas.drawRRect(
          RRect.fromLTRBAndCorners(x, h - mH, x + barW, h, topLeft: const Radius.circular(3), topRight: const Radius.circular(3)),
          Paint()..color = AppColors.statusError.withOpacity(0.8),
        );

        // Financiamento (Stacked)
        final fH = (d.financiamento / maxVal) * h;
        canvas.drawRRect(
          RRect.fromLTRBAndCorners(x + barW + 2, h - fH, x + (barW * 2) + 2, h, topLeft: const Radius.circular(3), topRight: const Radius.circular(3)),
          Paint()..color = AppColors.statusWarning.withOpacity(0.8),
        );

        // Receita (Line)
        if (i < dadosMensais.length - 1) {
            final dNext = dadosMensais[i+1];
            final xCenter = x + barW;
            final xNextCenter = (i + 1) * w + w * 0.2 + barW;
            final y = h - (d.receita / maxVal) * h;
            final yNext = h - (dNext.receita / maxVal) * h;

            canvas.drawLine(
              Offset(xCenter, y),
              Offset(xNextCenter, yNext),
              Paint()..color = AppColors.statusSuccess..strokeWidth = 2.5..strokeCap = StrokeCap.round,
            );
            canvas.drawCircle(Offset(xCenter, y), 4, Paint()..color = AppColors.statusSuccess);
            if (i == dadosMensais.length - 2) {
               canvas.drawCircle(Offset(xNextCenter, yNext), 4, Paint()..color = AppColors.statusSuccess);
            }
        }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
