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
// CRM
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

// ═══════════════════════════════════════════════════
// ESTADO GLOBAL DA SALA
// ═══════════════════════════════════════════════════
class SalaAtrState extends ChangeNotifier {
  static final SalaAtrState instance = SalaAtrState._();
  SalaAtrState._();

  List<AgendamentoSalaAtr> _agendamentos = _gerarAgendamentosMock();
  List<DespesaSalaAtr> _despesas = _gerarDespesasMock();
  List<PacoteSessao> _pacotes = _gerarPacotesMock();

  List<AgendamentoSalaAtr> get agendamentos => _agendamentos;
  List<DespesaSalaAtr> get despesas => _despesas;
  List<PacoteSessao> get pacotes => _pacotes;

  // ═══════════════════════════════════════════════════
  // PACOTES DE SESSÕES
  // ═══════════════════════════════════════════════════
  void criarPacote({
    required String clienteId,
    required String clienteNome,
    required int totalSessoes,
    required double valorPago,
    required double valorAvulso,
  }) {
    final pacote = PacoteSessao(
      id: 'pkg_${DateTime.now().millisecondsSinceEpoch}',
      clienteId: clienteId,
      clienteNome: clienteNome,
      totalSessoes: totalSessoes,
      valorPago: valorPago,
      valorPorSessao: valorAvulso,
      dataCriacao: DateTime.now(),
    );
    _pacotes.add(pacote);
    notifyListeners();
  }

  PacoteSessao? pacoteAtivoDoCliente(String clienteId) {
    final ativos = _pacotes
        .where((p) => p.clienteId == clienteId && p.ativo && !p.isEsgotado)
        .toList();
    if (ativos.isEmpty) return null;
    ativos.sort((a, b) => a.dataCriacao.compareTo(b.dataCriacao));
    return ativos.first;
  }

  void _consumirSessaoPacote(String clienteId) {
    final pacote = pacoteAtivoDoCliente(clienteId);
    if (pacote == null) return;
    final index = _pacotes.indexOf(pacote);
    _pacotes[index] = pacote.copyWith(sessoesUsadas: pacote.sessoesUsadas + 1);
    if (_pacotes[index].isEsgotado) {
      _pacotes[index] = _pacotes[index].copyWith(ativo: false);
    }
    notifyListeners();
  }

  // ═══════════════════════════════════════════════════
  // AGENDAMENTO & RECORRÊNCIA
  // ═══════════════════════════════════════════════════
  void adicionarAgendamento({
    required DateTime inicio,
    required int duracaoHoras,
    required String clienteNome,
    required String clienteTelefone,
    required double valorPorHora,
    TipoPagamento tipoPagamento = TipoPagamento.particular,
    int? semanasRecorrencia,
    int vezesRecorrencia = 1,
    int diasIntervalo = 7,
    bool lembrete24h = true,
    bool lembrete1h = true,
  }) {
    final String cId = 'cli_${clienteNome.replaceAll(' ', '_').toLowerCase()}';
    final totalOcorrencias = (semanasRecorrencia ?? vezesRecorrencia).clamp(1, 52);
    final intervaloDias = diasIntervalo.clamp(1, 365);

    for (int i = 0; i < totalOcorrencias; i++) {
      final dataOcorrencia = inicio.add(Duration(days: intervaloDias * i));
      final minutosSessao = (duracaoHoras * 60) - 10;

      final novo = AgendamentoSalaAtr(
        id: DateTime.now().microsecondsSinceEpoch.toString() + i.toString(),
        clienteId: cId,
        clienteNome: clienteNome,
        clienteTelefone: clienteTelefone,
        inicio: dataOcorrencia,
        fim: dataOcorrencia.add(Duration(minutes: minutosSessao)),
        valorTotal: valorPorHora * duracaoHoras,
        status: StatusAgendamento.pendente,
        tipoPagamento: tipoPagamento,
        lembrete24h: lembrete24h,
        lembrete1h: lembrete1h,
      );
      _agendamentos.add(novo);
    }

    _agendamentos.sort((a, b) => a.inicio.compareTo(b.inicio));
    notifyListeners();
  }

  void atualizarStatus(String id, StatusAgendamento novoStatus) {
    final index = _agendamentos.indexWhere((a) => a.id == id);
    if (index != -1) {
      final a = _agendamentos[index];
      _agendamentos[index] = a.copyWith(status: novoStatus);

      // Se marcou como pago/realizado, deduz do pacote ativo
      if (novoStatus == StatusAgendamento.pago || novoStatus == StatusAgendamento.realizado) {
        _consumirSessaoPacote(a.clienteId);
      }
      notifyListeners();
    }
  }

