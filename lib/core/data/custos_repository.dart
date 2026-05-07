import 'custos_models.dart';

abstract class ICustosRepository {
  /// Busca manutenções com paginação. [page] começa em 0, [pageSize] define
  /// quantos registros retornar por vez.
  Future<List<ManutencaoItem>> fetchManutencoes({int page = 0, int pageSize = 50});
  Future<void> saveManutencao(ManutencaoItem item);
  Future<void> deleteManutencao(String id);
  /// Busca despesas com paginação. [page] começa em 0, [pageSize] define
  /// quantos registros retornar por vez.
  Future<List<DespesaItem>> fetchDespesas({int page = 0, int pageSize = 50});
  Future<void> saveDespesa(DespesaItem item);
  Future<void> deleteDespesa(String id);
}

class LocalCustosRepository implements ICustosRepository {
  final List<ManutencaoItem> _manutencoes = [];
  final List<DespesaItem> _despesas = [];

  @override
  Future<List<ManutencaoItem>> fetchManutencoes({
    int page = 0,
    int pageSize = 50,
  }) {
    // LocalRepository: retorna todos em memória (usado em testes/dev)
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
  Future<List<DespesaItem>> fetchDespesas({
    int page = 0,
    int pageSize = 50,
  }) {
    // LocalRepository: retorna todos em memória (usado em testes/dev)
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
