import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/app_logger.dart';
import '../constants.dart';
import '../data/fleet_data.dart';
import '../enums/vehicle_status.dart';

// ═══════════════════════════════════════════════════════
// SUPABASE CONFIG
// ═══════════════════════════════════════════════════════

/// Configuração do Supabase — DEVE ser fornecida via --dart-define no
/// build/run. Não há fallback hardcoded (P004 fix). Se vazio, o app
/// falha rapidamente em [main] com mensagem clara.
///
/// Build:  flutter build windows --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
/// Run:    flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
const String kSupabaseUrl = String.fromEnvironment('SUPABASE_URL');
const String kSupabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

bool get kSupabaseConfigured =>
    kSupabaseUrl.isNotEmpty && kSupabaseAnonKey.isNotEmpty;

// ═══════════════════════════════════════════════════════
// MAPEAMENTO: linha Supabase → VehicleData
// ═══════════════════════════════════════════════════════

VehicleStatus _mapStatus(String? situacao) {
  if (situacao == null) return VehicleStatus.parado;
  final s = situacao.toLowerCase();
  if (s.contains('operando')) return VehicleStatus.emRota;
  if (s.contains('locado')) return VehicleStatus.reserva;
  if (s.contains('oficina') || s.contains('manutencao')) {
    return VehicleStatus.emOficina;
  }
  return VehicleStatus.parado;
}

/// Retorna um par de cores baseado na marca do veículo.
(Color, Color) _coresParaMarca(String marca) {
  switch (marca.toUpperCase()) {
    case 'TOYOTA':
      return (const Color(0xFF3B82F6), const Color(0xFF1D4ED8));
    case 'FIAT':
      return (const Color(0xFFEF4444), const Color(0xFFB91C1C));
    case 'VOLKSWAGEN':
      return (const Color(0xFF64748B), const Color(0xFF334155));
    case 'CHEVROLET':
      return (const Color(0xFFF59E0B), const Color(0xFFD97706));
    case 'IVECO':
      return (const Color(0xFF6366F1), const Color(0xFF4338CA));
    default:
      return (const Color(0xFF10B981), const Color(0xFF059669));
  }
}

