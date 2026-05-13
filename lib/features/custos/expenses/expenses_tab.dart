import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/data/custos_models.dart';
import '../custos_provider.dart';
import '../../../core/data/fleet_data.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/atr_button.dart';
import '../../../core/widgets/bento_card.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../core/widgets/atr_top_bar.dart';

import '../widgets/custos_filter_bar.dart';
import 'expense_form_modal.dart';

import '../../../core/utils/export_csv_stub.dart'
    if (dart.library.html) '../../../core/utils/export_csv_html.dart'
    if (dart.library.io) '../../../core/utils/export_csv_io.dart';

class ExpensesTab extends StatefulWidget {
  const ExpensesTab({super.key});

  @override
  State<ExpensesTab> createState() => _ExpensesTabState();
}

class _ExpensesTabState extends State<ExpensesTab> {
  // ── Filtros ──
  String? _veiculoSelecionado;
  String? _tipoSelecionado;
  DateTimeRange? _periodoSelecionado;
  bool? _statusPago;

  // ── Ordenação ──
  String _colunaOrdenacao = 'data';
  bool _ordemAscendente = false;

  // ── Paginação ──
  int _paginaAtual = 0;
  static const int _itensPorPagina = 15;

  final Set<String> _togglingIds = {};

  // ── Multi-select ──
  Set<String> _selectedIds = {};
  bool _selectionMode = false;
  bool _bulkProcessing = false;

  List<DespesaItem> _despesasFiltradas(CustosProvider provider) {
    var lista = provider.despesas.toList();

    // Filtro: Veículo
    if (_veiculoSelecionado != null) {
      lista =
          lista.where((d) => d.veiculoPlaca == _veiculoSelecionado).toList();
    }

    // Filtro: Tipo
    if (_tipoSelecionado != null) {
      lista = lista.where((d) => d.tipo == _tipoSelecionado).toList();
    }

    // Filtro: Período
    if (_periodoSelecionado != null) {
      lista = lista.where((d) {
        // Zera as horas para comparar apenas os dias
        final dData = DateTime(d.data.year, d.data.month, d.data.day);
        final start = DateTime(_periodoSelecionado!.start.year,
            _periodoSelecionado!.start.month, _periodoSelecionado!.start.day);
        final end = DateTime(_periodoSelecionado!.end.year,
            _periodoSelecionado!.end.month, _periodoSelecionado!.end.day);

        return dData.isAtSameMomentAs(start) ||
            dData.isAtSameMomentAs(end) ||
            (dData.isAfter(start) && dData.isBefore(end));
      }).toList();
    }

    // Filtro: Status (Pago/Pendente)
    if (_statusPago != null) {
      lista = lista.where((d) => d.pago == _statusPago).toList();
    }

    // Ordenação
    lista.sort((a, b) {
      int result = 0;
      if (_colunaOrdenacao == 'data') {
        result = a.data.compareTo(b.data);
      } else if (_colunaOrdenacao == 'valor') {
        result = a.valor.compareTo(b.valor);
      }
      return _ordemAscendente ? result : -result;
    });

    return lista;
  }

  void _onFiltroChanged() {
    setState(() {
      _paginaAtual = 0; // Resetar sempre que filtro mudar
    });
  }

  void _mudarOrdenacao(String coluna) {
    setState(() {
      if (_colunaOrdenacao == coluna) {
        _ordemAscendente = !_ordemAscendente;
      } else {
        _colunaOrdenacao = coluna;
        _ordemAscendente = false; // Padrão: decrescente para data/valor
      }
      _paginaAtual = 0;
    });
  }

  // ── Multi-select ──

