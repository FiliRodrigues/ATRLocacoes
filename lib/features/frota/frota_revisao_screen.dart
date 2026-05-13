import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../core/data/fleet_data.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/atr_page_background.dart';
import '../../core/widgets/atr_top_bar.dart';
import '../../core/widgets/app_sidebar.dart';
import '../../core/widgets/bento_card.dart';

final _kmFmt = NumberFormat('#,###', 'pt_BR');

class FrotaRevisaoScreen extends StatefulWidget {
  const FrotaRevisaoScreen({super.key});

  @override
  State<FrotaRevisaoScreen> createState() => _FrotaRevisaoScreenState();
}

class _FrotaRevisaoScreenState extends State<FrotaRevisaoScreen> {
  VehicleStatus? _filtroStatus;
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      setState(() => _searchQuery = _searchCtrl.text);
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<FleetRepository>();
    final frota = repo.frota;

    final porStatus = _filtroStatus == null
        ? frota
        : frota.where((v) => v.status == _filtroStatus).toList();

    final query = _searchQuery.toLowerCase().trim();
    final filtrada = query.isEmpty
        ? porStatus
        : porStatus.where((v) =>
            v.placa.toLowerCase().contains(query) ||
            v.nome.toLowerCase().contains(query)).toList();

    final urgentes = filtrada.where((v) => v.kmParaProxRevisao <= 1000).length;

