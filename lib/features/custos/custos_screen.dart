import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/widgets/app_sidebar.dart';
import '../../core/theme/app_colors.dart';
import 'custos_provider.dart';
import 'widgets/custos_kpi_row.dart';
import 'maintenance/maintenance_tab.dart';
import 'expenses/expenses_tab.dart';

class CustosScreen extends StatelessWidget {
  const CustosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: AppSidebar(
        child: Scaffold(
          body: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(32, 32, 32, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(context),
                      const SizedBox(height: 24),
                      Consumer<CustosProvider>(
                        builder: (_, provider, __) {
                          if (provider.isLoading) {
                            return const SizedBox(height: 80);
                          }
                          return CustosKpiRow(provider: provider);
                        },
                      ),
                      const SizedBox(height: 24),
                      _buildTabBar(context),
                    ],
                  ),
                ),
                Expanded(
                  child: const TabBarView(
                    children: [
                      Padding(
                        padding: EdgeInsets.fromLTRB(32, 24, 32, 32),
                        child: MaintenanceTab(),
                      ),
                      Padding(
                        padding: EdgeInsets.fromLTRB(32, 24, 32, 32),
                        child: ExpensesTab(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final now = DateTime.now();
    const meses = [
      '',
      'Janeiro',
      'Fevereiro',
      'Março',
      'Abril',
      'Maio',
      'Junho',
      'Julho',
      'Agosto',
      'Setembro',
      'Outubro',
      'Novembro',
      'Dezembro',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Custos da Frota',
          style:
              Theme.of(context).textTheme.displayLarge?.copyWith(fontSize: 28),
        ),
        const SizedBox(height: 4),
        Text(
          '${meses[now.month]} de ${now.year} - visão consolidada',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
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
      ],
    );
  }
}
