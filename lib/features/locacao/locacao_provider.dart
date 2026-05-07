import 'package:flutter/foundation.dart';
import '../../core/data/locacao_models.dart';
import '../../core/data/locacao_repository.dart';
import '../../core/services/audit_service.dart';
import '../../core/utils/app_logger.dart';

/// Estado central de locação B2B/B2G.
///
/// Gerencia contratos, checklist e ocorrências com persistência via Supabase.
class LocacaoProvider extends ChangeNotifier {
  LocacaoProvider(this._repo) {
    _init();
  }

  final LocacaoRepository _repo;
  bool _disposed = false;

  bool _loading = true;
  bool get isLoading => _loading;

  String? _error;
  String? get error => _error;

  List<Contrato> _contratos = [];
  List<Contrato> get contratos => List.unmodifiable(_contratos);

  List<Ocorrencia> _todasOcorrencias = [];
  List<Ocorrencia> get todasOcorrencias => List.unmodifiable(_todasOcorrencias);

  // ── Métricas agregadas ──
  List<Contrato> get contratosAtivos =>
      _contratos.where((c) => c.status == ContratoStatus.ativo).toList();

  double get receitaMensalAtiva => contratosAtivos.fold(0.0, (s, c) => s + c.valorMensal);

  int get ocorrenciasAbertas =>
      _todasOcorrencias.where((o) => o.status == OcorrenciaStatus.aberta).length;

  double get impactoFinanceiroTotal =>
      _todasOcorrencias.fold(0.0, (s, o) => s + o.impactoFinanceiro);

  // ── Checklist por contrato (cache local) ──
  final Map<String, List<ChecklistEvento>> _checklistCache = {};

  List<ChecklistEvento> checklistDoContrato(String contratoId) =>
      List.unmodifiable(_checklistCache[contratoId] ?? []);

  List<Ocorrencia> ocorrenciasDoContrato(String contratoId) =>
      _todasOcorrencias.where((o) => o.contratoId == contratoId).toList();

  // ════════════════════════════════════════════════════
  // CONTRATOS
  // ════════════════════════════════════════════════════

  Future<void> recarregarContratos() async {
    _loading = true;
    _safeNotify();
    await _init();
  }

  bool _isSaving = false;

  Future<Contrato> criarContrato(Contrato contrato) async {
    if (_isSaving) throw Exception('Salvamento em andamento');
    _isSaving = true;
    try {
      final criado = await _repo.createContrato(contrato);
      _contratos.insert(0, criado);
      await AuditService.log(
        action: AuditAction.criar,
        entity: AuditEntity.manutencao,
        entityId: criado.id,
        payload: {'numero': criado.numero, 'cliente': criado.clienteNome},
      );
      _safeNotify();
      return criado;
    } finally {
      _isSaving = false;
    }
  }

  Future<Contrato> atualizarContrato(Contrato contrato) async {
    final antes = _contratos.firstWhere((c) => c.id == contrato.id,
        orElse: () => contrato);
    final atualizado = await _repo.updateContrato(contrato);
    final idx = _contratos.indexWhere((c) => c.id == atualizado.id);
    if (idx != -1) _contratos[idx] = atualizado;
    await AuditService.log(
      action: AuditAction.atualizar,
      entity: AuditEntity.manutencao,
      entityId: atualizado.id,
      beforeState: {'status': antes.status.name, 'valorMensal': antes.valorMensal},
      afterState: {'status': atualizado.status.name, 'valorMensal': atualizado.valorMensal},
    );
    _safeNotify();
    return atualizado;
  }

  Future<void> deletarContrato(String id) async {
    final index = _contratos.indexWhere((c) => c.id == id);
    if (index == -1) return;
    final antes = _contratos[index];
    
    // Optimistic UI Update
    _contratos.removeAt(index);
    final cacheChecklist = _checklistCache[id];
    _checklistCache.remove(id);
    final ocorrenciasRemovidas = _todasOcorrencias.where((o) => o.contratoId == id).toList();
    _todasOcorrencias.removeWhere((o) => o.contratoId == id);
    _safeNotify();

    try {
      await _repo.deleteContrato(id);
      await AuditService.log(
        action: AuditAction.deletar,
        entity: AuditEntity.manutencao,
        entityId: id,
        beforeState: {'numero': antes.numero, 'cliente': antes.clienteNome},
      );
    } catch (e) {
      // Rollback
      _contratos.insert(index, antes);
      if (cacheChecklist != null) _checklistCache[id] = cacheChecklist;
      _todasOcorrencias.addAll(ocorrenciasRemovidas);
      _safeNotify();
      throw Exception('Falha ao deletar contrato: $e');
    }
  }

