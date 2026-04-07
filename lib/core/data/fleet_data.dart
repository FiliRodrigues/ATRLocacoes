import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// ═══════════════════════════════════════════════════════
// MODELOS
// ═══════════════════════════════════════════════════════

class MaintenanceEvent {
  final DateTime data;
  final String tipo;
  final int kmNoServico;
  final double custo;
  final String descricao;
  const MaintenanceEvent({required this.data, required this.tipo, required this.kmNoServico, required this.custo, required this.descricao});
}

class FinancingData {
  final double valorTotal;
  final double percentualEntrada;
  final int totalParcelas;
  final int parcelasPagas;
  final double recebimentoMensal;
  final double taxaJurosMensal;
  final String previsaoQuitacao;
  const FinancingData({required this.valorTotal, required this.percentualEntrada, required this.totalParcelas, required this.parcelasPagas, required this.recebimentoMensal, required this.taxaJurosMensal, required this.previsaoQuitacao});

  double get valorEntrada => valorTotal * percentualEntrada;
  double get valorFinanciado => valorTotal - valorEntrada;
  double get valorParcela { final i = taxaJurosMensal; final n = totalParcelas; final pv = valorFinanciado; final f = pow(1 + i, n).toDouble(); return pv * (i * f) / (f - 1); }
  int get parcelasRestantes => totalParcelas - parcelasPagas;
  double get totalParcelasCompleto => valorParcela * totalParcelas;
  double get totalJuros => totalParcelasCompleto - valorFinanciado;
  double get totalPago => valorParcela * parcelasPagas;
  double get totalRestante => valorParcela * parcelasRestantes;
  double get totalRecebido => recebimentoMensal * parcelasPagas;
  double get custoTotalVeiculo => valorEntrada + totalParcelasCompleto;
  double get progressoFinanciamento => parcelasPagas / totalParcelas;
  double get taxaJurosAnual => pow(1 + taxaJurosMensal, 12).toDouble() - 1;
  double get saldoMensal => recebimentoMensal - valorParcela;
}

class VehicleData {
  final String nome;
  final String placa;
  final String motorista;
  final String telefoneMotorista;
  String status;
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

  double get kmAtual => kmPorMes * mesesEmServico;
  bool get isFinanciado => financiamento != null;
  int get totalRevisoes => manutencoes.length;
  double get custoTotalManutencao => manutencoes.fold(0.0, (s, e) => s + e.custo);
  double get kmParaProxRevisao => 10000 - (kmAtual % 10000);

  // Inteligência Financeira
  double get receitaTotalAcumulada => mesesEmServico * (financiamento?.recebimentoMensal ?? 2000.0);
  double get custoTotalAcumulado => custoTotalManutencao + (financiamento?.totalPago ?? 0);
  double get lucroAbsoluto => receitaTotalAcumulada - custoTotalAcumulado;
  double get roi => (lucroAbsoluto / valorAquisicao) * 100;
  
  // Lógica de Ponto de Venda (Depreciação vs Custo)
  String get sugestaoVenda {
    final depreciacao = valorAquisicao - valorDeMercado;
    final custoManutencaoAnual = custoTotalManutencao / (mesesEmServico / 12);
    if (custoManutencaoAnual > (valorDeMercado * 0.15)) return 'SUGESTÃO: VENDA IMEDIATA (Custo Altíssimo)';
    if (mesesEmServico > 48 || kmAtual > 120000) return 'SUGESTÃO: TROCA PREVENTIVA (KM/Tempo)';
    return 'CARRO SAUDÁVEL (Manter em Frota)';
  }
}

class DriverData {
  final String nome;
  final String telefone;
  final DateTime vencimentoCNH;
  final String statusCNH;
  final int multas;
  final List<String> placasVeiculos;
  const DriverData({required this.nome, required this.telefone, required this.vencimentoCNH, required this.statusCNH, required this.multas, required this.placasVeiculos});
}

class AlertItem {
  final String tipo; // danger, warning, info
  final String titulo;
  final String mensagem;
  const AlertItem({required this.tipo, required this.titulo, required this.mensagem});
}