  void _toggleSelectionMode() {
    setState(() {
      _selectionMode = !_selectionMode;
      if (!_selectionMode) _selectedIds.clear();
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

  void _toggleSelectAll(List<DespesaItem> visibleItems) {
    setState(() {
      final allSelected =
          visibleItems.every((d) => _selectedIds.contains(d.id));
      if (allSelected) {
        for (final d in visibleItems) {
          _selectedIds.remove(d.id);
        }
      } else {
        for (final d in visibleItems) {
          _selectedIds.add(d.id);
        }
      }
    });
  }

  Future<void> _bulkSetPago(CustosProvider provider, bool pago) async {
    final count = _selectedIds.length;
    final ids = _selectedIds.toList();
    setState(() => _bulkProcessing = true);
    try {
      for (final id in ids) {
        await Supabase.instance.client
            .from('despesas')
            .update({'pago': pago}).eq('id', id);
      }
      // Atualiza estado local
      for (final id in ids) {
        final idx = provider.despesas.indexWhere((d) => d.id == id);
        if (idx != -1) {
          final updated = provider.despesas[idx].copyWith(pago: pago);
          await provider.updateDespesa(updated);
        }
      }
      _selectedIds.clear();
      _selectionMode = false;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(pago
                  ? '$count despesas marcadas como pagas'
                  : '$count despesas marcadas como pendentes')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _bulkProcessing = false);
    }
  }

  Future<void> _bulkDelete(CustosProvider provider) async {
    final count = _selectedIds.length;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir Despesas'),
        content: Text('Excluir $count despesas selecionadas?'),
        actions: [
          AtrGhostButton(
            label: 'Cancelar',
            onPressed: () => Navigator.pop(ctx, false),
          ),
          const SizedBox(width: 8),
          AtrGhostButton(
            label: 'Excluir',
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    // Backup para undo
    final backups = <DespesaItem>[];
    for (final id in _selectedIds.toList()) {
      final idx = provider.despesas.indexWhere((d) => d.id == id);
      if (idx != -1) backups.add(provider.despesas[idx]);
    }

    setState(() => _bulkProcessing = true);
    try {
      for (final id in _selectedIds.toList()) {
        await provider.deleteDespesa(id);
      }
      _selectedIds.clear();
      _selectionMode = false;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$count despesas excluídas'),
            action: SnackBarAction(
              label: 'Desfazer',
              onPressed: () async {
                for (final item in backups) {
                  await provider.addDespesa(item);
                }
              },
            ),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao excluir: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _bulkProcessing = false);
    }
  }

  Widget _buildSelectionBar(CustosProvider provider) {
    if (_selectedIds.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevatedDark,
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: AppColors.atrOrange.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(LucideIcons.checkSquare,
              size: 18, color: AppColors.atrOrange),
          const SizedBox(width: 10),
          Text(
            '${_selectedIds.length} selecionados',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: AppColors.textPrimaryDark,
            ),
          ),
          const Spacer(),
          if (_bulkProcessing)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          _selectionBarButton(
            icon: LucideIcons.check,
            label: 'Marcar Pago',
            color: AppColors.statusSuccess,
            onPressed:
                _bulkProcessing ? null : () => _bulkSetPago(provider, true),
          ),
          const SizedBox(width: 8),
          _selectionBarButton(
            icon: LucideIcons.x,
            label: 'Marcar Pendente',
            color: AppColors.statusWarning,
            onPressed:
                _bulkProcessing ? null : () => _bulkSetPago(provider, false),
          ),
          const SizedBox(width: 8),
          _selectionBarButton(
            icon: LucideIcons.trash2,
            label: 'Excluir',
            color: AppColors.statusError,
            onPressed:
                _bulkProcessing ? null : () => _bulkDelete(provider),
          ),
          const SizedBox(width: 8),
          _selectionBarButton(
            icon: LucideIcons.xCircle,
            label: 'Cancelar',
            color: AppColors.textSecondaryDark,
            onPressed:
                _bulkProcessing ? null : _toggleSelectionMode,
          ),
        ],
      ),
    );
  }