    return AppSidebar(
      child: Scaffold(
        body: AtrPageBackground(
          grid: true,
          child: SafeArea(
            child: Column(
              children: [
                AtrTopBar(
                  title: 'Frota',
                  subtitle: 'Visão geral por contrato',
                ),
                _buildStatusFilter(frota),
                _buildSearchBar(),
                Expanded(
                  child: filtrada.isEmpty
                      ? const Center(
                          child: Text(
                            'Nenhum veículo encontrado para este filtro.',
                            style: TextStyle(color: AppColors.textMutedDark, fontSize: 14),
                          ),
                        )
                      : SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final width = constraints.maxWidth;
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 16),
                                  _buildKpis(filtrada, urgentes, width),
                                  const SizedBox(height: 28),
                                  ..._buildCompanySections(filtrada, width),
                                ],
                              );
                            },
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusFilter(List<VehicleData> frota) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _StatusFilterChip(
              label: 'Todos',
              count: frota.length,
              active: _filtroStatus == null,
              onTap: () => setState(() => _filtroStatus = null),
            ),
            const SizedBox(width: 8),
            _StatusFilterChip(
              label: 'Em rota',
              count: frota.where((v) => v.status == VehicleStatus.emRota).length,
              color: AppColors.statusSuccess,
              active: _filtroStatus == VehicleStatus.emRota,
              onTap: () => setState(() => _filtroStatus = VehicleStatus.emRota),
            ),
            const SizedBox(width: 8),
            _StatusFilterChip(
              label: 'Parado',
              count: frota.where((v) => v.status == VehicleStatus.parado).length,
              color: AppColors.statusInfo,
              active: _filtroStatus == VehicleStatus.parado,
              onTap: () => setState(() => _filtroStatus = VehicleStatus.parado),
            ),
            const SizedBox(width: 8),
            _StatusFilterChip(
              label: 'Reserva',
              count: frota.where((v) => v.status == VehicleStatus.reserva).length,
              color: AppColors.statusWarning,
              active: _filtroStatus == VehicleStatus.reserva,
              onTap: () => setState(() => _filtroStatus = VehicleStatus.reserva),
            ),
            const SizedBox(width: 8),
            _StatusFilterChip(
              label: 'Oficina',
              count: frota.where((v) => v.status == VehicleStatus.emOficina).length,
              color: AppColors.statusError,
              active: _filtroStatus == VehicleStatus.emOficina,
              onTap: () => setState(() => _filtroStatus = VehicleStatus.emOficina),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
      child: SizedBox(
        height: 44,
        child: TextField(
          controller: _searchCtrl,
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.textPrimaryDark,
          ),
          decoration: InputDecoration(
            hintText: 'Buscar por placa ou modelo...',
            hintStyle: const TextStyle(
              fontSize: 13,
              color: AppColors.textMutedDark,
            ),
            prefixIcon: const Padding(
              padding: EdgeInsets.all(12),
              child: Icon(LucideIcons.search, size: 16, color: AppColors.textSecondaryDark),
            ),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(LucideIcons.x, size: 14, color: AppColors.textMutedDark),
                    onPressed: () {
                      _searchCtrl.clear();
                    },
                  )
                : null,
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.04),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: AppColors.atrOrange.withValues(alpha: 0.5),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildKpis(List<VehicleData> frota, int urgentes, double width) {
    final emRota = frota.where((v) => v.status == VehicleStatus.emRota).length;
    final emOficina = frota.where((v) => v.status == VehicleStatus.emOficina).length;

    double itemWidth = (width - 36) / 4;
    if (width < 900) itemWidth = (width - 12) / 2;
    if (width < 500) itemWidth = width;

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        SizedBox(
          width: itemWidth,
          child: _KpiCard(
            title: 'Total Veículos',
            value: '${frota.length}',
            icon: LucideIcons.truck,
            color: AppColors.statusInfo,
          ),
        ),
        SizedBox(
          width: itemWidth,
          child: _KpiCard(
            title: 'Em Rota',
            value: '$emRota',
            icon: LucideIcons.navigation,
            color: AppColors.statusSuccess,
          ),
        ),
        SizedBox(
          width: itemWidth,
          child: _KpiCard(
            title: 'Em Oficina',
            value: '$emOficina',
            icon: LucideIcons.wrench,
            color: AppColors.statusError,
          ),
        ),
        SizedBox(
          width: itemWidth,
          child: _KpiCard(
            title: 'Revisão Urgente',
            value: '$urgentes',
            sub: '< 1.000 km',
            icon: LucideIcons.alertCircle,
            color: AppColors.statusWarning,
          ),
        ),
      ],
    );
  }

  List<Widget> _buildCompanySections(List<VehicleData> vehicles, double width) {
    final grouped = _groupVehiclesByEmpresa(vehicles);
    final sections = <Widget>[];

    for (final group in grouped.entries) {
      sections.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            group.key,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimaryDark,
            ),
          ),
        ),
      );
      sections.add(
        Wrap(
          spacing: 14,
          runSpacing: 14,
          children: group.value.asMap().entries.map((entry) {
            double itemWidth = (width - 42) / 4;
            if (width < 1200) itemWidth = (width - 28) / 3;
            if (width < 900) itemWidth = (width - 14) / 2;
            if (width < 600) itemWidth = width;
            return SizedBox(
              width: itemWidth,
              child: _VehicleCard(v: entry.value),
            );
          }).toList(),
        ),
      );
      sections.add(const SizedBox(height: 24));
    }

    return sections;
  }

  // --- Agrupamento (mesma lógica do FinancialAdmin) ---

  Map<String, List<VehicleData>> _groupVehiclesByEmpresa(List<VehicleData> vehicles) {
    final grouped = <String, List<VehicleData>>{};
    for (final v in vehicles) {
      final groupKey = _resolveEmpresaGroup(v);
      grouped.putIfAbsent(groupKey, () => <VehicleData>[]).add(v);
    }

    final ordered = <String, List<VehicleData>>{};
    const orderedKeys = [
      'New Tesc', 'ATR', 'Ensin', 'New', 'Tesc',
      'Outras Locadoras', 'Não Locados',
    ];

    for (final key in orderedKeys) {
      final items = grouped[key];
      if (items == null || items.isEmpty) continue;
      items.sort((a, b) => a.placa.compareTo(b.placa));
      ordered[key] = items;
    }

    return ordered;
  }

  String _resolveEmpresaGroup(VehicleData veiculo) {
    final origem = veiculo.motorista.trim().toUpperCase();
    final mencionaNew = origem.contains('NEW');
    final mencionaTesc = origem.contains('TESC');
    final mencionaAtr = origem.contains('ATR');
    final mencionaEnsin = origem.contains('ENSIN');

    final isLocado = origem.contains('LOCADO') ||
        mencionaNew || mencionaTesc || mencionaAtr || mencionaEnsin ||
        veiculo.status == VehicleStatus.reserva;

    if (!isLocado) return 'Não Locados';
    if (mencionaNew && mencionaTesc) return 'New Tesc';
    if (mencionaAtr) return 'ATR';
    if (mencionaEnsin) return 'Ensin';
    if (mencionaNew) return 'New';
    if (mencionaTesc) return 'Tesc';
    return 'Outras Locadoras';
  }
}

