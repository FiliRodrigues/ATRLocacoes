import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../../core/data/fleet_data.dart';
import '../../core/widgets/app_sidebar.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/atr_page_background.dart';
import '../../core/widgets/atr_top_bar.dart';
import 'custos_provider.dart';
import 'widgets/custos_kpi_row.dart';
import 'maintenance/maintenance_tab.dart';
import 'expenses/expenses_tab.dart';
import 'combustivel/combustivel_tab.dart';

class CustosScreen extends StatefulWidget {
  const CustosScreen({super.key});

  @override
  State<CustosScreen> createState() => _CustosScreenState();
}

class _CustosScreenState extends State<CustosScreen> {
  DateTime? _selectedMonth;
  bool _periodoTotal = false;
  String? _veiculoSelecionado; // null = todos os carros

  String _subtitulo() {
    if (_periodoTotal) return 'Período Total — histórico completo';
    if (_selectedMonth != null) {
      final nomes = const [
        '', 'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
        'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro',
      ];
      return '${nomes[_selectedMonth!.month]} de ${_selectedMonth!.year}';
    }
    final now = DateTime.now();
    final nomes = const [
      '', 'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
      'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro',
    ];
    return '${nomes[now.month]} de ${now.year} - visão consolidada';
  }

  Future<void> _mostrarSeletorMes() async {
    final now = DateTime.now();
    final meses = List.generate(
      12,
      (i) => DateTime(now.year, now.month - i, 1),
    );
    final sentinel = DateTime(1900);
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
              'Filtrar por Período',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(LucideIcons.history),
              title: const Text('Período Total'),
              subtitle: const Text('Todos os registros históricos'),
              onTap: () => Navigator.pop(ctx, sentinel),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(LucideIcons.calendar),
              title: const Text('Mês atual'),
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
      setState(() {
        if (mes == sentinel) {
          _periodoTotal = true;
          _selectedMonth = null;
        } else {
          _periodoTotal = false;
          _selectedMonth = mes;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DefaultTabController(
      length: 3,
      child: AppSidebar(
        child: Scaffold(
          body: AtrPageBackground(
            grid: true,
            child: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(32, 32, 32, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: AtrTopBar(
                                title: 'Custos da Frota',
                                subtitle: _subtitulo(),
                              ),
                            ),
                            const SizedBox(width: 12),
                            _buildMonthChip(isDark),
                            if (_selectedMonth != null || _periodoTotal) ...[
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(LucideIcons.x, size: 16),
                                tooltip: 'Limpar filtro',
                                onPressed: () => setState(() {
                                  _selectedMonth = null;
                                  _periodoTotal = false;
                                }),
                              ),
                            ],
                          ],
                        ),
                        Consumer<CustosProvider>(
                          builder: (_, provider, __) {
                            if (provider.isLoading) {
                              return const SizedBox(height: 80);
                            }
                            return CustosKpiRow(
                              provider: provider,
                              selectedMonth: _selectedMonth,
                              allTime: _periodoTotal,
                              veiculoPlaca: _veiculoSelecionado,
                            );
                          },
                        ),
                        const SizedBox(height: 20),
                        _buildVehicleFilter(isDark),
                        const SizedBox(height: 20),
                        _buildTabBar(context),
                      ],
                    ),
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(32, 24, 32, 32),
                          child: MaintenanceTab(
                            selectedMonth: _selectedMonth,
                            veiculoPlaca: _veiculoSelecionado,
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.fromLTRB(32, 24, 32, 32),
                          child: ExpensesTab(),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(32, 24, 32, 32),
                          child: CombustivelTab(
                            selectedMonth: _selectedMonth,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVehicleFilter(bool isDark) {
    final repo = context.watch<FleetRepository>();
    final frota = repo.frota;

    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.surfaceDark,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0x12FFFFFF)),
            ),
            child: DropdownButtonFormField<String?>(
              initialValue: _veiculoSelecionado,
              decoration: const InputDecoration(
                labelText: 'Veículo',
                labelStyle: TextStyle(fontSize: 12, color: AppColors.textMutedDark),
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                isDense: true,
              ),
              icon: const Icon(LucideIcons.chevronDown, size: 16, color: AppColors.textMutedDark),
              style: const TextStyle(fontSize: 13, color: AppColors.textPrimaryDark, fontWeight: FontWeight.w600),
              dropdownColor: AppColors.surfaceElevatedDark,
              borderRadius: BorderRadius.circular(12),
              items: [
                const DropdownMenuItem<String?>(value: null, child: Text('Todos os carros')),
                ...frota.map((v) => DropdownMenuItem<String?>(
                  value: v.placa,
                  child: Text('${v.nome} (${v.placa})'),
                )),
              ],
              onChanged: (v) => setState(() => _veiculoSelecionado = v),
            ),
          ),
        ),
        if (_veiculoSelecionado != null) ...[
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(LucideIcons.x, size: 16),
            tooltip: 'Limpar veículo',
            style: IconButton.styleFrom(
              backgroundColor: AppColors.surfaceDark,
              foregroundColor: AppColors.textMutedDark,
            ),
            onPressed: () => setState(() => _veiculoSelecionado = null),
          ),
        ],
      ],
    );
  }

  Widget _buildMonthChip(bool isDark) {
    final isActive = _selectedMonth != null || _periodoTotal;
    String label;
    if (_periodoTotal) {
      label = 'Total';
    } else if (_selectedMonth != null) {
      label = DateFormat('MMM/yyyy', 'pt_BR').format(_selectedMonth!);
    } else {
      label = 'Período';
    }
    return Material(
      color: isActive
          ? AppColors.atrOrange.withValues(alpha: 0.1)
          : (isDark ? AppColors.surfaceElevatedDark : AppColors.surfaceLight),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: _mostrarSeletorMes,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isActive
                  ? AppColors.atrOrange.withValues(alpha: 0.3)
                  : (isDark ? AppColors.borderDark : AppColors.borderLight),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _periodoTotal ? LucideIcons.history : LucideIcons.calendarDays,
                size: 14,
                color: isActive ? AppColors.atrOrange : AppColors.textSecondaryLight,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isActive ? AppColors.atrOrange : AppColors.textSecondaryLight,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                LucideIcons.chevronDown,
                size: 12,
                color: isActive ? AppColors.atrOrange : AppColors.textSecondaryLight,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabBar(BuildContext context) {
    return const TabBar(
      indicator: UnderlineTabIndicator(
        borderSide: BorderSide(width: 2, color: AppColors.atrOrange),
      ),
      labelColor: AppColors.atrOrange,
      unselectedLabelColor: AppColors.textSecondaryLight,
      labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
      tabs: [
        Tab(text: 'Manutenções'),
        Tab(text: 'Despesas'),
        Tab(text: 'Combustível'),
      ],
    );
  }
}
