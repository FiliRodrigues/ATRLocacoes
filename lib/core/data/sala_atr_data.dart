import 'dart:math';
import 'package:flutter/material.dart';

// ═══════════════════════════════════════════════════
// DADOS SALA ATR — PREMIUM MANAGEMENT SYSTEM
// ═══════════════════════════════════════════════════

enum StatusAgendamento { pendente, confirmado, pago, realizado, cancelado_noshow }
enum CategoriaDespesa { energia, limpeza, internet, marketing, outros }
enum TipoPagamento { particular, convenio30, convenio60, convenio90 }

extension TipoPagamentoNome on TipoPagamento {
  String get nome {
    switch (this) {
      case TipoPagamento.particular: return 'Particular';
      case TipoPagamento.convenio30: return 'Convénio D+30';
      case TipoPagamento.convenio60: return 'Convénio D+60';
      case TipoPagamento.convenio90: return 'Convénio D+90';
    }
  }

  String get toDb {
    switch (this) {
      case TipoPagamento.particular: return 'particular';
      case TipoPagamento.convenio30: return 'convenio30';
      case TipoPagamento.convenio60: return 'convenio60';
      case TipoPagamento.convenio90: return 'convenio90';
    }
  }

  static TipoPagamento fromDb(String? str) {
    switch (str) {
      case 'particular': return TipoPagamento.particular;
      case 'convenio30': return TipoPagamento.convenio30;
      case 'convenio60': return TipoPagamento.convenio60;
      case 'convenio90': return TipoPagamento.convenio90;
      default: return TipoPagamento.particular;
    }
  }

  int get diasAteRecebimento {
    switch (this) {
      case TipoPagamento.particular: return 0;
      case TipoPagamento.convenio30: return 30;
      case TipoPagamento.convenio60: return 60;
      case TipoPagamento.convenio90: return 90;
    }
  }
}

// ═══════════════════════════════════════════════════
// PACOTE DE SESSÕES
// ═══════════════════════════════════════════════════
class PacoteSessao {
  final String id;
  final String clienteId;
  final String clienteNome;
  final int totalSessoes;
  final int sessoesUsadas;
  final double valorPago;
  final double valorPorSessao;
  final DateTime dataCriacao;
  final bool ativo;

  const PacoteSessao({
    required this.id,
    required this.clienteId,
    required this.clienteNome,
    required this.totalSessoes,
    this.sessoesUsadas = 0,
    required this.valorPago,
    required this.valorPorSessao,
    required this.dataCriacao,
    this.ativo = true,
  });

  int get sessoesRestantes => totalSessoes - sessoesUsadas;
  double get economiaVsAvulso => (valorPorSessao * totalSessoes) - valorPago;
  double get progressoUso => totalSessoes > 0 ? sessoesUsadas / totalSessoes : 0;
  bool get isEsgotado => sessoesRestantes <= 0;

  PacoteSessao copyWith({
    int? sessoesUsadas,
    bool? ativo,
  }) {
    return PacoteSessao(
      id: id,
      clienteId: clienteId,
      clienteNome: clienteNome,
      totalSessoes: totalSessoes,
      sessoesUsadas: sessoesUsadas ?? this.sessoesUsadas,
      valorPago: valorPago,
      valorPorSessao: valorPorSessao,
      dataCriacao: dataCriacao,
      ativo: ativo ?? this.ativo,
    );
  }
}

// ═══════════════════════════════════════════════════
// NOTA DE SESSÃO
// ═══════════════════════════════════════════════════
class NotaSessao {
  final String texto;
  final DateTime dataCriacao;

  const NotaSessao({required this.texto, required this.dataCriacao});
}

// ═══════════════════════════════════════════════════
// RECEBIMENTO FUTURO
// ═══════════════════════════════════════════════════
class RecebimentoFuturoMes {
  final DateTime mes;
  final List<AgendamentoSalaAtr> itens;

  const RecebimentoFuturoMes({required this.mes, required this.itens});

  String get mesFormatado {
    const nomes = [
      'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
      'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro',
    ];
    return '${nomes[mes.month - 1]}/${mes.year}';
  }

  double get valorTotal => itens.fold(0.0, (s, a) => s + a.valorTotal);
}

// ═══════════════════════════════════════════════════
// RESUMO DIÁRIO
// ═══════════════════════════════════════════════════
class ResumoDiario {
  final DateTime data;
  final List<AgendamentoSalaAtr> agendamentos;
  final int totalSessoes;
  final int confirmadas;
  final int pendentes;
  final double receitaParticularHoje;
  final List<String> aniversariantes;
  final AgendamentoSalaAtr? proximaSessao;

