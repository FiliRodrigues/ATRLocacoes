import 'package:flutter_test/flutter_test.dart';
import 'package:fleet_app/core/data/custos_models.dart';
import 'package:fleet_app/core/data/custos_repository.dart';
import 'package:fleet_app/core/enums/kanban_column.dart';
import 'package:fleet_app/core/enums/maintenance_priority.dart';
import 'package:fleet_app/features/custos/custos_provider.dart';

/// Repositório pré-populado para testes unitários do CustosProvider.
class _SeededCustosRepository extends LocalCustosRepository {
  _SeededCustosRepository() {
    // Garante ao menos um item em Pendentes para todos os testes de Kanban.
    saveManutencao(
      ManutencaoItem(
        id: 'seed-1',
        veiculoPlaca: 'TST-0001',
        veiculoNome: 'Veículo Teste',
        titulo: 'Revisão Geral',
        tipo: 'Revisão',
        data: DateTime(2026, 5),
        prioridade: MaintenancePriority.alta,
        coluna: KanbanColumn.pendentes,
      ),
    );
  }
}

void main() {
  Future<CustosProvider> buildProvider() async {
    final provider = CustosProvider(_SeededCustosRepository());
    while (provider.isLoading) {
      await Future<void>.delayed(Duration.zero);
    }
    return provider;
  }

  group('CustosProvider.moverKanban', () {
    test('move item para Em Oficina e remove de Pendentes', () async {
      final provider = await buildProvider();
      final item = provider.pendentes.first;

      await provider.moverKanban(item.id, KanbanColumn.emOficina);

      expect(provider.pendentes.any((i) => i.id == item.id), isFalse);
      expect(provider.emOficina.any((i) => i.id == item.id), isTrue);
      final moved = provider.emOficina.firstWhere((i) => i.id == item.id);
      expect(moved.isDone, isFalse);

      provider.dispose();
    });

    test('move item para Concluidos e marca como done', () async {
      final provider = await buildProvider();
      final item = provider.pendentes.first;

      await provider.moverKanban(item.id, KanbanColumn.concluidos);

      expect(provider.pendentes.any((i) => i.id == item.id), isFalse);
      expect(provider.concluidos.any((i) => i.id == item.id), isTrue);
      final moved = provider.concluidos.firstWhere((i) => i.id == item.id);
      expect(moved.isDone, isTrue);

      provider.dispose();
    });

    test('mantem item unico ao mover entre colunas', () async {
      final provider = await buildProvider();
      final item = provider.pendentes.first;

      await provider.moverKanban(item.id, KanbanColumn.emOficina);
      final moved = provider.emOficina.firstWhere((i) => i.id == item.id);
      await provider.moverKanban(moved.id, KanbanColumn.concluidos);

      final occurrences = [
        ...provider.pendentes,
        ...provider.emOficina,
        ...provider.concluidos,
      ].where((i) => i.id == item.id).length;

      expect(occurrences, 1);

      provider.dispose();
    });
  });
}
