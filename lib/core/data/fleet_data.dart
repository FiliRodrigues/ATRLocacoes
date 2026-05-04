import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../enums/vehicle_status.dart';
import '../enums/cnh_status.dart';
import '../enums/alert_type.dart';
import '../enums/event_type.dart';
import '../services/supabase_service.dart';

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
  final double valorTotal;
  final double percentualEntrada;
  final int totalParcelas;
  final int parcelasPagas;
  final double recebimentoMensal;
  final double taxaJurosMensal;
  final String previsaoQuitacao;
  final int mesesLocacaoTotais;
  final int mesesLocacaoPagos;
  
  const FinancingData({
      required this.valorTotal,
      required this.percentualEntrada,
      required this.totalParcelas,
      required this.parcelasPagas,
      required this.recebimentoMensal,
      required this.taxaJurosMensal,
      required this.previsaoQuitacao,
      this.mesesLocacaoTotais = 36,
      this.mesesLocacaoPagos = 0,
  });

  double get valorEntrada => valorTotal * percentualEntrada;
  double get valorFinanciado => valorTotal - valorEntrada;
  double get valorParcela {
    if (totalParcelas <= 1) return 0; // Quitado não tem parcela calculada
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
  double get totalRecebido => recebimentoMensal * mesesLocacaoPagos;
  double get custoTotalVeiculo => valorEntrada + totalParcelasCompleto;
  
  double get progressoFinanciamento {
    if (totalParcelas <= 1) return 1.0; // Quitado = 100%
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

  double get kmAtual => kmHodometro ?? (kmPorMes * mesesEmServico);
  bool get isFinanciado => financiamento != null;
  int get totalRevisoes => manutencoes.length;
  double get custoTotalManutencao =>
      manutencoes.fold(0.0, (s, e) => s + e.custo);
  double get custoTotalGastosNaoCiclicos =>
      gastosNaoCiclicos.fold(0.0, (s, e) => s + e.valor);
  double get gastoTotalVeiculoKpi =>
      custoTotalManutencao + custoTotalGastosNaoCiclicos;
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

// ═══════════════════════════════════════════════════════
// DADOS FROTA — carregados do Supabase em runtime
// ═══════════════════════════════════════════════════════

final List<VehicleData> _frota = [];

List<VehicleData> get frota => FleetRepository.instance.frota;

final List<DriverData> _motoristas = [];

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
  bool _isLoading = false;
  String? _loadError;

  bool get isLoading => _isLoading;
  String? get loadError => _loadError;

  final List<KmRegistro> _kmHistorico = [];

  /// Carrega a frota do Supabase, substituindo todos os dados locais.
  Future<void> loadFromSupabase() async {
    _isLoading = true;
    _loadError = null;
    notifyListeners();
    try {
      final veiculos = await FleetSupabaseService.fetchVehicles();
      _frota
        ..clear()
        ..addAll(veiculos);
      _motoristas.clear();
    } catch (e) {
      _loadError = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  List<KmRegistro> get kmHistorico => List.unmodifiable(_kmHistorico);

  List<KmRegistro> kmHistoricoVeiculo(String placa) => _kmHistorico
      .where((r) => r.placa == placa)
      .toList()
    ..sort((a, b) => b.data.compareTo(a.data));

  int get version => _version;

  /// Injeta veículos diretamente para uso em testes unitários.
  /// Não deve ser chamado em código de produção.
  @visibleForTesting
  void seedForTest(List<VehicleData> vehicles,
      {List<DriverData> drivers = const [],}) {
    _frota
      ..clear()
      ..addAll(vehicles);
    _motoristas
      ..clear()
      ..addAll(drivers);
    _cachedAlertas = null;
  }

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

  bool updateVehicleKm({
    required String placa,
    required double km,
  }) {
    final index = _frota.indexWhere((v) => v.placa == placa);
    if (index == -1) return false;
    _frota[index] = _frota[index].copyWith(
      kmHodometro: km,
      ultimaAtualizacaoKm: DateTime.now(),
    );
    _kmHistorico.add(
      KmRegistro(placa: placa, km: km, data: DateTime.now()),
    );
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