  const ResumoDiario({
    required this.data,
    required this.agendamentos,
    required this.totalSessoes,
    required this.confirmadas,
    required this.pendentes,
    required this.receitaParticularHoje,
    required this.aniversariantes,
    this.proximaSessao,
  });
}

// ═══════════════════════════════════════════════════
// AGENDAMENTO
// ═══════════════════════════════════════════════════
class AgendamentoSalaAtr {
  final String id;
  final String clienteId;
  final String clienteNome;
  final String clienteTelefone;
  final DateTime inicio;
  final DateTime fim;
  final double valorTotal;
  final StatusAgendamento status;
  final TipoPagamento tipoPagamento;
  final String? observacoes;
  final NotaSessao? notaSessao;
  final bool lembrete24h;
  final bool lembrete1h;

  const AgendamentoSalaAtr({
    required this.id,
    required this.clienteId,
    required this.clienteNome,
    required this.clienteTelefone,
    required this.inicio,
    required this.fim,
    required this.valorTotal,
    required this.status,
    this.tipoPagamento = TipoPagamento.particular,
    this.observacoes,
    this.notaSessao,
    this.lembrete24h = true,
    this.lembrete1h = true,
  });

  bool get isFuturo => inicio.isAfter(DateTime.now());
  bool get isPassado => fim.isBefore(DateTime.now());
  bool get isHoje {
    final now = DateTime.now();
    return inicio.year == now.year && inicio.month == now.month && inicio.day == now.day;
  }

  DateTime get dataRecebimento {
    switch (tipoPagamento) {
      case TipoPagamento.particular: return inicio;
      case TipoPagamento.convenio30: return inicio.add(const Duration(days: 30));
      case TipoPagamento.convenio60: return inicio.add(const Duration(days: 60));
      case TipoPagamento.convenio90: return inicio.add(const Duration(days: 90));
    }
  }

  String get whatsappUrl {
    final tel = clienteTelefone.replaceAll(RegExp(r'[^\d]'), '');
    final msg = Uri.encodeComponent(
      'Olá $clienteNome! '
      'Lembrete da sua sessão dia ${_fmtData(inicio)} às ${_fmtHora(inicio)}. '
      'Duração: ${fim.difference(inicio).inMinutes}min. '
      'Valor: R\$ ${valorTotal.toStringAsFixed(2)}. '
      'Confirma? 🙏',
    );
    return 'https://wa.me/55$tel?text=$msg';
  }

  String get whatsappUrlConfirmacao {
    final tel = clienteTelefone.replaceAll(RegExp(r'[^\d]'), '');
    final msg = Uri.encodeComponent(
      'Olá $clienteNome! 😊\n\n'
      'Confirmação da sua sessão:\n'
      '📅 ${_fmtDataExtenso(inicio)}\n'
      '⏰ ${_fmtHora(inicio)}\n'
      '⏱ ${fim.difference(inicio).inMinutes}min\n\n'
      'Está tudo certo? Até já!',
    );
    return 'https://wa.me/55$tel?text=$msg';
  }

  String get whatsappUrlLembrete {
    final tel = clienteTelefone.replaceAll(RegExp(r'[^\d]'), '');
    final horasAte = inicio.difference(DateTime.now()).inHours;
    final msg = Uri.encodeComponent(
      '🔔 *LEMBRETE DE SESSÃO*\n\n'
      'Olá $clienteNome!\n'
      'Sua sessão é em *$horasAte horas*:\n'
      '📅 ${_fmtDataExtenso(inicio)}\n'
      '⏰ ${_fmtHora(inicio)}\n\n'
      'Até já! 🌟',
    );
    return 'https://wa.me/55$tel?text=$msg';
  }

  AgendamentoSalaAtr copyWith({
    StatusAgendamento? status,
    TipoPagamento? tipoPagamento,
    String? observacoes,
    NotaSessao? notaSessao,
    bool? lembrete24h,
    bool? lembrete1h,
  }) {
    return AgendamentoSalaAtr(
      id: id,
      clienteId: clienteId,
      clienteNome: clienteNome,
      clienteTelefone: clienteTelefone,
      inicio: inicio,
      fim: fim,
      valorTotal: valorTotal,
      status: status ?? this.status,
      tipoPagamento: tipoPagamento ?? this.tipoPagamento,
      observacoes: observacoes ?? this.observacoes,
      notaSessao: notaSessao ?? this.notaSessao,
      lembrete24h: lembrete24h ?? this.lembrete24h,
      lembrete1h: lembrete1h ?? this.lembrete1h,
    );
  }
}

