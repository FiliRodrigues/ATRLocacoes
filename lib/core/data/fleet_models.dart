import 'dart:math';
import 'package:flutter/material.dart';
import '../enums/vehicle_status.dart';
import '../enums/cnh_status.dart';
import '../enums/alert_type.dart';
import '../enums/event_type.dart';

// ═══════════════════════════════════════════════════════
// MODELOS — extraídos de fleet_data.dart (refactor M1)
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

class VehicleCostEvent {
  final DateTime data;
  final String categoria;
  final double valor;
  final String descricao;

  const VehicleCostEvent({
    required this.data,
    required this.categoria,
    required this.valor,
    required this.descricao,
  });
}

class FinancingData {
  final String? id;
  final double valorTotal;
  final double percentualEntrada;
  final int totalParcelas;
  final int parcelasPagas;
  final double recebimentoMensal;
  final double taxaJurosMensal;
  final String previsaoQuitacao;
  final int mesesLocacaoTotais;
  final int mesesLocacaoPagos;
  final double totalPagoReal;
  final Map<int, double> recebidoPorMes;

  double? recebidoNoMes(int year, int month) => recebidoPorMes[year * 100 + month];

  const FinancingData({
      this.id,
      required this.valorTotal,
      required this.percentualEntrada,
      required this.totalParcelas,
      required this.parcelasPagas,
      required this.recebimentoMensal,
      required this.taxaJurosMensal,
      required this.previsaoQuitacao,
      this.mesesLocacaoTotais = 36,
      this.mesesLocacaoPagos = 0,
      this.totalPagoReal = 0.0,
      this.recebidoPorMes = const {},
  });

  double get valorEntrada => valorTotal * percentualEntrada;
  double get valorFinanciado => valorTotal - valorEntrada;
  double get valorParcela {
    if (totalParcelas <= 1) return 0;
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
  int get locacaoRestantes => max(mesesLocacaoTotais - mesesLocacaoPagos, 0);
  double get totalParcelasCompleto => valorParcela * totalParcelas;
  double get totalJuros => totalParcelasCompleto - valorFinanciado;
  double get totalPago => valorParcela * parcelasPagas;
  double get totalRestante => valorParcela * parcelasRestantes;
  double get totalRecebido =>
      totalPagoReal > 0 ? totalPagoReal : recebimentoMensal * mesesLocacaoPagos;
  double get custoTotalVeiculo => valorEntrada + totalParcelasCompleto;

  double get progressoFinanciamento {
    if (totalParcelas <= 1) return 1.0;
    return (parcelasPagas / totalParcelas).clamp(0.0, 1.0);
  }

  double get progressoLocacao {
    if (mesesLocacaoTotais <= 0 || recebimentoMensal <= 0) return 0.0;
    return (mesesLocacaoPagos / mesesLocacaoTotais).clamp(0.0, 1.0);
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
  final List<VehicleCostEvent> gastosNaoCiclicos;
  final double? kmHodometro;
  final DateTime? ultimaAtualizacaoKm;

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
    this.gastosNaoCiclicos = const [],
    this.kmHodometro,
    this.ultimaAtualizacaoKm,
  });

  VehicleData copyWith({
    VehicleStatus? status,
    double? kmHodometro,
    DateTime? ultimaAtualizacaoKm,
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
      gastosNaoCiclicos: gastosNaoCiclicos,
      kmHodometro: kmHodometro ?? this.kmHodometro,
      ultimaAtualizacaoKm: ultimaAtualizacaoKm ?? this.ultimaAtualizacaoKm,
    );
  }

  double get kmAtual {
    final kmManut = manutencoes.isNotEmpty
        ? manutencoes.map((m) => m.kmNoServico.toDouble()).reduce(max)
        : 0.0;
    final base = kmHodometro ?? (kmPorMes * mesesEmServico);
    return base > kmManut ? base : kmManut;
  }
  bool get isFinanciado => financiamento != null;
  int get totalRevisoes => manutencoes.length;
  double get custoTotalManutencao =>
      manutencoes.fold(0.0, (s, e) => s + e.custo);
  double get custoTotalGastosNaoCiclicos =>
      gastosNaoCiclicos.fold(0.0, (s, e) => s + e.valor);
  double get gastoTotalVeiculoKpi =>
      custoTotalManutencao + custoTotalGastosNaoCiclicos + (financiamento?.totalPago ?? 0);
  double get kmParaProxRevisao => 10000 - (kmAtual % 10000);

  DateTime? get dataPrimeiroRecebimento {
    if (mesesEmServico <= 0) return null;
    return DateTime(
      dataAquisicao.year,
      dataAquisicao.month + 1,
      dataAquisicao.day,
    );
  }

  DateTime? get dataPrimeiroGasto {
    final datas = <DateTime>[
      ...manutencoes.map((e) => e.data),
      ...gastosNaoCiclicos.map((e) => e.data),
    ];
    if (datas.isEmpty) return null;
    datas.sort();
    return datas.first;
  }

  double get lucroPrejuizoAteAgora => receitaTotalAcumulada - gastoTotalVeiculoKpi;

  double get receitaTotalAcumulada =>
      mesesEmServico * (financiamento?.recebimentoMensal ?? 2000.0);
  double get custoTotalAcumulado =>
      custoTotalManutencao + custoTotalGastosNaoCiclicos + (financiamento?.totalPago ?? 0);
  double get lucroAbsoluto => receitaTotalAcumulada - custoTotalAcumulado;
  double get roi {
    if (valorAquisicao <= 0) return 0;
    return (lucroAbsoluto / valorAquisicao) * 100;
  }

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

class KmRegistro {
  final String placa;
  final double km;
  final DateTime data;
  const KmRegistro({
    required this.placa,
    required this.km,
    required this.data,
  });
}