// --- KPI Card ---

class _KpiCard extends StatelessWidget {
  final String title;
  final String value;
  final String? sub;
  final IconData icon;
  final Color color;

  const _KpiCard({
    required this.title,
    required this.value,
    this.sub,
    required this.icon,
    required this.color,
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
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondaryDark,
                    ),
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
            if (sub != null) ...[
              const SizedBox(height: 4),
              Text(
                sub!,
                style: const TextStyle(fontSize: 10, color: AppColors.textMutedDark),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// --- Vehicle Card ---

class _VehicleCard extends StatelessWidget {
  final VehicleData v;

  const _VehicleCard({required this.v});

  Color get _statusColor {
    switch (v.status) {
      case VehicleStatus.emRota:
        return AppColors.statusSuccess;
      case VehicleStatus.emOficina:
        return AppColors.statusError;
      case VehicleStatus.reserva:
        return AppColors.statusWarning;
      case VehicleStatus.parado:
        return AppColors.statusInfo;
    }
  }

  String get _statusLabel => v.status.label;

  @override
  Widget build(BuildContext context) {
    final km = v.kmAtual;
    final motorista = v.motorista.isNotEmpty ? v.motorista : '—';
    final proxRevisao = v.kmParaProxRevisao;
    final totalRev = v.totalRevisoes;
    final statusColor = _statusColor;

    return BentoCard(
      padding: EdgeInsets.zero,
      onTap: () => context.go('/vehicles/${v.placa}'),
      child: Container(
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: statusColor, width: 3)),
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: ícone + placa/nome + badge
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
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        v.placa,
                        style: const TextStyle(
                          fontFamily: 'RobotoMono',
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                          color: AppColors.textPrimaryDark,
                        ),
                      ),
                      Text(
                        v.nome,
                        style: const TextStyle(fontSize: 10, color: AppColors.textSecondaryDark),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _statusLabel,
                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: statusColor, letterSpacing: 0.5),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            // KM + Motorista
            Row(
              children: [
                Expanded(
                  child: _infoCol('KM Atual', km > 0 ? _kmFmt.format(km.toInt()) : '—'),
                ),
                Expanded(
                  child: _infoCol('Motorista', motorista.length > 16 ? '${motorista.substring(0, 16)}…' : motorista),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Próxima revisão + Revisões
            Row(
              children: [
                Expanded(
                  child: _infoCol('Próx. Revisão', '${_kmFmt.format(proxRevisao.toInt())} km'),
                ),
                Expanded(
                  child: _infoCol('Revisões', '$totalRev realizadas'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoCol(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 0.8, color: AppColors.textMutedDark)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimaryDark), overflow: TextOverflow.ellipsis),
      ],
    );
  }
}

// --- Status Filter Chip (mantido do design anterior) ---

class _StatusFilterChip extends StatelessWidget {
  final String label;
  final int count;
  final Color? color;
  final bool active;
  final VoidCallback onTap;

  const _StatusFilterChip({
    required this.label,
    required this.count,
    this.color,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.textSecondaryDark;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: active ? (color ?? AppColors.atrOrange).withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active ? (color ?? AppColors.atrOrange).withValues(alpha: 0.4) : Colors.white.withValues(alpha: 0.07),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: active ? (color ?? AppColors.atrOrange) : AppColors.textSecondaryDark)),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: active ? c.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('$count', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: active ? c : AppColors.textMutedDark)),
            ),
          ],
        ),
      ),
    );
  }
}
