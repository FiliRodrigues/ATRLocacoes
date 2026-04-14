import 'dart:math';

// ═══════════════════════════════════════════════════════
// DADOS SALA ATR — Locação por hora e por dia (Jan-Abr 2026)
// ═══════════════════════════════════════════════════════

enum TipoLocacao { hora, diaria, mensalidade }

enum StatusAgendamento { confirmado, realizado, cancelado, pendente }

enum StatusPagamento { pago, pendente, atrasado }

class AgendamentoSala {
  final int id;
  final int salaId;
  final String cliente;
  final String contato;
  final DateTime inicio;
  final DateTime fim;
  final TipoLocacao tipo;
  final double valorTotal;
  final StatusAgendamento status;
  final String? descricao;

  const AgendamentoSala({
    required this.id,
    required this.salaId,
    required this.cliente,
    required this.contato,
    required this.inicio,
    required this.fim,
    required this.tipo,
    required this.valorTotal,
    required this.status,
    this.descricao,
  });

  int get duracaoHoras => fim.difference(inicio).inHours;
  bool get isFuturo => inicio.isAfter(DateTime.now());
  bool get isPassado => fim.isBefore(DateTime.now());
  bool get isHoje {
    final now = DateTime.now();
    return inicio.year == now.year &&
        inicio.month == now.month &&
        inicio.day == now.day;
  }
}

class DespesaSala {
  final int id;
  final int? salaId; // null = despesa geral do espaço
  final String descricao;
  final String
      categoria; // 'energia' | 'limpeza' | 'manutenção' | 'marketing' | 'outros'
  final double valor;
  final DateTime data;
  final StatusPagamento status;

  const DespesaSala({
    required this.id,
    required this.descricao,
    required this.categoria,
    required this.valor,
    required this.data,
    required this.status,
    this.salaId,
  });
}

class SalaComercial {
  final int id;
  final String nome;
  final String descricao;
  final double areaMt2;
  final int capacidadePessoas;
  final double valorHora;
  final double valorDiaria;
  final List<String>
      recursos; // 'projetor' | 'ar-cond' | 'wi-fi' | 'coffee' | etc.
  final String imagemEmoji;

  const SalaComercial({
    required this.id,
    required this.nome,
    required this.descricao,
    required this.areaMt2,
    required this.capacidadePessoas,
    required this.valorHora,
    required this.valorDiaria,
    required this.recursos,
    required this.imagemEmoji,
  });
}

// ── Salas do espaço ATR ──────────────────────────────────────────────
final List<SalaComercial> salasAtr = [
  const SalaComercial(
    id: 1,
    nome: 'Sala de Reunião A',
    descricao: 'Sala executiva com mesa oval para até 8 pessoas',
    areaMt2: 24,
    capacidadePessoas: 8,
    valorHora: 120,
    valorDiaria: 600,
    recursos: ['projetor', 'ar-cond', 'wi-fi', 'café'],
    imagemEmoji: '🏢',
  ),
  const SalaComercial(
    id: 2,
    nome: 'Sala de Treinamento B',
    descricao: 'Espaço amplo para workshops e treinamentos corporativos',
    areaMt2: 48,
    capacidadePessoas: 20,
    valorHora: 180,
    valorDiaria: 900,
    recursos: ['projetor', 'ar-cond', 'wi-fi', 'café', 'lousa', 'microfone'],
    imagemEmoji: '🎓',
  ),
  const SalaComercial(
    id: 3,
    nome: 'Escritório Coworking C',
    descricao: 'Estações de trabalho compartilhadas em ambiente moderno',
    areaMt2: 36,
    capacidadePessoas: 12,
    valorHora: 80,
    valorDiaria: 350,
    recursos: ['ar-cond', 'wi-fi', 'café', 'impressora'],
    imagemEmoji: '💻',
  ),
  const SalaComercial(
    id: 4,
    nome: 'Auditório D',
    descricao: 'Espaço para eventos, seminários e apresentações',
    areaMt2: 80,
    capacidadePessoas: 50,
    valorHora: 350,
    valorDiaria: 1800,
    recursos: [
      'projetor',
      'ar-cond',
      'wi-fi',
      'café',
      'microfone',
      'som',
      'palco',
    ],
    imagemEmoji: '🎤',
  ),
];

// ── Geração de agendamentos ──────────────────────────────────────────
final List<AgendamentoSala> _agendamentosCache = _gerarAgendamentos();
List<AgendamentoSala> get agendamentosSala => _agendamentosCache;

