import 'package:flutter/foundation.dart';
import '../../core/data/fleet_data.dart';

class MaintenanceProvider with ChangeNotifier {
  final List<MaintenanceItem> _pending = [
    MaintenanceItem(id: '1', title: 'Troca de Óleo', vehicle: 'Corolla (VD-1234)', date: '15/Mai', price: 350, priority: 'ALTA'),
    MaintenanceItem(id: '2', title: 'Revisão 40k', vehicle: 'Hilux (TX-2041)', date: '22/Mai', price: 1200, priority: 'BAIXA'),
  ];

  final List<MaintenanceItem> _ongoing = [
    MaintenanceItem(id: '3', title: 'Alinhamento/Balanc.', vehicle: 'Civic (XT-9090)', date: 'Hoje', price: 180, priority: 'MÉDIA'),
  ];

  final List<MaintenanceItem> _completed = [
    MaintenanceItem(id: '4', title: 'Troca 4 Pneus', vehicle: 'Corolla (VD-1234)', date: 'Ontem', price: 2450, priority: 'OK', isDone: true),
  ];

  List<MaintenanceItem> get pending => _pending;
  List<MaintenanceItem> get ongoing => _ongoing;
  List<MaintenanceItem> get completed => _completed;

  void moveItem(MaintenanceItem item, String targetStatus) {
    // Remove de onde estiver
    _pending.removeWhere((i) => i.id == item.id);
    _ongoing.removeWhere((i) => i.id == item.id);
    _completed.removeWhere((i) => i.id == item.id);

    // Atualiza status interno do item (opcional, para UI)
    final newItem = item.copyWith(isDone: targetStatus == 'Concluídos');

    // Adiciona na nova lista
    if (targetStatus == 'Pendentes') _pending.add(newItem);
    if (targetStatus == 'Em Oficina') _ongoing.add(newItem);
    if (targetStatus == 'Concluídos') _completed.add(newItem);

    notifyListeners();
  }
}

class MaintenanceItem {
  final String id;
  final String title;
  final String vehicle;
  final String date;
  final double price;
  final String priority;
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

  MaintenanceItem copyWith({bool? isDone}) {
    return MaintenanceItem(
      id: id,
      title: title,
      vehicle: vehicle,
      date: date,
      price: price,
      priority: priority,
      isDone: isDone ?? this.isDone,
    );
  }
}
