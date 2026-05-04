import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../core/data/fleet_data.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_sidebar.dart';
import '../../core/widgets/bento_card.dart';

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
        backgroundColor:
            isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
        body: Column(
          children: [
            _buildTopHeader(context, isDark),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                children: [
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _kpiCard(
                        title: 'Total de Carros',
                        value: '${frota.length}',
                        icon: LucideIcons.truck,
                        color: AppColors.statusInfo,
                      ),
                      _kpiCard(
                        title: 'Atualizados na Semana',
                        value: '$atualizadosSemana',
                        icon: LucideIcons.checkCircle2,
                        color: AppColors.statusSuccess,
                      ),
                      _kpiCard(
                        title: 'Revisão Urgente',
                        value: '$urgentes',
                        icon: LucideIcons.alertCircle,
                        color: AppColors.statusError,
                      ),
                      _kpiCard(
                        title: 'Em Atenção',
                        value: '$atencao',
                        icon: LucideIcons.alertTriangle,
                        color: AppColors.statusWarning,
                      ),
                      _kpiCard(
                        title: 'Em Dia',
                        value: '$emDia',
                        icon: LucideIcons.shieldCheck,
                        color: AppColors.atrOrange,
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
    );
  }

  Widget _buildTopHeader(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(32, 28, 32, 16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.atrNavyDarker : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.06),
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.atrOrange.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              LucideIcons.calendarCheck2,
              color: AppColors.atrOrange,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Controle de Revisão',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.3,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Visão geral da frota e acompanhamento por veículo',
                  style: TextStyle(
                    color: isDark ? Colors.white54 : Colors.black54,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _kpiCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return SizedBox(
      width: 220,
      child: BentoCard(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
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
            color: isDark ? Colors.white54 : Colors.black54,
          ),
          const SizedBox(width: 8),
          Text(
            'Mês:',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white54 : Colors.black54,
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
            TextButton.icon(
              style: TextButton.styleFrom(
                foregroundColor: AppColors.statusError,
              ),
              onPressed: () => setState(() => _filtroMes = null),
              icon: const Icon(LucideIcons.x, size: 12),
              label: const Text('Limpar'),
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
                        color: isDark ? Colors.white54 : Colors.black54,
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
            child: OutlinedButton.icon(
              onPressed: () => _showVehicleDetails(v, hist, statusText, statusColor),
              icon: const Icon(LucideIcons.eye, size: 15),
              label: const Text('Ver detalhes'),
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
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Fechar'),
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
