import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/fleet_data.dart';
import '../enums/vehicle_status.dart';

// ═══════════════════════════════════════════════════════
// SUPABASE CONFIG
// ═══════════════════════════════════════════════════════

const String _kFallbackSupabaseUrl = 'https://ybajzitijjtzhavgrarz.supabase.co';
const String _kFallbackSupabaseAnonKey =
    'sb_publishable_SAX5OUy6ECnlYp_x0IuV-A_Veo9AvJA';

/// Permite sobrescrever a conexão sem editar código:
/// --dart-define=SUPABASE_URL=...
/// --dart-define=SUPABASE_ANON_KEY=...
const String kSupabaseUrl = String.fromEnvironment(
  'SUPABASE_URL',
  defaultValue: _kFallbackSupabaseUrl,
);
const String kSupabaseAnonKey = String.fromEnvironment(
  'SUPABASE_ANON_KEY',
  defaultValue: _kFallbackSupabaseAnonKey,
);

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
}) {
  final marca = (row['marca'] as String? ?? '').trim();
  final modelo = (row['modelo'] as String? ?? '').trim();
  final nome = '$marca $modelo'.trim();
  final placa = (row['placa'] as String? ?? '').trim();
  final situacao = row['situacao_operacional'] as String?;
  final status = _mapStatus(situacao);
  final propriedadeStatus = (row['propriedade_status'] as String? ?? '');
  final isFinanciado = propriedadeStatus.contains('Financiado');

  final kmInicial = (row['km_inicial'] as num?)?.toDouble();

  DateTime dataAquisicao = DateTime.now();
  if (row['data_compra'] != null) {
    try {
      dataAquisicao = DateTime.parse(row['data_compra'] as String);
    } catch (_) {}
  }

  final mesesEmServico =
      DateTime.now().difference(dataAquisicao).inDays ~/ 30;

  final valorVeiculo = (row['valor_veiculo'] as num?)?.toDouble() ?? 0.0;

  final (cor1, cor2) = _coresParaMarca(marca);

  // Vencimentos padrão (1 ano a partir de hoje) — sem dados no Supabase ainda
  final vencPadrao = DateTime(DateTime.now().year + 1, DateTime.now().month, 1);

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
    // valor_ja_pago do banco inclui entrada+juros+parcelas de forma inconsistente,
    // então usamos mesesEmServico como fonte confiável.
    //
    // Para veículos quitados (quantidade_parcelas = 1) mas com locação ativa:
    // usa 36 meses como duração do contrato de locação, garantindo que
    // progressoFinanciamento e totalRecebido reflitam o contrato real.
    final effectiveTotalParcelas =
        (totalParcelas == 1 && recebimentoMensal > 0) ? 36 : totalParcelas;
    final int parcelasPagas =
        mesesEmServico.clamp(0, effectiveTotalParcelas);
    // valorJaPago disponível para referência futura, mas não usado no cálculo.
    final _ = valorJaPago;

    financing = FinancingData(
      valorTotal: valorTotalDb,
      percentualEntrada: percentualEntrada,
      totalParcelas: effectiveTotalParcelas,
      parcelasPagas: parcelasPagas,
      recebimentoMensal: recebimentoMensal,
      taxaJurosMensal: taxaJurosMensal,
      previsaoQuitacao: previsaoQuitacao,
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
    manutencoes: const [],
    vencimentoIPVA: vencPadrao,
    vencimentoSeguro: vencPadrao,
    vencimentoLicenciamento: vencPadrao,
    valorDeMercado: valorVeiculo,
    valorAquisicao: valorVeiculo,
    dataAquisicao: dataAquisicao,
    kmHodometro: kmInicial,
    gastosNaoCiclicos: const [],
    financiamento: financing,
  );
}

// ═══════════════════════════════════════════════════════
// SERVIÇO DE BUSCA
// ═══════════════════════════════════════════════════════

class FleetSupabaseService {
  static Future<List<VehicleData>> fetchVehicles() async {
    final client = Supabase.instance.client;

    // Busca veículos e financiamentos em paralelo
    final results = await Future.wait([
      client.from('veiculos').select().order('placa', ascending: true),
      client.from('financiamentos').select(),
    ]);

    final veiculoRows = results[0] as List<dynamic>;
    final financiamentoRows = results[1] as List<dynamic>;

    // Indexa financiamentos por veiculo_id para lookup O(1)
    final financiamentoByVeiculoId = <String, Map<String, dynamic>>{};
    for (final f in financiamentoRows) {
      final fMap = f as Map<String, dynamic>;
      final veiculoId = fMap['veiculo_id'] as String?;
      if (veiculoId != null) {
        financiamentoByVeiculoId[veiculoId] = fMap;
      }
    }

    return veiculoRows.map((row) {
      final vRow = row as Map<String, dynamic>;
      final veiculoId = vRow['id'] as String?;
      final fRow =
          veiculoId != null ? financiamentoByVeiculoId[veiculoId] : null;
      return vehicleFromSupabase(vRow, financiamentoRow: fRow);
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
    String tenantId = '00000000-0000-0000-0000-000000000001',
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
