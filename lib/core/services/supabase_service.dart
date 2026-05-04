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

VehicleData vehicleFromSupabase(Map<String, dynamic> row) {
  final marca = (row['marca'] as String? ?? '').trim();
  final modelo = (row['modelo'] as String? ?? '').trim();
  final nome = '$marca $modelo'.trim();
  final placa = (row['placa'] as String? ?? '').trim();
  final situacao = row['situacao_operacional'] as String?;
  final status = _mapStatus(situacao);
  final isFinanciado =
      (row['propriedade_status'] as String? ?? '').contains('Financiado');

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
    financiamento: isFinanciado
        ? FinancingData(
            valorTotal: valorVeiculo,
            percentualEntrada: 0.20,
            totalParcelas: 48,
            parcelasPagas: mesesEmServico.clamp(0, 48),
            recebimentoMensal: 0,
            taxaJurosMensal: 0.0139,
            previsaoQuitacao: '',
          )
        : null,
  );
}

// ═══════════════════════════════════════════════════════
// SERVIÇO DE BUSCA
// ═══════════════════════════════════════════════════════

class FleetSupabaseService {
  static Future<List<VehicleData>> fetchVehicles() async {
    final client = Supabase.instance.client;
    final response = await client
        .from('veiculos')
        .select()
        .order('placa', ascending: true);

    return (response as List<dynamic>)
        .map((row) => vehicleFromSupabase(row as Map<String, dynamic>))
        .toList();
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
