import 'dart:convert';
import 'dart:ui';
import 'package:hive_flutter/hive_flutter.dart';
import '../enums/vehicle_status.dart';
import '../utils/app_logger.dart';
import 'fleet_models.dart';

/// Cache offline da frota usando Hive.
/// Armazena a lista de VehicleData como JSON com timestamp para validação de stale.
class FleetCache {
  static const _boxName = 'fleet_cache';
  static const _keyFrota = 'frota_json';
  static const _keyTimestamp = 'frota_timestamp';
  static const _staleDuration = Duration(minutes: 5);

  static Future<void> init() async {
    await Hive.initFlutter();
    await Hive.openBox(_boxName);
  }

  static Box get _box => Hive.box(_boxName);

  /// Salva a frota no cache como JSON.
  static Future<void> saveFrota(List<VehicleData> frota) async {
    try {
      final jsonList = frota.map(_vehicleToJson).toList();
      await _box.put(_keyFrota, jsonEncode(jsonList));
      await _box.put(_keyTimestamp, DateTime.now().toIso8601String());
    } catch (e) {
      AppLogger.warning('FleetCache save: $e');
    }
  }

  /// Carrega a frota do cache. Retorna null se vazio ou stale (>5 min).
  static List<VehicleData>? loadFrota() {
    try {
      final jsonStr = _box.get(_keyFrota) as String?;
      final tsStr = _box.get(_keyTimestamp) as String?;
      if (jsonStr == null || tsStr == null) return null;

      final timestamp = DateTime.tryParse(tsStr);
      if (timestamp == null || isStale()) return null;

      final List<dynamic> jsonList = jsonDecode(jsonStr);
      return jsonList.map((j) => _vehicleFromJson(j as Map<String, dynamic>)).toList();
    } catch (e) {
      AppLogger.warning('FleetCache load: $e');
      return null;
    }
  }

  /// Verifica se o cache expirou (>5 min).
  static bool isStale() {
    final tsStr = _box.get(_keyTimestamp) as String?;
    if (tsStr == null) return true;
    final timestamp = DateTime.tryParse(tsStr);
    if (timestamp == null) return true;
    return DateTime.now().difference(timestamp) > _staleDuration;
  }

  /// Limpa o cache.
  static Future<void> clear() async {
    await _box.delete(_keyFrota);
    await _box.delete(_keyTimestamp);
  }

  // Serialização simplificada (campos essenciais para reconstruir VehicleData)
  static Map<String, dynamic> _vehicleToJson(VehicleData v) {
    return {
      'nome': v.nome,
      'placa': v.placa,
      'motorista': v.motorista,
      'telefoneMotorista': v.telefoneMotorista,
      'status': v.status.index,
      'mesesEmServico': v.mesesEmServico,
      'kmPorMes': v.kmPorMes,
      'cor1': v.cor1.toARGB32(),
      'cor2': v.cor2.toARGB32(),
      'valorDeMercado': v.valorDeMercado,
      'valorAquisicao': v.valorAquisicao,
      'dataAquisicao': v.dataAquisicao.toIso8601String(),
      'kmHodometro': v.kmHodometro,
      'ultimaAtualizacaoKm': v.ultimaAtualizacaoKm?.toIso8601String(),
      'vencimentoIPVA': v.vencimentoIPVA.toIso8601String(),
      'vencimentoSeguro': v.vencimentoSeguro.toIso8601String(),
      'vencimentoLicenciamento': v.vencimentoLicenciamento.toIso8601String(),
      'manutencoes': v.manutencoes.map((m) => {
        'data': m.data.toIso8601String(),
        'tipo': m.tipo,
        'kmNoServico': m.kmNoServico,
        'custo': m.custo,
        'descricao': m.descricao,
      }).toList(),
      'gastosNaoCiclicos': v.gastosNaoCiclicos.map((g) => {
        'data': g.data.toIso8601String(),
        'categoria': g.categoria,
        'valor': g.valor,
        'descricao': g.descricao,
      }).toList(),
      'financiamento': v.financiamento != null ? {
        'id': v.financiamento!.id,
        'valorTotal': v.financiamento!.valorTotal,
        'percentualEntrada': v.financiamento!.percentualEntrada,
        'totalParcelas': v.financiamento!.totalParcelas,
        'parcelasPagas': v.financiamento!.parcelasPagas,
        'recebimentoMensal': v.financiamento!.recebimentoMensal,
        'taxaJurosMensal': v.financiamento!.taxaJurosMensal,
        'previsaoQuitacao': v.financiamento!.previsaoQuitacao,
        'mesesLocacaoTotais': v.financiamento!.mesesLocacaoTotais,
        'mesesLocacaoPagos': v.financiamento!.mesesLocacaoPagos,
        'totalPagoReal': v.financiamento!.totalPagoReal,
      } : null,
    };
  }

