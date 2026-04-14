import 'package:flutter_test/flutter_test.dart';
import 'package:fleet_app/features/maintenance/maintenance_provider.dart';

void main() {
  group('MaintenanceProvider.moveItem', () {
    test('move item para Em Oficina e remove de Pendentes', () {
      final provider = MaintenanceProvider();
      final item = provider.pending.first;

      provider.moveItem(item, KanbanColumn.emOficina);

      expect(provider.pending.any((i) => i.id == item.id), isFalse);
      expect(provider.ongoing.any((i) => i.id == item.id), isTrue);
      final moved = provider.ongoing.firstWhere((i) => i.id == item.id);
      expect(moved.isDone, isFalse);
    });

    test('move item para Concluidos e marca como done', () {
      final provider = MaintenanceProvider();
      final item = provider.pending.first;

      provider.moveItem(item, KanbanColumn.concluidos);

      expect(provider.pending.any((i) => i.id == item.id), isFalse);
      expect(provider.completed.any((i) => i.id == item.id), isTrue);
      final moved = provider.completed.firstWhere((i) => i.id == item.id);
      expect(moved.isDone, isTrue);
    });

    test('mantem item unico ao mover entre colunas', () {
      final provider = MaintenanceProvider();
      final item = provider.pending.first;

      provider.moveItem(item, KanbanColumn.emOficina);
      final moved = provider.ongoing.firstWhere((i) => i.id == item.id);
      provider.moveItem(moved, KanbanColumn.concluidos);

      final occurrences = [
        ...provider.pending,
        ...provider.ongoing,
        ...provider.completed,
      ].where((i) => i.id == item.id).length;

      expect(occurrences, 1);
    });
  });
}
