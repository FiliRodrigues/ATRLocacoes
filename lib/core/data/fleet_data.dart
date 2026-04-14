import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../enums/vehicle_status.dart';
import '../enums/cnh_status.dart';
import '../enums/alert_type.dart';
import '../enums/event_type.dart';

export '../enums/vehicle_status.dart';
export '../enums/cnh_status.dart';
export '../enums/alert_type.dart';
export '../enums/event_type.dart';

// ═══════════════════════════════════════════════════════
// MODELOS
// ═══════════════════════════════════════════════════════

class MaintenanceEvent {
  final DateTime data;
  final String tipo;
  final int kmNoServico;
  final double custo;
  final String descricao;
  const MaintenanceEvent(
      {required this.data,
      required this.tipo,
      required this.kmNoServico,
      required this.custo,
      required this.descricao,});
}

class FinancingData {
  final double valorTotal;
  final double percentualEntrada;
  final int totalParcelas;
  final int parcelasPagas;
  final double recebimentoMensal;
  final double taxaJurosMensal;
  final String previsaoQuitacao;
  const FinancingData(
      {required this.valorTotal,
      required this.percentualEntrada,
      required this.totalParcelas,
      required this.parcelasPagas,
      required this.recebimentoMensal,
      required this.taxaJurosMensal,
      required this.previsaoQuitacao,});

  double get valorEntrada => valorTotal * percentualEntrada;
  double get valorFinanciado => valorTotal - valorEntrada;
  double get valorParcela {
    if (totalParcelas <= 0) return 0;
    final i = taxaJurosMensal;
    final n = totalParcelas;
    final pv = valorFinanciado;
    if (i <= 0) return pv / n;
    final f = pow(1 + i, n).toDouble();
    final denominator = f - 1;
    if (denominator.abs() < 1e-10) return pv / n;
    return pv * (i * f) / denominator;
  }

  int get parcelasRestantes => max(totalParcelas - parcelasPagas, 0);
  double get totalParcelasCompleto => valorParcela * totalParcelas;
  double get totalJuros => totalParcelasCompleto - valorFinanciado;
  double get totalPago => valorParcela * parcelasPagas;
  double get totalRestante => valorParcela * parcelasRestantes;
  double get totalRecebido => recebimentoMensal * parcelasPagas;
  double get custoTotalVeiculo => valorEntrada + totalParcelasCompleto;
  double get progressoFinanciamento {
    if (totalParcelas <= 0) return 0;
    return (parcelasPagas / totalParcelas).clamp(0.0, 1.0);
  }

  double get taxaJurosAnual =>
      taxaJurosMensal <= 0 ? 0 : pow(1 + taxaJurosMensal, 12).toDouble() - 1;
  double get saldoMensal => recebimentoMensal - valorParcela;
}

class VehicleData {
  final String nome;
  final String placa;
  final String motorista;
  final String telefoneMotorista;
  final VehicleStatus status;
  final int mesesEmServico;
  final double kmPorMes;
  final String? imagemAsset;
  final Color cor1;
  final Color cor2;
  final FinancingData? financiamento;
  final List<MaintenanceEvent> manutencoes;
  final DateTime vencimentoIPVA;
  final DateTime vencimentoSeguro;
  final DateTime vencimentoLicenciamento;
  final double valorDeMercado;
  final double valorAquisicao;
  final DateTime dataAquisicao;

  VehicleData({
    required this.nome,
    required this.placa,
    required this.motorista,
    required this.telefoneMotorista,
    required this.status,
    required this.mesesEmServico,
    required this.kmPorMes,
    this.imagemAsset,
    required this.cor1,
    required this.cor2,
    this.financiamento,
    required this.manutencoes,
    required this.vencimentoIPVA,
    required this.vencimentoSeguro,
    required this.vencimentoLicenciamento,
    required this.valorDeMercado,
    required this.valorAquisicao,
    required this.dataAquisicao,
  });

