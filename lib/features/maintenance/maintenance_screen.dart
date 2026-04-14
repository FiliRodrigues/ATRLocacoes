import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../../core/widgets/app_sidebar.dart';
import '../../core/widgets/bento_card.dart';
import '../../core/theme/app_colors.dart';
import 'maintenance_provider.dart';

class MaintenanceScreen extends StatefulWidget {
  const MaintenanceScreen({super.key});

  @override
  State<MaintenanceScreen> createState() => _MaintenanceScreenState();
}

class _MaintenanceScreenState extends State<MaintenanceScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    final nextQuery = _searchCtrl.text.toLowerCase();
    if (nextQuery == _query) return;
    setState(() => _query = nextQuery);
  }

  @override
  void dispose() {
    _searchCtrl.removeListener(_onSearchChanged);
    _searchCtrl.dispose();
    super.dispose();
  }

  List<MaintenanceItem> _filter(List<MaintenanceItem> items) {
    if (_query.isEmpty) return items;
    return items
        .where(
          (e) =>
              e.title.toLowerCase().contains(_query) ||
              e.vehicle.toLowerCase().contains(_query),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return AppSidebar(
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(context),
                const SizedBox(height: 32),
                Expanded(
                  child: Consumer<MaintenanceProvider>(
                    builder: (context, provider, child) {
                      return LayoutBuilder(
                        builder: (context, constraints) {
                          final isMobile = constraints.maxWidth < 1100;
                          final filteredPending = _filter(provider.pending);
                          final filteredOngoing = _filter(provider.ongoing);
                          final filteredCompleted = _filter(provider.completed);

                          final pendingColumn = _buildKanbanColumn(
                            context,
                            KanbanColumn.pendentes.label,
                            filteredPending
                                .map((item) => _buildKanbanCard(context, item))
                                .toList(),
                            onAccept: (item) =>
                                provider.moveItem(item, KanbanColumn.pendentes),
                          );
                          final ongoingColumn = _buildKanbanColumn(
                            context,
                            KanbanColumn.emOficina.label,
                            filteredOngoing
                                .map((item) => _buildKanbanCard(context, item))
                                .toList(),
                            onAccept: (item) =>
                                provider.moveItem(item, KanbanColumn.emOficina),
                          );
                          final completedColumn = _buildKanbanColumn(
                            context,
                            KanbanColumn.concluidos.label,
                            filteredCompleted
                                .map((item) => _buildKanbanCard(context, item))
                                .toList(),
                            onAccept: (item) => provider.moveItem(
                                item, KanbanColumn.concluidos,),
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
                    },
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
    return Row(
      children: [
        Flexible(
            child: Text('Quadro de Manutenções',
                style: Theme.of(context)
                    .textTheme
                    .displayLarge
                    ?.copyWith(fontSize: 28),
                overflow: TextOverflow.ellipsis,),),
        const SizedBox(width: 24),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 300),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border:
                    Border.all(color: Theme.of(context).dividerTheme.color!),),
            child: Row(
              children: [
                const Icon(LucideIcons.search,
                    size: 16, color: AppColors.textSecondaryLight,),
                const SizedBox(width: 8),
                Expanded(
                    child: TextField(
                        controller: _searchCtrl,
                        decoration: const InputDecoration(
                            isDense: true,
                            hintText: 'Buscar OS ou Placa...',
                            hintStyle: TextStyle(
                                color: AppColors.textSecondaryLight,
                                fontSize: 14,),
                            border: InputBorder.none,),),),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Theme.of(context).dividerTheme.color!),),
          child: const Icon(LucideIcons.filter, size: 18, color: AppColors.atrOrange),
        ),
      ],
    );
  }

  Widget _buildKanbanColumn(
    BuildContext context,
    String title,
    List<Widget> cards, {
    required ValueChanged<MaintenanceItem> onAccept,
  }) {
    final Color bgColor = Theme.of(context).brightness == Brightness.dark
        ? AppColors.surfaceElevatedDark
        : AppColors.surfaceLight.withValues(alpha: 0.6);

    return DragTarget<MaintenanceItem>(
      onWillAcceptWithDetails: (details) => true,
      onAcceptWithDetails: (details) => onAccept(details.data),
      builder: (context, candidateData, rejectedData) {
        final isOver = candidateData.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color:
                isOver ? AppColors.atrOrange.withValues(alpha: 0.05) : bgColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: isOver
                    ? AppColors.atrOrange
                    : Theme.of(context)
                        .dividerTheme
                        .color!
                        .withValues(alpha: 0.5),),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(title,
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontSize: 18),),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                        color: Theme.of(context).scaffoldBackgroundColor,
                        borderRadius: BorderRadius.circular(12),),
                    child: Text('${cards.length}',
                        style: const TextStyle(
                            color: AppColors.textSecondaryLight,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,),),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView(
                  children: cards
                      .map(
                        (c) => Padding(
                          padding: const EdgeInsets.only(bottom: 12.0),
                          child: c,
                        ),
                      )
                      .toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildKanbanCard(BuildContext context, MaintenanceItem item) {
    final bool isHighPriority = item.priority == MaintenancePriority.alta;
    final bool isFinished = item.isDone;

    final Widget cardChild = BentoCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isFinished
                      ? AppColors.statusSuccess.withValues(alpha: 0.15)
                      : (isHighPriority
                          ? AppColors.statusError.withValues(alpha: 0.15)
                          : Theme.of(context).scaffoldBackgroundColor),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  item.priority.label,
                  style: TextStyle(
                    color: isFinished
                        ? AppColors.statusSuccess
                        : (isHighPriority
                            ? AppColors.statusError
                            : AppColors.textSecondaryLight),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Icon(LucideIcons.moreHorizontal,
                  size: 16, color: AppColors.textSecondaryLight,),
            ],
          ),
          const SizedBox(height: 12),
          Text(item.title,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontSize: 16),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(LucideIcons.car,
                  size: 14, color: AppColors.textSecondaryLight,),
              const SizedBox(width: 4),
              Flexible(
                  child: Text(item.vehicle,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,),),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                        isFinished
                            ? LucideIcons.checkCircle
                            : LucideIcons.calendar,
                        size: 14,
                        color: isFinished
                            ? AppColors.statusSuccess
                            : AppColors.textSecondaryLight,),
                    const SizedBox(width: 4),
                    Flexible(
                        child: Text(item.dateLabel,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                    fontSize: 12,
                                    color: isFinished
                                        ? AppColors.statusSuccess
                                        : AppColors.textSecondaryLight,),
                            overflow: TextOverflow.ellipsis,),),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'R\$ ${item.price.toStringAsFixed(0)}',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontSize: 14,
                      color: isFinished
                          ? AppColors.statusSuccess
                          : AppColors.statusError,
                      fontWeight: FontWeight.w900,
                    ),
              ),
            ],
          ),
        ],
      ),
    );

    final Widget draggingFeedback = Material(
      color: Colors.transparent,
      child: Transform.rotate(
        angle: -0.05,
        child: Container(
          width: 300,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 20,
                  spreadRadius: 5,
                  offset: const Offset(10, 10),),
            ],
          ),
          child: cardChild,
        ),
      ),
    );

    return LongPressDraggable<MaintenanceItem>(
      data: item,
      feedback: draggingFeedback,
      childWhenDragging: Opacity(opacity: 0.3, child: cardChild),
      child: cardChild,
    );
  }
}