  void adicionarNotaSessao(String agendamentoId, String texto) {
    final index = _agendamentos.indexWhere((a) => a.id == agendamentoId);
    if (index != -1 && texto.trim().isNotEmpty) {
      _agendamentos[index] = _agendamentos[index].copyWith(
        notaSessao: NotaSessao(texto: texto.trim(), dataCriacao: DateTime.now()),
      );
      notifyListeners();
    }
  }

  void toggleLembrete24h(String agendamentoId) {
    final index = _agendamentos.indexWhere((a) => a.id == agendamentoId);
    if (index != -1) {
      _agendamentos[index] = _agendamentos[index].copyWith(
        lembrete24h: !_agendamentos[index].lembrete24h,
      );
      notifyListeners();
    }
  }

  void adicionarDespesa({
    required String descricao,
    required CategoriaDespesa categoria,
    required double valor,
    required DateTime data,
  }) {
    _despesas.add(DespesaSalaAtr(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      descricao: descricao,
      categoria: categoria,
      valor: valor,
      data: data,
    ));
    _despesas.sort((a, b) => b.data.compareTo(a.data));
    notifyListeners();
  }

  // ═══════════════════════════════════════════════════
  // RESUMO DIÁRIO
  // ═══════════════════════════════════════════════════
  ResumoDiario resumoDiario(DateTime dia) {
    final sessoes = _agendamentos
        .where((a) => a.inicio.year == dia.year &&
            a.inicio.month == dia.month &&
            a.inicio.day == dia.day &&
            a.status != StatusAgendamento.cancelado_noshow)
        .toList()
      ..sort((a, b) => a.inicio.compareTo(b.inicio));

    final confirmadas = sessoes
        .where((a) => a.status == StatusAgendamento.confirmado || a.status == StatusAgendamento.pago)
        .length;
    final pendentes = sessoes.where((a) => a.status == StatusAgendamento.pendente).length;
    final receitaParticular = sessoes
        .where((a) => a.tipoPagamento == TipoPagamento.particular &&
            a.status != StatusAgendamento.cancelado_noshow)
        .fold(0.0, (s, a) => s + a.valorTotal);

    final aniversariantes = <String>[];
    final todosClientes = <String, String>{};
    for (final a in _agendamentos) {
      todosClientes[a.clienteId] = a.clienteNome;
    }
    // Aniversariantes mock (num sistema real viria do cadastro do paciente)
    final nomesAniversario = ['Carlos Silva', 'Ana Oliveira'];
    for (final nome in nomesAniversario) {
      if (sessoes.any((a) => a.clienteNome == nome)) {
        aniversariantes.add(nome);
      }
    }

    return ResumoDiario(
      data: dia,
      agendamentos: sessoes,
      totalSessoes: sessoes.length,
      confirmadas: confirmadas,
      pendentes: pendentes,
      receitaParticularHoje: receitaParticular,
      aniversariantes: aniversariantes,
      proximaSessao: sessoes.isNotEmpty ? sessoes.first : null,
    );
  }

  // ═══════════════════════════════════════════════════
  // CRM
  // ═══════════════════════════════════════════════════
  List<RelatorioCliente> gerarCRM() {
    final map = <String, RelatorioCliente>{};
    for (var a in _agendamentos) {
      if (!map.containsKey(a.clienteId)) {
        map[a.clienteId] = RelatorioCliente(
          clienteId: a.clienteId,
          nome: a.clienteNome,
          telefone: a.clienteTelefone,
        );
      }
      final c = map[a.clienteId]!;
      c.qtdeAgendamentos++;
      if (a.status == StatusAgendamento.cancelado_noshow) c.qtdeNoShows++;
      if (a.status == StatusAgendamento.pago || a.status == StatusAgendamento.realizado) {
        c.totalGasto += a.valorTotal;
      }
      if (a.isPassado) {
        if (c.ultimoAtendimento == null || a.inicio.isAfter(c.ultimoAtendimento!)) {
          c.ultimoAtendimento = a.inicio;
        }
      }
    }
    // Adiciona pacotes ativos ao CRM
    for (final p in _pacotes.where((p) => p.ativo && !p.isEsgotado)) {
      if (map.containsKey(p.clienteId)) {
        map[p.clienteId]!.pacotesAtivos.add(p);
      }
    }
    final lista = map.values.toList();
    lista.sort((a, b) => b.totalGasto.compareTo(a.totalGasto));
    return lista;
  }