List<AgendamentoSala> _gerarAgendamentos() {
  final rng = Random(77);
  final lista = <AgendamentoSala>[];
  final hoje = DateTime.now();
  final inicio = DateTime(2026, 1, 4); // começa semana de trabalho
  // gera até hoje + 60 dias
  final fim = hoje.add(const Duration(days: 60));

  final clientes = [
    'Contabilidade Visão Ltda',
    'Advocacia Ferreira & Souza',
    'Tech Solutions ME',
    'Startup Hub Inovação',
    'Corretora Prime Imóveis',
    'Dr. Carlos Mendes',
    'Escola de Negócios Smart',
    'RH Talentos Conectados',
    'Construtora Alfa',
    'Clínica Saúde Total',
    'Empresa Beta Corp',
    'Instituto Capacita BR',
    'Consultoria Ágil',
    'Academia Digital',
    'Grupo Educare',
  ];

  int id = 1;
  for (var dia = inicio;
      !dia.isAfter(fim);
      dia = dia.add(const Duration(days: 1))) {
    // pular domingos
    if (dia.weekday == DateTime.sunday) continue;

    for (final sala in salasAtr) {
      // ~60% de chance de ter ao menos 1 agendamento por dia por sala
      if (rng.nextDouble() > 0.60) continue;

      final qtd = rng.nextInt(3) + 1; // 1-3 agendamentos por sala/dia
      var horaAtual = 8;

      for (var i = 0; i < qtd && horaAtual < 19; i++) {
        final tipo =
            rng.nextDouble() < 0.7 ? TipoLocacao.hora : TipoLocacao.diaria;
        final duracaoH =
            tipo == TipoLocacao.diaria ? 8 : (rng.nextInt(4) + 1); // 1-4h

        final inicioSlot = DateTime(dia.year, dia.month, dia.day, horaAtual);
        final fimSlot = inicioSlot.add(Duration(hours: duracaoH));
        if (fimSlot.hour > 20) break;

        final valor = tipo == TipoLocacao.diaria
            ? sala.valorDiaria
            : sala.valorHora * duracaoH;

        final passado = fimSlot.isBefore(hoje);
        final futuro = inicioSlot.isAfter(hoje);

        StatusAgendamento status;
        if (passado) {
          status = rng.nextDouble() < 0.05
              ? StatusAgendamento.cancelado
              : StatusAgendamento.realizado;
        } else if (futuro) {
          status = rng.nextDouble() < 0.1
              ? StatusAgendamento.pendente
              : StatusAgendamento.confirmado;
        } else {
          status = StatusAgendamento.confirmado;
        }

        final cliente = clientes[rng.nextInt(clientes.length)];
        lista.add(
          AgendamentoSala(
            id: id++,
            salaId: sala.id,
            cliente: cliente,
            contato:
                '(11) 9${rng.nextInt(9000) + 1000}-${rng.nextInt(9000) + 1000}',
            inicio: inicioSlot,
            fim: fimSlot,
            tipo: tipo,
            valorTotal: double.parse(valor.toStringAsFixed(2)),
            status: status,
            descricao: tipo == TipoLocacao.diaria
                ? 'Diária completa'
                : 'Reunião ${duracaoH}h',
          ),
        );

        horaAtual = fimSlot.hour + rng.nextInt(2); // pequena pausa
      }
    }
  }

  lista.sort((a, b) => a.inicio.compareTo(b.inicio));
  return lista;
}

