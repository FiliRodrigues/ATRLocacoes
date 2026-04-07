import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../../core/widgets/app_sidebar.dart';
import '../../core/widgets/bento_card.dart';
import '../../core/theme/app_colors.dart';
import 'maintenance_provider.dart';

class MaintenanceScreen extends StatelessWidget {
  const MaintenanceScreen({super.key});

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
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildKanbanColumn(
                            context, 
                            'Pendentes', 
                            provider.pending.map((item) => _buildKanbanCard(context, item)).toList(),
                            onAccept: (item) => provider.moveItem(item, 'Pendentes'),
                          ),
                          const SizedBox(width: 24),
                          _buildKanbanColumn(
                            context, 
                            'Em Oficina', 
                            provider.ongoing.map((item) => _buildKanbanCard(context, item)).toList(),
                            onAccept: (item) => provider.moveItem(item, 'Em Oficina'),
                          ),
                          const SizedBox(width: 24),
                          _buildKanbanColumn(
                            context, 
                            'Concluídos', 
                            provider.completed.map((item) => _buildKanbanCard(context, item)).toList(),
                            onAccept: (item) => provider.moveItem(item, 'Concluídos'),
                          ),
                        ],
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
        Flexible(child: Text('Quadro de Manutenções', style: Theme.of(context).textTheme.displayLarge?.copyWith(fontSize: 28), overflow: TextOverflow.ellipsis)),
        const SizedBox(width: 24),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 300),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: Theme.of(context).dividerTheme.color!)),
            child: Row(
              children: [
                Icon(LucideIcons.search, size: 16, color: AppColors.textSecondaryLight),
                const SizedBox(width: 8),
                Expanded(child: TextField(decoration: InputDecoration(isDense: true, hintText: 'Buscar OS ou Placa...', hintStyle: TextStyle(color: AppColors.textSecondaryLight, fontSize: 14), border: InputBorder.none))),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: Theme.of(context).dividerTheme.color!)),
          child: Icon(LucideIcons.filter, size: 18, color: AppColors.atrOrange),
        ),
      ],
    );
  }

  Widget _buildKanbanColumn(BuildContext context, String title, List<Widget> cards, {required Function(MaintenanceItem) onAccept}) {
    Color bgColor = Theme.of(context).brightness == Brightness.dark 
        ? AppColors.surfaceElevatedDark 
        : AppColors.surfaceLight.withOpacity(0.6);

    return Expanded(
      child: DragTarget<MaintenanceItem>(
        onWillAccept: (data) => true,
        onAccept: onAccept,
        builder: (context, candidateData, rejectedData) {
          final isOver = candidateData.isNotEmpty;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: isOver ? AppColors.atrOrange.withOpacity(0.05) : bgColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isOver ? AppColors.atrOrange : Theme.of(context).dividerTheme.color!.withOpacity(0.5)),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 18)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: Theme.of(context).scaffoldBackgroundColor, borderRadius: BorderRadius.circular(12)),
                      child: Text('${cards.length}', style: TextStyle(color: AppColors.textSecondaryLight, fontWeight: FontWeight.bold, fontSize: 13)),
                    )
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView(
                    children: cards.map((c) => Padding(padding: const EdgeInsets.only(bottom: 12.0), child: c)).toList(),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildKanbanCard(BuildContext context, MaintenanceItem item) {
    bool isHighPriority = item.priority == 'ALTA';
    bool isFinished = item.isDone;

    Widget cardChild = BentoCard(
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
                  color: isFinished ? AppColors.statusSuccess.withOpacity(0.15) : (isHighPriority ? AppColors.statusError.withOpacity(0.15) : Theme.of(context).scaffoldBackgroundColor),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  item.priority,
                  style: TextStyle(
                    color: isFinished ? AppColors.statusSuccess : (isHighPriority ? AppColors.statusError : AppColors.textSecondaryLight),
                    fontSize: 10, fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Icon(LucideIcons.moreHorizontal, size: 16, color: AppColors.textSecondaryLight),
            ],
          ),
          const SizedBox(height: 12),
          Text(item.title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 16), overflow: TextOverflow.ellipsis, maxLines: 1),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(LucideIcons.car, size: 14, color: AppColors.textSecondaryLight),
              const SizedBox(width: 4),
              Flexible(child: Text(item.vehicle, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
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
                    Icon(isFinished ? LucideIcons.checkCircle : LucideIcons.calendar, size: 14, color: isFinished ? AppColors.statusSuccess : AppColors.textSecondaryLight),
                    const SizedBox(width: 4),
                    Flexible(child: Text(item.date, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 12, color: isFinished ? AppColors.statusSuccess : AppColors.textSecondaryLight), overflow: TextOverflow.ellipsis)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'R\$ ${item.price.toStringAsFixed(0)}',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontSize: 14, color: isFinished ? AppColors.statusSuccess : AppColors.statusError,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          )
        ],
      ),
    );

    Widget draggingFeedback = Material(
      color: Colors.transparent,
      child: Transform.rotate(
        angle: -0.05, 
        child: Container(
          width: 300, 
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 20, spreadRadius: 5, offset: const Offset(10, 10))
            ]
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