  // ═══════════════════════════════════════════════════
  // DASHBOARD
  // ═══════════════════════════════════════════════════
  List<AgendamentoSalaAtr> agendamentosDoDia(DateTime dia) {
    return _agendamentos
        .where((a) => a.inicio.year == dia.year &&
            a.inicio.month == dia.month &&
            a.inicio.day == dia.day)
        .toList()
      ..sort((a, b) => a.inicio.compareTo(b.inicio));
  }

  AgendamentoSalaAtr? proximoCliente() {
    final hoje = DateTime.now();
    final futuros = _agendamentos
        .where((a) => a.inicio.isAfter(hoje) && a.status != StatusAgendamento.cancelado_noshow)
        .toList();
    futuros.sort((a, b) => a.inicio.compareTo(b.inicio));
    return futuros.isNotEmpty ? futuros.first : null;
  }

  double receitaBrutaMes(int mes, int ano) {
    return _agendamentos
        .where((a) => a.inicio.month == mes &&
            a.inicio.year == ano &&
            (a.status == StatusAgendamento.pago || a.status == StatusAgendamento.realizado))
        .fold(0.0, (s, a) => s + a.valorTotal);
  }

  double inadimplenciaMes(int mes, int ano) {
    return _agendamentos
        .where((a) => a.inicio.month == mes &&
            a.inicio.year == ano &&
            a.status == StatusAgendamento.pendente &&
            a.isPassado)
        .fold(0.0, (s, a) => s + a.valorTotal);
  }

  double despesasMes(int mes, int ano) {
    return _despesas
        .where((d) => d.data.month == mes && d.data.year == ano)
        .fold(0.0, (s, d) => s + d.valor);
  }

  double lucroLiquidoMes(int mes, int ano) {
    return receitaBrutaMes(mes, ano) - despesasMes(mes, ano);
  }

  double lucroLiquidoMesAnterior(int mes, int ano) {
    if (mes == 1) return lucroLiquidoMes(12, ano - 1);
    return lucroLiquidoMes(mes - 1, ano);
  }

  double variacaoLucro(int mes, int ano) {
    final anterior = lucroLiquidoMesAnterior(mes, ano);
    if (anterior == 0) return 0;
    return ((lucroLiquidoMes(mes, ano) - anterior) / anterior.abs()) * 100;
  }

  double ocupacaoPerc(int mes, int ano) {
    final diasUteis = 22;
    final horasNoMes = diasUteis * 12;
    final horasOcupadas = _agendamentos
        .where((a) => a.inicio.month == mes &&
            a.inicio.year == ano &&
            a.status != StatusAgendamento.cancelado_noshow)
        .length;
    return (horasOcupadas / horasNoMes * 100).clamp(0, 100);
  }

  double ocupacaoPercMesAnterior(int mes, int ano) {
    if (mes == 1) return ocupacaoPerc(12, ano - 1);
    return ocupacaoPerc(mes - 1, ano);
  }

  List<RecebimentoFuturoMes> gerarRecebimentosFuturos() {
    final agora = DateTime.now();
    final mapa = <String, List<AgendamentoSalaAtr>>{};

    for (final a in _agendamentos) {
      if (a.tipoPagamento == TipoPagamento.particular) continue;
      if (a.status != StatusAgendamento.pago && a.status != StatusAgendamento.realizado) continue;
      final receb = a.dataRecebimento;
      if (receb.isBefore(agora)) continue;

      final mesRef = DateTime(receb.year, receb.month);
      final chave = '${mesRef.year}-${mesRef.month.toString().padLeft(2, '0')}';
      mapa.putIfAbsent(chave, () => []).add(a);
    }

    final saida = <RecebimentoFuturoMes>[];
    for (final entrada in mapa.entries) {
      final partes = entrada.key.split('-');
      final ano = int.parse(partes[0]);
      final mes = int.parse(partes[1]);
      final itens = entrada.value..sort((x, y) => x.dataRecebimento.compareTo(y.dataRecebimento));
      saida.add(RecebimentoFuturoMes(mes: DateTime(ano, mes), itens: itens));
    }
    saida.sort((a, b) => a.mes.compareTo(b.mes));
    return saida;
  }

