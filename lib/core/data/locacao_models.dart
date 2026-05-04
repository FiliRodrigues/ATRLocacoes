import 'package:flutter/material.dart';

// ═══════════════════════════════════════════════════════
// ENUMS
// ═══════════════════════════════════════════════════════

enum ContratoStatus {
  rascunho('Rascunho', Color(0xFF94A3B8)),
  ativo('Ativo', Color(0xFF34D399)),
  suspenso('Suspenso', Color(0xFFFBBF24)),
  encerrado('Encerrado', Color(0xFFF87171));

  const ContratoStatus(this.label, this.color);
  final String label;
  final Color color;
}

enum ChecklistTipo {
  checkIn('Check-in'),
  checkOut('Check-out');

  const ChecklistTipo(this.label);
  final String label;
}

enum OcorrenciaTipo {
  multa('Multa', Color(0xFFFBBF24)),
  sinistro('Sinistro', Color(0xFFF87171)),
  avaria('Avaria', Color(0xFFFF8C42)),
  outro('Outro', Color(0xFF94A3B8));

  const OcorrenciaTipo(this.label, this.color);
  final String label;
  final Color color;
}

enum OcorrenciaStatus {
  aberta('Aberta', Color(0xFFF87171)),
  emAnalise('Em Análise', Color(0xFFFBBF24)),
  resolvida('Resolvida', Color(0xFF34D399)),
  cancelada('Cancelada', Color(0xFF94A3B8));

  const OcorrenciaStatus(this.label, this.color);
  final String label;
  final Color color;
}

// ═══════════════════════════════════════════════════════
// MODELOS
// ═══════════════════════════════════════════════════════

class Contrato {
  final String id;
  final String numero;
  final String clienteNome;
  final String clienteCnpj;
  final String clienteContato;
  final String veiculoPlaca;
  final DateTime dataInicio;
  final DateTime dataFim;
  final int slaKmMes;
  final double valorMensal;
  final ContratoStatus status;
  final String observacoes;
  final String criadoPor;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Contrato({
    required this.id,
    required this.numero,
    required this.clienteNome,
    required this.clienteCnpj,
    this.clienteContato = '',
    required this.veiculoPlaca,
    required this.dataInicio,
    required this.dataFim,
    this.slaKmMes = 0,
    required this.valorMensal,
    this.status = ContratoStatus.rascunho,
    this.observacoes = '',
    this.criadoPor = '',
    required this.createdAt,
    required this.updatedAt,
  });

  int get duracaoMeses {
    final diff = dataFim.difference(dataInicio);
    return (diff.inDays / 30).ceil().clamp(1, 9999);
  }

  double get valorTotalContrato => valorMensal * duracaoMeses;

  bool get isVigente {
    final hoje = DateTime.now();
    return status == ContratoStatus.ativo &&
        hoje.isAfter(dataInicio) &&
        hoje.isBefore(dataFim.add(const Duration(days: 1)));
  }

