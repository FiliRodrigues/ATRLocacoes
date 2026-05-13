import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants.dart';
import '../../../core/data/custos_models.dart';
import '../../../core/data/fleet_data.dart';
import '../../../core/enums/kanban_column.dart';
import '../../../core/enums/maintenance_priority.dart';
import '../../../core/services/audit_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/export_csv_stub.dart'
    if (dart.library.html) '../../../core/utils/export_csv_html.dart'
    if (dart.library.io) '../../../core/utils/export_csv_io.dart';
import '../../../core/widgets/atr_button.dart';
import '../custos_provider.dart';
import 'maintenance_form_modal.dart';

class MaintenanceTab extends StatefulWidget {
  final DateTime? selectedMonth;
  final String? veiculoPlaca; // null = todos os carros
  const MaintenanceTab({super.key, this.selectedMonth, this.veiculoPlaca});

  @override
  State<MaintenanceTab> createState() => _MaintenanceTabState();
}

class _MaintenanceTabState extends State<MaintenanceTab> {
  final _buscaCtrl = TextEditingController();
  String _busca = '';
  String? _filtroTipo; // null=todos, 'prev', 'corr'
  Set<String> _selectedIds = {};
  bool _bulkProcessing = false;

  bool get _selectionMode => _selectedIds.isNotEmpty;

  static final _brl = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
  static final _dateFmt = DateFormat('dd/MM/yy');

  @override
  void initState() {
    super.initState();
    _buscaCtrl.addListener(() => setState(() => _busca = _buscaCtrl.text.trim().toLowerCase()));
  }

  @override
  void dispose() {
    _buscaCtrl.dispose();
    super.dispose();
  }

  List<ManutencaoItem> _applyFilters(List<ManutencaoItem> source) {
    return source.where((item) {
      if (_filtroTipo == 'prev' && !item.isPreventiva) return false;
      if (_filtroTipo == 'corr' && item.isPreventiva) return false;
      if (widget.selectedMonth != null) {
        final m = widget.selectedMonth!;
        if (item.data.year != m.year || item.data.month != m.month) return false;
      }
      if (_busca.isNotEmpty) {
        return item.titulo.toLowerCase().contains(_busca) ||
            item.veiculoPlaca.toLowerCase().contains(_busca) ||
            item.fornecedor.toLowerCase().contains(_busca);
      }
      return true;
    }).toList();
  }

  Future<void> _editItem(ManutencaoItem item, FleetRepository fleet, CustosProvider provider) async {
    final result = await MaintenanceFormModal.show(context, fleet: fleet, item: item);
    if (result != null) await provider.updateManutencao(result);
  }

