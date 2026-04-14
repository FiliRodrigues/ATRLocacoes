import 'dart:math';

// ═══════════════════════════════════════════════════════
// DADOS ÁREA DE LAZER — Reservas fins de semana 2026
// ═══════════════════════════════════════════════════════

class ReservaLazer {
  final DateTime data;
  final String tipoEvento;
  final String cliente;
  final double valor;
  final String statusLimpeza; // 'concluido' | 'pendente'
  final String statusReserva; // 'confirmada' | 'cancelada' | 'realizada'
  final int? duracaoHoras;
  final String? observacao;

  const ReservaLazer({
    required this.data,
    required this.tipoEvento,
    required this.cliente,
    required this.valor,
    required this.statusLimpeza,
    required this.statusReserva,
    this.duracaoHoras,
    this.observacao,
  });

  bool get limpezaConcluida => statusLimpeza == 'concluido';
  bool get realizada => statusReserva == 'realizada';
}

final List<ReservaLazer> _reservasCache = _gerarReservas();
List<ReservaLazer> get reservasLazer => _reservasCache;

List<ReservaLazer> _gerarReservas() {
  final rng = Random(99);
  final reservas = <ReservaLazer>[];
  final inicio = DateTime(2026);
  final fim = DateTime.now().add(const Duration(days: 60));

  final tipos = [
    'Aniversário',
    'Churrasco',
    'Confraternização',
    'Casamento',
    'Festa Infantil',
    'Evento Corporativo',
    'Reunião Familiar',
  ];

  final nomes = [
    'Família Santos',
    'João Pereira',
    'Maria Oliveira',
    'Carlos Silva',
    'Ana Rodrigues',
    'Pedro Almeida',
    'Fernanda Costa',
    'Lucas Martins',
    'Juliana Souza',
    'Rafael Lima',
    'Patrícia Nunes',
    'Empresa XYZ',
    'Família Mendes',
    'Bruno Ferreira',
    'Camila Araújo',
    'Diego Ribeiro',
  ];

  final valores = {
    'Aniversário': 800.0,
    'Churrasco': 600.0,
    'Confraternização': 1000.0,
    'Casamento': 2500.0,
    'Festa Infantil': 700.0,
    'Evento Corporativo': 1500.0,
    'Reunião Familiar': 500.0,
  };

  for (var dia = inicio;
      !dia.isAfter(fim);
      dia = dia.add(const Duration(days: 1))) {
    if (dia.weekday != DateTime.saturday && dia.weekday != DateTime.sunday) {
      continue;
    }

    // ~85% dos fins de semana tem reserva
    if (rng.nextDouble() < 0.15) continue;

    final tipo = tipos[rng.nextInt(tipos.length)];
    final nome = nomes[rng.nextInt(nomes.length)];
    final valorBase = valores[tipo] ?? 800.0;
    final valorFinal = valorBase + (rng.nextDouble() * 400 - 200); // ±200

    final passado = dia.isBefore(DateTime(2026, 4, 9));
    // Cancelamento raro (~5%)
    final cancelado = rng.nextDouble() < 0.05;

    String statusReserva;
    String statusLimpeza;

    if (cancelado) {
      statusReserva = 'cancelada';
      statusLimpeza = 'pendente';
    } else if (passado) {
      statusReserva = 'realizada';
      statusLimpeza = rng.nextDouble() < 0.9 ? 'concluido' : 'pendente';
    } else {
      statusReserva = 'confirmada';
      statusLimpeza = 'pendente';
    }

    reservas.add(
      ReservaLazer(
        data: dia,
        tipoEvento: tipo,
        cliente: nome,
        valor: double.parse(valorFinal.toStringAsFixed(2)),
        statusLimpeza: statusLimpeza,
        statusReserva: statusReserva,
        duracaoHoras: rng.nextInt(6) + 4, // 4-9h
      ),
    );
  }

  return reservas;
}

// ── Métricas ──
double get faturamentoBrutoLazer =>
    reservasLazer.where((r) => r.realizada).fold(0.0, (s, r) => s + r.valor);

int get totalReservas => reservasLazer.length;
int get reservasRealizadas => reservasLazer.where((r) => r.realizada).length;
int get reservasCanceladas =>
    reservasLazer.where((r) => r.statusReserva == 'cancelada').length;
int get reservasConfirmadas =>
    reservasLazer.where((r) => r.statusReserva == 'confirmada').length;
int get limpezasPendentes => reservasLazer
    .where(
      (r) => r.statusLimpeza == 'pendente' && r.statusReserva != 'cancelada',
    )
    .length;

List<ReservaLazer> get proximasReservas =>
    reservasLazer.where((r) => r.statusReserva == 'confirmada').toList()
      ..sort((a, b) => a.data.compareTo(b.data));