  Contrato copyWith({
    String? id,
    String? numero,
    String? clienteNome,
    String? clienteCnpj,
    String? clienteContato,
    String? veiculoPlaca,
    DateTime? dataInicio,
    DateTime? dataFim,
    int? slaKmMes,
    double? valorMensal,
    ContratoStatus? status,
    String? observacoes,
    String? criadoPor,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Contrato(
      id: id ?? this.id,
      numero: numero ?? this.numero,
      clienteNome: clienteNome ?? this.clienteNome,
      clienteCnpj: clienteCnpj ?? this.clienteCnpj,
      clienteContato: clienteContato ?? this.clienteContato,
      veiculoPlaca: veiculoPlaca ?? this.veiculoPlaca,
      dataInicio: dataInicio ?? this.dataInicio,
      dataFim: dataFim ?? this.dataFim,
      slaKmMes: slaKmMes ?? this.slaKmMes,
      valorMensal: valorMensal ?? this.valorMensal,
      status: status ?? this.status,
      observacoes: observacoes ?? this.observacoes,
      criadoPor: criadoPor ?? this.criadoPor,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toRow() => {
        'numero': numero,
        'cliente_nome': clienteNome,
        'cliente_cnpj': clienteCnpj,
        'cliente_contato': clienteContato,
        'veiculo_placa': veiculoPlaca,
        'data_inicio': dataInicio.toIso8601String().split('T').first,
        'data_fim': dataFim.toIso8601String().split('T').first,
        'sla_km_mes': slaKmMes,
        'valor_mensal': valorMensal,
        'status': status.name,
        'observacoes': observacoes,
        'criado_por': criadoPor,
      };

  factory Contrato.fromRow(Map<String, dynamic> row) => Contrato(
        id: row['id'] as String,
        numero: row['numero'] as String,
        clienteNome: row['cliente_nome'] as String,
        clienteCnpj: row['cliente_cnpj'] as String,
        clienteContato: row['cliente_contato'] as String? ?? '',
        veiculoPlaca: row['veiculo_placa'] as String,
        dataInicio: DateTime.parse(row['data_inicio'] as String),
        dataFim: DateTime.parse(row['data_fim'] as String),
        slaKmMes: (row['sla_km_mes'] as num?)?.toInt() ?? 0,
        valorMensal: (row['valor_mensal'] as num?)?.toDouble() ?? 0.0,
        status: () {
          final raw = (row['status']?.toString() ?? '').trim().toLowerCase();
          if (raw.isEmpty) return ContratoStatus.rascunho;

          if (raw == 'ativo') return ContratoStatus.ativo;
          if (raw == 'suspenso') return ContratoStatus.suspenso;
          if (raw == 'encerrado') return ContratoStatus.encerrado;
          if (raw == 'rascunho') return ContratoStatus.rascunho;

          final normalized = raw
              .replaceAll('-', '_')
              .replaceAll(' ', '_');
          return ContratoStatus.values.firstWhere(
            (s) => s.name.toLowerCase() == normalized,
            orElse: () => ContratoStatus.rascunho,
          );
        }(),
        observacoes: row['observacoes'] as String? ?? '',
        criadoPor: row['criado_por'] as String? ?? '',
        createdAt: DateTime.parse(row['created_at'] as String),
        updatedAt: DateTime.parse(row['updated_at'] as String),
      );
}

// ──────────────────────────────────────────────────────
class ChecklistEvento {
  final String id;
  final String contratoId;
  final ChecklistTipo tipo;
  final int kmOdometro;
  final int? kmPercorridos;
  final int combustivelPct;
  final String observacoes;
  final List<String> fotos;
  final String? docUrl;
  final String? assinaturaUrl;
  final String realizadoPor;
  final DateTime createdAt;

  const ChecklistEvento({
    required this.id,
    required this.contratoId,
    required this.tipo,
    required this.kmOdometro,
    this.kmPercorridos,
    this.combustivelPct = 100,
    this.observacoes = '',
    this.fotos = const [],
    this.docUrl,
    this.assinaturaUrl,
    this.realizadoPor = '',
    required this.createdAt,
  });

  Map<String, dynamic> toRow() => {
        'contrato_id': contratoId,
        'tipo': tipo.name == 'checkIn' ? 'check_in' : 'check_out',
        'km_odometro': kmOdometro,
        'km_percorridos': kmPercorridos,
        'combustivel_pct': combustivelPct,
        'observacoes': observacoes,
        'fotos': fotos,
        'doc_url': docUrl,
        'assinatura_url': assinaturaUrl,
        'realizado_por': realizadoPor,
      };

  factory ChecklistEvento.fromRow(Map<String, dynamic> row) {
    final tipoRaw = row['tipo'] as String? ?? 'check_in';
    return ChecklistEvento(
      id: row['id'] as String,
      contratoId: row['contrato_id'] as String,
      tipo: tipoRaw == 'check_in' ? ChecklistTipo.checkIn : ChecklistTipo.checkOut,
      kmOdometro: (row['km_odometro'] as num?)?.toInt() ?? 0,
      kmPercorridos: (row['km_percorridos'] as num?)?.toInt(),
      combustivelPct: (row['combustivel_pct'] as num?)?.toInt() ?? 100,
      observacoes: row['observacoes'] as String? ?? '',
      fotos: (row['fotos'] as List<dynamic>?)
              ?.map((f) => f as String)
              .toList() ??
          [],
      docUrl: row['doc_url'] as String?,
      assinaturaUrl: row['assinatura_url'] as String?,
      realizadoPor: row['realizado_por'] as String? ?? '',
      createdAt: DateTime.parse(row['created_at'] as String),
    );
  }
}

// ──────────────────────────────────────────────────────
class Ocorrencia {
  final String id;
  final String contratoId;
  final OcorrenciaTipo tipo;
  final OcorrenciaStatus status;
  final String descricao;
  final DateTime dataOcorrencia;
  final double valorEstimado;
  final double? valorFinal;
  final double impactoFinanceiro;
  final String responsavelPagamento;
  final List<String> fotos;
  final String observacoes;
  final String registradoPor;
  final String? resolvidoPor;
  final DateTime? dataResolucao;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Ocorrencia({
    required this.id,
    required this.contratoId,
    required this.tipo,
    this.status = OcorrenciaStatus.aberta,
    required this.descricao,
    required this.dataOcorrencia,
    this.valorEstimado = 0.0,
    this.valorFinal,
    this.impactoFinanceiro = 0.0,
    this.responsavelPagamento = 'cliente',
    this.fotos = const [],
    this.observacoes = '',
    this.registradoPor = '',
    this.resolvidoPor,
    this.dataResolucao,
    required this.createdAt,
    required this.updatedAt,
  });

  Ocorrencia copyWith({
    String? id,
    OcorrenciaStatus? status,
    double? valorFinal,
    double? impactoFinanceiro,
    String? resolvidoPor,
    DateTime? dataResolucao,
    DateTime? updatedAt,
  }) {
    return Ocorrencia(
      id: id ?? this.id,
      contratoId: contratoId,
      tipo: tipo,
      status: status ?? this.status,
      descricao: descricao,
      dataOcorrencia: dataOcorrencia,
      valorEstimado: valorEstimado,
      valorFinal: valorFinal ?? this.valorFinal,
      impactoFinanceiro: impactoFinanceiro ?? this.impactoFinanceiro,
      responsavelPagamento: responsavelPagamento,
      fotos: fotos,
      observacoes: observacoes,
      registradoPor: registradoPor,
      resolvidoPor: resolvidoPor ?? this.resolvidoPor,
      dataResolucao: dataResolucao ?? this.dataResolucao,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toInsertRow() => {
        'contrato_id': contratoId,
        'tipo': tipo.name,
        'status': status.name == 'emAnalise' ? 'em_analise' : status.name,
        'descricao': descricao,
        'data_ocorrencia': dataOcorrencia.toIso8601String().split('T').first,
        'valor_estimado': valorEstimado,
        'valor_final': valorFinal,
        'impacto_financeiro': impactoFinanceiro,
        'responsavel_pagamento': responsavelPagamento,
        'fotos': fotos,
        'observacoes': observacoes,
        'registrado_por': registradoPor,
      };

  factory Ocorrencia.fromRow(Map<String, dynamic> row) {
    final statusRaw = row['status'] as String? ?? 'aberta';
    final OcorrenciaStatus parsedStatus;
    if (statusRaw == 'em_analise') {
      parsedStatus = OcorrenciaStatus.emAnalise;
    } else {
      parsedStatus = OcorrenciaStatus.values.firstWhere(
        (s) => s.name == statusRaw,
        orElse: () => OcorrenciaStatus.aberta,
      );
    }
    return Ocorrencia(
      id: row['id'] as String,
      contratoId: row['contrato_id'] as String,
      tipo: OcorrenciaTipo.values.firstWhere(
        (t) => t.name == row['tipo'],
        orElse: () => OcorrenciaTipo.outro,
      ),
      status: parsedStatus,
      descricao: row['descricao'] as String,
      dataOcorrencia: DateTime.parse(row['data_ocorrencia'] as String),
      valorEstimado: (row['valor_estimado'] as num?)?.toDouble() ?? 0.0,
      valorFinal: (row['valor_final'] as num?)?.toDouble(),
      impactoFinanceiro: (row['impacto_financeiro'] as num?)?.toDouble() ?? 0.0,
      responsavelPagamento:
          row['responsavel_pagamento'] as String? ?? 'cliente',
      fotos: (row['fotos'] as List<dynamic>?)
              ?.map((f) => f as String)
              .toList() ??
          [],
      observacoes: row['observacoes'] as String? ?? '',
      registradoPor: row['registrado_por'] as String? ?? '',
      resolvidoPor: row['resolvido_por'] as String?,
      dataResolucao: row['data_resolucao'] != null
          ? DateTime.parse(row['data_resolucao'] as String)
          : null,
      createdAt: DateTime.parse(row['created_at'] as String),
      updatedAt: DateTime.parse(row['updated_at'] as String),
    );
  }
}
