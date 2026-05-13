import '../enums/maintenance_priority.dart';

/// Regra de manutenção preventiva automática.
///
/// Quando ativa, o sistema verifica periodicamente cada veículo
/// e gera uma OS em [KanbanColumn.pendentes] quando o intervalo é atingido.
class RegraManutencao {
  final String id;

  /// Título da OS gerada (ex: "Troca de Óleo 10k")
  final String titulo;

  /// Tipo de serviço (ex: "Troca de Óleo", "Revisão Periódica", "Pneus")
  final String tipo;

  /// Se preenchido, aplica apenas ao veículo com essa placa.
  /// Se nulo, aplica a todos os veículos da frota.
  final String? veiculoPlaca;

  /// Intervalo em KM para disparar a OS (ex: 10000 para troca de óleo a cada 10k km).
  /// Se nulo, usa apenas [intervaloDias].
  final int? intervaloKm;

  /// Intervalo em dias para disparar a OS (ex: 180 = 6 meses).
  /// Se nulo, usa apenas [intervaloKm].
  final int? intervaloDias;

  final double custoEstimado;
  final MaintenancePriority prioridade;
  final bool isAtiva;

  /// KM do veículo quando a última OS foi gerada por esta regra.
  final int? kmUltimaExecucao;

  /// Data/hora em que a última OS foi gerada por esta regra.
  final DateTime? dataUltimaExecucao;

  const RegraManutencao({
    required this.id,
    required this.titulo,
    required this.tipo,
    this.veiculoPlaca,
    this.intervaloKm,
    this.intervaloDias,
    this.custoEstimado = 0,
    this.prioridade = MaintenancePriority.media,
    this.isAtiva = true,
    this.kmUltimaExecucao,
    this.dataUltimaExecucao,
  }) : assert(
          intervaloKm != null || intervaloDias != null,
          'Ao menos um critério (intervaloKm ou intervaloDias) deve ser definido.',
        );

  /// Retorna true se a regra deve disparar para [kmAtual] e [dataReferencia].
  bool deveDisparar({
    required double kmAtual,
    required DateTime dataReferencia,
  }) {
    if (!isAtiva) return false;

    // Verifica por KM
    if (intervaloKm != null && kmUltimaExecucao != null) {
      if (kmAtual - kmUltimaExecucao! >= intervaloKm!) return true;
    }
    // Nunca rodou — usa KM absoluto como proxy (km % intervalo dentro de 5%)
    if (intervaloKm != null && kmUltimaExecucao == null) {
      final resto = kmAtual % intervaloKm!;
      if (resto < intervaloKm! * 0.05) return true;
    }

    // Verifica por dias
    if (intervaloDias != null && dataUltimaExecucao != null) {
      final diasPassados =
          dataReferencia.difference(dataUltimaExecucao!).inDays;
      if (diasPassados >= intervaloDias!) return true;
    }
    // Nunca rodou por tempo — dispara na primeira verificação se tem só intervalo de dias
    if (intervaloDias != null &&
        intervaloKm == null &&
        dataUltimaExecucao == null) {
      return true;
    }

    return false;
  }

  RegraManutencao copyWith({
    String? id,
    String? titulo,
    String? tipo,
    String? veiculoPlaca,
    int? intervaloKm,
    int? intervaloDias,
    double? custoEstimado,
    MaintenancePriority? prioridade,
    bool? isAtiva,
    int? kmUltimaExecucao,
    DateTime? dataUltimaExecucao,
    bool clearVeiculoPlaca = false,
    bool clearIntervaloKm = false,
    bool clearIntervaloDias = false,
    bool clearKmUltima = false,
    bool clearDataUltima = false,
  }) {
    return RegraManutencao(
      id: id ?? this.id,
      titulo: titulo ?? this.titulo,
      tipo: tipo ?? this.tipo,
      veiculoPlaca:
          clearVeiculoPlaca ? null : (veiculoPlaca ?? this.veiculoPlaca),
      intervaloKm: clearIntervaloKm ? null : (intervaloKm ?? this.intervaloKm),
      intervaloDias:
          clearIntervaloDias ? null : (intervaloDias ?? this.intervaloDias),
      custoEstimado: custoEstimado ?? this.custoEstimado,
      prioridade: prioridade ?? this.prioridade,
      isAtiva: isAtiva ?? this.isAtiva,
      kmUltimaExecucao:
          clearKmUltima ? null : (kmUltimaExecucao ?? this.kmUltimaExecucao),
      dataUltimaExecucao: clearDataUltima
          ? null
          : (dataUltimaExecucao ?? this.dataUltimaExecucao),
    );
  }
}