class MonthlyData {
  final String mes;
  final double manutencao;
  final double financiamento;
  final double receita;
  const MonthlyData({required this.mes, required this.manutencao, required this.financiamento, required this.receita});
  double get custoTotal => manutencao + financiamento;
}

class UpcomingEvent {
  final String titulo;
  final String descricao;
  final String prazo;
  final String tipo; // maintenance, payment, alert
  const UpcomingEvent({required this.titulo, required this.descricao, required this.prazo, required this.tipo});
}

// ═══════════════════════════════════════════════════════
// DADOS MOCK — FROTA
// ═══════════════════════════════════════════════════════

final List<VehicleData> frota = [
  VehicleData(
    nome: 'Toyota Corolla XEi 2.0', placa: 'VD-1234', motorista: 'João Silva', telefoneMotorista: '(11) 98888-1234',
    status: 'EM ROTA', mesesEmServico: 36, kmPorMes: 2800, imagemAsset: 'assets/images/corolla.png',
    cor1: const Color(0xFF3B82F6), cor2: const Color(0xFF1D4ED8),
    vencimentoIPVA: DateTime(2026, 08, 15), vencimentoSeguro: DateTime(2026, 05, 20), vencimentoLicenciamento: DateTime(2026, 10, 30),
    valorDeMercado: 115000, valorAquisicao: 145000, dataAquisicao: DateTime(2023, 01, 10),
    manutencoes: [
      MaintenanceEvent(data: DateTime(2023, 07, 15), tipo: 'Revisão', kmNoServico: 10000, custo: 1050, descricao: 'Revisão 10k - Troca de óleo e filtros'),
      MaintenanceEvent(data: DateTime(2023, 11, 20), tipo: 'Revisão', kmNoServico: 20000, custo: 1150, descricao: 'Revisão 20k - Troca óleo, filtros e alinhamento'),
      MaintenanceEvent(data: DateTime(2024, 03, 10), tipo: 'Revisão', kmNoServico: 30000, custo: 1050, descricao: 'Revisão 30k - Troca de óleo e filtros'),
      MaintenanceEvent(data: DateTime(2024, 07, 15), tipo: 'Revisão', kmNoServico: 40000, custo: 1250, descricao: 'Revisão 40k - Filtros, óleo e velas'),
      MaintenanceEvent(data: DateTime(2024, 11, 20), tipo: 'Revisão', kmNoServico: 50000, custo: 1050, descricao: 'Revisão 50k - Troca de óleo e filtros'),
      MaintenanceEvent(data: DateTime(2025, 03, 10), tipo: 'Revisão', kmNoServico: 60000, custo: 1450, descricao: 'Revisão 60k - Kit Correias e Arrefecimento'),
      MaintenanceEvent(data: DateTime(2025, 07, 15), tipo: 'Revisão', kmNoServico: 70000, custo: 1050, descricao: 'Revisão 70k - Troca de óleo e filtros'),
      MaintenanceEvent(data: DateTime(2025, 11, 20), tipo: 'Revisão', kmNoServico: 80000, custo: 1200, descricao: 'Revisão 80k - Troca pastilhas e discos de freio'),
      MaintenanceEvent(data: DateTime(2026, 03, 10), tipo: 'Revisão', kmNoServico: 90000, custo: 1050, descricao: 'Revisão 90k - Troca de óleo e filtros'),
      MaintenanceEvent(data: DateTime(2026, 07, 15), tipo: 'Revisão', kmNoServico: 100000, custo: 1200, descricao: 'Revisão 100k - Revisão completa + correia'),
    ],
  ),
  VehicleData(
    nome: 'Toyota Hilux SRV 2.8', placa: 'TX-2041', motorista: 'Marcos Antônio', telefoneMotorista: '(11) 97777-5678',
    status: 'EM ROTA', mesesEmServico: 24, kmPorMes: 3000, imagemAsset: 'assets/images/hilux.png',
    cor1: const Color(0xFF10B981), cor2: const Color(0xFF059669),
    vencimentoIPVA: DateTime(2026, 04, 15), vencimentoSeguro: DateTime(2026, 09, 10), vencimentoLicenciamento: DateTime(2026, 11, 15),
    valorDeMercado: 245000, valorAquisicao: 290000, dataAquisicao: DateTime(2024, 05, 01),
    manutencoes: [
      MaintenanceEvent(data: DateTime(2024, 07, 01), tipo: 'Revisão', kmNoServico: 10000, custo: 1200, descricao: 'Revisão 10k - Troca de óleo e filtros'),
      MaintenanceEvent(data: DateTime(2024, 10, 15), tipo: 'Revisão', kmNoServico: 20000, custo: 1150, descricao: 'Revisão 20k - Troca de óleo e filtros'),
      MaintenanceEvent(data: DateTime(2025, 02, 01), tipo: 'Revisão', kmNoServico: 30000, custo: 1350, descricao: 'Revisão 30k - Filtros e Injeção'),
      MaintenanceEvent(data: DateTime(2025, 05, 10), tipo: 'Revisão', kmNoServico: 40000, custo: 1200, descricao: 'Revisão 40k - Troca de óleo e filtros'),
      MaintenanceEvent(data: DateTime(2025, 08, 15), tipo: 'Revisão', kmNoServico: 50000, custo: 1800, descricao: 'Revisão 50k - Freios e Suspensão'),
      MaintenanceEvent(data: DateTime(2025, 12, 01), tipo: 'Revisão', kmNoServico: 60000, custo: 1200, descricao: 'Revisão 60k - Troca de óleo e filtros'),
      MaintenanceEvent(data: DateTime(2026, 04, 15), tipo: 'Revisão', kmNoServico: 70000, custo: 1250, descricao: 'Revisão 70k - Troca amortecedores + óleo'),
    ],
  ),
  VehicleData(
    nome: 'Fiat Argo Drive 1.0', placa: 'ARG-1D23', motorista: 'João Silva', telefoneMotorista: '(11) 98888-1234',
    status: 'EM ROTA', mesesEmServico: 41, kmPorMes: 2500,
    cor1: const Color(0xFF667EEA), cor2: const Color(0xFF764BA2),
    vencimentoIPVA: DateTime(2026, 05, 10), vencimentoSeguro: DateTime(2026, 04, 12), vencimentoLicenciamento: DateTime(2026, 09, 20),
    valorDeMercado: 55000, valorAquisicao: 72000, dataAquisicao: DateTime(2022, 11, 10),
    financiamento: const FinancingData(valorTotal: 70000, percentualEntrada: 0.10, totalParcelas: 48, parcelasPagas: 41, recebimentoMensal: 2000, taxaJurosMensal: 0.008, previsaoQuitacao: 'Nov/2026'),
    manutencoes: [
      MaintenanceEvent(data: DateTime(2023, 03, 10), tipo: 'Revisão', kmNoServico: 10000, custo: 1050, descricao: 'Revisão 10k - Troca de óleo e filtros'),
      MaintenanceEvent(data: DateTime(2023, 07, 12), tipo: 'Revisão', kmNoServico: 20000, custo: 1200, descricao: 'Revisão 20k - Filtros e Alinhamento'),
      MaintenanceEvent(data: DateTime(2023, 11, 15), tipo: 'Revisão', kmNoServico: 30000, custo: 1050, descricao: 'Revisão 30k - Troca de óleo e filtros'),
      MaintenanceEvent(data: DateTime(2024, 03, 20), tipo: 'Revisão', kmNoServico: 40000, custo: 1350, descricao: 'Revisão 40k - Filtros, óleo e velas'),
      MaintenanceEvent(data: DateTime(2024, 07, 25), tipo: 'Revisão', kmNoServico: 50000, custo: 1050, descricao: 'Revisão 50k - Troca de óleo e filtros'),
      MaintenanceEvent(data: DateTime(2024, 11, 28), tipo: 'Revisão', kmNoServico: 60000, custo: 1550, descricao: 'Revisão 60k - Kit Correia Dentada'),
      MaintenanceEvent(data: DateTime(2025, 03, 05), tipo: 'Revisão', kmNoServico: 70000, custo: 1050, descricao: 'Revisão 70k - Troca de óleo e filtros'),
      MaintenanceEvent(data: DateTime(2025, 07, 10), tipo: 'Revisão', kmNoServico: 80000, custo: 1200, descricao: 'Revisão 80k - Discos e Pastilhas de freio'),
      MaintenanceEvent(data: DateTime(2025, 11, 15), tipo: 'Revisão', kmNoServico: 90000, custo: 1050, descricao: 'Revisão 90k - Troca de óleo e filtros'),
      MaintenanceEvent(data: DateTime(2026, 03, 10), tipo: 'Revisão', kmNoServico: 100000, custo: 1800, descricao: 'Revisão 100k - Revisão completa + fluidos'),
    ],
  ),
  VehicleData(
    nome: 'Fiat Argo Trekking 1.3', placa: 'ARG-4H78', motorista: 'Roberto Carlos', telefoneMotorista: '(11) 99999-0000',
    status: 'EM ROTA', mesesEmServico: 12, kmPorMes: 2200,
    cor1: const Color(0xFFf093fb), cor2: const Color(0xFFf5576c),
    vencimentoIPVA: DateTime(2027, 01, 15), vencimentoSeguro: DateTime(2026, 12, 01), vencimentoLicenciamento: DateTime(2026, 12, 10),
    valorDeMercado: 68000, valorAquisicao: 85000, dataAquisicao: DateTime(2025, 05, 15),
    financiamento: const FinancingData(valorTotal: 75000, percentualEntrada: 0.15, totalParcelas: 60, parcelasPagas: 12, recebimentoMensal: 2000, taxaJurosMensal: 0.008, previsaoQuitacao: 'Abr/2030'),
    manutencoes: [
      MaintenanceEvent(data: DateTime(2025, 09, 10), tipo: 'Revisão', kmNoServico: 10000, custo: 1050, descricao: 'Revisão 10k - Troca de óleo e filtros'),
      MaintenanceEvent(data: DateTime(2026, 01, 15), tipo: 'Revisão', kmNoServico: 20000, custo: 1050, descricao: 'Revisão 20k - Troca óleo, filtros e alinhamento'),
    ],
  ),
];