  VehicleData copyWith({
    VehicleStatus? status,
  }) {
    return VehicleData(
      nome: nome,
      placa: placa,
      motorista: motorista,
      telefoneMotorista: telefoneMotorista,
      status: status ?? this.status,
      mesesEmServico: mesesEmServico,
      kmPorMes: kmPorMes,
      imagemAsset: imagemAsset,
      cor1: cor1,
      cor2: cor2,
      financiamento: financiamento,
      manutencoes: manutencoes,
      vencimentoIPVA: vencimentoIPVA,
      vencimentoSeguro: vencimentoSeguro,
      vencimentoLicenciamento: vencimentoLicenciamento,
      valorDeMercado: valorDeMercado,
      valorAquisicao: valorAquisicao,
      dataAquisicao: dataAquisicao,
    );
  }

  double get kmAtual => kmPorMes * mesesEmServico;
  bool get isFinanciado => financiamento != null;
  int get totalRevisoes => manutencoes.length;
  double get custoTotalManutencao =>
      manutencoes.fold(0.0, (s, e) => s + e.custo);
  double get kmParaProxRevisao => 10000 - (kmAtual % 10000);

  // Inteligência Financeira
  double get receitaTotalAcumulada =>
      mesesEmServico * (financiamento?.recebimentoMensal ?? 2000.0);
  double get custoTotalAcumulado =>
      custoTotalManutencao + (financiamento?.totalPago ?? 0);
  double get lucroAbsoluto => receitaTotalAcumulada - custoTotalAcumulado;
  double get roi {
    if (valorAquisicao <= 0) return 0;
    return (lucroAbsoluto / valorAquisicao) * 100;
  }

  // Lógica de Ponto de Venda (Depreciação vs Custo)
  String get sugestaoVenda {
    if (mesesEmServico <= 0) return 'CARRO SAUDÁVEL (Manter em Frota)';
    final custoManutencaoAnual = custoTotalManutencao / (mesesEmServico / 12);
    if (custoManutencaoAnual > (valorDeMercado * 0.15)) {
      return 'SUGESTÃO: VENDA IMEDIATA (Custo Altíssimo)';
    }
    if (mesesEmServico > 48 || kmAtual > 120000) {
      return 'SUGESTÃO: TROCA PREVENTIVA (KM/Tempo)';
    }
    return 'CARRO SAUDÁVEL (Manter em Frota)';
  }
}

class DriverData {
  final String nome;
  final String telefone;
  final DateTime vencimentoCNH;
  final CnhStatus statusCNH;
  final int multas;
  final List<String> placasVeiculos;
  const DriverData(
      {required this.nome,
      required this.telefone,
      required this.vencimentoCNH,
      required this.statusCNH,
      required this.multas,
      required this.placasVeiculos,});
}

class AlertItem {
  final AlertType tipo;
  final String titulo;
  final String mensagem;
  const AlertItem(
      {required this.tipo, required this.titulo, required this.mensagem,});
}

class MonthlyData {
  final String mes;
  final double manutencao;
  final double financiamento;
  final double receita;
  const MonthlyData(
      {required this.mes,
      required this.manutencao,
      required this.financiamento,
      required this.receita,});
  double get custoTotal => manutencao + financiamento;
}

class UpcomingEvent {
  final String titulo;
  final String descricao;
  final String prazo;
  final EventType tipo;
  const UpcomingEvent(
      {required this.titulo,
      required this.descricao,
      required this.prazo,
      required this.tipo,});
}

// ═══════════════════════════════════════════════════════
// DADOS MOCK — FROTA
// ═══════════════════════════════════════════════════════