  Future<void> _deleteItem(ManutencaoItem item, CustosProvider provider) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar exclusão'),
        content: Text("Excluir OS '${item.titulo}'?"),
        actions: [
          AtrGhostButton(label: 'Cancelar', onPressed: () => Navigator.pop(ctx, false)),
          const SizedBox(width: 8),
          AtrPrimaryButton(label: 'Excluir', onPressed: () => Navigator.pop(ctx, true)),
        ],
      ),
    );
    if (confirm != true) return;
    final tenantId = AuditService.currentTenantId ?? kDefaultTenantId;
    final savedData = <String, dynamic>{
      'id': item.id,
      'veiculo_placa': item.veiculoPlaca,
      'veiculo_nome': item.veiculoNome,
      'titulo': item.titulo,
      'descricao': item.descricao,
      'tipo': item.tipo,
      'data': item.data.toIso8601String(),
      'km_no_servico': item.kmNoServico,
      'odometro': item.odometro,
      'custo': item.custo,
      'prioridade': item.prioridade.name,
      'coluna': item.coluna.name,
      'fornecedor': item.fornecedor,
      'numero_os': item.numeroOS,
      'nome_anexo': item.nomeAnexo,
      'is_preventiva': item.isPreventiva,
      'data_conclusao': item.dataConclusao?.toIso8601String(),
      'tenant_id': tenantId,
    };
    await provider.deleteManutencao(item.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: const Text('Manutenção excluída'),
          action: SnackBarAction(
            label: 'Desfazer',
            onPressed: () async {
              await Supabase.instance.client.from('manutencoes').insert(savedData);
              if (context.mounted) {
                await context.read<CustosProvider>().refresh();
              }
            },
          ),
          duration: const Duration(seconds: 4),
        ),
      );
  }

  Future<void> _newOS(FleetRepository fleet) async {
    final result = await MaintenanceFormModal.show(
      context,
      fleet: fleet,
      veiculoPre: widget.veiculoPlaca,
    );
    if (!context.mounted || result == null) return;
    await context.read<CustosProvider>().addManutencao(result);
  }

  // ── Seleção múltipla ──

  void _toggleItemSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _toggleSelectAll(List<ManutencaoItem> itens) {
    setState(() {
      if (_selectedIds.length == itens.length) {
        _selectedIds.clear();
      } else {
        _selectedIds = itens.map((i) => i.id).toSet();
      }
    });
  }

  Widget _buildSelectionBar(List<ManutencaoItem> itens, CustosProvider provider) {
    final naoConcluidas = itens
        .where((i) => _selectedIds.contains(i.id) && i.coluna != KanbanColumn.concluidos)
        .length;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.atrOrange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.atrOrange.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => _toggleSelectAll(itens),
            child: Row(
              children: [
                Icon(
                  _selectedIds.length == itens.length
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
          if (naoConcluidas > 0)
            AtrPrimaryButton(
              label: _bulkProcessing ? 'Processando...' : 'Concluir ($naoConcluidas)',
              onPressed: _bulkProcessing ? null : () => _bulkConcluir(provider),
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

  Future<void> _bulkConcluir(CustosProvider provider) async {
    final toComplete = <ManutencaoItem>[];
    for (final pool in [provider.pendentes, provider.emOficina, provider.concluidos]) {
      for (final item in pool) {
        if (_selectedIds.contains(item.id) && item.coluna != KanbanColumn.concluidos) {
          toComplete.add(item);
        }
      }
    }
    if (toComplete.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Concluir manutenções?'),
        content: Text('Deseja mover ${toComplete.length} OS para Concluídas?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Confirmar')),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _bulkProcessing = true);
    try {
      for (final item in toComplete) {
        final concluido = ManutencaoItem(
          id: item.id,
          veiculoPlaca: item.veiculoPlaca,
          veiculoNome: item.veiculoNome,
          titulo: item.titulo,
          descricao: item.descricao,
          tipo: item.tipo,
          data: item.data,
          kmNoServico: item.kmNoServico,
          odometro: item.odometro,
          custo: item.custo,
          prioridade: item.prioridade,
          coluna: KanbanColumn.concluidos,
          fornecedor: item.fornecedor,
          numeroOS: item.numeroOS,
          nomeAnexo: item.nomeAnexo,
          isPreventiva: item.isPreventiva,
          dataConclusao: DateTime.now(),
        );
        await provider.updateManutencao(concluido);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${toComplete.length} OS concluída(s).')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao concluir: $e')),
        );
      }
    } finally {
      if (mounted) setState(() { _selectedIds.clear(); _bulkProcessing = false; });
    }
  }

  // ── Exportação CSV ──

  Future<void> _exportCsv(List<ManutencaoItem> itens) async {
    final buffer = StringBuffer();
    buffer.writeln(
      '"VEICULO";"TITULO";"TIPO";"DATA";"FORNECEDOR";"CUSTO";"KM";"PRIORIDADE";"STATUS PGTO";"COLUNA"',
    );

    for (final i in itens) {
      final tipoStr = i.isPreventiva ? 'Preventiva' : 'Corretiva';
      final dataStr = _dateFmt.format(i.data);
      final custoStr = i.custo.toStringAsFixed(2).replaceAll('.', ',');
      final kmStr = i.kmNoServico.toString();
      final prioridadeStr = i.prioridade.label;
      final colunaStr = i.coluna.label;

      buffer.writeln(
        '${_csvField(i.veiculoPlaca)};${_csvField(i.titulo)};${_csvField(tipoStr)};${_csvField(dataStr)};${_csvField(i.fornecedor)};${_csvField(custoStr)};${_csvField(kmStr)};${_csvField(prioridadeStr)};${_csvField('Pago')};${_csvField(colunaStr)}',
      );
    }

    try {
      final fileName =
          'manutencoes_export_${DateTime.now().millisecondsSinceEpoch}.csv';
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

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CustosProvider>();
    final fleet = context.watch<FleetRepository>();

    final todosConcluidos = widget.veiculoPlaca != null
        ? provider.concluidos.where((m) => m.veiculoPlaca == widget.veiculoPlaca).toList()
        : provider.concluidos;

    final filtrados = _applyFilters(todosConcluidos);
    final vehicle = widget.veiculoPlaca != null
        ? fleet.frota.firstWhere((v) => v.placa == widget.veiculoPlaca, orElse: () => fleet.frota.first)
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFilterBar(filtrados),
        const SizedBox(height: 14),
        if (_selectionMode)
          _buildSelectionBar(filtrados, provider),
        if (vehicle != null)
          Expanded(child: _buildVehicleDossier(vehicle, todosConcluidos, filtrados, provider, fleet))
        else
          Expanded(child: _buildAllVehiclesList(filtrados, provider, fleet)),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════
  // FILTER BAR (simplificada, sem dropdown veículo)
  // ═══════════════════════════════════════════════════════

  Widget _buildFilterBar(List<ManutencaoItem> filtrados) {
    return Row(
      children: [
        _buildTypeToggle(),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: AppColors.surfaceDark,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0x12FFFFFF)),
            ),
            child: Row(
              children: [
                const Icon(LucideIcons.search, size: 14, color: AppColors.textMutedDark),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _buscaCtrl,
                    decoration: const InputDecoration(
                      isDense: true,
                      hintText: 'Buscar título, placa ou fornecedor...',
                      hintStyle: TextStyle(color: AppColors.textMutedDark, fontSize: 12),
                      border: InputBorder.none,
                    ),
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'csv') {
              _exportCsv(filtrados);
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
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.surfaceDark,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0x12FFFFFF)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(LucideIcons.download, size: 14, color: AppColors.textMutedDark),
                SizedBox(width: 6),
                Text(
                  'Exportar',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMutedDark,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        AtrPrimaryButton(
          label: 'Nova OS',
          icon: LucideIcons.plus,
          onPressed: () => _newOS(context.read<FleetRepository>()),
        ),
      ],
    );
  }

  Widget _buildTypeToggle() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0x12FFFFFF)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(9),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _toggleBtn('Todos', null),
            _toggleBtn('Preventiva', 'prev'),
            _toggleBtn('Corretiva', 'corr'),
          ],
        ),
      ),
    );
  }

  Widget _toggleBtn(String label, String? valor) {
    final ativo = _filtroTipo == valor;
    return InkWell(
      onTap: () => setState(() => _filtroTipo = valor),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: ativo ? AppColors.atrOrange.withValues(alpha: 0.15) : Colors.transparent,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: ativo ? AppColors.atrOrange : AppColors.textMutedDark,
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // ALL VEHICLES LIST
  // ═══════════════════════════════════════════════════════

  Widget _buildAllVehiclesList(List<ManutencaoItem> itens, CustosProvider provider, FleetRepository fleet) {
    if (itens.isEmpty) {
      return const Center(
        child: Text('Nenhuma manutenção concluída.', style: TextStyle(color: AppColors.textMutedDark, fontSize: 13)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: itens.length,
      itemBuilder: (_, i) {
        final item = itens[i];
        return _MaintenanceCard(
          item: item,
          isSelected: _selectedIds.contains(item.id),
          showCheckbox: _selectionMode,
          onTap: () {
            if (_selectionMode) {
              _toggleItemSelection(item.id);
            } else {
              _editItem(item, fleet, provider);
            }
          },
          onEdit: () => _editItem(item, fleet, provider),
          onDelete: () => _deleteItem(item, provider),
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════
  // VEHICLE DOSSIER
  // ═══════════════════════════════════════════════════════

  Widget _buildVehicleDossier(
    VehicleData vehicle,
    List<ManutencaoItem> todosConcluidos,
    List<ManutencaoItem> filtrados,
    CustosProvider provider,
    FleetRepository fleet,
  ) {
    final totalGasto = todosConcluidos.fold(0.0, (s, m) => s + m.custo);
    final custosMensais = _buildMonthlyCosts(todosConcluidos);

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Vehicle header
          _buildVehicleHeader(vehicle, todosConcluidos.length, totalGasto),
          const SizedBox(height: 20),
          // Monthly cost cards
          if (custosMensais.isNotEmpty) ...[
            _buildMonthlyCards(custosMensais),
            const SizedBox(height: 20),
            // Bar chart
            _buildBarChart(custosMensais),
            const SizedBox(height: 24),
          ],
          // Maintenance list
          Text(
            'Manutenções Concluídas',
            style: GoogleFonts.syne(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimaryDark),
          ),
          const SizedBox(height: 10),
          if (filtrados.isEmpty)
            const Text('Nenhuma manutenção no período.', style: TextStyle(color: AppColors.textMutedDark, fontSize: 13))
          else
            ...filtrados.map((item) => _MaintenanceCard(
              item: item,
              isSelected: _selectedIds.contains(item.id),
              showCheckbox: _selectionMode,
              onTap: () {
                if (_selectionMode) {
                  _toggleItemSelection(item.id);
                } else {
                  _editItem(item, fleet, provider);
                }
              },
              onEdit: () => _editItem(item, fleet, provider),
              onDelete: () => _deleteItem(item, provider),
            )),
        ],
      ),
    );
  }

  Widget _buildVehicleHeader(VehicleData v, int totalOS, double totalGasto) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x12FFFFFF)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [v.cor1, v.cor2]),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(LucideIcons.car, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      v.placa,
                      style: const TextStyle(
                        fontFamily: 'RobotoMono',
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                        color: AppColors.textPrimaryDark,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      v.nome,
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondaryDark),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '$totalOS OS concluídas · Total: ${_brl.format(totalGasto)}',
                  style: const TextStyle(fontSize: 12, color: AppColors.textMutedDark),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // MONTHLY COSTS
  // ═══════════════════════════════════════════════════════

  List<MapEntry<String, _MesCusto>> _buildMonthlyCosts(List<ManutencaoItem> itens) {
    final map = <String, _MesCusto>{};
    for (final m in itens) {
      final key = '${m.data.year}-${m.data.month.toString().padLeft(2, '0')}';
      map.putIfAbsent(key, () => _MesCusto(ano: m.data.year, mes: m.data.month));
      map[key]!.custo += m.custo;
      map[key]!.count++;
    }
    final sorted = map.entries.toList()..sort((a, b) => b.key.compareTo(a.key));
    return sorted.take(12).toList();
  }

  Widget _buildMonthlyCards(List<MapEntry<String, _MesCusto>> meses) {
    final nomes = const ['', 'Jan', 'Fev', 'Mar', 'Abr', 'Mai', 'Jun', 'Jul', 'Ago', 'Set', 'Out', 'Nov', 'Dez'];
    final now = DateTime.now();
    final currentKey = '${now.year}-${now.month.toString().padLeft(2, '0')}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Gastos Mensais',
          style: GoogleFonts.syne(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimaryDark),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 100,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: meses.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, i) {
              final e = meses[i];
              final m = e.value;
              final label = '${nomes[m.mes]}/${m.ano.toString().substring(2)}';
              final isCurrent = e.key == currentKey;
              return Container(
                width: 120,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceDark,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isCurrent ? AppColors.atrOrange.withValues(alpha: 0.5) : const Color(0x12FFFFFF),
                    width: isCurrent ? 1.5 : 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: isCurrent ? AppColors.atrOrange : AppColors.textSecondaryDark,
                      ),
                    ),
                    const SizedBox(height: 6),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        _brl.format(m.custo),
                        maxLines: 1,
                        style: const TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.statusError,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${m.count} OS',
                      style: const TextStyle(fontSize: 10, color: AppColors.textMutedDark),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildBarChart(List<MapEntry<String, _MesCusto>> meses) {
    if (meses.isEmpty) return const SizedBox.shrink();

    final nomes = const ['', 'Jan', 'Fev', 'Mar', 'Abr', 'Mai', 'Jun', 'Jul', 'Ago', 'Set', 'Out', 'Nov', 'Dez'];
    final maxCusto = meses.map((e) => e.value.custo).reduce((a, b) => a > b ? a : b);
    final reversed = meses.reversed.toList();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x12FFFFFF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Evolução de Custos',
                style: GoogleFonts.syne(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimaryDark),
              ),
              const Spacer(),
              Text(
                'últimos ${reversed.length} meses',
                style: const TextStyle(fontSize: 11, color: AppColors.textMutedDark),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 160,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: reversed.map((e) {
                final m = e.value;
                final label = '${nomes[m.mes]}/${m.ano.toString().substring(2)}';
                final ratio = maxCusto > 0 ? m.custo / maxCusto : 0.0;
                final barHeight = 20 + (ratio * 120);

                final t = ratio.clamp(0.0, 1.0);
                final barColor = Color.lerp(AppColors.statusInfo, AppColors.statusError, t)!;

                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Tooltip(
                      message: '$label: ${_brl.format(m.custo)} (${m.count} OS)',
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 400),
                            curve: Curves.easeOutCubic,
                            height: barHeight,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                                colors: [barColor, barColor.withValues(alpha: 0.5)],
                              ),
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            label,
                            style: const TextStyle(fontSize: 9, color: AppColors.textMutedDark, fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
// MAINTENANCE CARD (simples, usado em ambas as listas)
// ═══════════════════════════════════════════════════════

class _MaintenanceCard extends StatelessWidget {
  final ManutencaoItem item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onTap;
  final bool isSelected;
  final bool showCheckbox;

  const _MaintenanceCard({
    required this.item,
    required this.onEdit,
    required this.onDelete,
    this.onTap,
    this.isSelected = false,
    this.showCheckbox = false,
  });

  Color get _prioColor {
    switch (item.prioridade) {
      case MaintenancePriority.alta: return AppColors.statusError;
      case MaintenancePriority.media: return AppColors.statusWarning;
      case MaintenancePriority.baixa: return AppColors.statusInfo;
      case MaintenancePriority.ok: return AppColors.statusSuccess;
    }
  }

  @override
  Widget build(BuildContext context) {
    final brl = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    final dateFmt = DateFormat('dd/MM/yy');

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isSelected
            ? AppColors.atrOrange.withValues(alpha: 0.08)
            : AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected
              ? AppColors.atrOrange.withValues(alpha: 0.4)
              : const Color(0x12FFFFFF),
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            left: 0, top: 0, bottom: 0,
            child: Container(
              width: 3,
              decoration: BoxDecoration(
                color: _prioColor,
                borderRadius: const BorderRadius.horizontal(left: Radius.circular(11)),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (showCheckbox) ...[
                      Icon(
                        isSelected ? LucideIcons.checkSquare : LucideIcons.square,
                        size: 16,
                        color: isSelected ? AppColors.atrOrange : AppColors.textMutedDark,
                      ),
                      const SizedBox(width: 8),
                    ],
                    Expanded(
                      child: Text(
                        item.titulo,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimaryDark),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    _TypeBadge(isPreventiva: item.isPreventiva),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Container(
                      width: 7, height: 7,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: _prioColor),
                    ),
                    const SizedBox(width: 4),
                    Text(item.veiculoPlaca, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textPrimaryDark)),
                    const SizedBox(width: 4),
                    const Text('·', style: TextStyle(color: AppColors.textMutedDark)),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(item.veiculoNome, style: const TextStyle(fontSize: 11, color: AppColors.textMutedDark), overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(LucideIcons.calendar, size: 11, color: AppColors.textMutedDark),
                    const SizedBox(width: 3),
                    Text(dateFmt.format(item.data), style: const TextStyle(fontSize: 11, color: AppColors.textMutedDark)),
                    const SizedBox(width: 4),
                    const Text('·', style: TextStyle(color: AppColors.textMutedDark)),
                    const SizedBox(width: 4),
                    Text(
                      brl.format(item.custo),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: item.custo > 0 ? AppColors.statusSuccess : AppColors.textMutedDark,
                      ),
                    ),
                    if (item.fornecedor.isNotEmpty) ...[
                      const SizedBox(width: 4),
                      const Text('·', style: TextStyle(color: AppColors.textMutedDark)),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(item.fornecedor, style: const TextStyle(fontSize: 11, color: AppColors.textMutedDark), overflow: TextOverflow.ellipsis),
                      ),
                    ],
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: onEdit,
                      borderRadius: BorderRadius.circular(6),
                      child: const Icon(LucideIcons.pencil, size: 13, color: AppColors.textMutedDark),
                    ),
                    const SizedBox(width: 4),
                    InkWell(
                      onTap: onDelete,
                      borderRadius: BorderRadius.circular(6),
                      child: const Icon(LucideIcons.trash2, size: 13, color: AppColors.textMutedDark),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
// TYPE BADGE
// ═══════════════════════════════════════════════════════

class _TypeBadge extends StatelessWidget {
  final bool isPreventiva;
  const _TypeBadge({required this.isPreventiva});

  @override
  Widget build(BuildContext context) {
    final color = isPreventiva ? AppColors.statusInfo : AppColors.statusWarning;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        isPreventiva ? 'PREV' : 'CORR',
        style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 0.4, color: color),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
// HELPERS
// ═══════════════════════════════════════════════════════

class _MesCusto {
  final int ano;
  final int mes;
  double custo = 0;
  int count = 0;
  _MesCusto({required this.ano, required this.mes});
}