VehicleData vehicleFromSupabase(
  Map<String, dynamic> row, {
  Map<String, dynamic>? financiamentoRow,
  double totalPagoReal = 0.0,
  int mesesLocacaoTotaisReal = 0,
  int mesesLocacaoPagosReal = 0,
  Map<int, double> recebidoPorMes = const {},
  List<MaintenanceEvent> manutencoes = const [],
  List<VehicleCostEvent> gastosNaoCiclicos = const [],
}) {
  final marca = (row['marca'] as String? ?? '').trim();
  final modelo = (row['modelo'] as String? ?? '').trim();
  final nome = '$marca $modelo'.trim();
  final placa = (row['placa'] as String? ?? '').trim();
  final situacao = row['situacao_operacional'] as String?;
  final status = _mapStatus(situacao);
  final propriedadeStatus = (row['propriedade_status'] as String? ?? '');
  final isFinanciado = propriedadeStatus.contains('Financiado');

  final kmAtual = (row['km_atual'] as num?)?.toDouble() ??
      (row['km_inicial'] as num?)?.toDouble();

  DateTime? ultimaAtualizacaoKm;
  if (row['status_atualizado_em'] != null) {
    ultimaAtualizacaoKm = DateTime.tryParse(
      row['status_atualizado_em'].toString(),
    );
  }

  DateTime dataAquisicao = DateTime.now();
  if (row['data_compra'] != null) {
    try {
      dataAquisicao = DateTime.tryParse(row['data_compra']?.toString() ?? '') ?? DateTime.now();
    } catch (_) {}
  }

  final mesesEmServico =
      DateTime.now().difference(dataAquisicao).inDays ~/ 30;

  final valorVeiculo = (row['valor_veiculo'] as num?)?.toDouble() ?? 0.0;

  final (cor1, cor2) = _coresParaMarca(marca);

  // Lê vencimentos reais do banco com fallback seguro.
  final vencPadrao = DateTime(
    DateTime.now().year + 1,
    DateTime.now().month,
    1,
  );
  final vencIPVA = DateTime.tryParse((row['vencimento_ipva'] ?? '').toString()) ??
      vencPadrao;
  final vencSeguro =
      DateTime.tryParse((row['vencimento_seguro'] ?? '').toString()) ??
          vencPadrao;
  final vencLic = DateTime.tryParse(
        (row['vencimento_licenciamento'] ?? '').toString(),
      ) ??
      vencPadrao;

  FinancingData? financing;
  if (financiamentoRow != null) {
    final f = financiamentoRow;
    final valorTotalDb =
        (f['valor_total_veiculo'] as num?)?.toDouble() ?? valorVeiculo;
    final valorEntradaDb = (f['valor_entrada'] as num?)?.toDouble();
    final valorFinanciadoDb = (f['valor_financiado'] as num?)?.toDouble();
    final totalParcelas = (f['quantidade_parcelas'] as num?)?.toInt() ?? 48;
    final recebimentoMensal =
        (f['recebimento_mensal'] as num?)?.toDouble() ?? 0.0;
    final taxaJurosMensal =
        (f['taxa_juros_mensal'] as num?)?.toDouble() ?? 0.0139;
    final previsaoQuitacao = (f['previsao_quitacao'] as String?) ?? '';
    final valorJaPago = (f['valor_ja_pago'] as num?)?.toDouble() ?? 0.0;

    final bool isQuitado = totalParcelas <= 1;

    // Calcula percentual de entrada a partir dos valores reais, se disponíveis.
    // Para veículos quitados (não financiados), força percentualEntrada=1.0 para
    // que valorFinanciado=0 e, consequentemente, valorParcela=0.
    double percentualEntrada = isQuitado ? 1.0 : 0.20;
    if (!isQuitado) {
      if (valorEntradaDb != null && valorTotalDb > 0) {
        percentualEntrada = (valorEntradaDb / valorTotalDb).clamp(0.0, 1.0);
      } else if (valorFinanciadoDb != null && valorTotalDb > 0) {
        percentualEntrada =
            ((valorTotalDb - valorFinanciadoDb) / valorTotalDb).clamp(0.0, 1.0);
      }
    }

    // Parcelas pagas = meses desde a data de compra, limitado ao total de parcelas.
    final int parcelasPagas = mesesEmServico.clamp(0, totalParcelas);
    
    // Meses de locação — usa dados reais da parcelas_financiamento se disponíveis
    final int locTotais = mesesLocacaoTotaisReal > 0
        ? mesesLocacaoTotaisReal
        : (recebimentoMensal > 0 ? 36 : 0);
    final int locPagos = mesesLocacaoTotaisReal > 0
        ? mesesLocacaoPagosReal
        : mesesEmServico.clamp(0, 36);

    // valorJaPago disponível para referência futura, mas não usado no cálculo.
    final _ = valorJaPago;

    financing = FinancingData(
      valorTotal: valorTotalDb,
      percentualEntrada: percentualEntrada,
      totalParcelas: totalParcelas,
      parcelasPagas: parcelasPagas,
      recebimentoMensal: recebimentoMensal,
      taxaJurosMensal: taxaJurosMensal,
      previsaoQuitacao: previsaoQuitacao,
      mesesLocacaoTotais: locTotais,
      mesesLocacaoPagos: locPagos,
      totalPagoReal: totalPagoReal,
      recebidoPorMes: recebidoPorMes,
    );
  } else if (isFinanciado) {
    // Sem dados de financiamento no banco — usa estimativa padrão
    financing = FinancingData(
      valorTotal: valorVeiculo,
      percentualEntrada: 0.20,
      totalParcelas: 48,
      parcelasPagas: mesesEmServico.clamp(0, 48),
      recebimentoMensal: 0,
      taxaJurosMensal: 0.0139,
      previsaoQuitacao: '',
    );
  }

  return VehicleData(
    nome: nome.isEmpty ? placa : nome,
    placa: placa,
    motorista: situacao ?? '',
    telefoneMotorista: '',
    status: status,
    mesesEmServico: mesesEmServico.clamp(0, 999),
    kmPorMes: 0,
    cor1: cor1,
    cor2: cor2,
    manutencoes: manutencoes,
    vencimentoIPVA: vencIPVA,
    vencimentoSeguro: vencSeguro,
    vencimentoLicenciamento: vencLic,
    valorDeMercado: valorVeiculo,
    valorAquisicao: valorVeiculo,
    dataAquisicao: dataAquisicao,
    kmHodometro: kmAtual,
    gastosNaoCiclicos: gastosNaoCiclicos,
    ultimaAtualizacaoKm: ultimaAtualizacaoKm,
    financiamento: financing,
  );
}