final List<VehicleData> _frota = [
  VehicleData(
    nome: 'Toyota Corolla XEi 2.0',
    placa: 'VD-1234',
    motorista: 'João Silva',
    telefoneMotorista: '(11) 98888-1234',
    status: VehicleStatus.emRota,
    mesesEmServico: 36,
    kmPorMes: 2800,
    imagemAsset: 'assets/images/corolla.png',
    cor1: const Color(0xFF3B82F6),
    cor2: const Color(0xFF1D4ED8),
    vencimentoIPVA: DateTime(2026, 08, 15),
    vencimentoSeguro: DateTime(2026, 05, 20),
    vencimentoLicenciamento: DateTime(2026, 10, 30),
    valorDeMercado: 115000,
    valorAquisicao: 145000,
    dataAquisicao: DateTime(2023, 01, 10),
    manutencoes: [
      MaintenanceEvent(
          data: DateTime(2023, 07, 15),
          tipo: 'Revisão',
          kmNoServico: 10000,
          custo: 1050,
          descricao: 'Revisão 10k - Troca de óleo e filtros',),
      MaintenanceEvent(
          data: DateTime(2023, 11, 20),
          tipo: 'Revisão',
          kmNoServico: 20000,
          custo: 1150,
          descricao: 'Revisão 20k - Troca óleo, filtros e alinhamento',),
      MaintenanceEvent(
          data: DateTime(2024, 03, 10),
          tipo: 'Revisão',
          kmNoServico: 30000,
          custo: 1050,
          descricao: 'Revisão 30k - Troca de óleo e filtros',),
      MaintenanceEvent(
          data: DateTime(2024, 07, 15),
          tipo: 'Revisão',
          kmNoServico: 40000,
          custo: 1250,
          descricao: 'Revisão 40k - Filtros, óleo e velas',),
      MaintenanceEvent(
          data: DateTime(2024, 11, 20),
          tipo: 'Revisão',
          kmNoServico: 50000,
          custo: 1050,
          descricao: 'Revisão 50k - Troca de óleo e filtros',),
      MaintenanceEvent(
          data: DateTime(2025, 03, 10),
          tipo: 'Revisão',
          kmNoServico: 60000,
          custo: 1450,
          descricao: 'Revisão 60k - Kit Correias e Arrefecimento',),
      MaintenanceEvent(
          data: DateTime(2025, 07, 15),
          tipo: 'Revisão',
          kmNoServico: 70000,
          custo: 1050,
          descricao: 'Revisão 70k - Troca de óleo e filtros',),
      MaintenanceEvent(
          data: DateTime(2025, 11, 20),
          tipo: 'Revisão',
          kmNoServico: 80000,
          custo: 1200,
          descricao: 'Revisão 80k - Troca pastilhas e discos de freio',),
      MaintenanceEvent(
          data: DateTime(2026, 03, 10),
          tipo: 'Revisão',
          kmNoServico: 90000,
          custo: 1050,
          descricao: 'Revisão 90k - Troca de óleo e filtros',),
      MaintenanceEvent(
          data: DateTime(2026, 07, 15),
          tipo: 'Revisão',
          kmNoServico: 100000,
          custo: 1200,
          descricao: 'Revisão 100k - Revisão completa + correia',),
    ],
  ),
  VehicleData(
    nome: 'Toyota Hilux SRV 2.8',
    placa: 'TX-2041',
    motorista: 'Marcos Antônio',
    telefoneMotorista: '(11) 97777-5678',
    status: VehicleStatus.emRota,
    mesesEmServico: 24,
    kmPorMes: 3000,
    imagemAsset: 'assets/images/hilux.png',
    cor1: const Color(0xFF10B981),
    cor2: const Color(0xFF059669),
    vencimentoIPVA: DateTime(2026, 04, 15),
    vencimentoSeguro: DateTime(2026, 09, 10),
    vencimentoLicenciamento: DateTime(2026, 11, 15),
    valorDeMercado: 245000,
    valorAquisicao: 290000,
    dataAquisicao: DateTime(2024, 05),
    manutencoes: [
      MaintenanceEvent(
          data: DateTime(2024, 07),
          tipo: 'Revisão',
          kmNoServico: 10000,
          custo: 1200,
          descricao: 'Revisão 10k - Troca de óleo e filtros',),
      MaintenanceEvent(
          data: DateTime(2024, 10, 15),
          tipo: 'Revisão',
          kmNoServico: 20000,
          custo: 1150,
          descricao: 'Revisão 20k - Troca de óleo e filtros',),
      MaintenanceEvent(
          data: DateTime(2025, 02),
          tipo: 'Revisão',
          kmNoServico: 30000,
          custo: 1350,
          descricao: 'Revisão 30k - Filtros e Injeção',),
      MaintenanceEvent(
          data: DateTime(2025, 05, 10),
          tipo: 'Revisão',
          kmNoServico: 40000,
          custo: 1200,
          descricao: 'Revisão 40k - Troca de óleo e filtros',),
      MaintenanceEvent(
          data: DateTime(2025, 08, 15),
          tipo: 'Revisão',
          kmNoServico: 50000,
          custo: 1800,
          descricao: 'Revisão 50k - Freios e Suspensão',),
      MaintenanceEvent(
          data: DateTime(2025, 12),
          tipo: 'Revisão',
          kmNoServico: 60000,
          custo: 1200,
          descricao: 'Revisão 60k - Troca de óleo e filtros',),
      MaintenanceEvent(
          data: DateTime(2026, 04, 15),
          tipo: 'Revisão',
          kmNoServico: 70000,
          custo: 1250,
          descricao: 'Revisão 70k - Troca amortecedores + óleo',),
    ],
  ),
  VehicleData(
    nome: 'Fiat Argo Drive 1.0',
    placa: 'ARG-1D23',
    motorista: 'João Silva',
    telefoneMotorista: '(11) 98888-1234',
    status: VehicleStatus.emRota,
    mesesEmServico: 41,
    kmPorMes: 2500,
    cor1: const Color(0xFF667EEA),
    cor2: const Color(0xFF764BA2),
    vencimentoIPVA: DateTime(2026, 05, 10),
    vencimentoSeguro: DateTime(2026, 04, 12),
    vencimentoLicenciamento: DateTime(2026, 09, 20),
    valorDeMercado: 55000,
    valorAquisicao: 72000,
    dataAquisicao: DateTime(2022, 11, 10),
    financiamento: const FinancingData(
        valorTotal: 70000,
        percentualEntrada: 0.10,
        totalParcelas: 48,
        parcelasPagas: 41,
        recebimentoMensal: 2000,
        taxaJurosMensal: 0.008,
        previsaoQuitacao: 'Nov/2026',),
    manutencoes: [
      MaintenanceEvent(
          data: DateTime(2023, 03, 10),
          tipo: 'Revisão',
          kmNoServico: 10000,
          custo: 1050,
          descricao: 'Revisão 10k - Troca de óleo e filtros',),
      MaintenanceEvent(
          data: DateTime(2023, 07, 12),
          tipo: 'Revisão',
          kmNoServico: 20000,
          custo: 1200,
          descricao: 'Revisão 20k - Filtros e Alinhamento',),
      MaintenanceEvent(
          data: DateTime(2023, 11, 15),
          tipo: 'Revisão',
          kmNoServico: 30000,
          custo: 1050,
          descricao: 'Revisão 30k - Troca de óleo e filtros',),
      MaintenanceEvent(
          data: DateTime(2024, 03, 20),
          tipo: 'Revisão',
          kmNoServico: 40000,
          custo: 1350,
          descricao: 'Revisão 40k - Filtros, óleo e velas',),
      MaintenanceEvent(
          data: DateTime(2024, 07, 25),
          tipo: 'Revisão',
          kmNoServico: 50000,
          custo: 1050,
          descricao: 'Revisão 50k - Troca de óleo e filtros',),
      MaintenanceEvent(
          data: DateTime(2024, 11, 28),
          tipo: 'Revisão',
          kmNoServico: 60000,
          custo: 1550,
          descricao: 'Revisão 60k - Kit Correia Dentada',),
      MaintenanceEvent(
          data: DateTime(2025, 03, 05),
          tipo: 'Revisão',
          kmNoServico: 70000,
          custo: 1050,
          descricao: 'Revisão 70k - Troca de óleo e filtros',),
      MaintenanceEvent(
          data: DateTime(2025, 07, 10),
          tipo: 'Revisão',
          kmNoServico: 80000,
          custo: 1200,
          descricao: 'Revisão 80k - Discos e Pastilhas de freio',),
      MaintenanceEvent(
          data: DateTime(2025, 11, 15),
          tipo: 'Revisão',
          kmNoServico: 90000,
          custo: 1050,
          descricao: 'Revisão 90k - Troca de óleo e filtros',),
      MaintenanceEvent(
          data: DateTime(2026, 03, 10),
          tipo: 'Revisão',
          kmNoServico: 100000,
          custo: 1800,
          descricao: 'Revisão 100k - Revisão completa + fluidos',),
    ],
  ),
  VehicleData(
    nome: 'Fiat Argo Trekking 1.3',
    placa: 'ARG-4H78',
    motorista: 'Roberto Carlos',
    telefoneMotorista: '(11) 99999-0000',
    status: VehicleStatus.emRota,
    mesesEmServico: 12,
    kmPorMes: 2200,
    cor1: const Color(0xFFf093fb),
    cor2: const Color(0xFFf5576c),
    vencimentoIPVA: DateTime(2027, 01, 15),
    vencimentoSeguro: DateTime(2026, 12),
    vencimentoLicenciamento: DateTime(2026, 12, 10),
    valorDeMercado: 68000,
    valorAquisicao: 85000,
    dataAquisicao: DateTime(2025, 05, 15),
    financiamento: const FinancingData(
        valorTotal: 75000,
        percentualEntrada: 0.15,
        totalParcelas: 60,
        parcelasPagas: 12,
        recebimentoMensal: 2000,
        taxaJurosMensal: 0.008,
        previsaoQuitacao: 'Abr/2030',),
    manutencoes: [
      MaintenanceEvent(
          data: DateTime(2025, 09, 10),
          tipo: 'Revisão',
          kmNoServico: 10000,
          custo: 1050,
          descricao: 'Revisão 10k - Troca de óleo e filtros',),
      MaintenanceEvent(
          data: DateTime(2026, 01, 15),
          tipo: 'Revisão',
          kmNoServico: 20000,
          custo: 1050,
          descricao: 'Revisão 20k - Troca óleo, filtros e alinhamento',),
    ],
  ),
];

