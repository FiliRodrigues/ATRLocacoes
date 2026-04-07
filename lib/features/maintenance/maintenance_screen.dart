import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../core/widgets/app_sidebar.dart';
import '../../core/widgets/bento_card.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/status_badge.dart';

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
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildKanbanColumn(context, 'Pendentes', [
                        _buildKanbanCard(context, '0', 'Troca de Óleo', 'Corolla (VD-1234)', '15/Mai', 'Alta', 'R\$ 350,00', isHighPriority: true),
                        _buildKanbanCard(context, '1', 'Revisão 40k', 'Hilux (TX-2041)', '22/Mai', 'Baixa', 'R\$ 1.200,00', isHighPriority: false),
                      ]),
                      const SizedBox(width: 24),
                      _buildKanbanColumn(context, 'Em Oficina', [
                        _buildKanbanCard(context, '2', 'Alinhamento/Balanc.', 'Civic (XT-9090)', 'Hoje', 'Média', 'R\$ 180,00', isHighPriority: false),
                      ]),
                      const SizedBox(width: 24),
                      _buildKanbanColumn(context, 'Concluídos', [
                        _buildKanbanCard(context, '3', 'Troca 4 Pneus', 'Corolla (VD-1234)', 'Finalizado', 'Ok', 'R\$ 2.450,00', isFinished: true),
                      ]),
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
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text('Quadro de Manutenções', style: Theme.of(context).textTheme.displayLarge?.copyWith(fontSize: 28)),
        Row(
          children: [
            Container(
              width: 300,
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
            const SizedBox(width: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: Theme.of(context).dividerTheme.color!)),
              child: Icon(LucideIcons.filter, size: 18, color: AppColors.atrOrange),
            ),
          ],
        )
      ],
    );
  }

  Widget _buildKanbanColumn(BuildContext context, String title, List<Widget> cards) {
    Color bgColor = Theme.of(context).brightness == Brightness.dark 
        ? AppColors.surfaceElevatedDark 
        : AppColors.surfaceLight.withOpacity(0.6);

    return Expanded(
      child: Container(
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Theme.of(context).dividerTheme.color!.withOpacity(0.5)),
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
              child: SingleChildScrollView(
                child: Column(
                  children: cards.map((c) => Padding(padding: const EdgeInsets.only(bottom: 12.0), child: c)).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKanbanCard(BuildContext context, String id, String title, String vehicle, String date, String priority, String price, {bool isHighPriority = false, bool isFinished = false}) {
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
                  priority.toUpperCase(),
                  style: TextStyle(
                    color: isFinished ? AppColors.statusSuccess : (isHighPriority ? AppColors.statusError : AppColors.textSecondaryLight),
                    fontSize: 10, fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              // Menu Editar Ordem de Serviço
              PopupMenuButton<String>(
                icon: Icon(LucideIcons.moreHorizontal, size: 16, color: AppColors.textSecondaryLight),
                onSelected: (String result) {
                  if (result == 'edit') {
                    _showEditMaintenanceModal(context, title, vehicle, price, date);
                  }
                },
                itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                  const PopupMenuItem<String>(
                    value: 'edit',
                    child: Row(children: [Icon(LucideIcons.edit2, size: 16), SizedBox(width: 8), Text('Editar O.S.')]),
                  ),
                  const PopupMenuItem<String>(
                    value: 'delete',
                    child: Row(children: [Icon(LucideIcons.trash2, size: 16, color: AppColors.statusError), SizedBox(width: 8), Text('Excluir O.S.', style: TextStyle(color: AppColors.statusError))]),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 16)),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(LucideIcons.car, size: 14, color: AppColors.textSecondaryLight),
              const SizedBox(width: 4),
              Text(vehicle, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
               Row(
                children: [
                  Icon(isFinished ? LucideIcons.checkCircle : LucideIcons.calendar, size: 14, color: isFinished ? AppColors.statusSuccess : AppColors.textSecondaryLight),
                  const SizedBox(width: 4),
                  Text(date, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 12, color: isFinished ? AppColors.statusSuccess : AppColors.textSecondaryLight)),
                ],
              ),
              Text(
                price,
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
              BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 20, spreadRadius: 5, offset: const Offset(10, 10))
            ]
          ),
          child: cardChild,
        ),
      ),
    );

    return LongPressDraggable<String>(
      data: id,
      feedback: draggingFeedback,
      childWhenDragging: Opacity(opacity: 0.3, child: cardChild),
      child: cardChild,
    );
  }

  void _showEditMaintenanceModal(BuildContext context, String currentTitle, String currentVehicle, String currentPrice, String currentDate) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.2), 
      builder: (ctx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10), 
        child: AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surface.withOpacity(0.9), 
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: BorderSide(color: Colors.white.withOpacity(0.2))),
          title: const Text('Editar Despesa/OS', style: TextStyle(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(decoration: const InputDecoration(labelText: 'Nome da Manutenção'), initialValue: currentTitle),
                const SizedBox(height: 16),
                TextFormField(decoration: const InputDecoration(labelText: 'Data / Prazo'), initialValue: currentDate),
                const SizedBox(height: 16),
                TextFormField(decoration: const InputDecoration(labelText: 'Valor Estimado'), initialValue: currentPrice.replaceAll('R\$ ', '')),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.atrOrange, foregroundColor: Colors.white, elevation: 0),
              onPressed: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('OS Atualizada com sucesso!'))); 
              },
              child: const Text('Salvar Alterações'),
            )
          ],
        ),
      ),
    );
  }
}
