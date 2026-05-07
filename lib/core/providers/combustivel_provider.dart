import 'package:flutter/foundation.dart';
import '../data/combustivel_models.dart';
import '../data/combustivel_repository.dart';
import '../data/fleet_data.dart';
import '../services/audit_service.dart';

import '../constants.dart';

class CombustivelProvider extends ChangeNotifier {
  final CombustivelRepository _repo;
  bool _disposed = false;

  List<Abastecimento> _abastecimentos = [];
  bool _isLoading = false;
  String? _erro;

  List<Abastecimento> get abastecimentos => _abastecimentos;
  bool get isLoading => _isLoading;
  String? get erro => _erro;

  CombustivelProvider(this._repo) {
    _load();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> _load() async {
    _isLoading = true;
    _safeNotify();
    try {
      _abastecimentos = await _repo.fetchAll();
      _erro = null;
    } catch (e) {
      _erro = e.toString();
    } finally {
      _isLoading = false;
      _safeNotify();
    }
  }

  Future<void> refresh() => _load();

  bool _isSaving = false;

  Future<void> addAbastecimento(Abastecimento a) async {
    if (_isSaving) return;
    _isSaving = true;
    try {
      await _repo.save(a);
      await _load();
    } finally {
      _isSaving = false;
    }
  }

  Future<void> deleteAbastecimento(String id) async {
    final idx = _abastecimentos.indexWhere((a) => a.id == id);
    if (idx == -1) return;
    final backup = _abastecimentos[idx];
    _abastecimentos.removeAt(idx);
    _safeNotify();
    try {
      await _repo.delete(id);
    } catch (e) {
      _abastecimentos.insert(idx, backup);
      _safeNotify();
      rethrow;
    }
  }

  // ── KPIs calculados ──────────────────────────────────────────────

  /// KPIs por veículo usando abastecimentos consecutivos para calcular km/l.
  List<CombustivelKpi> kpisPorVeiculo(FleetRepository fleet) {
    final resultado = <CombustivelKpi>[];

    for (final v in fleet.frota) {
      final lista = _abastecimentos
          .where((a) => a.veiculoPlaca == v.placa)
          .toList()
        ..sort((a, b) => a.data.compareTo(b.data));

      if (lista.isEmpty) continue;

      final totalLitros = lista.fold(0.0, (s, a) => s + a.litros);
      final totalGasto = lista.fold(0.0, (s, a) => s + a.valorTotal);
      final precoMedio = totalLitros > 0 ? totalGasto / totalLitros : 0.0;

      // Calcula km/l com base nos pares de odômetro consecutivos
      double kmTotal = 0;
      double litrosParaKml = 0;
      for (var i = 1; i < lista.length; i++) {
        final kmDelta = lista[i].kmOdometro - lista[i - 1].kmOdometro;
        if (kmDelta > 0) {
          kmTotal += kmDelta;
          litrosParaKml += lista[i].litros;
        }
      }
      final kml = litrosParaKml > 0 ? kmTotal / litrosParaKml : 0.0;

      // custo por km = total gasto / km rodado estimado
      final kmRodado = lista.last.kmOdometro - lista.first.kmOdometro;
      final cpk = kmRodado > 0 ? totalGasto / kmRodado : 0.0;

      resultado.add(CombustivelKpi(
        veiculoPlaca: v.placa,
        totalAbastecimentos: lista.length,
        totalLitros: totalLitros,
        totalGasto: totalGasto,
        kmMedia: kml,
        custoKm: cpk,
        precoMedioLitro: precoMedio,
        ultimoAbastecimento: lista.last.data,
      ));
    }

    resultado.sort((a, b) => b.totalGasto.compareTo(a.totalGasto));
    return resultado;
  }

  /// Total gasto em combustível no mês/ano especificado.
  double totalMes(int ano, int mes) => _abastecimentos
      .where((a) => a.data.year == ano && a.data.month == mes)
      .fold(0.0, (s, a) => s + a.valorTotal);

  /// Constrói novo Abastecimento com id gerado e tenant correto.
  Abastecimento buildNovo({
    required String veiculoPlaca,
    required DateTime data,
    required double litros,
    required double valorTotal,
    required double kmOdometro,
    required TipoCombustivel tipo,
    String? posto,
    String registradoPor = 'sistema',
  }) {
    return Abastecimento(
      id: 'fuel_${DateTime.now().millisecondsSinceEpoch}',
      veiculoPlaca: veiculoPlaca,
      data: data,
      litros: litros,
      valorTotal: valorTotal,
      kmOdometro: kmOdometro,
      tipo: tipo,
      posto: posto,
      registradoPor: registradoPor,
      tenantId: AuditService.currentTenantId ?? kDefaultTenantId,
    );
  }
}