List<VehicleData> get frota => FleetRepository.instance.frota;

final List<DriverData> _motoristas = [
  DriverData(
      nome: 'João Silva',
      telefone: '(11) 98888-1234',
      vencimentoCNH: DateTime(2026, 10, 12),
      statusCNH: CnhStatus.ok,
      multas: 0,
      placasVeiculos: ['VD-1234', 'ARG-1D23'],),
  DriverData(
      nome: 'Marcos Antônio',
      telefone: '(11) 97777-5678',
      vencimentoCNH: DateTime(2026, 05, 14),
      statusCNH: CnhStatus.vencendo,
      multas: 2,
      placasVeiculos: ['TX-2041'],),
  DriverData(
      nome: 'Roberto Carlos',
      telefone: '(11) 99999-0000',
      vencimentoCNH: DateTime(2024),
      statusCNH: CnhStatus.vencida,
      multas: 0,
      placasVeiculos: ['ARG-4H78'],),
];

List<DriverData> get motoristas => FleetRepository.instance.motoristas;

// ═══════════════════════════════════════════════════════
// DADOS MENSAIS (gráfico dashboard)
// ═══════════════════════════════════════════════════════

final List<MonthlyData> _dadosMensais = [
  const MonthlyData(
      mes: 'Nov/25', manutencao: 3250, financiamento: 2800, receita: 4000,),
  const MonthlyData(
      mes: 'Dez/25', manutencao: 1150, financiamento: 2800, receita: 4000,),
  const MonthlyData(
      mes: 'Jan/26', manutencao: 2100, financiamento: 2800, receita: 4000,),
  const MonthlyData(
      mes: 'Fev/26', manutencao: 1250, financiamento: 2800, receita: 4000,),
  const MonthlyData(
      mes: 'Mar/26', manutencao: 3650, financiamento: 2800, receita: 4000,),
  const MonthlyData(mes: 'Abr/26', manutencao: 0, financiamento: 2800, receita: 4000),
];