  // ════════════════════════════════════════════════════
  // CHECKLIST
  // ════════════════════════════════════════════════════

  Future<void> carregarChecklist(String contratoId) async {
    try {
      final lista = await _repo.fetchChecklist(contratoId);
      _checklistCache[contratoId] = lista;
      _safeNotify();
    } catch (e, s) {
      AppLogger.error('carregarChecklist falhou [contrato=$contratoId]', e, s);
      // Seta erro visível para o contrato específico
      _error = 'Falha ao carregar checklist: ${e.toString().split('\n').first}';
      _safeNotify();
    }
  }

  Future<ChecklistEvento> registrarChecklist(ChecklistEvento evento) async {
    final criado = await _repo.createChecklist(evento);
    final lista = _checklistCache[evento.contratoId] ?? [];
    _checklistCache[evento.contratoId] = [criado, ...lista];
    await AuditService.log(
      action: AuditAction.criar,
      entity: AuditEntity.veiculo,
      entityId: evento.contratoId,
      afterState: {
        'tipo': evento.tipo.name,
        'km': evento.kmOdometro,
        'combustivel_pct': evento.combustivelPct,
        'realizado_por': evento.realizadoPor,
      },
    );
    _safeNotify();
    return criado;
  }

  // ════════════════════════════════════════════════════
  // OCORRÊNCIAS
  // ════════════════════════════════════════════════════

  Future<Ocorrencia> criarOcorrencia(Ocorrencia ocorrencia) async {
    if (_isSaving) throw Exception('Salvamento em andamento');
    _isSaving = true;
    try {
      final criada = await _repo.createOcorrencia(ocorrencia);
      _todasOcorrencias.insert(0, criada);
      await AuditService.log(
        action: AuditAction.criar,
        entity: AuditEntity.despesa,
        entityId: criada.id,
        payload: {'contrato': criada.contratoId, 'tipo': criada.tipo.name},
      );
      _safeNotify();
      return criada;
    } finally {
      _isSaving = false;
    }
  }

  Future<Ocorrencia> atualizarOcorrencia(Ocorrencia ocorrencia) async {
    final antes = _todasOcorrencias.firstWhere((o) => o.id == ocorrencia.id,
        orElse: () => ocorrencia);
    final atualizada = await _repo.updateOcorrencia(ocorrencia);
    final idx = _todasOcorrencias.indexWhere((o) => o.id == atualizada.id);
    if (idx != -1) _todasOcorrencias[idx] = atualizada;
    await AuditService.log(
      action: AuditAction.atualizar,
      entity: AuditEntity.despesa,
      entityId: atualizada.id,
      beforeState: {'status': antes.status.name, 'valor_final': antes.valorFinal},
      afterState: {'status': atualizada.status.name, 'valor_final': atualizada.valorFinal},
    );
    _safeNotify();
    return atualizada;
  }

  // ════════════════════════════════════════════════════
  // INTERNOS
  // ════════════════════════════════════════════════════

  Future<void> _init() async {
    try {
      final results = await Future.wait([
        _repo.fetchContratos(),
        _repo.fetchTodasOcorrencias(),
      ]);
      _contratos = results[0] as List<Contrato>;
      _todasOcorrencias = results[1] as List<Ocorrencia>;
      _error = null;
    } catch (e, s) {
      AppLogger.error('LocacaoProvider._init falhou', e, s);
      // Sem fallback silencioso — propaga o erro para a UI exibir
      _error = 'Falha ao carregar dados de locação: ${e.toString().split('\n').first}';
    } finally {
      _loading = false;
      _safeNotify();
    }
  }

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
