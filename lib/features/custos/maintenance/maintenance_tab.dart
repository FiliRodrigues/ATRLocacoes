import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../../../core/data/custos_models.dart';
import '../../../core/data/fleet_data.dart';
import '../../../core/enums/kanban_column.dart';
import '../../../core/enums/maintenance_priority.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/bento_card.dart';
import '../custos_provider.dart';
import 'maintenance_form_modal.dart';

class MaintenanceTab extends StatefulWidget {
  const MaintenanceTab({super.key});

  @override
  State<MaintenanceTab> createState() => _MaintenanceTabState();
}

class _MaintenanceTabState extends State<MaintenanceTab> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';
  String? _filtroVeiculo;
  bool _mostrarTodosAlertas = false;
  final Set<int> _alertasDispensados = {};

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      setState(() => _query = _searchCtrl.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CustosProvider>();
    final fleet = context.watch<FleetRepository>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildAlerts(context, fleet),
        const SizedBox(height: 16),
        _buildFilterBar(context, fleet),
        const SizedBox(height: 16),
        Expanded(child: _buildKanban(context, provider, fleet)),
      ],
    );
  }

  Widget _buildAlerts(BuildContext context, FleetRepository fleet) {
    final now = DateTime.now();
    final alertas = <_AlertaMant>[];

    for (final v in fleet.frota) {
      if (v.kmParaProxRevisao < 1500) {
        alertas.add(
          _AlertaMant(
            texto: 'Revisao proxima - ${v.nome} (${v.placa})',
            cor: Colors.orange,
          ),
        );
      }
      if (v.vencimentoIPVA.difference(now).inDays < 30) {
        alertas.add(
          _AlertaMant(
            texto: 'IPVA a vencer - ${v.placa}',
            cor: Colors.amber,
          ),
        );
      }
      if (v.vencimentoSeguro.difference(now).inDays < 30) {
        alertas.add(
          _AlertaMant(
            texto: 'Seguro a vencer - ${v.placa}',
            cor: Colors.amber,
          ),
        );
      }
    }

    final visiveis = <MapEntry<int, _AlertaMant>>[];
    for (var i = 0; i < alertas.length; i++) {
      if (!_alertasDispensados.contains(i)) {
        visiveis.add(MapEntry(i, alertas[i]));
      }
    }

    if (visiveis.isEmpty) return const SizedBox.shrink();

    final itens = _mostrarTodosAlertas ? visiveis : visiveis.take(3).toList();
    final extras = visiveis.length - itens.length;

    return Column(
      children: [
        for (final entry in itens)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: entry.value.cor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(
                    LucideIcons.alertTriangle,
                    size: 16,
                    color: entry.value.cor,
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(entry.value.texto)),
                  IconButton(
                    onPressed: () {
                      setState(() => _alertasDispensados.add(entry.key));
                    },
                    icon: Icon(LucideIcons.x, size: 16, color: entry.value.cor),
                  ),
                ],
              ),
            ),
          ),
        if (extras > 0 || _mostrarTodosAlertas)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () {
                setState(() => _mostrarTodosAlertas = !_mostrarTodosAlertas);
              },
              child: Text(
                _mostrarTodosAlertas ? 'Ver menos' : 'Ver todos (+$extras)',
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildFilterBar(BuildContext context, FleetRepository fleet) {
    return Row(
      children: [
        Flexible(
          child: DropdownButtonFormField<String?>(
            initialValue: _filtroVeiculo,
            decoration: const InputDecoration(
              isDense: true,
              labelText: 'Veiculo',
              border: OutlineInputBorder(),
            ),
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('Todos os veiculos'),
              ),
              ...fleet.frota.map(
                (v) => DropdownMenuItem<String?>(
                  value: v.placa,
                  child: Text('${v.nome} (${v.placa})'),
                ),
              ),
            ],
            onChanged: (value) => setState(() => _filtroVeiculo = value),
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Theme.of(context).dividerTheme.color!),
            ),
            child: Row(
              children: [
                const Icon(
                  LucideIcons.search,
                  size: 16,
                  color: AppColors.textSecondaryLight,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    decoration: const InputDecoration(
                      isDense: true,
                      hintText: 'Buscar titulo, placa ou fornecedor...',
                      hintStyle: TextStyle(
                        color: AppColors.textSecondaryLight,
                        fontSize: 14,
                      ),
                      border: InputBorder.none,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const Spacer(),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.atrOrange),
          onPressed: () async {
            final result = await MaintenanceFormModal.show(
              context,
              fleet: fleet,
            );
            if (!context.mounted || result == null) return;
            await context.read<CustosProvider>().addManutencao(result);
          },
          icon: const Icon(LucideIcons.plus),
          label: const Text('Nova OS'),
        ),
      ],
    );
  }

  Widget _buildKanban(
    BuildContext context,
    CustosProvider provider,
    FleetRepository fleet,
  ) {
    List<ManutencaoItem> filtrar(List<ManutencaoItem> source) {
      return source.where((item) {
        if (_filtroVeiculo != null && item.veiculoPlaca != _filtroVeiculo) {
          return false;
        }
        if (_query.isEmpty) return true;
        return item.titulo.toLowerCase().contains(_query) ||
            item.veiculoPlaca.toLowerCase().contains(_query) ||
            item.fornecedor.toLowerCase().contains(_query);
      }).toList();
    }

    final pendentes = filtrar(provider.pendentes);
    final emOficina = filtrar(provider.emOficina);
    final concluidos = filtrar(provider.concluidos);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 1100;

        final pendingColumn = _buildKanbanColumn(
          context,
          KanbanColumn.pendentes,
          pendentes,
          provider,
          fleet,
        );
        final ongoingColumn = _buildKanbanColumn(
          context,
          KanbanColumn.emOficina,
          emOficina,
          provider,
          fleet,
        );
        final completedColumn = _buildKanbanColumn(
          context,
          KanbanColumn.concluidos,
          concluidos,
          provider,
          fleet,
        );

        if (!isMobile) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: pendingColumn),
              const SizedBox(width: 24),
              Expanded(child: ongoingColumn),
              const SizedBox(width: 24),
              Expanded(child: completedColumn),
            ],
          );
        }

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: 1020,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: 324, child: pendingColumn),
                const SizedBox(width: 24),
                SizedBox(width: 324, child: ongoingColumn),
                const SizedBox(width: 24),
                SizedBox(width: 324, child: completedColumn),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildKanbanColumn(
    BuildContext context,
    KanbanColumn coluna,
    List<ManutencaoItem> itens,
    CustosProvider provider,
    FleetRepository fleet,
  ) {
    final bool isConcluded = coluna == KanbanColumn.concluidos;
    final bgBase = Theme.of(context).brightness == Brightness.dark
        ? AppColors.surfaceElevatedDark
        : AppColors.surfaceLight.withValues(alpha: 0.6);

    return DragTarget<ManutencaoItem>(
      onWillAcceptWithDetails: (_) => true,
      onAcceptWithDetails: (details) {
        provider.moverKanban(details.data.id, coluna);
      },
      builder: (context, candidateData, rejectedData) {
        final isOver = candidateData.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isConcluded
                ? AppColors.statusSuccess.withValues(alpha: 0.08)
                : (isOver
                    ? AppColors.atrOrange.withValues(alpha: 0.05)
                    : bgBase),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isOver
                  ? AppColors.atrOrange
                  : Theme.of(context)
                      .dividerTheme
                      .color!
                      .withValues(alpha: 0.5),
            ),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    coluna.label,
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontSize: 18),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${itens.length}',
                      style: const TextStyle(
                        color: AppColors.textSecondaryLight,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  itemCount: itens.length,
                  itemBuilder: (context, index) {
                    final item = itens[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _buildKanbanCard(context, item, provider, fleet),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildKanbanCard(
    BuildContext context,
    ManutencaoItem item,
    CustosProvider provider,
    FleetRepository fleet,
  ) {
    final card = BentoCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildPrioridadeBadge(item.prioridade),
              Row(
                children: [
                  IconButton(
                    iconSize: 14,
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(
                      LucideIcons.edit2,
                      size: 14,
                      color: AppColors.textSecondaryLight,
                    ),
                    onPressed: () async {
                      final result = await MaintenanceFormModal.show(
                        context,
                        fleet: fleet,
                        item: item,
                      );
                      if (result != null) {
                        await provider.updateManutencao(result);
                      }
                    },
                  ),
                  IconButton(
                    iconSize: 14,
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(
                      LucideIcons.trash2,
                      size: 14,
                      color: AppColors.statusError,
                    ),
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Confirmar exclusao'),
                          content: Text("Excluir OS '${item.titulo}'?"),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(false),
                              child: const Text('Cancelar'),
                            ),
                            ElevatedButton(
                              onPressed: () => Navigator.of(context).pop(true),
                              child: const Text('Excluir'),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        await provider.deleteManutencao(item.id);
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            item.titulo,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(
                LucideIcons.car,
                size: 12,
                color: AppColors.textSecondaryLight,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  '${item.veiculoNome} • ${item.veiculoPlaca}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondaryLight,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(
                LucideIcons.calendar,
                size: 12,
                color: AppColors.textSecondaryLight,
              ),
              const SizedBox(width: 4),
              Text(
                formatDate(item.data),
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondaryLight,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(
                LucideIcons.dollarSign,
                size: 12,
                color: AppColors.textSecondaryLight,
              ),
              const SizedBox(width: 4),
              Text(
                formatCurrency(item.custo),
                style:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          if (item.fornecedor.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(
                  LucideIcons.building,
                  size: 12,
                  color: AppColors.textSecondaryLight,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    item.fornecedor,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondaryLight,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );

    return Draggable<ManutencaoItem>(
      data: item,
      feedback: Material(
        color: Colors.transparent,
        child: Opacity(opacity: 0.7, child: SizedBox(width: 300, child: card)),
      ),
      childWhenDragging: Opacity(opacity: 0.35, child: card),
      child: card,
    );
  }

  Widget _buildPrioridadeBadge(MaintenancePriority priority) {
    Color bg;
    Color fg;
    switch (priority) {
      case MaintenancePriority.alta:
        bg = AppColors.statusError.withValues(alpha: 0.15);
        fg = AppColors.statusError;
        break;
      case MaintenancePriority.media:
        bg = Colors.amber.withValues(alpha: 0.15);
        fg = Colors.amber.shade800;
        break;
      case MaintenancePriority.baixa:
        bg = AppColors.statusInfo.withValues(alpha: 0.15);
        fg = AppColors.statusInfo;
        break;
      case MaintenancePriority.ok:
        bg = AppColors.statusSuccess.withValues(alpha: 0.15);
        fg = AppColors.statusSuccess;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        priority.label,
        style: TextStyle(
          color: fg,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _AlertaMant {
  final String texto;
  final Color cor;

  const _AlertaMant({required this.texto, required this.cor});
}