List<MonthlyData> get dadosMensais => FleetRepository.instance.dadosMensais;

// ═══════════════════════════════════════════════════════
// ALERTAS (computados)
// ═══════════════════════════════════════════════════════

List<AlertItem> get frotaAlertas => FleetRepository.instance.frotaAlertas;

// ═══════════════════════════════════════════════════════
// PRÓXIMOS EVENTOS
// ═══════════════════════════════════════════════════════

List<UpcomingEvent> get proximosEventos =>
    FleetRepository.instance.proximosEventos;

// ═══════════════════════════════════════════════════════
// HELPERS
// ═══════════════════════════════════════════════════════

VehicleData? getVehicleByPlate(String placa) {
  return FleetRepository.instance.getVehicleByPlate(placa);
}

bool updateVehicleStatus({
  required String placa,
  required VehicleStatus status,
}) {
  return FleetRepository.instance.updateVehicleStatus(
    placa: placa,
    status: status,
  );
}

List<VehicleData> getVehiclesByDriver(String nome) =>
    FleetRepository.instance.getVehiclesByDriver(nome);

List<VehicleData> get veiculosFinanciados =>
    FleetRepository.instance.veiculosFinanciados;

class FleetRepository extends ChangeNotifier {
  FleetRepository._();

  static final FleetRepository instance = FleetRepository._();