  double totalRecebidoPacotes() {
    return _pacotes.fold(0.0, (s, p) => s + p.valorPago);
  }

  int totalSessoesPacotesAtivas() {
    return _pacotes
        .where((p) => p.ativo)
        .fold(0, (s, p) => s + p.sessoesRestantes);
  }

  // ═══════════════════════════════════════════════════
  // MOCKS
  // ═══════════════════════════════════════════════════
  static List<AgendamentoSalaAtr> _gerarAgendamentosMock() {
    final rng = Random(123);
    final lista = <AgendamentoSalaAtr>[];
    final hoje = DateTime.now();
    final nomes = ['Carlos Silva', 'Ana Oliveira', 'Marcos Paulo', 'Fernanda Lima', 'Dr. João Mendes'];

    for (int i = -10; i <= 30; i++) {
      final data = hoje.add(Duration(days: i));
      if (data.weekday == DateTime.sunday) continue;

      for (int h = 8; h <= 19; h++) {
        if (rng.nextDouble() > 0.7) {
          final duracao = rng.nextDouble() > 0.8 ? 2 : 1;
          final nome = nomes[rng.nextInt(nomes.length)];
          final inicio = DateTime(data.year, data.month, data.day, h, 0);
          final fim = inicio.add(Duration(minutes: (duracao * 60) - 10));

          if (fim.hour > 20) continue;

          final isPast = fim.isBefore(hoje);

          StatusAgendamento status;
          if (isPast) {
            status = rng.nextDouble() > 0.1 ? StatusAgendamento.realizado : StatusAgendamento.cancelado_noshow;
          } else if (i <= 2 && i >= 0) {
            status = rng.nextDouble() > 0.5 ? StatusAgendamento.confirmado : StatusAgendamento.pendente;
          } else {
            status = rng.nextDouble() > 0.4 ? StatusAgendamento.pago : StatusAgendamento.pendente;
          }

          lista.add(AgendamentoSalaAtr(
            id: 'mock_${data.millisecondsSinceEpoch}_$h',
            clienteId: 'cli_${nome.replaceAll(' ', '_').toLowerCase()}',
            clienteNome: nome,
            clienteTelefone: '551199999${rng.nextInt(9000) + 1000}',
            inicio: inicio,
            fim: fim,
            valorTotal: 150.0 * duracao,
            status: status,
            tipoPagamento: TipoPagamento.values[rng.nextInt(TipoPagamento.values.length)],
            lembrete24h: rng.nextDouble() > 0.2,
            lembrete1h: rng.nextDouble() > 0.3,
          ));
          h += (duracao - 1);
        }
      }
    }
    lista.sort((a, b) => a.inicio.compareTo(b.inicio));
    return lista;
  }

  static List<DespesaSalaAtr> _gerarDespesasMock() {
    final hoje = DateTime.now();
    return [
      DespesaSalaAtr(id: 'd1', descricao: 'Energia Elétrica', categoria: CategoriaDespesa.energia, valor: 350.0, data: hoje.subtract(const Duration(days: 5))),
      DespesaSalaAtr(id: 'd2', descricao: 'Limpeza Semanal', categoria: CategoriaDespesa.limpeza, valor: 150.0, data: hoje.subtract(const Duration(days: 2))),
      DespesaSalaAtr(id: 'd3', descricao: 'Internet Fibra', categoria: CategoriaDespesa.internet, valor: 99.90, data: DateTime(hoje.year, hoje.month, 10)),
    ];
  }

  static List<PacoteSessao> _gerarPacotesMock() {
    return [
      PacoteSessao(
        id: 'pkg_mock_1',
        clienteId: 'cli_carlos_silva',
        clienteNome: 'Carlos Silva',
        totalSessoes: 10,
        sessoesUsadas: 4,
        valorPago: 1200.00,
        valorPorSessao: 150.00,
        dataCriacao: DateTime.now().subtract(const Duration(days: 45)),
      ),
      PacoteSessao(
        id: 'pkg_mock_2',
        clienteId: 'cli_ana_oliveira',
        clienteNome: 'Ana Oliveira',
        totalSessoes: 4,
        sessoesUsadas: 1,
        valorPago: 500.00,
        valorPorSessao: 150.00,
        dataCriacao: DateTime.now().subtract(const Duration(days: 15)),
      ),
    ];
  }
}