// ── Métricas por mês ──
List<ReservaLazer> reservasPorMes({required int mes, required int ano}) =>
    reservasLazer
        .where((r) => r.data.month == mes && r.data.year == ano)
        .toList();

double receitaMesLazer({required int mes, required int ano}) =>
    reservasPorMes(mes: mes, ano: ano)
        .where((r) => r.statusReserva == 'realizada')
        .fold(0.0, (s, r) => s + r.valor);

double despesasMesLazer({required int mes, required int ano}) => despesasLazer
    .where((d) => d.data.month == mes && d.data.year == ano)
    .fold(0.0, (s, d) => s + d.valor);

/// % dos fins de semana do mês que tiveram reserva (confirmada ou realizada)
double ocupacaoPercMesLazer({required int mes, required int ano}) {
  int totalFds = 0;
  int ocupados = 0;
  for (var d = DateTime(ano, mes);
      d.month == mes;
      d = d.add(const Duration(days: 1))) {
    if (d.weekday == DateTime.saturday || d.weekday == DateTime.sunday) {
      totalFds++;
      final tem = reservasLazer.any(
        (r) =>
            r.data.year == d.year &&
            r.data.month == d.month &&
            r.data.day == d.day &&
            r.statusReserva != 'cancelada',
      );
      if (tem) ocupados++;
    }
  }
  if (totalFds == 0) return 0;
  return (ocupados / totalFds) * 100;
}

// ═══════════════════════════════════════════════════════
// CLASSE DespesaLazer
// ═══════════════════════════════════════════════════════

class DespesaLazer {
  final String id;
  final String descricao;
  final String categoria; // 'limpeza' | 'manutenção' | 'energia' | 'outros'
  final double valor;
  final DateTime data;
  final String status; // 'pago' | 'pendente' | 'atrasado'

  const DespesaLazer({
    required this.id,
    required this.descricao,
    required this.categoria,
    required this.valor,
    required this.data,
    required this.status,
  });
}

// ── Helper ──
class DateTimeUtilsLazer {
  static int daysInMonth(int mes, int ano) => DateTime(ano, mes + 1, 0).day;
}

// ── Mock de despesas ──
final List<DespesaLazer> despesasLazer = [
  DespesaLazer(
    id: 'dl01',
    descricao: 'Limpeza pós-evento',
    categoria: 'limpeza',
    valor: 350.0,
    data: DateTime(2026, 1, 6),
    status: 'pago',
  ),
  DespesaLazer(
    id: 'dl02',
    descricao: 'Manutenção churrasqueira',
    categoria: 'manutenção',
    valor: 480.0,
    data: DateTime(2026, 1, 18),
    status: 'pago',
  ),
  DespesaLazer(
    id: 'dl03',
    descricao: 'Energia elétrica',
    categoria: 'energia',
    valor: 620.0,
    data: DateTime(2026, 1, 31),
    status: 'pago',
  ),
  DespesaLazer(
    id: 'dl04',
    descricao: 'Limpeza pós-evento',
    categoria: 'limpeza',
    valor: 350.0,
    data: DateTime(2026, 2, 3),
    status: 'pago',
  ),
  DespesaLazer(
    id: 'dl05',
    descricao: 'Reparo na piscina',
    categoria: 'manutenção',
    valor: 1200.0,
    data: DateTime(2026, 2, 15),
    status: 'pago',
  ),
  DespesaLazer(
    id: 'dl06',
    descricao: 'Energia elétrica',
    categoria: 'energia',
    valor: 590.0,
    data: DateTime(2026, 2, 28),
    status: 'pago',
  ),
  DespesaLazer(
    id: 'dl07',
    descricao: 'Limpeza pós-evento',
    categoria: 'limpeza',
    valor: 350.0,
    data: DateTime(2026, 3, 3),
    status: 'pago',
  ),
  DespesaLazer(
    id: 'dl08',
    descricao: 'Manutenção jardim',
    categoria: 'manutenção',
    valor: 320.0,
    data: DateTime(2026, 3, 20),
    status: 'pago',
  ),
  DespesaLazer(
    id: 'dl09',
    descricao: 'Energia elétrica',
    categoria: 'energia',
    valor: 640.0,
    data: DateTime(2026, 3, 31),
    status: 'pago',
  ),
  DespesaLazer(
    id: 'dl10',
    descricao: 'Limpeza pós-evento',
    categoria: 'limpeza',
    valor: 350.0,
    data: DateTime(2026, 4, 7),
    status: 'pago',
  ),
  DespesaLazer(
    id: 'dl11',
    descricao: 'Energia elétrica',
    categoria: 'energia',
    valor: 610.0,
    data: DateTime(2026, 4, 30),
    status: 'pendente',
  ),
  DespesaLazer(
    id: 'dl12',
    descricao: 'Material de limpeza',
    categoria: 'outros',
    valor: 180.0,
    data: DateTime(2026, 5, 5),
    status: 'pendente',
  ),
];