  List<AlertItem>? _cachedAlertas;
  int _version = 0;

  int get version => _version;

  @override
  void notifyListeners() {
    _version++;
    _cachedAlertas = null;
    super.notifyListeners();
  }

  List<VehicleData> get frota => List.unmodifiable(_frota);
  List<DriverData> get motoristas => List.unmodifiable(_motoristas);
  List<MonthlyData> get dadosMensais => List.unmodifiable(_dadosMensais);

  List<VehicleData> get veiculosFinanciados =>
      _frota.where((v) => v.isFinanciado).toList();

  VehicleData? getVehicleByPlate(String placa) {
    try {
      return _frota.firstWhere((v) => v.placa == placa);
    } catch (_) {
      return null;
    }
  }

  List<VehicleData> getVehiclesByDriver(String nome) =>
      _frota.where((v) => v.motorista == nome).toList();

  bool addDriver({
    required String nome,
    required String telefone,
    required DateTime vencimentoCNH,
    int multas = 0,
    List<String> placasVeiculos = const <String>[],
  }) {
    final normalizedName = nome.trim();
    final normalizedPhone = telefone.trim();
    if (normalizedName.isEmpty || normalizedPhone.isEmpty) return false;

    final alreadyExists = _motoristas.any(
      (d) => d.telefone == normalizedPhone,
    );
    if (alreadyExists) return false;

    final hoje = DateTime.now();
    final daysToExpiry = vencimentoCNH.difference(hoje).inDays;
    final status = daysToExpiry < 0
        ? CnhStatus.vencida
        : (daysToExpiry <= 60 ? CnhStatus.vencendo : CnhStatus.ok);

    _motoristas.add(
      DriverData(
        nome: normalizedName,
        telefone: normalizedPhone,
        vencimentoCNH: vencimentoCNH,
        statusCNH: status,
        multas: max(multas, 0),
        placasVeiculos: placasVeiculos,
      ),
    );
    notifyListeners();
    return true;
  }

  bool updateVehicleStatus({
    required String placa,
    required VehicleStatus status,
  }) {
    final index = _frota.indexWhere((v) => v.placa == placa);
    if (index == -1) return false;
    _frota[index] = _frota[index].copyWith(status: status);
    notifyListeners();
    return true;
  }

