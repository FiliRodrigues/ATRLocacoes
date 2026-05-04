import '../enums/maintenance_priority.dart';
import '../enums/kanban_column.dart';

class ManutencaoItem {
  final String id;
  final String veiculoPlaca;
  final String veiculoNome;
  final String titulo;
  final String descricao;
  final String tipo;
  final DateTime data;
  final int kmNoServico;
  final int odometro;
  final double custo;
  final MaintenancePriority prioridade;
  final KanbanColumn coluna;
  final String fornecedor;
  final String numeroOS;
  final String nomeAnexo;
  final bool isPreventiva;
  final DateTime? dataConclusao;

  const ManutencaoItem({
    required this.id,
    required this.veiculoPlaca,
    required this.veiculoNome,
    required this.titulo,
    this.descricao = '',
    required this.tipo,
    required this.data,
    this.kmNoServico = 0,
    this.odometro = 0,
    this.custo = 0,
    required this.prioridade,
    required this.coluna,
    this.fornecedor = '',
    this.numeroOS = '',
    this.nomeAnexo = '',
    this.isPreventiva = true,
    this.dataConclusao,
  });

  bool get isDone => coluna == KanbanColumn.concluidos;

  ManutencaoItem copyWith({
    String? id,
    String? veiculoPlaca,
    String? veiculoNome,
    String? titulo,
    String? descricao,
    String? tipo,
    DateTime? data,
    int? kmNoServico,
    int? odometro,
    double? custo,
    MaintenancePriority? prioridade,
    KanbanColumn? coluna,
    String? fornecedor,
    String? numeroOS,
    String? nomeAnexo,
    bool? isPreventiva,
    DateTime? dataConclusao,
    bool clearDataConclusao = false,
  }) {
    return ManutencaoItem(
      id: id ?? this.id,
      veiculoPlaca: veiculoPlaca ?? this.veiculoPlaca,
      veiculoNome: veiculoNome ?? this.veiculoNome,
      titulo: titulo ?? this.titulo,
      descricao: descricao ?? this.descricao,
      tipo: tipo ?? this.tipo,
      data: data ?? this.data,
      kmNoServico: kmNoServico ?? this.kmNoServico,
      odometro: odometro ?? this.odometro,
      custo: custo ?? this.custo,
      prioridade: prioridade ?? this.prioridade,
      coluna: coluna ?? this.coluna,
      fornecedor: fornecedor ?? this.fornecedor,
      numeroOS: numeroOS ?? this.numeroOS,
      nomeAnexo: nomeAnexo ?? this.nomeAnexo,
      isPreventiva: isPreventiva ?? this.isPreventiva,
      dataConclusao: clearDataConclusao
          ? null
          : (dataConclusao ?? this.dataConclusao),
    );
  }
}

class DespesaItem {
  final String id;
  final String veiculoPlaca;
  final String motorista;
  final DateTime data;
  final String tipo;
  final String descricao;
  final int odometro;
  final double litros;
  final double valor;
  final bool pago;
  final String nf;
  final String nomeAnexo;

  String get veiculo => veiculoPlaca;
  bool get temAnexo => nomeAnexo.isNotEmpty;

  const DespesaItem({
    required this.id,
    String? veiculoPlaca,
    String? veiculo,
    this.motorista = '',
    required this.data,
    required this.tipo,
    this.descricao = '',
    this.odometro = 0,
    this.litros = 0.0,
    this.valor = 0,
    this.pago = false,
    this.nf = '',
    this.nomeAnexo = '',
  }) : veiculoPlaca = veiculoPlaca ?? veiculo ?? '';

  DespesaItem copyWith({
    String? id,
    String? veiculoPlaca,
    String? motorista,
    DateTime? data,
    String? tipo,
    String? descricao,
    int? odometro,
    double? litros,
    double? valor,
    bool? pago,
    String? nf,
    String? nomeAnexo,
  }) {
    return DespesaItem(
      id: id ?? this.id,
      veiculoPlaca: veiculoPlaca ?? this.veiculoPlaca,
      motorista: motorista ?? this.motorista,
      data: data ?? this.data,
      tipo: tipo ?? this.tipo,
      descricao: descricao ?? this.descricao,
      odometro: odometro ?? this.odometro,
      litros: litros ?? this.litros,
      valor: valor ?? this.valor,
      pago: pago ?? this.pago,
      nf: nf ?? this.nf,
      nomeAnexo: nomeAnexo ?? this.nomeAnexo,
    );
  }
}
