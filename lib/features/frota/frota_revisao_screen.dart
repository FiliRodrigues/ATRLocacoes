import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../core/data/fleet_data.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/atr_page_background.dart';
import '../../core/widgets/atr_top_bar.dart';
import '../../core/widgets/app_sidebar.dart';
import '../../core/widgets/atr_button.dart';
import '../../core/widgets/bento_card.dart';
import '../../core/widgets/atr_kpi_card.dart';

class FrotaRevisaoScreen extends StatefulWidget {
  const FrotaRevisaoScreen({super.key});

  @override
  State<FrotaRevisaoScreen> createState() => _FrotaRevisaoScreenState();
}

class _FrotaRevisaoScreenState extends State<FrotaRevisaoScreen> {
  DateTime? _filtroMes;

  bool _foiAtualizadoNaSemana(DateTime? datetime) {
    if (datetime == null) return false;
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1)).copyWith(
          hour: 0,
          minute: 0,
          second: 0,
          millisecond: 0,
          microsecond: 0,
        );
    return datetime.isAfter(startOfWeek) ||
        datetime.isAtSameMomentAs(startOfWeek);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final repo = context.watch<FleetRepository>();
    final frota = repo.frota;
    final historico = repo.kmHistorico;

    final atualizadosSemana =
        frota.where((v) => _foiAtualizadoNaSemana(v.ultimaAtualizacaoKm)).length;
    final urgentes = frota.where((v) => v.kmParaProxRevisao <= 1000).length;
    final atencao = frota
        .where((v) => v.kmParaProxRevisao > 1000 && v.kmParaProxRevisao <= 2500)
        .length;
    final emDia = (frota.length - urgentes - atencao).clamp(0, frota.length);

    return AppSidebar(
      child: Scaffold(
        body: AtrPageBackground(
          grid: true,
          child: Column(
          children: [
            const AtrTopBar(
              title: 'Controle de Revisão',
              subtitle: 'Visão geral da frota e acompanhamento por veículo',
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                children: [
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      SizedBox(
                        width: 220,
                        child: AtrKpiCard(
                          label: 'Total de Carros',
                          value: '${frota.length}',
                          icon: LucideIcons.truck,
                          tone: KpiTone.info,
                        ),
                      ),
                      SizedBox(
                        width: 220,
                        child: AtrKpiCard(
                          label: 'Atualizados na Semana',
                          value: '$atualizadosSemana',
                          icon: LucideIcons.checkCircle2,
                          tone: KpiTone.success,
                        ),
                      ),
                      SizedBox(
                        width: 220,
                        child: AtrKpiCard(
                          label: 'Revisão Urgente',
                          value: '$urgentes',
                          icon: LucideIcons.alertCircle,
                          tone: KpiTone.error,
                        ),
                      ),
                      SizedBox(
                        width: 220,
                        child: AtrKpiCard(
                          label: 'Em Atenção',
                          value: '$atencao',
                          icon: LucideIcons.alertTriangle,
                          tone: KpiTone.warning,
                        ),
                      ),
                      SizedBox(
                        width: 220,
                        child: AtrKpiCard(
                          label: 'Em Dia',
                          value: '$emDia',
                          icon: LucideIcons.shieldCheck,
                          tone: KpiTone.orange,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildFilterBar(isDark),
                  const SizedBox(height: 12),
                  ...frota.asMap().entries.map((entry) {
                    final i = entry.key;
                    final v = entry.value;
                    final hist = historico
                        .where((r) =>
                            r.placa == v.placa &&
                            (_filtroMes == null ||
                                (r.data.year == _filtroMes!.year &&
                                    r.data.month == _filtroMes!.month)))
                        .toList()
                      ..sort((a, b) => b.data.compareTo(a.data));

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _vehicleCard(v, hist, isDark)
                          .animate(delay: (i * 60).ms)
                          .fadeIn(duration: 260.ms)
                          .moveY(begin: 8, end: 0),
                    );
                  }),
                ],
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }

  Widget _buildFilterBar(bool isDark) {
    return BentoCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Icon(
            LucideIcons.filter,
            size: 15,
            color: isDark ? AppColors.textSecondaryDark : Colors.black54,
          ),
          const SizedBox(width: 8),
          Text(
            'Mês:',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? AppColors.textSecondaryDark : Colors.black54,
            ),
          ),
          const SizedBox(width: 8),
          _buildFilterChip(
            label: _filtroMes != null
                ? DateFormat('MMM/yyyy', 'pt_BR').format(_filtroMes!)
                : 'Todos os meses',
            isDark: isDark,
            onTap: _mostrarSeletorMes,
          ),
          if (_filtroMes != null) ...[
            const SizedBox(width: 8),
            AtrGhostButton(
              label: 'Limpar',
              icon: LucideIcons.x,
              onPressed: () => setState(() => _filtroMes = null),
            ),
          ],
        ],
      ),
    );
  }

  Widget _vehicleCard(VehicleData v, List<KmRegistro> hist, bool isDark) {
    final kmAtual = v.kmAtual;
    final kmProxRevisao = ((kmAtual / 10000).floor() + 1) * 10000;
    final kmPara = kmProxRevisao - kmAtual;

    final Color statusColor;
    final String statusText;
    if (kmPara <= 1000) {
      statusColor = AppColors.statusError;
      statusText = 'URGENTE';
    } else if (kmPara <= 2500) {
      statusColor = AppColors.statusWarning;
      statusText = 'ATENÇÃO';
    } else {
      statusColor = AppColors.statusSuccess;
      statusText = 'EM DIA';
    }

    return BentoCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${v.placa} • ${v.nome}',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'Motorista: ${v.motorista}',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppColors.textSecondaryDark : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 14,
            runSpacing: 6,
            children: [
              Text(
                'KM atual: ${NumberFormat('#,###', 'pt_BR').format(kmAtual.toInt())} km',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
              Text(
                'Próxima revisão: ${NumberFormat('#,###', 'pt_BR').format(kmProxRevisao)} km',
                style: const TextStyle(fontSize: 12),
              ),
              Text(
                'Faltam: ${NumberFormat('#,###', 'pt_BR').format(kmPara.toInt())} km',
                style: TextStyle(fontSize: 12, color: statusColor),
              ),
              Text(
                'Registros no período: ${hist.length}',
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: AtrSecondaryButton(
              label: 'Ver detalhes',
              icon: LucideIcons.eye,
              onPressed: () => _showVehicleDetails(v, hist, statusText, statusColor),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showVehicleDetails(
    VehicleData v,
    List<KmRegistro> hist,
    String statusText,
    Color statusColor,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Detalhes ${v.placa}'),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${v.nome} • ${v.motorista}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text('Status revisão: '),
                    Text(
                      statusText,
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text('KM atual: ${NumberFormat('#,###', 'pt_BR').format(v.kmAtual.toInt())} km'),
                Text('KM para próxima revisão: ${NumberFormat('#,###', 'pt_BR').format(v.kmParaProxRevisao.toInt())} km'),
                const SizedBox(height: 12),
                const Text(
                  'Histórico de KM',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                if (hist.isEmpty)
                  const Text('Sem registros para o período selecionado.')
                else
                  ...hist.take(14).map(
                    (r) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          Text(DateFormat('dd/MM/yyyy').format(r.data)),
                          const Spacer(),
                          Text(
                            '${NumberFormat('#,###', 'pt_BR').format(r.km.toInt())} km',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          AtrGhostButton(
            label: 'Fechar',
            onPressed: () => Navigator.pop(ctx),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.black.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.atrOrange.withValues(alpha: 0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: const TextStyle(fontSize: 12)),
            const SizedBox(width: 6),
            const Icon(LucideIcons.chevronDown, size: 12),
          ],
        ),
      ),
    );
  }

  Future<void> _mostrarSeletorMes() async {
    final now = DateTime.now();
    final meses = List.generate(
      12,
      (i) => DateTime(now.year, now.month - i, 1),
    );

    final mes = await showModalBottomSheet<DateTime?>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Filtrar por Mês',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(LucideIcons.calendar),
              title: const Text('Todos os meses'),
              onTap: () => Navigator.pop(ctx, null),
            ),
            const Divider(height: 1),
            SizedBox(
              height: 240,
              child: ListView.builder(
                itemCount: meses.length,
                itemBuilder: (_, i) {
                  final m = meses[i];
                  final label = DateFormat('MMMM yyyy', 'pt_BR').format(m);
                  return ListTile(
                    leading: const Icon(LucideIcons.calendarDays),
                    title: Text(label),
                    onTap: () => Navigator.pop(ctx, m),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );

    if (mounted) {
      setState(() => _filtroMes = mes);
    }
  }
}
