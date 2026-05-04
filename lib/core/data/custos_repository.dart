import 'custos_models.dart';

abstract class ICustosRepository {
  Future<List<ManutencaoItem>> fetchManutencoes();
  Future<void> saveManutencao(ManutencaoItem item);
  Future<void> deleteManutencao(String id);
  Future<List<DespesaItem>> fetchDespesas();
  Future<void> saveDespesa(DespesaItem item);
  Future<void> deleteDespesa(String id);
}

class LocalCustosRepository implements ICustosRepository {
  final List<ManutencaoItem> _manutencoes = [];
  final List<DespesaItem> _despesas = [];

  @override
  Future<List<ManutencaoItem>> fetchManutencoes() {
    return Future.value(List.unmodifiable(_manutencoes));
  }

  @override
  Future<void> saveManutencao(ManutencaoItem item) {
    final index = _manutencoes.indexWhere((m) => m.id == item.id);
    if (index == -1) {
      _manutencoes.add(item);
    } else {
      _manutencoes[index] = item;
    }
    return Future.value();
  }

  @override
  Future<void> deleteManutencao(String id) {
    _manutencoes.removeWhere((m) => m.id == id);
    return Future.value();
  }

  @override
  Future<List<DespesaItem>> fetchDespesas() {
    return Future.value(List.unmodifiable(_despesas));
  }

  @override
  Future<void> saveDespesa(DespesaItem item) {
    final index = _despesas.indexWhere((d) => d.id == item.id);
    if (index == -1) {
      _despesas.add(item);
    } else {
      _despesas[index] = item;
    }
    return Future.value();
  }

  @override
  Future<void> deleteDespesa(String id) {
    _despesas.removeWhere((d) => d.id == id);
    return Future.value();
  }
}
