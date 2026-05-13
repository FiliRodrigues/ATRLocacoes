import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/fleet_data.dart';
import '../data/custos_models.dart';
import '../data/regras_manutencao_models.dart';
import '../data/regras_manutencao_repository.dart';
import '../enums/kanban_column.dart';
import '../services/audit_service.dart';
import '../utils/app_logger.dart';
import '../../features/custos/custos_provider.dart';

/// Provider de Regras de Manutenção Preventiva.
///
/// Responsabilidades:
/// 1. CRUD de [RegraManutencao] via [RegrasManutencaoRepository].
/// 2. Ao carregar/atualizar, executa [checkAndSchedule] que:
///    - Para cada regra ativa + cada veículo elegível
///    - Verifica se o critério (KM ou dias) foi atingido
///    - Se sim, e não existe OS aberta do mesmo tipo, cria uma OS em pendentes
///      via [CustosProvider.addManutencao].
class RegrasManutencaoProvider extends ChangeNotifier {
  RegrasManutencaoProvider({
    required RegrasManutencaoRepository repo,
    required CustosProvider custosProvider,
  })  : _repo = repo,
        _custos = custosProvider {
    FleetRepository.instance.addListener(_onFrotaUpdated);
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.signedIn ||
          data.event == AuthChangeEvent.tokenRefreshed) {
        _reloadFromSupabase();
      }
    });
    final session = Supabase.instance.client.auth.currentSession;
    if (session != null) {
      _init();
    } else {
      _loading = false;
    }
  }

  final RegrasManutencaoRepository _repo;
  final CustosProvider _custos;
  bool _disposed = false;
  bool _loading = true;
  String? _erro;
  bool get isLoading => _loading;
  String? get erro => _erro;

  List<RegraManutencao> _regras = [];
  List<RegraManutencao> get regras => List.unmodifiable(_regras);

  List<RegraManutencao> get regrasAtivas =>
      _regras.where((r) => r.isAtiva).toList();

  // ─────────────────────────────────────────────────────────────────
  // INIT / LIFECYCLE
  // ─────────────────────────────────────────────────────────────────

  Future<void> _reloadFromSupabase() async {
    if (_disposed) return;
    _loading = true;
    _safeNotify();
    await _init();
  }

  Future<void> _init() async {
    try {
      _regras = await _repo.fetchAll();
      _erro = null;
      if (FleetRepository.instance.frota.isNotEmpty) {
        await checkAndSchedule();
      }
    } catch (e, st) {
      _erro = e.toString();
      AppLogger.error('RegrasManutencaoProvider._init falhou', e, st);
    } finally {
      _loading = false;
      _safeNotify();
    }
  }

  bool _isChecking = false;

  void _onFrotaUpdated() async {
    if (_disposed || _loading || _isChecking) return;
    if (FleetRepository.instance.frota.isNotEmpty) {
      _isChecking = true;
      try {
        await checkAndSchedule();
      } finally {
        _isChecking = false;
      }
    }
  }

  // ─────────────────────────────────────────────────────────────────
  // CRUD
  // ─────────────────────────────────────────────────────────────────

  Future<void> addRegra(RegraManutencao regra) async {
    try {
      final newId = await _repo.save(regra);
      final saved = regra.copyWith(id: newId);
      _regras.add(saved);
      _erro = null;
      _safeNotify();
      await checkAndScheduleForRegra(saved);
    } catch (e, st) {
      _erro = e.toString();
      AppLogger.error('RegrasManutencaoProvider.addRegra falhou', e, st);
      _safeNotify();
      rethrow;
    }
  }

  Future<void> updateRegra(RegraManutencao regra) async {
    try {
      await _repo.save(regra);
      final idx = _regras.indexWhere((r) => r.id == regra.id);
      if (idx != -1) _regras[idx] = regra;
      _erro = null;
      _safeNotify();
    } catch (e, st) {
      _erro = e.toString();
      AppLogger.error('RegrasManutencaoProvider.updateRegra falhou', e, st);
      _safeNotify();
      rethrow;
    }
  }

  Future<void> deleteRegra(String id) async {
    try {
      await _repo.delete(id);
      _regras.removeWhere((r) => r.id == id);
      _erro = null;
      _safeNotify();
    } catch (e, st) {
      _erro = e.toString();
      AppLogger.error('RegrasManutencaoProvider.deleteRegra falhou', e, st);
      _safeNotify();
      rethrow;
    }
  }

  Future<void> toggleRegra(String id) async {
    final idx = _regras.indexWhere((r) => r.id == id);
    if (idx == -1) return;
    final updated = _regras[idx].copyWith(isAtiva: !_regras[idx].isAtiva);
    await updateRegra(updated);
  }

  // ─────────────────────────────────────────────────────────────────
  // AGENDAMENTO AUTOMÁTICO
  // ─────────────────────────────────────────────────────────────────

  /// Verifica todas as regras ativas e cria OS para cada veículo elegível.
  Future<void> checkAndSchedule() async {
    for (final regra in regrasAtivas) {
      await checkAndScheduleForRegra(regra);
    }
  }

  Future<void> checkAndScheduleForRegra(RegraManutencao regra) async {
    if (!regra.isAtiva) return;

    final frota = FleetRepository.instance.frota;
    final veiculosAlvo = regra.veiculoPlaca != null
        ? frota.where((v) => v.placa == regra.veiculoPlaca).toList()
        : frota;

    final agora = DateTime.now();

    try {
      for (final veiculo in veiculosAlvo) {
        if (!regra.deveDisparar(
          kmAtual: veiculo.kmAtual,
          dataReferencia: agora,
        )) {
          continue;
        }

        // Verifica se já existe OS aberta (pendente ou em oficina) para este tipo + veículo
        final osExistente = _custos.pendentes
                .any((m) =>
                    m.veiculoPlaca == veiculo.placa && m.tipo == regra.tipo) ||
            _custos.emOficina
                .any((m) =>
                    m.veiculoPlaca == veiculo.placa && m.tipo == regra.tipo);

        if (osExistente) continue;

        // Cria OS automaticamente
        final novaOs = ManutencaoItem(
          id: 'auto_${regra.id}_${veiculo.placa}_${agora.millisecondsSinceEpoch}',
          veiculoPlaca: veiculo.placa,
          veiculoNome: veiculo.nome,
          titulo: '${regra.titulo} [Auto]',
          descricao:
              'OS gerada automaticamente pela regra de manutenção preventiva.',
          tipo: regra.tipo,
          data: agora,
          kmNoServico: veiculo.kmAtual.toInt(),
          custo: regra.custoEstimado,
          prioridade: regra.prioridade,
          coluna: KanbanColumn.pendentes,
          isPreventiva: true,
        );

        await _custos.addManutencao(novaOs);

        // Marca execução no banco para não re-disparar
        final regraAtualizada = regra.copyWith(
          kmUltimaExecucao: veiculo.kmAtual.toInt(),
          dataUltimaExecucao: agora,
        );
        await _repo.marcarExecucao(
          id: regra.id,
          kmExecucao: veiculo.kmAtual.toInt(),
          dataExecucao: agora,
        );

        final idx = _regras.indexWhere((r) => r.id == regra.id);
        if (idx != -1) _regras[idx] = regraAtualizada;

        AuditService.log(
          action: AuditAction.criar,
          entity: AuditEntity.manutencao,
          entityId: novaOs.id,
          payload: {
            'origem': 'regra_automatica',
            'regra_id': regra.id,
            'veiculo': veiculo.placa,
            'tipo': regra.tipo,
          },
        );
      }
      _erro = null;
    } catch (e, st) {
      _erro = e.toString();
      AppLogger.error(
        'RegrasManutencaoProvider.checkAndScheduleForRegra falhou',
        e,
        st,
      );
    }

    _safeNotify();
  }

  // ─────────────────────────────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────────────────────────────

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    FleetRepository.instance.removeListener(_onFrotaUpdated);
    super.dispose();
  }
}