  Widget _selectionBarButton({
    required IconData icon,
    required String label,
    required Color color,
    VoidCallback? onPressed,
  }) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(color: color.withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Escuta o provider para atualizar a lista automaticamente
    final provider = context.watch<CustosProvider>();

    final todasDespesas = _despesasFiltradas(provider);
    final totalPaginas = (todasDespesas.length / _itensPorPagina).ceil();

    // Evita _paginaAtual out of bounds
    if (_paginaAtual >= totalPaginas && totalPaginas > 0) {
      _paginaAtual = totalPaginas - 1;
    }

    final startIndex = _paginaAtual * _itensPorPagina;
    final endIndex = (startIndex + _itensPorPagina > todasDespesas.length)
        ? todasDespesas.length
        : startIndex + _itensPorPagina;

    final despesasPaginadas = todasDespesas.sublist(
      startIndex,
      endIndex < startIndex ? startIndex : endIndex,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AtrTopBar(
          title: 'Despesas Operacionais',
          subtitle: 'Gestão de custos e comprovantes.',
          actions: [
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'csv') {
                  _exportCsv(todasDespesas);
                } else if (value == 'pdf') {
                  _exportPdf(todasDespesas);
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
                PopupMenuItem(
                  value: 'pdf',
                  child: Row(
                    children: [
                      Icon(LucideIcons.fileText, size: 16),
                      SizedBox(width: 8),
                      Text('Exportar PDF'),
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
            InkWell(
              onTap: _toggleSelectionMode,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: _selectionMode
                        ? AppColors.atrOrange
                        : AppColors.borderLight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  color: _selectionMode
                      ? AppColors.atrOrange.withValues(alpha: 0.1)
                      : Theme.of(context).colorScheme.surface,
                ),
                child: Row(
                  children: [
                    Icon(
                      LucideIcons.listChecks,
                      size: 16,
                      color: _selectionMode
                          ? AppColors.atrOrange
                          : AppColors.textSecondaryLight,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Selecionar',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: _selectionMode
                            ? AppColors.atrOrange
                            : AppColors.textSecondaryLight,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            AtrPrimaryButton(
              label: 'Lançamento Rápido',
              icon: LucideIcons.plus,
              onPressed: () async {
                final newItem = await ExpenseFormModal.show(context);
                if (newItem != null && context.mounted) {
                  context.read<CustosProvider>().addDespesa(newItem);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Despesa adicionada com sucesso!')),
                  );
                }
              },
            ),
          ],
        ),
        const SizedBox(height: 24),

        // ── Filtros ──
        CustosFilterBar(
          veiculoSelecionado: _veiculoSelecionado,
          tipoSelecionado: _tipoSelecionado,
          periodoSelecionado: _periodoSelecionado,
          statusPago: _statusPago,
          showPagoFilter: true,
          placasDisponiveis:
              FleetRepository.instance.frota.map((v) => v.placa).toList(),
          tiposDisponiveis: ExpenseFormModal.tiposDespesa,
          onVeiculoChanged: (v) {
            _veiculoSelecionado = v;
            _onFiltroChanged();
          },
          onTipoChanged: (t) {
            _tipoSelecionado = t;
            _onFiltroChanged();
          },
          onPeriodoChanged: (p) {
            _periodoSelecionado = p;
            _onFiltroChanged();
          },
          onStatusPagoChanged: (s) {
            _statusPago = s;
            _onFiltroChanged();
          },
          onLimparFiltros: () {
            _veiculoSelecionado = null;
            _tipoSelecionado = null;
            _periodoSelecionado = null;
            _statusPago = null;
            _onFiltroChanged();
          },
        ),
        const SizedBox(height: 24),

        // ── Barra de multi-select ──
        _buildSelectionBar(provider),

        // ── Tabela ──
        BentoCard(
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildTableHeader(context, visibleItems: despesasPaginadas),
              if (despesasPaginadas.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(48.0),
                  child: Center(
                    child: Text(
                      'Nenhuma despesa encontrada com os filtros atuais.',
                      style: TextStyle(color: AppColors.textSecondaryLight),
                    ),
                  ),
                )
              else
                ...despesasPaginadas.map(
                  (d) => Column(
                    children: [
                      _buildTableRow(context, d),
                      const Divider(height: 1),
                    ],
                  ),
                ),
              if (todasDespesas.isNotEmpty)
                _buildTableFooter(todasDespesas.length, totalPaginas),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTableHeader(BuildContext context,
      {List<DespesaItem>? visibleItems}) {
    final allSelected = _selectionMode &&
        visibleItems != null &&
        visibleItems.isNotEmpty &&
        visibleItems.every((d) => _selectedIds.contains(d.id));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
      decoration: BoxDecoration(
        color: AppColors.atrOrange.withValues(alpha: 0.05),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Row(
        children: [
          if (_selectionMode) ...[
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Checkbox(
                value: allSelected,
                onChanged: (_) => _toggleSelectAll(visibleItems!),
                activeColor: AppColors.atrOrange,
                checkColor: AppColors.backgroundDark,
                side: const BorderSide(
                    color: AppColors.textSecondaryLight, width: 1.5),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4)),
              ),
            ),
          ],
          // DATA (Clicável)
          Expanded(
            flex: 2,
            child: InkWell(
              onTap: () => _mudarOrdenacao('data'),
              child: Row(
                children: [
                  const Text(
                    'DATA',
                    style: TextStyle(
                      color: AppColors.atrOrange,
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                      letterSpacing: 0.5,
                    ),
                  ),
                  if (_colunaOrdenacao == 'data') ...[
                    const SizedBox(width: 4),
                    Icon(
                      _ordemAscendente
                          ? LucideIcons.chevronUp
                          : LucideIcons.chevronDown,
                      size: 14,
                      color: AppColors.atrOrange,
                    ),
                  ]
                ],
              ),
            ),
          ),
          const Expanded(
            flex: 3,
            child: Text(
              'TIPO / DESCRIÇÃO',
              style: TextStyle(
                color: AppColors.atrOrange,
                fontWeight: FontWeight.w800,
                fontSize: 11,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const Expanded(
            flex: 2,
            child: Text(
              'VEÍCULO',
              style: TextStyle(
                color: AppColors.atrOrange,
                fontWeight: FontWeight.w800,
                fontSize: 11,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const Expanded(
            flex: 2,
            child: Text(
              'STATUS',
              style: TextStyle(
                color: AppColors.atrOrange,
                fontWeight: FontWeight.w800,
                fontSize: 11,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const Expanded(
            child: Text(
              'ANEXO',
              style: TextStyle(
                color: AppColors.atrOrange,
                fontWeight: FontWeight.w800,
                fontSize: 11,
                letterSpacing: 0.5,
              ),
            ),
          ),
          // VALOR (Clicável)
          Expanded(
            flex: 2,
            child: InkWell(
              onTap: () => _mudarOrdenacao('valor'),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (_colunaOrdenacao == 'valor') ...[
                    Icon(
                      _ordemAscendente
                          ? LucideIcons.chevronUp
                          : LucideIcons.chevronDown,
                      size: 14,
                      color: AppColors.atrOrange,
                    ),
                    const SizedBox(width: 4),
                  ],
                  const Text(
                    'VALOR',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: AppColors.atrOrange,
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 48), // Espaço para as actions
        ],
      ),
    );
  }

  Widget _buildTableRow(BuildContext context, DespesaItem d) {
    final isSelected = _selectedIds.contains(d.id);

    final row = Row(
      children: [
        if (_selectionMode) ...[
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Checkbox(
              value: isSelected,
              onChanged: (_) => _toggleItemSelection(d.id),
              activeColor: AppColors.atrOrange,
              checkColor: AppColors.backgroundDark,
              side: const BorderSide(
                  color: AppColors.textSecondaryLight, width: 1.5),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4)),
            ),
          ),
        ],
        Expanded(
          flex: 2,
          child: Text(
            formatDate(d.data),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        Expanded(
          flex: 3,
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.atrOrange.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  d.tipo == 'Manutenção' || d.tipo == 'Revisão'
                      ? LucideIcons.wrench
                      : LucideIcons.receipt,
                  size: 14,
                  color: AppColors.atrOrange,
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      d.tipo,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontSize: 14),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (d.descricao.isNotEmpty)
                      Text(
                        d.descricao,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondaryLight,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    if (d.nf.isNotEmpty)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            LucideIcons.receipt,
                            size: 10,
                            color: AppColors.atrOrange,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            'NF ${d.nf}',
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppColors.atrOrange,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          flex: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                d.veiculoPlaca,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
              Text(
                d.motorista,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondaryLight,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          flex: 2,
          child: Align(
            alignment: Alignment.centerLeft,
            child: _togglingIds.contains(d.id)
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : _selectionMode
                    ? StatusBadge(
                        text: d.pago ? 'PAGO' : 'PENDENTE',
                        type:
                            d.pago ? BadgeType.success : BadgeType.warning,
                      )
                    : InkWell(
                        onTap: () async {
                          setState(() => _togglingIds.add(d.id));
                          final updated = d.copyWith(pago: !d.pago);
                          try {
                            await context
                                .read<CustosProvider>()
                                .updateDespesa(updated);
                          } catch (_) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content:
                                        Text('Erro ao atualizar status')),
                              );
                            }
                          } finally {
                            if (mounted) {
                              setState(() => _togglingIds.remove(d.id));
                            }
                          }
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: StatusBadge(
                          text: d.pago ? 'PAGO' : 'PENDENTE',
                          type: d.pago
                              ? BadgeType.success
                              : BadgeType.warning,
                        ),
                      ),
          ),
        ),
        Expanded(
          child: InkWell(
            onTap: () {
              if (d.nomeAnexo.isNotEmpty) {
                _viewAnexo(context, d.nomeAnexo);
              }
            },
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.all(4.0),
              child: d.nomeAnexo.isNotEmpty
                  ? Tooltip(
                      message: d.nomeAnexo,
                      child: const Icon(
                        LucideIcons.fileText,
                        size: 18,
                        color: AppColors.statusInfo,
                      ),
                    )
                  : Icon(
                      LucideIcons.fileMinus,
                      size: 18,
                      color: AppColors.textSecondaryLight
                          .withValues(alpha: 0.2),
                    ),
            ),
          ),
        ),
        Expanded(
          flex: 2,
          child: Text(
            formatCurrency(d.valor),
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppColors.statusError,
            ),
          ),
        ),
        const SizedBox(width: 16),
        _buildActions(context, d),
      ],
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: _selectionMode
          ? InkWell(
              onTap: () => _toggleItemSelection(d.id),
              borderRadius: BorderRadius.circular(8),
              child: row,
            )
          : row,
    );
  }

  Widget _buildActions(BuildContext context, DespesaItem item) {
    return PopupMenuButton<String>(
      icon: const Icon(
        LucideIcons.moreHorizontal,
        size: 18,
        color: AppColors.textSecondaryLight,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: (val) async {
        if (val == 'edit') {
          final updated = await ExpenseFormModal.show(context, item: item);
          if (updated != null && context.mounted) {
            context.read<CustosProvider>().updateDespesa(updated);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Despesa atualizada com sucesso!')),
            );
          }
        } else if (val == 'delete') {
          final confirm = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Excluir Despesa'),
              content:
                  Text('Excluir despesa de ${formatCurrency(item.valor)}?'),
              actions: [
                AtrGhostButton(
                  label: 'Cancelar',
                  onPressed: () => Navigator.pop(ctx, false),
                ),
                const SizedBox(width: 8),
                AtrGhostButton(
                  label: 'Excluir',
                  onPressed: () => Navigator.pop(ctx, true),
                ),
              ],
            ),
          );
          if (confirm == true && context.mounted) {
            final savedData = item;
            await context.read<CustosProvider>().deleteDespesa(item.id);
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Despesa excluída'),
                action: SnackBarAction(
                  label: 'Desfazer',
                  onPressed: () async {
                    await context
                        .read<CustosProvider>()
                        .addDespesa(savedData);
                  },
                ),
                duration: const Duration(seconds: 5),
              ),
            );
          }
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'edit',
          child: Row(
            children: [
              Icon(LucideIcons.edit2, size: 14),
              SizedBox(width: 12),
              Text('Editar', style: TextStyle(fontSize: 13)),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(LucideIcons.trash2, size: 14, color: Colors.red),
              SizedBox(width: 12),
              Text(
                'Excluir',
                style: TextStyle(fontSize: 13, color: Colors.red),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTableFooter(int total, int totalPaginas) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.atrOrange.withValues(alpha: 0.02),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Total de $total registros encontrados',
            style: const TextStyle(
              color: AppColors.textSecondaryLight,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (totalPaginas > 1)
            Row(
              children: [
                IconButton(
                  icon: const Icon(LucideIcons.chevronLeft, size: 18),
                  onPressed: _paginaAtual > 0
                      ? () => setState(() => _paginaAtual--)
                      : null,
                ),
                Text(
                  '${_paginaAtual + 1} de $totalPaginas',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(LucideIcons.chevronRight, size: 18),
                  onPressed: _paginaAtual < totalPaginas - 1
                      ? () => setState(() => _paginaAtual++)
                      : null,
                ),
              ],
            ),
        ],
      ),
    );
  }

  Future<void> _viewAnexo(BuildContext ctx, String nomeAnexo) async {
    final url = Supabase.instance.client.storage
        .from('atr-attachments')
        .getPublicUrl(nomeAnexo);
    final lower = nomeAnexo.toLowerCase();
    final isImage = lower.endsWith('.png') ||
        lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.gif') ||
        lower.endsWith('.webp');
    final isPdf = lower.endsWith('.pdf');

    if (isImage) {
      if (!mounted) return;
      showDialog(
        context: ctx,
        builder: (dialogCtx) => Dialog(
          backgroundColor: Colors.transparent,
          child: Stack(
            children: [
              InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: Image.network(
                  url,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => const Center(
                    child: Text('Erro ao carregar anexo',
                        style: TextStyle(color: Colors.white)),
                  ),
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    );
                  },
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  icon: const Icon(LucideIcons.x, color: Colors.white),
                  onPressed: () => Navigator.pop(dialogCtx),
                ),
              ),
            ],
          ),
        ),
      );
    } else if (isPdf) {
      try {
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(ctx).showSnackBar(
            const SnackBar(content: Text('Erro ao abrir PDF')),
          );
        }
      }
    } else {
      try {
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(ctx).showSnackBar(
            const SnackBar(content: Text('Erro ao abrir anexo')),
          );
        }
      }
    }
  }

  // ── Funções de Exportação ──

  Future<void> _exportCsv(List<DespesaItem> itens) async {
    final buffer = StringBuffer();
    // Cabeçalho
    buffer.writeln(
      '"DATA";"TIPO";"DESCRIÇÃO";"NF";"VEÍCULO";"MOTORISTA";"STATUS";"VALOR"',
    );

    for (final i in itens) {
      final dateStr = formatDate(i.data);
      final pagoStr = i.pago ? 'Pago' : 'Pendente';
      final valorStr = i.valor.toStringAsFixed(2).replaceAll('.', ',');
      buffer.writeln(
        '${_csvField(dateStr)};${_csvField(i.tipo)};${_csvField(i.descricao)};${_csvField(i.nf)};${_csvField(i.veiculoPlaca)};${_csvField(i.motorista)};${_csvField(pagoStr)};${_csvField(valorStr)}',
      );
    }

    try {
      final fileName =
          'despesas_export_${DateTime.now().millisecondsSinceEpoch}.csv';
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

  Future<void> _exportPdf(List<DespesaItem> itens) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            pw.Header(
              level: 0,
              child: pw.Text('Relatório de Despesas Operacionais',
                  style: pw.TextStyle(
                      fontSize: 24, fontWeight: pw.FontWeight.bold)),
            ),
            pw.SizedBox(height: 16),
            pw.TableHelper.fromTextArray(
              context: context,
              headers: ['Data', 'Tipo', 'Veículo', 'Status', 'Valor'],
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              headerDecoration:
                  const pw.BoxDecoration(color: PdfColors.grey300),
              data: itens.map((i) {
                return [
                  formatDate(i.data),
                  i.tipo,
                  i.veiculoPlaca,
                  i.pago ? 'Pago' : 'Pendente',
                  formatCurrency(i.valor),
                ];
              }).toList(),
            ),
            pw.SizedBox(height: 24),
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text(
                'Total: ${formatCurrency(itens.fold(0.0, (sum, item) => sum + item.valor))}',
                style:
                    pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
              ),
            ),
          ];
        },
      ),
    );

    try {
      await Printing.sharePdf(
        bytes: await pdf.save(),
        filename:
            'despesas_relatorio_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao exportar PDF: $e')),
        );
      }
    }
  }

  String _csvField(String value) {
    final escaped = value.replaceAll('"', '""');
    return '"$escaped"';
  }
}
