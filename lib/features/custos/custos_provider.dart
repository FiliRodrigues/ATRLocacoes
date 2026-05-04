import 'package:flutter/foundation.dart';
import '../../core/data/custos_models.dart';
import '../../core/data/custos_repository.dart';
import '../../core/data/fleet_data.dart';
import '../../core/enums/kanban_column.dart';
import '../../core/enums/maintenance_priority.dart';
import '../../core/services/audit_service.dart';

class CustosProvider extends ChangeNotifier {
  CustosProvider(this._repo) {
    _init();
  }

  final ICustosRepository _repo;
  bool _disposed = false;
  bool _loading = true;
  bool get isLoading => _loading;

  List<ManutencaoItem> _manutencoes = [];
  List<DespesaItem> _despesas = [];

  List<ManutencaoItem> get pendentes =>
      _manutencoes.where((m) => m.coluna == KanbanColumn.pendentes).toList();
  List<ManutencaoItem> get emOficina =>
      _manutencoes.where((m) => m.coluna == KanbanColumn.emOficina).toList();
  List<ManutencaoItem> get concluidos =>
      _manutencoes.where((m) => m.coluna == KanbanColumn.concluidos).toList();
  List<ManutencaoItem> get manutencoes => List.unmodifiable(_manutencoes);
  List<DespesaItem> get despesas => List.unmodifiable(_despesas);

  double get totalCustoManutencoesMes {
    final now = DateTime.now();
    return _manutencoes
        .where((m) => m.data.year == now.year && m.data.month == now.month)
        .fold(0.0, (s, m) => s + m.custo);
  }

  double get totalCustoDespesasMes {
    final now = DateTime.now();
    return _despesas
        .where((d) => d.data.year == now.year && d.data.month == now.month)
        .fold(0.0, (s, d) => s + d.valor);
  }

  double get totalGeralMes => totalCustoManutencoesMes + totalCustoDespesasMes;

    double get cpkGlobal {
    final now = DateTime.now();
    final limite = now.subtract(const Duration(days: 30));

    final manutencoesRecentes = _manutencoes
      .where((m) => m.isDone && !m.data.isBefore(limite))
      .toList();
    final despesasRecentes =
      _despesas.where((d) => !d.data.isBefore(limite)).toList();

    final custoManutencoes =
      manutencoesRecentes.fold<double>(0.0, (sum, item) => sum + item.custo);
    final custoDespesas =
      despesasRecentes.fold<double>(0.0, (sum, item) => sum + item.valor);
    final custoTotal = custoManutencoes + custoDespesas;
    if (custoTotal <= 0) return 0.0;

    final odometros = <int>[
      ...manutencoesRecentes
        .map((item) => item.odometro)
        .where((value) => value > 0),
      ...despesasRecentes
        .map((item) => item.odometro)
        .where((value) => value > 0),
    ];

    final kmRodados = odometros.length >= 2
      ? odometros.reduce((a, b) => a > b ? a : b) -
        odometros.reduce((a, b) => a < b ? a : b)
      : 5000;
    if (kmRodados <= 0) return custoTotal / 5000;

    return custoTotal / kmRodados;
    }

  int get totalOsAbertas => pendentes.length + emOficina.length;

  int get totalDespesasPendentes => _despesas.where((d) => !d.pago).length;

  ManutencaoItem? get proximaManutencao {
    final futuras = _manutencoes
        .where((m) => m.data.isAfter(DateTime.now()) && !m.isDone)
        .toList()
      ..sort((a, b) => a.data.compareTo(b.data));
    return futuras.isEmpty ? null : futuras.first;
  }

  Future<void> addManutencao(ManutencaoItem item) async {
    await _repo.saveManutencao(item);
    _manutencoes.add(item);
    AuditService.log(
      action: AuditAction.criar,
      entity: AuditEntity.manutencao,
      entityId: item.id,
      payload: {'titulo': item.titulo, 'veiculo': item.veiculoPlaca, 'custo': item.custo},
    );
    _safeNotify();
  }

  Future<void> updateManutencao(ManutencaoItem item) async {
    await _repo.saveManutencao(item);
    final idx = _manutencoes.indexWhere((m) => m.id == item.id);
    if (idx != -1) _manutencoes[idx] = item;
    _safeNotify();
  }

  Future<void> deleteManutencao(String id) async {
    await _repo.deleteManutencao(id);
    _manutencoes.removeWhere((m) => m.id == id);
    AuditService.log(
      action: AuditAction.deletar,
      entity: AuditEntity.manutencao,
      entityId: id,
    );
    _safeNotify();
  }

  Future<void> moverKanban(String id, KanbanColumn destino) async {
    final idx = _manutencoes.indexWhere((m) => m.id == id);
    if (idx == -1) return;
    final atualizado = _manutencoes[idx].copyWith(coluna: destino);
    await _repo.saveManutencao(atualizado);
    _manutencoes[idx] = atualizado;
    AuditService.log(
      action: AuditAction.moverKanban,
      entity: AuditEntity.manutencao,
      entityId: id,
      payload: {'destino': destino.name},
    );
    _safeNotify();
  }

  Future<void> addDespesa(DespesaItem item) async {
    await _repo.saveDespesa(item);
    _despesas.add(item);
    AuditService.log(
      action: AuditAction.criar,
      entity: AuditEntity.despesa,
      entityId: item.id,
      payload: {'tipo': item.tipo, 'veiculo': item.veiculoPlaca, 'valor': item.valor},
    );
    _safeNotify();
  }

  Future<void> updateDespesa(DespesaItem item) async {
    await _repo.saveDespesa(item);
    final idx = _despesas.indexWhere((d) => d.id == item.id);
    if (idx != -1) _despesas[idx] = item;
    _safeNotify();
  }

  Future<void> deleteDespesa(String id) async {
    await _repo.deleteDespesa(id);
    _despesas.removeWhere((d) => d.id == id);
    AuditService.log(
      action: AuditAction.deletar,
      entity: AuditEntity.despesa,
      entityId: id,
    );
    _safeNotify();
  }

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  Future<void> _init() async {
    _manutencoes = (await _repo.fetchManutencoes()).toList();
    _despesas = (await _repo.fetchDespesas()).toList();
    
    _loading = false;
    _safeNotify();
  }


}
