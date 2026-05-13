import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/atr_page_background.dart';
import '../../core/widgets/atr_top_bar.dart';
import '../../core/widgets/app_sidebar.dart';
import '../../core/widgets/atr_button.dart';
import '../../core/widgets/atr_kpi_card.dart';
import 'locacao_provider.dart';
import '../../core/data/locacao_models.dart';
import 'widgets/contrato_form_sheet.dart';
import 'contrato_detalhe_screen.dart';

import '../../core/utils/export_csv_stub.dart'
    if (dart.library.html) '../../core/utils/export_csv_html.dart'
    if (dart.library.io) '../../core/utils/export_csv_io.dart';

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
  Set<String> _selectedIds = {};
  bool _bulkProcessing = false;

  bool get _selectionMode => _selectedIds.isNotEmpty;

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

    return AppSidebar(
      child: Scaffold(
        body: AtrPageBackground(
          grid: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(context, isDark, provider, contratos),
                    _buildMetrics(isDark, provider),
                  ],
                ),
              ),
              _buildFiltros(isDark),
              if (_selectionMode) _buildSelectionBar(contratos, isDark),
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
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isDark, LocacaoProvider provider, List<Contrato> contratos) {
    return AtrTopBar(
      title: 'Contratos de Locação',
      subtitle: '${provider.contratosAtivos.length} contratos ativos · ${_brl.format(provider.receitaMensalAtiva)}/mês',
      actions: [
        PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'csv') {
              _exportCsv(contratos);
            }
          },
          itemBuilder: (context) => const [
            PopupMenuItem(
              value: 'csv',
              child: Row(
                children: [
                  Icon(LucideIcons.fileSpreadsheet, size: 16),
                  SizedBox(width: 8),
                  Text('Exportar CSV'),
                ],
              ),
            ),
          ],
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.borderLight),
              borderRadius: BorderRadius.circular(12),
              color: Theme.of(context).colorScheme.surface,
            ),
            child: const Row(
              children: [
                Icon(LucideIcons.download,
                    size: 16, color: AppColors.textSecondaryLight),
                SizedBox(width: 8),
                Text(
                  'Exportar',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondaryLight,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        AtrPrimaryButton(
          label: 'Novo Contrato',
          icon: LucideIcons.plus,
          onPressed: () => _abrirFormContrato(context),
        ),
      ],
    );
  }

  Widget _buildMetrics(bool isDark, LocacaoProvider provider) {
    return Row(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 12),
            child: AtrKpiCard(
              label: 'Contratos Ativos',
              value: '${provider.contratosAtivos.length}',
              icon: LucideIcons.fileCheck2,
              tone: KpiTone.success,
            ),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 12),
            child: AtrKpiCard(
              label: 'Receita Mensal',
              value: _brl.format(provider.receitaMensalAtiva),
              icon: LucideIcons.trendingUp,
              tone: KpiTone.orange,
            ),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 12),
            child: AtrKpiCard(
              label: 'Ocorrências Abertas',
              value: '${provider.ocorrenciasAbertas}',
              icon: LucideIcons.alertTriangle,
              tone: KpiTone.warning,
            ),
          ),
        ),
        Expanded(
          child: AtrKpiCard(
            label: 'Impacto Financeiro',
            value: _brl.format(provider.impactoFinanceiroTotal),
            icon: LucideIcons.alertCircle,
            tone: KpiTone.error,
          ),
        ),
      ],
    );
  }

  void _toggleSelectAll(List<Contrato> contratos) {
    setState(() {
      if (_selectedIds.length == contratos.length) {
        _selectedIds.clear();
      } else {
        _selectedIds = contratos.map((c) => c.id).toSet();
      }
    });
  }

  void _toggleItemSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  Widget _buildSelectionBar(List<Contrato> contratos, bool isDark) {
    final ativosSelecionados = contratos
        .where((c) => _selectedIds.contains(c.id) && c.status == ContratoStatus.ativo)
        .length;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.atrOrange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.atrOrange.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => _toggleSelectAll(contratos),
            child: Row(
              children: [
                Icon(
                  _selectedIds.length == contratos.length
                      ? LucideIcons.checkSquare
                      : LucideIcons.square,
                  size: 16,
                  color: AppColors.atrOrange,
                ),
                const SizedBox(width: 8),
                Text(
                  '${_selectedIds.length} selecionados',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: AppColors.atrOrange,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          if (ativosSelecionados > 0)
            AtrPrimaryButton(
              label: _bulkProcessing ? 'Processando...' : 'Encerrar ($ativosSelecionados)',
              onPressed: _bulkProcessing ? null : () => _bulkEncerrar(contratos),
            ),
          const SizedBox(width: 8),
          AtrGhostButton(
            label: 'Cancelar',
            onPressed: () => setState(() => _selectedIds.clear()),
          ),
        ],
      ),
    );
  }

  Future<void> _bulkEncerrar(List<Contrato> contratos) async {
    final toClose = contratos
        .where((c) => _selectedIds.contains(c.id) && c.status == ContratoStatus.ativo)
        .toList();
    if (toClose.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Encerrar contratos?'),
        content: Text('Deseja encerrar ${toClose.length} contrato(s) ativo(s)?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Confirmar')),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _bulkProcessing = true);
    try {
      for (final c in toClose) {
        await context.read<LocacaoProvider>().encerrarContrato(c.id);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${toClose.length} contrato(s) encerrado(s).')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao encerrar: $e')),
        );
      }
    } finally {
      if (mounted) setState(() { _selectedIds.clear(); _bulkProcessing = false; });
    }
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
        isSelected: _selectedIds.contains(contratos[i].id),
        showCheckbox: _selectionMode,
        onTap: () {
          if (_selectionMode) {
            _toggleItemSelection(contratos[i].id);
          } else {
            Navigator.push(
              ctx,
              MaterialPageRoute(
                builder: (_) => ContratoDetalheScreen(contratoId: contratos[i].id),
              ),
            );
          }
        },
        onLongPress: () => _toggleItemSelection(contratos[i].id),
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

  Future<void> _exportCsv(List<Contrato> itens) async {
    final buffer = StringBuffer();
    buffer.writeln(
      '"NUMERO";"CLIENTE";"CNPJ";"PLACA";"DATA INICIO";"DATA FIM";"SLA KM/MES";"VALOR MENSAL";"STATUS"',
    );

    for (final c in itens) {
      final valorStr = c.valorMensal.toStringAsFixed(2).replaceAll('.', ',');
      buffer.writeln(
        '${_csvField(c.numero)};${_csvField(c.clienteNome)};${_csvField(c.clienteCnpj)};${_csvField(c.veiculoPlaca)};${_csvField(_dateFmt.format(c.dataInicio))};${_csvField(_dateFmt.format(c.dataFim))};${_csvField(c.slaKmMes.toString())};${_csvField(valorStr)};${_csvField(c.status.label)}',
      );
    }

    try {
      final fileName =
          'contratos_export_${DateTime.now().millisecondsSinceEpoch}.csv';
      await exportCsv(fileName, buffer.toString());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('CSV exportado: $fileName')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao exportar CSV: $e')),
        );
      }
    }
  }

  String _csvField(String value) {
    final escaped = value.replaceAll('"', '""');
    return '"$escaped"';
  }
}

// ── Widgets internos ──────────────────────────────────

class _ContratoCard extends StatelessWidget {
  final Contrato contrato;
  final bool isDark;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool isSelected;
  final bool showCheckbox;
  const _ContratoCard({
    required this.contrato,
    required this.isDark,
    required this.onTap,
    this.onLongPress,
    this.isSelected = false,
    this.showCheckbox = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.atrOrange.withValues(alpha: 0.08)
              : isDark
                  ? AppColors.surfaceDark
                  : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? AppColors.atrOrange.withValues(alpha: 0.4)
                : isDark
                    ? AppColors.borderDark
                    : AppColors.borderLight,
          ),
        ),
        child: Row(
          children: [
            if (showCheckbox) ...[
              Icon(
                isSelected ? LucideIcons.checkSquare : LucideIcons.square,
                size: 18,
                color: isSelected ? AppColors.atrOrange : AppColors.textMutedDark,
              ),
              const SizedBox(width: 10),
            ],
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
