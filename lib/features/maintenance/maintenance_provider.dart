import 'package:flutter/foundation.dart';
import '../../core/enums/maintenance_priority.dart';
import '../../core/enums/kanban_column.dart';

export '../../core/enums/maintenance_priority.dart';
export '../../core/enums/kanban_column.dart';

class MaintenanceProvider with ChangeNotifier {
  final List<MaintenanceItem> _pending = [
    MaintenanceItem(id: '1', title: 'Troca de Óleo', vehicle: 'Corolla (VD-1234)', date: DateTime(2026, 5, 15), price: 350, priority: MaintenancePriority.alta),
    MaintenanceItem(id: '2', title: 'Revisão 40k', vehicle: 'Hilux (TX-2041)', date: DateTime(2026, 5, 22), price: 1200, priority: MaintenancePriority.baixa),
  ];

  final List<MaintenanceItem> _ongoing = [
    MaintenanceItem(id: '3', title: 'Alinhamento/Balanc.', vehicle: 'Argo (ARG-4H78)', date: DateTime.now(), price: 180, priority: MaintenancePriority.media),
  ];

  final List<MaintenanceItem> _completed = [
    MaintenanceItem(id: '4', title: 'Troca 4 Pneus', vehicle: 'Corolla (VD-1234)', date: DateTime.now().subtract(const Duration(days: 1)), price: 2450, priority: MaintenancePriority.ok, isDone: true),
  ];

  List<MaintenanceItem> get pending => List.unmodifiable(_pending);
  List<MaintenanceItem> get ongoing => List.unmodifiable(_ongoing);
  List<MaintenanceItem> get completed => List.unmodifiable(_completed);

  void moveItem(MaintenanceItem item, KanbanColumn column) {
    _pending.removeWhere((i) => i.id == item.id);
    _ongoing.removeWhere((i) => i.id == item.id);
    _completed.removeWhere((i) => i.id == item.id);

    final newItem = item.copyWith(isDone: column == KanbanColumn.concluidos);

    switch (column) {
      case KanbanColumn.pendentes:
        _pending.add(newItem);
      case KanbanColumn.emOficina:
        _ongoing.add(newItem);
      case KanbanColumn.concluidos:
        _completed.add(newItem);
    }

    notifyListeners();
  }
}

class MaintenanceItem {
  final String id;
  final String title;
  final String vehicle;
  final DateTime date;
  final double price;
  final MaintenancePriority priority;
  final bool isDone;

  MaintenanceItem({
    required this.id,
    required this.title,
    required this.vehicle,
    required this.date,
    required this.price,
    required this.priority,
    this.isDone = false,
  });

  MaintenanceItem copyWith({bool? isDone, String? id}) {
    return MaintenanceItem(
      id: id ?? this.id,
      title: title,
      vehicle: vehicle,
      date: date,
      price: price,
      priority: priority,
      isDone: isDone ?? this.isDone,
    );
  }

  String get dateLabel {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(date.year, date.month, date.day);
    if (d == today) return 'Hoje';
    if (d == today.subtract(const Duration(days: 1))) return 'Ontem';
    if (d == today.add(const Duration(days: 1))) return 'Amanhã';
    final months = ['','Jan','Fev','Mar','Abr','Mai','Jun','Jul','Ago','Set','Out','Nov','Dez'];
    return '${date.day.toString().padLeft(2,'0')}/${months[date.month]}';
  }
}