final List<DriverData> motoristas = [
  DriverData(nome: 'João Silva', telefone: '(11) 98888-1234', vencimentoCNH: DateTime(2026, 10, 12), statusCNH: 'ok', multas: 0, placasVeiculos: ['VD-1234', 'ARG-1D23']),
  DriverData(nome: 'Marcos Antônio', telefone: '(11) 97777-5678', vencimentoCNH: DateTime(2026, 05, 14), statusCNH: 'vencendo', multas: 2, placasVeiculos: ['TX-2041']),
  DriverData(nome: 'Roberto Carlos', telefone: '(11) 99999-0000', vencimentoCNH: DateTime(2024, 01, 01), statusCNH: 'vencida', multas: 0, placasVeiculos: ['ARG-4H78']),
];

// ═══════════════════════════════════════════════════════
// DADOS MENSAIS (gráfico dashboard)
// ═══════════════════════════════════════════════════════

final List<MonthlyData> dadosMensais = [
  MonthlyData(mes: 'Nov/25', manutencao: 3250, financiamento: 2800, receita: 4000),
  MonthlyData(mes: 'Dez/25', manutencao: 1150, financiamento: 2800, receita: 4000),
  MonthlyData(mes: 'Jan/26', manutencao: 2100, financiamento: 2800, receita: 4000),
  MonthlyData(mes: 'Fev/26', manutencao: 1250, financiamento: 2800, receita: 4000),
  MonthlyData(mes: 'Mar/26', manutencao: 3650, financiamento: 2800, receita: 4000),
  MonthlyData(mes: 'Abr/26', manutencao: 0, financiamento: 2800, receita: 4000),
];

