import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_sidebar.dart';
import 'locacao_provider.dart';
import '../../core/data/locacao_models.dart';
import 'widgets/contrato_form_sheet.dart';
import 'contrato_detalhe_screen.dart';

final _brl = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
final _dateFmt = DateFormat('dd/MM/yyyy');

class ContratosScreen extends StatefulWidget {
  const ContratosScreen({super.key});

  @override
  State<ContratosScreen> createState() => _ContratosScreenState();
}

class _ContratosScreenState extends State<ContratosScreen> {
  ContratoStatus? _filtroStatus;
  String _busca = '';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final provider = context.watch<LocacaoProvider>();
    final contratos = provider.contratos
        .where((c) => _filtroStatus == null || c.status == _filtroStatus)
        .where((c) =>
            _busca.isEmpty ||
            c.clienteNome.toLowerCase().contains(_busca.toLowerCase()) ||
            c.numero.toLowerCase().contains(_busca.toLowerCase()) ||
            c.veiculoPlaca.toLowerCase().contains(_busca.toLowerCase()))
        .toList();

    final bgColor = isDark ? AppColors.backgroundDark : AppColors.backgroundLight;

    return AppSidebar(
      child: Scaffold(
        backgroundColor: bgColor,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context, isDark, provider),
            _buildFiltros(isDark),
            Expanded(
              child: provider.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : contratos.isEmpty
                      ? _buildEmpty(isDark)
                      : _buildLista(contratos, isDark),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isDark, LocacaoProvider provider) {
    return Container(
      padding: const EdgeInsets.fromLTRB(28, 28, 28, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Contratos de Locação',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: isDark
                          ? AppColors.textPrimaryDark
                          : AppColors.textPrimaryLight,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${provider.contratosAtivos.length} contratos ativos · ${_brl.format(provider.receitaMensalAtiva)}/mês',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: () => _abrirFormContrato(context),
                icon: const Icon(LucideIcons.plus, size: 16),
                label: const Text('Novo Contrato'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.atrOrange,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildMetrics(isDark, provider),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildMetrics(bool isDark, LocacaoProvider provider) {
    final cards = [
      _MetricData('Contratos Ativos', '${provider.contratosAtivos.length}',
          LucideIcons.fileCheck2, AppColors.statusSuccess),
      _MetricData('Receita Mensal', _brl.format(provider.receitaMensalAtiva),
          LucideIcons.trendingUp, AppColors.atrOrange),
      _MetricData('Ocorrências Abertas', '${provider.ocorrenciasAbertas}',
          LucideIcons.alertTriangle, AppColors.statusWarning),
      _MetricData('Impacto Financeiro',
          _brl.format(provider.impactoFinanceiroTotal),
          LucideIcons.alertCircle, AppColors.statusError),
    ];
    return Row(
      children: cards
          .map((d) => Expanded(child: Padding(
                padding: const EdgeInsets.only(right: 12),
                child: _MetricCard(data: d, isDark: isDark),
              )))
          .toList(),
    );
  }

  Widget _buildFiltros(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 0, 28, 16),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 40,
              child: TextField(
                onChanged: (v) => setState(() => _busca = v),
                decoration: InputDecoration(
                  hintText: 'Buscar por cliente, nº contrato ou placa...',
                  prefixIcon: const Icon(LucideIcons.search, size: 16),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: isDark
                          ? AppColors.borderDark
                          : AppColors.borderLight,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          _FiltroChip(
            label: 'Todos',
            isSelected: _filtroStatus == null,
            onTap: () => setState(() => _filtroStatus = null),
            isDark: isDark,
          ),
          ...ContratoStatus.values.map((s) => _FiltroChip(
                label: s.label,
                isSelected: _filtroStatus == s,
                onTap: () => setState(() => _filtroStatus = s),
                isDark: isDark,
                color: s.color,
              )),
        ],
      ),
    );
  }

  Widget _buildLista(List<Contrato> contratos, bool isDark) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(28, 0, 28, 28),
      itemCount: contratos.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (ctx, i) => _ContratoCard(
        contrato: contratos[i],
        isDark: isDark,
        onTap: () => Navigator.push(
          ctx,
          MaterialPageRoute(
            builder: (_) => ContratoDetalheScreen(contratoId: contratos[i].id),
          ),
        ),
      ),
    );
  }

  Widget _buildEmpty(bool isDark) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.fileX2, size: 48,
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
          const SizedBox(height: 12),
          Text(
            'Nenhum contrato encontrado',
            style: TextStyle(
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
            ),
          ),
        ],
      ),
    );
  }

  void _abrirFormContrato(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const ContratoFormSheet(),
    );
  }
}

// ── Widgets internos ──────────────────────────────────

class _MetricData {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _MetricData(this.label, this.value, this.icon, this.color);
}

class _MetricCard extends StatelessWidget {
  final _MetricData data;
  final bool isDark;
  const _MetricCard({required this.data, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: data.color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(data.icon, size: 18, color: data.color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimaryLight,
                  ),
                ),
                Text(
                  data.label,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ContratoCard extends StatelessWidget {
  final Contrato contrato;
  final bool isDark;
  final VoidCallback onTap;
  const _ContratoCard({required this.contrato, required this.isDark, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? AppColors.borderDark : AppColors.borderLight,
          ),
        ),
        child: Row(
          children: [
            // Status indicator
            Container(
              width: 4,
              height: 48,
              margin: const EdgeInsets.only(right: 16),
              decoration: BoxDecoration(
                color: contrato.status.color,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        contrato.numero,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.atrOrange,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _StatusBadge(status: contrato.status),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    contrato.clienteNome,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: isDark
                          ? AppColors.textPrimaryDark
                          : AppColors.textPrimaryLight,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${contrato.veiculoPlaca} · ${_dateFmt.format(contrato.dataInicio)} – ${_dateFmt.format(contrato.dataFim)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                    ),
                  ),
                ],
              ),
            ),
            // Valor
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _brl.format(contrato.valorMensal),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimaryLight,
                  ),
                ),
                Text(
                  'por mês',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.speed,
                        size: 12,
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight),
                    const SizedBox(width: 4),
                    Text(
                      '${contrato.slaKmMes} km/mês',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(width: 12),
            Icon(LucideIcons.chevronRight,
                size: 18,
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final ContratoStatus status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: status.color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: status.color,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _FiltroChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isDark;
  final Color? color;
  const _FiltroChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.isDark,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final chipColor = color ?? AppColors.atrOrange;
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? chipColor.withValues(alpha: 0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected
                  ? chipColor
                  : (isDark ? AppColors.borderDark : AppColors.borderLight),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected
                  ? chipColor
                  : (isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight),
            ),
          ),
        ),
      ),
    );
  }
}