  static VehicleData _vehicleFromJson(Map<String, dynamic> j) {
    final statusIdx = j['status'] as int? ?? 0;
    final status = VehicleStatus.values[statusIdx.clamp(0, VehicleStatus.values.length - 1)];
    final vencPadrao = DateTime(
      DateTime.now().year + 1,
      DateTime.now().month,
      1,
    );

    return VehicleData(
      nome: j['nome'] as String? ?? '',
      placa: j['placa'] as String? ?? '',
      motorista: j['motorista'] as String? ?? '',
      telefoneMotorista: j['telefoneMotorista'] as String? ?? '',
      status: status,
      mesesEmServico: j['mesesEmServico'] as int? ?? 0,
      kmPorMes: (j['kmPorMes'] as num?)?.toDouble() ?? 0,
      cor1: Color(j['cor1'] as int? ?? 0xFF10B981),
      cor2: Color(j['cor2'] as int? ?? 0xFF059669),
      financiamento: _financingFromJson(j['financiamento'] as Map<String, dynamic>?),
      manutencoes: (j['manutencoes'] as List<dynamic>?)?.map((m) {
        final mm = m as Map<String, dynamic>;
        return MaintenanceEvent(
          data: DateTime.tryParse(mm['data'] as String? ?? '') ?? DateTime.now(),
          tipo: mm['tipo'] as String? ?? '',
          kmNoServico: mm['kmNoServico'] as int? ?? 0,
          custo: (mm['custo'] as num?)?.toDouble() ?? 0,
          descricao: mm['descricao'] as String? ?? '',
        );
      }).toList() ?? [],
      vencimentoIPVA: DateTime.tryParse(j['vencimentoIPVA'] as String? ?? '') ?? vencPadrao,
      vencimentoSeguro: DateTime.tryParse(j['vencimentoSeguro'] as String? ?? '') ?? vencPadrao,
      vencimentoLicenciamento: DateTime.tryParse(j['vencimentoLicenciamento'] as String? ?? '') ?? vencPadrao,
      valorDeMercado: (j['valorDeMercado'] as num?)?.toDouble() ?? 0,
      valorAquisicao: (j['valorAquisicao'] as num?)?.toDouble() ?? 0,
      dataAquisicao: DateTime.tryParse(j['dataAquisicao'] as String? ?? '') ?? DateTime.now(),
      gastosNaoCiclicos: (j['gastosNaoCiclicos'] as List<dynamic>?)?.map((g) {
        final gg = g as Map<String, dynamic>;
        return VehicleCostEvent(
          data: DateTime.tryParse(gg['data'] as String? ?? '') ?? DateTime.now(),
          categoria: gg['categoria'] as String? ?? '',
          valor: (gg['valor'] as num?)?.toDouble() ?? 0,
          descricao: gg['descricao'] as String? ?? '',
        );
      }).toList() ?? [],
      kmHodometro: (j['kmHodometro'] as num?)?.toDouble(),
      ultimaAtualizacaoKm: DateTime.tryParse(j['ultimaAtualizacaoKm'] as String? ?? ''),
    );
  }

  static FinancingData? _financingFromJson(Map<String, dynamic>? j) {
    if (j == null) return null;
    return FinancingData(
      id: j['id'] as String?,
      valorTotal: (j['valorTotal'] as num?)?.toDouble() ?? 0,
      percentualEntrada: (j['percentualEntrada'] as num?)?.toDouble() ?? 0.20,
      totalParcelas: j['totalParcelas'] as int? ?? 0,
      parcelasPagas: j['parcelasPagas'] as int? ?? 0,
      recebimentoMensal: (j['recebimentoMensal'] as num?)?.toDouble() ?? 0,
      taxaJurosMensal: (j['taxaJurosMensal'] as num?)?.toDouble() ?? 0,
      previsaoQuitacao: j['previsaoQuitacao'] as String? ?? '',
      mesesLocacaoTotais: j['mesesLocacaoTotais'] as int? ?? 36,
      mesesLocacaoPagos: j['mesesLocacaoPagos'] as int? ?? 0,
      totalPagoReal: (j['totalPagoReal'] as num?)?.toDouble() ?? 0,
    );
  }
}