// ═══════════════════════════════════════════════════════
// ALERTAS (computados)
// ═══════════════════════════════════════════════════════

List<AlertItem> get frotaAlertas {
  final a = <AlertItem>[];
  final hoje = DateTime.now();
  
  for (final d in motoristas) {
    if (d.statusCNH == 'vencida') a.add(AlertItem(tipo: 'danger', titulo: 'CNH Vencida', mensagem: '${d.nome} - CNH vencida em ${formatDate(d.vencimentoCNH)}. Regularizar imediatamente.'));
    if (d.statusCNH == 'vencendo') a.add(AlertItem(tipo: 'warning', titulo: 'CNH Vencendo', mensagem: '${d.nome} - CNH vence em ${formatDate(d.vencimentoCNH)}. Agendar renovação.'));
  }

  for (final v in frota) {
    if (v.kmParaProxRevisao < 2000) a.add(AlertItem(tipo: 'warning', titulo: 'Revisão Próxima', mensagem: '${v.placa} (${v.nome}) - Faltam ${formatKm(v.kmParaProxRevisao)} para próxima revisão.'));
    
    // Alertas de Documentação (Compliance)
    if (v.vencimentoSeguro.isBefore(hoje.add(const Duration(days: 15)))) {
      a.add(AlertItem(tipo: 'danger', titulo: 'Seguro Expirando', mensagem: '${v.placa} - Seguro vence em ${formatDate(v.vencimentoSeguro)}. Renovação Urgente!'));
    }
    if (v.vencimentoIPVA.isBefore(hoje.add(const Duration(days: 20)))) {
      a.add(AlertItem(tipo: 'warning', titulo: 'IPVA Próximo', mensagem: '${v.placa} - IPVA vence em ${formatDate(v.vencimentoIPVA)}. Verificar pagamento.'));
    }
  }

  for (final v in frota.where((v) => v.isFinanciado)) {
    if (v.financiamento!.parcelasRestantes <= 7) a.add(AlertItem(tipo: 'info', titulo: 'Quitação Próxima', mensagem: '${v.placa} - Faltam apenas ${v.financiamento!.parcelasRestantes} parcelas. Previsão: ${v.financiamento!.previsaoQuitacao}.'));
  }
  for (final d in motoristas) {
    if (d.multas > 0) a.add(AlertItem(tipo: 'warning', titulo: 'Multas Pendentes', mensagem: '${d.nome} - ${d.multas} multa(s) pendente(s).'));
  }
  return a;
}