String _fmtData(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
String _fmtHora(DateTime d) => '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
String _fmtDataExtenso(DateTime d) {
  const nomes = ['janeiro', 'fevereiro', 'março', 'abril', 'maio', 'junho',
    'julho', 'agosto', 'setembro', 'outubro', 'novembro', 'dezembro'];
  return '${d.day} de ${nomes[d.month - 1]}';
}

// ═══════════════════════════════════════════════════
// DESPESA
// ═══════════════════════════════════════════════════
class DespesaSalaAtr {
  final String id;
  final String descricao;
  final CategoriaDespesa categoria;
  final double valor;
  final DateTime data;

  const DespesaSalaAtr({
    required this.id,
    required this.descricao,
    required this.categoria,
    required this.valor,
    required this.data,
  });
}

// ═══════════════════════════════════════════════════
// CLIENTE (FICHA COMPLETA)
// ═══════════════════════════════════════════════════
class SalaAtrCliente {
  final String id;
  final String nome;
  final String telefone;
  final String email;
  final DateTime? dataNascimento;
  final String endereco;
  final String convenio;
  final String responsavelNome;
  final String responsavelTelefone;
  final String anotacoes;
  final bool ativo;
  final DateTime createdAt;

  SalaAtrCliente({
    required this.id,
    required this.nome,
    this.telefone = '',
    this.email = '',
    this.dataNascimento,
    this.endereco = '',
    this.convenio = '',
    this.responsavelNome = '',
    this.responsavelTelefone = '',
    this.anotacoes = '',
    this.ativo = true,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory SalaAtrCliente.fromMap(Map<String, dynamic> m) => SalaAtrCliente(
    id: m['id'] as String,
    nome: m['nome'] as String? ?? '',
    telefone: m['telefone'] as String? ?? '',
    email: m['email'] as String? ?? '',
    dataNascimento: m['data_nascimento'] != null ? DateTime.tryParse(m['data_nascimento'].toString()) : null,
    endereco: m['endereco'] as String? ?? '',
    convenio: m['convenio'] as String? ?? '',
    responsavelNome: m['responsavel_nome'] as String? ?? '',
    responsavelTelefone: m['responsavel_telefone'] as String? ?? '',
    anotacoes: m['anotacoes'] as String? ?? '',
    ativo: m['ativo'] as bool? ?? true,
    createdAt: m['created_at'] != null ? DateTime.parse(m['created_at'].toString()) : null,
  );

  Map<String, dynamic> toMap() => {
    'nome': nome,
    'telefone': telefone,
    'email': email,
    if (dataNascimento != null) 'data_nascimento': _fmtDate(dataNascimento!),
    'endereco': endereco,
    'convenio': convenio,
    'responsavel_nome': responsavelNome,
    'responsavel_telefone': responsavelTelefone,
    'anotacoes': anotacoes,
    'ativo': ativo,
  };

  String get whatsappUrl {
    final tel = telefone.replaceAll(RegExp(r'[^\d]'), '');
    return 'https://wa.me/55$tel';
  }

  bool get isMinor => dataNascimento != null && _idade(dataNascimento!) < 18;

  static int _idade(DateTime nasc) {
    final hoje = DateTime.now();
    int idade = hoje.year - nasc.year;
    if (hoje.month < nasc.month || (hoje.month == nasc.month && hoje.day < nasc.day)) idade--;
    return idade;
  }

  static String _fmtDate(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

// ═══════════════════════════════════════════════════
// CRM (RELATÓRIO AGREGADO)
// ═══════════════════════════════════════════════════
class RelatorioCliente {
  final String clienteId;
  final String nome;
  final String telefone;
  int qtdeAgendamentos = 0;
  int qtdeNoShows = 0;
  double totalGasto = 0.0;
  DateTime? ultimoAtendimento;
  final List<PacoteSessao> pacotesAtivos = [];

  RelatorioCliente({
    required this.clienteId,
    required this.nome,
    required this.telefone,
  });

  int get sessoesPacoteRestantes =>
      pacotesAtivos.where((p) => p.ativo).fold(0, (s, p) => s + p.sessoesRestantes);
}