// ═══════════════════════════════════════════════════════
// SERVIÇO DE BUSCA
// ═══════════════════════════════════════════════════════

class FleetSupabaseService {
  static Future<List<VehicleData>> fetchVehicles({String tenantId = kDefaultTenantId}) async {
    final client = Supabase.instance.client;

    // Busca fontes relevantes do TCO em paralelo.
    // skill:query — SELECT com colunas explícitas evita transferência desnecessária
    //               de dados e reduz I/O no Postgres (elimina SELECT *).
    // skill:security — filtro explícito de tenant_id como fallback de aplicação;
    //                  a RLS é a segunda camada de segurança no banco.
    // Busca veículos e financiamentos em paralelo.
    // Manutenções e despesas são buscadas separadamente para isolar falhas
    // de schema sem derrubar a query principal.
    final coreResults = await Future.wait([
      client
          .from('veiculos')
          .select(
            'id, placa, marca, modelo, situacao_operacional, '
            'propriedade_status, km_atual, km_inicial, '
            'status_atualizado_em, status_alterado_por, '
            'data_compra, valor_veiculo',
          )
          .eq('tenant_id', tenantId)
          .order('placa', ascending: true),
      client
          .from('financiamentos')
          .select(
            'id, veiculo_id, valor_total_veiculo, valor_entrada, '
            'valor_financiado, quantidade_parcelas, recebimento_mensal, '
            'taxa_juros_mensal, previsao_quitacao, valor_ja_pago',
          )
          .eq('tenant_id', tenantId),
    ]);

    final veiculoRows = coreResults[0] as List<dynamic>;
    final financiamentoRows = coreResults[1] as List<dynamic>;

    // Mapa id → placa para vincular manutenções (schema usa veiculo_id, não veiculo_placa)
    final idParaPlaca = <String, String>{};
    for (final v in veiculoRows) {
      final vMap = v as Map<String, dynamic>;
      final id = vMap['id'] as String?;
      final placa = (vMap['placa'] as String? ?? '').trim();
      if (id != null && placa.isNotEmpty) idParaPlaca[id] = placa;
    }

    // Busca manutenções e despesas com tratamento de erro independente
    List<dynamic> manutencaoRows = const [];
    List<dynamic> despesaRows = const [];
    try {
      manutencaoRows = await client
          .from('manutencoes')
          .select(
            'veiculo_id, data_servico, tipo_servico, descricao, km_registro, valor_servico',
          )
          .eq('tenant_id', tenantId)
          .order('data_servico', ascending: false);
    } catch (e) {
      AppLogger.warning('Falha ao carregar manutenções: $e');
    }
    try {
      despesaRows = await client
          .from('despesas')
          .select(
            'veiculo_placa, data, tipo, descricao, valor',
          )
          .eq('tenant_id', tenantId)
          .order('data', ascending: false);
    } catch (e) {
      AppLogger.warning('Falha ao carregar despesas: $e');
    }

    // Indexa financiamentos por veiculo_id para lookup O(1)
    final financiamentoByVeiculoId = <String, Map<String, dynamic>>{};
    final financiamentoIdToVeiculoId = <String, String>{};
    debugPrint('[SUPABASE] financiamentosRows: ${financiamentoRows.length}');
    for (final f in financiamentoRows) {
      final fMap = f as Map<String, dynamic>;
      final veiculoId = fMap['veiculo_id'] as String?;
      final finId = fMap['id'] as String?;
      final recMensal = fMap['recebimento_mensal'];
      debugPrint('[SUPABASE]   finId=$finId veiculoId=$veiculoId recebimento_mensal=$recMensal');
      if (veiculoId != null) {
        financiamentoByVeiculoId[veiculoId] = fMap;
      }
      if (finId != null && veiculoId != null) {
        financiamentoIdToVeiculoId[finId] = veiculoId;
      }
    }
    debugPrint('[SUPABASE] financiamentoIdToVeiculoId.size=${financiamentoIdToVeiculoId.length}');
    // Consulta parcelas_financiamento para valores reais recebidos.
    // Tenant filtering é feito client-side via financiamento_id → veiculo_id → tenant.
    final totalPagoByVeiculoId = <String, double>{};
    final totalMesesByVeiculoId = <String, int>{};
    final mesesPagosByVeiculoId = <String, int>{};
    final recebidoPorMesByVeiculoId = <String, Map<int, double>>{};
    try {
      final parcelasRows = await client
          .from('parcelas_financiamento')
          .select('financiamento_id, valor_parcela, status_pagamento, data_pagamento')
          .eq('tenant_id', tenantId);
      for (final p in parcelasRows) {
        final pMap = p;
        final finId = pMap['financiamento_id'] as String?;
        final valor = (pMap['valor_parcela'] as num?)?.toDouble() ?? 0.0;
        final pago = pMap['status_pagamento'] == 'Pago';
        final veiculoId = finId != null ? financiamentoIdToVeiculoId[finId] : null;
        if (veiculoId != null) {
          totalMesesByVeiculoId.update(
            veiculoId,
            (v) => v + 1,
            ifAbsent: () => 1,
          );
          if (pago) {
            totalPagoByVeiculoId.update(
              veiculoId,
              (v) => v + valor,
              ifAbsent: () => valor,
            );
            mesesPagosByVeiculoId.update(
              veiculoId,
              (v) => v + 1,
              ifAbsent: () => 1,
            );
            // Agrupa por mês da data de pagamento para o dashboard mensal
            final dtPg = DateTime.tryParse(
              (pMap['data_pagamento'] ?? '').toString(),
            );
            if (dtPg != null) {
              final key = dtPg.year * 100 + dtPg.month;
              recebidoPorMesByVeiculoId
                  .putIfAbsent(veiculoId, () => {})
                  .update(
                    key,
                    (v) => v + valor,
                    ifAbsent: () => valor,
                  );
            }
          }
        }
      }
      debugPrint('[SUPABASE] parcelas: totalRows=${parcelasRows.length} veiculosComParcelas=${recebidoPorMesByVeiculoId.length}');
      // Amostra dos primeiros 5 financiamento_id das parcelas para debug
      final amostraFinIds = <String>{};
      for (final p in parcelasRows.take(10)) {
        final pMap = p;
        amostraFinIds.add((pMap['financiamento_id'] ?? 'NULL').toString());
      }
      debugPrint('[SUPABASE] amostra finIds das parcelas: $amostraFinIds');
      debugPrint('[SUPABASE] finIds conhecidos: ${financiamentoIdToVeiculoId.keys.take(5).toList()}');
      for (final e in recebidoPorMesByVeiculoId.entries) {
        debugPrint('[SUPABASE]   veiculoId=${e.key} meses=${e.value.keys.toList()} valores=${e.value.values.toList()}');
      }
    } catch (e) {
      AppLogger.warning('Falha ao carregar parcelas_financiamento: $e');
    }

    // Manutenções: usa veiculo_id → placa via idParaPlaca
    final manutencoesByPlaca = <String, List<MaintenanceEvent>>{};
    for (final m in manutencaoRows) {
      final mMap = m as Map<String, dynamic>;
      final veiculoId = mMap['veiculo_id'] as String?;
      final placa = veiculoId != null ? idParaPlaca[veiculoId] : null;
      if (placa == null || placa.isEmpty) continue;

      final data = DateTime.tryParse(
              (mMap['data_servico'] ?? mMap['data'] ?? '').toString()) ??
          DateTime.now();
      final kmNoServico = (mMap['km_registro'] as num?)?.toInt() ??
          (mMap['km_no_servico'] as num?)?.toInt() ??
          0;

      final event = MaintenanceEvent(
        data: data,
        tipo: (mMap['tipo_servico'] ?? mMap['tipo'] as String?)
                    ?.toString()
                    .trim()
                    .isNotEmpty ==
                true
            ? (mMap['tipo_servico'] ?? mMap['tipo']).toString()
            : 'manutencao',
        kmNoServico: kmNoServico,
        custo: (mMap['valor_servico'] as num?)?.toDouble() ??
            (mMap['custo'] as num?)?.toDouble() ??
            0.0,
        descricao: (mMap['descricao'] as String?) ?? '',
      );

      manutencoesByPlaca.putIfAbsent(placa, () => []).add(event);
    }

    final gastosByPlaca = <String, List<VehicleCostEvent>>{};
    for (final d in despesaRows) {
      final dMap = d as Map<String, dynamic>;
      final placa = (dMap['veiculo_placa'] as String?)?.trim();
      if (placa == null || placa.isEmpty) continue;

      final event = VehicleCostEvent(
        data: DateTime.tryParse((dMap['data'] ?? '').toString()) ??
            DateTime.now(),
        categoria: (dMap['tipo'] as String?)?.trim().isNotEmpty == true
            ? dMap['tipo'].toString()
            : 'despesa',
        valor: (dMap['valor'] as num?)?.toDouble() ?? 0.0,
        descricao: (dMap['descricao'] as String?) ?? '',
      );

      gastosByPlaca.putIfAbsent(placa, () => []).add(event);
    }

    return veiculoRows.map((row) {
      final vRow = row as Map<String, dynamic>;
      final veiculoId = vRow['id'] as String?;
      final fRow =
          veiculoId != null ? financiamentoByVeiculoId[veiculoId] : null;
      final placa = (vRow['placa'] as String? ?? '').trim();

      final totalPagoReal = veiculoId != null
          ? (totalPagoByVeiculoId[veiculoId] ?? 0.0)
          : 0.0;
      final mesesLocTotaisReal = veiculoId != null
          ? (totalMesesByVeiculoId[veiculoId] ?? 0)
          : 0;
      final mesesLocPagosReal = veiculoId != null
          ? (mesesPagosByVeiculoId[veiculoId] ?? 0)
          : 0;
      final recebidoPorMes = veiculoId != null
          ? (recebidoPorMesByVeiculoId[veiculoId] ?? const {})
          : const <int, double>{};

      return vehicleFromSupabase(
        vRow,
        financiamentoRow: fRow,
        totalPagoReal: totalPagoReal,
        mesesLocacaoTotaisReal: mesesLocTotaisReal,
        mesesLocacaoPagosReal: mesesLocPagosReal,
        recebidoPorMes: recebidoPorMes,
        manutencoes: manutencoesByPlaca[placa] ?? const [],
        gastosNaoCiclicos: gastosByPlaca[placa] ?? const [],
      );
    }).toList();
  }