// ═══════════════════════════════════════════════════════
// PRÓXIMOS EVENTOS
// ═══════════════════════════════════════════════════════

List<UpcomingEvent> get proximosEventos {
  final e = <UpcomingEvent>[];
  // Revisões próximas
  final sorted = [...frota]..sort((a, b) => a.kmParaProxRevisao.compareTo(b.kmParaProxRevisao));
  for (final v in sorted.take(3)) {
    final meses = (v.kmParaProxRevisao / v.kmPorMes).toStringAsFixed(1);
    e.add(UpcomingEvent(titulo: 'Revisão ${v.placa}', descricao: '${v.nome} - ~${formatKm(v.kmParaProxRevisao)} restantes', prazo: '~$meses meses', tipo: 'maintenance'));
  }
  // Parcelas
  for (final v in frota.where((v) => v.isFinanciado)) {
    e.add(UpcomingEvent(titulo: 'Parcela ${v.financiamento!.parcelasPagas + 1}/${v.financiamento!.totalParcelas}', descricao: '${v.placa} - ${formatCurrency(v.financiamento!.valorParcela)}', prazo: 'Este mês', tipo: 'payment'));
  }
  return e;
}

// ═══════════════════════════════════════════════════════
// HELPERS
// ═══════════════════════════════════════════════════════

VehicleData? getVehicleByPlate(String placa) {
  try { return frota.firstWhere((v) => v.placa == placa); } catch (_) { return null; }
}

List<VehicleData> getVehiclesByDriver(String nome) => frota.where((v) => v.motorista == nome).toList();

List<VehicleData> get veiculosFinanciados => frota.where((v) => v.isFinanciado).toList();

String formatDate(DateTime date) {
  return DateFormat('dd/MM/yyyy').format(date);
}

String formatCurrency(double value) {
  final isNeg = value < 0;
  final abs = value.abs();
  final intP = abs.toInt();
  final dec = ((abs - intP) * 100).round().toString().padLeft(2, '0');
  final fmt = intP.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.');
  return '${isNeg ? '-' : ''}R\$ $fmt,$dec';
}

String formatKm(double km) {
  final intKm = km.toInt();
  return '${intKm.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')} km';
}

const List<String> statusOptions = ['EM ROTA', 'EM OFICINA', 'PARADO', 'RESERVA'];
