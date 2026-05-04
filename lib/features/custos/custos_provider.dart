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
    _seedIfEmpty();
    _loading = false;
    _safeNotify();
  }

  void _seedIfEmpty() {
    final frota = FleetRepository.instance.frota;
    if (frota.isEmpty) return;

    final primeiro = frota[0];
    final segundo = frota.length > 1 ? frota[1] : frota[0];
    final terceiro = frota.length > 2 ? frota[2] : frota[0];
    final hoje = DateTime.now();

    if (_manutencoes.isEmpty) {
      _manutencoes.addAll([
        ManutencaoItem(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          veiculoPlaca: primeiro.placa,
          veiculoNome: 'Corolla',
          titulo: 'Troca de Óleo',
          tipo: 'Troca de Óleo',
          data: hoje.add(const Duration(days: 15)),
          custo: 350.0,
          prioridade: MaintenancePriority.alta,
          kmNoServico: 45000,
          coluna: KanbanColumn.pendentes,
          fornecedor: 'Auto Center Silva',
        ),
        ManutencaoItem(
          id: (DateTime.now().millisecondsSinceEpoch + 1).toString(),
          veiculoPlaca: segundo.placa,
          veiculoNome: 'Hilux',
          titulo: 'Revisão 40k',
          tipo: 'Revisão Periódica',
          data: hoje.add(const Duration(days: 22)),
          custo: 1200.0,
          prioridade: MaintenancePriority.baixa,
          kmNoServico: 40000,
          coluna: KanbanColumn.pendentes,
        ),
        ManutencaoItem(
          id: (DateTime.now().millisecondsSinceEpoch + 2).toString(),
          veiculoPlaca: terceiro.placa,
          veiculoNome: 'Argo',
          titulo: 'Alinhamento/Balanceamento',
          tipo: 'Pneus',
          data: hoje,
          custo: 180.0,
          prioridade: MaintenancePriority.media,
          kmNoServico: 38000,
          coluna: KanbanColumn.emOficina,
          fornecedor: 'Pneus & Cia',
        ),
        ManutencaoItem(
          id: (DateTime.now().millisecondsSinceEpoch + 3).toString(),
          veiculoPlaca: primeiro.placa,
          veiculoNome: 'Corolla',
          titulo: 'Troca de Pastilhas de Freio',
          tipo: 'Freios',
          data: hoje,
          custo: 420.0,
          prioridade: MaintenancePriority.alta,
          kmNoServico: 50000,
          coluna: KanbanColumn.emOficina,
          fornecedor: 'Freios Express',
        ),
        ManutencaoItem(
          id: (DateTime.now().millisecondsSinceEpoch + 4).toString(),
          veiculoPlaca: segundo.placa,
          veiculoNome: 'Hilux',
          titulo: 'Troca 4 Pneus',
          tipo: 'Pneus',
          data: hoje.subtract(const Duration(days: 3)),
          custo: 2450.0,
          prioridade: MaintenancePriority.ok,
          kmNoServico: 39000,
          coluna: KanbanColumn.concluidos,
          fornecedor: 'Pneus & Cia',
        ),
      ]);
    }

    if (_despesas.isEmpty) {
      _despesas.addAll([
        DespesaItem(
          id: (DateTime.now().millisecondsSinceEpoch + 10).toString(),
          veiculoPlaca: primeiro.placa,
          motorista: primeiro.motorista,
          data: DateTime(2026, 2, 4),
          tipo: 'Combustível',
          descricao: 'Abastecimento semanal',
          valor: 285.90,
          pago: true,
          nf: 'NF-001',
        ),
        DespesaItem(
          id: (DateTime.now().millisecondsSinceEpoch + 11).toString(),
          veiculoPlaca: segundo.placa,
          motorista: segundo.motorista,
          data: DateTime(2026, 2, 12),
          tipo: 'Pedágio',
          descricao: 'Rota interior',
          valor: 42.30,
          pago: true,
        ),
        DespesaItem(
          id: (DateTime.now().millisecondsSinceEpoch + 12).toString(),
          veiculoPlaca: terceiro.placa,
          motorista: terceiro.motorista,
          data: DateTime(2026, 2, 18),
          tipo: 'Lavagem',
          descricao: 'Higienização completa',
          valor: 95.0,
        ),
        DespesaItem(
          id: (DateTime.now().millisecondsSinceEpoch + 13).toString(),
          veiculoPlaca: primeiro.placa,
          motorista: primeiro.motorista,
          data: DateTime(2026, 3, 3),
          tipo: 'Manutenção',
          descricao: 'Pequeno reparo elétrico',
          valor: 180.0,
          pago: true,
          nf: 'NF-002',
        ),
        DespesaItem(
          id: (DateTime.now().millisecondsSinceEpoch + 14).toString(),
          veiculoPlaca: segundo.placa,
          motorista: segundo.motorista,
          data: DateTime(2026, 3, 10),
          tipo: 'Seguro',
          descricao: 'Parcela seguro frota',
          valor: 1320.0,
        ),
        DespesaItem(
          id: (DateTime.now().millisecondsSinceEpoch + 15).toString(),
          veiculoPlaca: terceiro.placa,
          motorista: terceiro.motorista,
          data: DateTime(2026, 3, 16),
          tipo: 'Combustível',
          descricao: 'Abastecimento viagem',
          valor: 310.5,
          pago: true,
        ),
        DespesaItem(
          id: (DateTime.now().millisecondsSinceEpoch + 16).toString(),
          veiculoPlaca: primeiro.placa,
          motorista: primeiro.motorista,
          data: DateTime(2026, 4, 2),
          tipo: 'IPVA',
          descricao: 'Pagamento anual',
          valor: 2340.0,
        ),
        DespesaItem(
          id: (DateTime.now().millisecondsSinceEpoch + 17).toString(),
          veiculoPlaca: segundo.placa,
          motorista: segundo.motorista,
          data: DateTime(2026, 4, 7),
          tipo: 'Pedágio',
          descricao: 'Viagem BR-116',
          valor: 66.4,
          pago: true,
        ),
        DespesaItem(
          id: (DateTime.now().millisecondsSinceEpoch + 18).toString(),
          veiculoPlaca: terceiro.placa,
          motorista: terceiro.motorista,
          data: DateTime(2026, 4, 11),
          tipo: 'Lavagem',
          descricao: 'Limpeza interna',
          valor: 75.0,
        ),
        DespesaItem(
          id: (DateTime.now().millisecondsSinceEpoch + 19).toString(),
          veiculoPlaca: primeiro.placa,
          motorista: primeiro.motorista,
          data: DateTime(2026, 4, 22),
          tipo: 'Manutenção',
          descricao: 'Troca de lâmpadas',
          valor: 120.0,
          pago: true,
        ),
      ]);
    }
  }
}