  /// Registra leitura de hodômetro com validação server-side via RPC [registrar_km].
  ///
  /// A função Postgres executa:
  ///   1. Validação anti-regressão (novo KM < atual → erro).
  ///   2. Validação de salto suspeito (> 1000 km/dia → erro).
  ///   3. INSERT em hodometros + UPDATE em veiculos (atômico).
  ///
  /// Lança [Exception] se a validação falhar — NÃO altera estado.
  static Future<void> updateVehicleKm({
    required String placa,
    required int km,
    required String registradoPor,
    String tenantId = kDefaultTenantId,
  }) async {
    final client = Supabase.instance.client;
    final result = await client.rpc('registrar_km', params: {
      'p_placa': placa,
      'p_km': km,
      'p_registrado_por': registradoPor,
      'p_tenant_id': tenantId,
    }) as Map<String, dynamic>;

    if (result['ok'] != true) {
      throw Exception(result['error'] as String? ?? 'Erro ao registrar KM');
    }
  }

  /// Atualiza a situação operacional de um veículo na tabela [veiculos].
  static Future<void> updateVehicleStatus({
    required String placa,
    required String novasSituacao,
    required String alteradoPor,
  }) async {
    final client = Supabase.instance.client;
    await client
        .from('veiculos')
        .update({
          'situacao_operacional': novasSituacao,
          'status_alterado_por': alteradoPor,
          'status_atualizado_em': DateTime.now().toIso8601String(),
        })
        .eq('placa', placa);
  }
}