// ── Despesas fixas/variáveis das salas ──────────────────────────────
final List<DespesaSala> despesasSala = [
  DespesaSala(
    id: 1,
    descricao: 'Energia elétrica',
    categoria: 'energia',
    valor: 680,
    data: DateTime(2026, 1, 5),
    status: StatusPagamento.pago,
  ),
  DespesaSala(
    id: 2,
    descricao: 'Limpeza mensal Jan',
    categoria: 'limpeza',
    valor: 280,
    data: DateTime(2026, 1, 10),
    status: StatusPagamento.pago,
  ),
  DespesaSala(
    id: 3,
    descricao: 'Internet fibra',
    categoria: 'outros',
    valor: 199,
    data: DateTime(2026, 1, 15),
    status: StatusPagamento.pago,
  ),
  DespesaSala(
    id: 4,
    descricao: 'Energia elétrica',
    categoria: 'energia',
    valor: 710,
    data: DateTime(2026, 2, 5),
    status: StatusPagamento.pago,
  ),
  DespesaSala(
    id: 5,
    descricao: 'Limpeza mensal Fev',
    categoria: 'limpeza',
    valor: 280,
    data: DateTime(2026, 2, 10),
    status: StatusPagamento.pago,
  ),
  DespesaSala(
    id: 6,
    descricao: 'Manutenção ar-condicionado',
    categoria: 'manutenção',
    valor: 450,
    data: DateTime(2026, 2, 20),
    status: StatusPagamento.pago,
  ),
  DespesaSala(
    id: 7,
    descricao: 'Energia elétrica',
    categoria: 'energia',
    valor: 695,
    data: DateTime(2026, 3, 5),
    status: StatusPagamento.pago,
  ),
  DespesaSala(
    id: 8,
    descricao: 'Limpeza mensal Mar',
    categoria: 'limpeza',
    valor: 280,
    data: DateTime(2026, 3, 10),
    status: StatusPagamento.pago,
  ),
  DespesaSala(
    id: 9,
    descricao: 'Material de escritório',
    categoria: 'outros',
    valor: 145,
    data: DateTime(2026, 3, 18),
    status: StatusPagamento.pago,
  ),
  DespesaSala(
    id: 10,
    descricao: 'Energia elétrica',
    categoria: 'energia',
    valor: 725,
    data: DateTime(2026, 4, 5),
    status: StatusPagamento.pendente,
  ),
  DespesaSala(
    id: 11,
    descricao: 'Limpeza mensal Abr',
    categoria: 'limpeza',
    valor: 280,
    data: DateTime(2026, 4, 10),
    status: StatusPagamento.pendente,
  ),
  DespesaSala(
    id: 12,
    descricao: 'Renovação Google Workspace',
    categoria: 'outros',
    valor: 378,
    data: DateTime(2026, 4),
    status: StatusPagamento.pago,
  ),
];

// ── Funções de consulta ──────────────────────────────────────────────
List<AgendamentoSala> agendamentosPorMes({int? mes, int? ano, int? salaId}) {
  return agendamentosSala.where((a) {
    if (mes != null && a.inicio.month != mes) return false;
    if (ano != null && a.inicio.year != ano) return false;
    if (salaId != null && a.salaId != salaId) return false;
    return true;
  }).toList();
}

double receitaMes({int? mes, int? ano}) {
  final m = mes ?? DateTime.now().month;
  final a = ano ?? DateTime.now().year;
  return agendamentosSala
      .where(
        (ag) =>
            ag.inicio.month == m &&
            ag.inicio.year == a &&
            ag.status == StatusAgendamento.realizado,
      )
      .fold(0.0, (s, ag) => s + ag.valorTotal);
}

double despesasMes({int? mes, int? ano}) {
  final m = mes ?? DateTime.now().month;
  final a = ano ?? DateTime.now().year;
  return despesasSala
      .where((d) => d.data.month == m && d.data.year == a)
      .fold(0.0, (s, d) => s + d.valor);
}

double ocupacaoPercMes({int? mes, int? ano}) {
  final m = mes ?? DateTime.now().month;
  final a = ano ?? DateTime.now().year;
  final diasMes = DateTimeRange(
    start: DateTime(a, m),
    end: DateTime(a, m + 1, 0),
  ).duration.inDays;
  final diasUteis = diasMes * 5 ~/ 7; // aproximação
  final totalSlots = diasUteis * salasAtr.length * 8; // 8h/dia/sala
  final horasAgendadas = agendamentosSala
      .where(
        (ag) =>
            ag.inicio.month == m &&
            ag.inicio.year == a &&
            ag.status != StatusAgendamento.cancelado,
      )
      .fold(0, (s, ag) => s + ag.duracaoHoras);
  if (totalSlots == 0) return 0;
  return (horasAgendadas / totalSlots * 100).clamp(0, 100);
}

List<AgendamentoSala> get proximosAgendamentos => agendamentosSala
    .where(
      (a) =>
          a.isFuturo &&
          (a.status == StatusAgendamento.confirmado ||
              a.status == StatusAgendamento.pendente),
    )
    .toList()
  ..sort((a, b) => a.inicio.compareTo(b.inicio));

List<AgendamentoSala> get agendamentosHoje {
  final hoje = DateTime.now();
  return agendamentosSala
      .where(
        (a) =>
            a.inicio.year == hoje.year &&
            a.inicio.month == hoje.month &&
            a.inicio.day == hoje.day,
      )
      .toList()
    ..sort((a, b) => a.inicio.compareTo(b.inicio));
}

// Helper de classe DateTimeRange para não depender do Flutter em dados
class DateTimeRange {
  final DateTime start;
  final DateTime end;
  const DateTimeRange({required this.start, required this.end});
  Duration get duration => end.difference(start);
}