  List<AlertItem> get frotaAlertas {
    if (_cachedAlertas != null) return _cachedAlertas!;
    final a = <AlertItem>[];
    final hoje = DateTime.now();

    for (final d in _motoristas) {
      if (d.statusCNH == CnhStatus.vencida) {
        a.add(
          AlertItem(
            tipo: AlertType.danger,
            titulo: 'CNH Vencida',
            mensagem:
                '${d.nome} - CNH vencida em ${formatDate(d.vencimentoCNH)}. Regularizar imediatamente.',
          ),
        );
      }
      if (d.statusCNH == CnhStatus.vencendo) {
        a.add(
          AlertItem(
            tipo: AlertType.warning,
            titulo: 'CNH Vencendo',
            mensagem:
                '${d.nome} - CNH vence em ${formatDate(d.vencimentoCNH)}. Agendar renovação.',
          ),
        );
      }
    }

    for (final v in _frota) {
      if (v.kmParaProxRevisao < 2000) {
        a.add(
          AlertItem(
            tipo: AlertType.warning,
            titulo: 'Revisão Próxima',
            mensagem:
                '${v.placa} (${v.nome}) - Faltam ${formatKm(v.kmParaProxRevisao)} para próxima revisão.',
          ),
        );
      }

      if (v.vencimentoSeguro.isBefore(hoje.add(const Duration(days: 15)))) {
        a.add(
          AlertItem(
            tipo: AlertType.danger,
            titulo: 'Seguro Expirando',
            mensagem:
                '${v.placa} - Seguro vence em ${formatDate(v.vencimentoSeguro)}. Renovação Urgente!',
          ),
        );
      }
      if (v.vencimentoIPVA.isBefore(hoje.add(const Duration(days: 20)))) {
        a.add(
          AlertItem(
            tipo: AlertType.warning,
            titulo: 'IPVA Próximo',
            mensagem:
                '${v.placa} - IPVA vence em ${formatDate(v.vencimentoIPVA)}. Verificar pagamento.',
          ),
        );
      }
    }

    for (final v in _frota.where((v) => v.isFinanciado)) {
      if (v.financiamento!.parcelasRestantes <= 7) {
        a.add(
          AlertItem(
            tipo: AlertType.info,
            titulo: 'Quitação Próxima',
            mensagem:
                '${v.placa} - Faltam apenas ${v.financiamento!.parcelasRestantes} parcelas. Previsão: ${v.financiamento!.previsaoQuitacao}.',
          ),
        );
      }
    }
    for (final d in _motoristas) {
      if (d.multas > 0) {
        a.add(
          AlertItem(
            tipo: AlertType.warning,
            titulo: 'Multas Pendentes',
            mensagem: '${d.nome} - ${d.multas} multa(s) pendente(s).',
          ),
        );
      }
    }
    _cachedAlertas = a;
    return a;
  }

  List<UpcomingEvent> get proximosEventos {
    final e = <UpcomingEvent>[];
    final sorted = [..._frota]
      ..sort((a, b) => a.kmParaProxRevisao.compareTo(b.kmParaProxRevisao));
    for (final v in sorted.take(3)) {
      final meses = (v.kmParaProxRevisao / v.kmPorMes).toStringAsFixed(1);
      e.add(
        UpcomingEvent(
          titulo: 'Revisão ${v.placa}',
          descricao: '${v.nome} - ~${formatKm(v.kmParaProxRevisao)} restantes',
          prazo: '~$meses meses',
          tipo: EventType.maintenance,
        ),
      );
    }

    for (final v in _frota.where((v) => v.isFinanciado)) {
      e.add(
        UpcomingEvent(
          titulo:
              'Parcela ${v.financiamento!.parcelasPagas + 1}/${v.financiamento!.totalParcelas}',
          descricao:
              '${v.placa} - ${formatCurrency(v.financiamento!.valorParcela)}',
          prazo: 'Este mês',
          tipo: EventType.payment,
        ),
      );
    }
    return e;
  }
}

final DateFormat _dateFormatter = DateFormat('dd/MM/yyyy');
final NumberFormat _thousandsFormatter = NumberFormat.decimalPattern('pt_BR');

String formatDate(DateTime date) {
  return _dateFormatter.format(date);
}

String formatCurrency(double value) {
  final isNeg = value < 0;
  final abs = value.abs();
  final intP = abs.toInt();
  final dec = ((abs - intP) * 100).round().toString().padLeft(2, '0');
  final fmt = _thousandsFormatter.format(intP);
  return '${isNeg ? '-' : ''}R\$ $fmt,$dec';
}

String formatKm(double km) {
  final intKm = km.toInt();
  return '${_thousandsFormatter.format(intKm)} km';
}

const List<VehicleStatus> statusOptions = VehicleStatus.values;
