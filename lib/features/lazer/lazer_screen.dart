import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/data/lazer_data.dart';
import '../../core/widgets/bookable_area_shared.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ÁREA DE LAZER — 3 abas: Dashboard, Despesas, Agendamentos
// ─────────────────────────────────────────────────────────────────────────────
class LazerScreen extends StatefulWidget {
  const LazerScreen({super.key});

  @override
  State<LazerScreen> createState() => _LazerScreenState();
}

class _LazerScreenState extends State<LazerScreen> {
  int _tabIndex = 0;
  DateTime _mesFiltro = DateTime(DateTime.now().year, DateTime.now().month);

  void _setMes(int delta) {
    setState(() {
      _mesFiltro = DateTime(_mesFiltro.year, _mesFiltro.month + delta);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.backgroundDark,
                    AppColors.atrNavyDarker,
                    AppColors.backgroundDark,
                  ],
                  stops: [0, 0.5, 1],
                )
              : null,
          color: isDark ? null : AppColors.backgroundLight,
        ),
        child: SafeArea(
          child: Row(
            children: [
              BookableAreaSidebar(
                title: 'Área de Lazer',
                subtitle: 'Gestão de Reservas',
                icon: LucideIcons.palmtree,
                tabIndex: _tabIndex,
                onTabChange: (i) => setState(() => _tabIndex = i),
                onBack: () => context.go('/selector'),
                isDark: isDark,
                showConsolidado: true,
              ),
              Expanded(
                child: Column(
                  children: [
                    BookableAreaHeader(
                      mesFiltro: _mesFiltro,
                      onPrev: () => _setMes(-1),
                      onNext: () => _setMes(1),
                      isDark: isDark,
                    ),
                    Expanded(
                      child: IndexedStack(
                        index: _tabIndex,
                        children: [
                          _LazerDashboard(mes: _mesFiltro, isDark: isDark),
                          _LazerDespesas(mes: _mesFiltro, isDark: isDark),
                          _LazerAgendamentos(mes: _mesFiltro, isDark: isDark),
                          _LazerConsolidado(ano: _mesFiltro.year, isDark: isDark),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Status helpers ─────────────────────────────────────────────────────────
Widget _badge(String label, Color color) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );

Widget _statusReserva(String status) {
  switch (status) {
    case 'confirmada':
      return _badge('Confirmada', AppColors.statusInfo);
    case 'realizada':
      return _badge('Realizada', AppColors.statusSuccess);
    case 'cancelada':
      return _badge('Cancelada', AppColors.statusError);
    default:
      return _badge('Pendente', AppColors.statusWarning);
  }
}

Widget _statusLimpeza(String status) {
  if (status == 'concluido') {
    return _badge('Concluída', AppColors.statusSuccess);
  }
  return _badge('Pendente', AppColors.statusWarning);
}

// ═══════════════════════════════════════════════════════════════════════════
// ABA 0 — DASHBOARD
// ═══════════════════════════════════════════════════════════════════════════
class _LazerDashboard extends StatelessWidget {
  final DateTime mes;
  final bool isDark;
  const _LazerDashboard({required this.mes, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    final m = mes.month;
    final a = mes.year;

    final receita = receitaMesLazer(mes: m, ano: a);
    final despesas = despesasMesLazer(mes: m, ano: a);
    final lucro = receita - despesas;
    final ocupacao = ocupacaoPercMesLazer(mes: m, ano: a);

    final proximas = proximasReservas.take(8).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── KPIs ──
          LayoutBuilder(
            builder: (ctx, c) {
              final w = (c.maxWidth - 48) / 4;
              return Row(
                children: [
                  SizedBox(
                    width: w,
                    child: BookableAreaKpiCard(
                      label: 'Receita do Mês',
                      value: fmt.format(receita),
                      icon: LucideIcons.trendingUp,
                      iconColor: AppColors.statusSuccess,
                      isDark: isDark,
                    ).animate().fadeIn(delay: 0.ms),
                  ),
                  const SizedBox(width: 16),
                  SizedBox(
                    width: w,
                    child: BookableAreaKpiCard(
                      label: 'Despesas',
                      value: fmt.format(despesas),
                      icon: LucideIcons.trendingDown,
                      iconColor: AppColors.statusError,
                      isDark: isDark,
                    ).animate().fadeIn(delay: 60.ms),
                  ),
                  const SizedBox(width: 16),
                  SizedBox(
                    width: w,
                    child: BookableAreaKpiCard(
                      label: 'Lucro Líquido',
                      value: fmt.format(lucro),
                      icon: LucideIcons.dollarSign,
                      iconColor: lucro >= 0
                          ? AppColors.statusSuccess
                          : AppColors.statusError,
                      isDark: isDark,
                    ).animate().fadeIn(delay: 120.ms),
                  ),
                  const SizedBox(width: 16),
                  SizedBox(
                    width: w,
                    child: BookableAreaKpiCard(
                      label: '% Ocupação FDS',
                      value: '${ocupacao.toStringAsFixed(1)}%',
                      icon: LucideIcons.activity,
                      iconColor: AppColors.atrOrange,
                      isDark: isDark,
                    ).animate().fadeIn(delay: 180.ms),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),
          // ── Resumo de reservas ──
          LayoutBuilder(
            builder: (ctx, c) {
              final w = (c.maxWidth - 32) / 3;
              final realizadas = reservasPorMes(mes: m, ano: a)
                  .where((r) => r.statusReserva == 'realizada')
                  .length;
              final confirmadas = reservasPorMes(mes: m, ano: a)
                  .where((r) => r.statusReserva == 'confirmada')
                  .length;
              final limpPend = reservasPorMes(mes: m, ano: a)
                  .where(
                    (r) =>
                        r.statusLimpeza == 'pendente' &&
                        r.statusReserva != 'cancelada',
                  )
                  .length;
              return Column(
                children: [
                  Row(
                    children: [
                      SizedBox(
                        width: w,
                        child: BookableAreaKpiCard(
                          label: 'Realizadas',
                          value: '$realizadas',
                          icon: LucideIcons.checkCircle,
                          iconColor: AppColors.statusSuccess,
                          isDark: isDark,
                        ),
                      ),
                      const SizedBox(width: 16),
                      SizedBox(
                        width: w,
                        child: BookableAreaKpiCard(
                          label: 'Confirmadas',
                          value: '$confirmadas',
                          icon: LucideIcons.calendarCheck,
                          iconColor: AppColors.statusInfo,
                          isDark: isDark,
                        ),
                      ),
                      const SizedBox(width: 16),
                      SizedBox(
                        width: w,
                        child: BookableAreaKpiCard(
                          label: 'Limpezas Pendentes',
                          value: '$limpPend',
                          icon: LucideIcons.sparkles,
                          iconColor: AppColors.statusWarning,
                          isDark: isDark,
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),
          Text(
            'Próximas Reservas',
            style: TextStyle(
              color: isDark ? Colors.white : AppColors.textPrimaryLight,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          if (proximas.isEmpty)
            BookableAreaEmptyState(
              message: 'Nenhuma reserva futura confirmada',
              icon: LucideIcons.calendarOff,
              isDark: isDark,
            )
          else
            ...proximas.map((r) => _ReservaRow(reserva: r, isDark: isDark)),
        ],
      ),
    );
  }
}

class _ReservaRow extends StatelessWidget {
  final ReservaLazer reserva;
  final bool isDark;
  const _ReservaRow({required this.reserva, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    final dateFmt = DateFormat('dd/MM (EEE)', 'pt_BR');
    final bg =
        isDark ? AppColors.surfaceElevatedDark : AppColors.surfaceElevatedLight;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              dateFmt.format(reserva.data),
              style: TextStyle(
                color: isDark ? Colors.white70 : AppColors.textSecondaryLight,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              reserva.cliente,
              style: TextStyle(
                color: isDark ? Colors.white : AppColors.textPrimaryLight,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              reserva.tipoEvento,
              style: TextStyle(
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: Text(
              fmt.format(reserva.valor),
              style: const TextStyle(
                color: AppColors.statusSuccess,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
          _statusReserva(reserva.statusReserva),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ABA 1 — DESPESAS
// ═══════════════════════════════════════════════════════════════════════════
class _LazerDespesas extends StatelessWidget {
  final DateTime mes;
  final bool isDark;
  const _LazerDespesas({required this.mes, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    final m = mes.month;
    final a = mes.year;
    final dsps = despesasLazer
        .where((d) => d.data.month == m && d.data.year == a)
        .toList();
    final total = dsps.fold(0.0, (s, d) => s + d.valor);
    final pendente = dsps
        .where((d) => d.status == 'pendente' || d.status == 'atrasado')
        .fold(0.0, (s, d) => s + d.valor);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: BookableAreaKpiCard(
                  label: 'Total de Despesas',
                  value: fmt.format(total),
                  icon: LucideIcons.receipt,
                  iconColor: AppColors.statusError,
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: BookableAreaKpiCard(
                  label: 'Lançamentos',
                  value: '${dsps.length}',
                  icon: LucideIcons.fileText,
                  iconColor: AppColors.statusInfo,
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: BookableAreaKpiCard(
                  label: 'A Pagar',
                  value: fmt.format(pendente),
                  icon: LucideIcons.alertCircle,
                  iconColor: AppColors.statusWarning,
                  isDark: isDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            'Lançamentos',
            style: TextStyle(
              color: isDark ? Colors.white : AppColors.textPrimaryLight,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          if (dsps.isEmpty)
            BookableAreaEmptyState(
              message: 'Nenhuma despesa neste mês',
              icon: LucideIcons.inbox,
              isDark: isDark,
            )
          else
            _DespesasTable(despesas: dsps, fmt: fmt, isDark: isDark),
        ],
      ),
    );
  }
}

class _DespesasTable extends StatelessWidget {
  final List<DespesaLazer> despesas;
  final NumberFormat fmt;
  final bool isDark;
  const _DespesasTable({
    required this.despesas,
    required this.fmt,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? AppColors.surfaceDark : AppColors.surfaceLight;
    final border = isDark ? AppColors.borderDark : AppColors.borderLight;
    final headerBg =
        isDark ? AppColors.surfaceElevatedDark : AppColors.surfaceElevatedLight;

    final catColors = <String, Color>{
      'energia': AppColors.statusWarning,
      'limpeza': AppColors.statusInfo,
      'manutenção': AppColors.atrOrange,
      'outros': AppColors.textSecondaryDark,
    };

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: headerBg,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: const Row(
              children: [
                BookableAreaTableCol('Data', flex: 2),
                BookableAreaTableCol('Descrição', flex: 4),
                BookableAreaTableCol('Categoria', flex: 2),
                BookableAreaTableCol('Valor', flex: 2),
                BookableAreaTableCol('Status', flex: 2),
              ],
            ),
          ),
          ...despesas.asMap().entries.map((e) {
            final d = e.value;
            final rowBg = e.key % 2 == 1
                ? (isDark
                    ? Colors.white.withValues(alpha: 0.02)
                    : Colors.black.withValues(alpha: 0.02))
                : Colors.transparent;
            final catColor =
                catColors[d.categoria] ?? AppColors.textSecondaryDark;
            final statusColor = d.status == 'pago'
                ? AppColors.statusSuccess
                : d.status == 'atrasado'
                    ? AppColors.statusError
                    : AppColors.statusWarning;
            return Container(
              color: rowBg,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Text(
                      DateFormat('dd/MM/yy').format(d.data),
                      style: TextStyle(
                        color: isDark
                            ? Colors.white70
                            : AppColors.textSecondaryLight,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 4,
                    child: Text(
                      d.descricao,
                      style: TextStyle(
                        color:
                            isDark ? Colors.white : AppColors.textPrimaryLight,
                        fontSize: 13,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      d.categoria,
                      style: TextStyle(
                        color: catColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      fmt.format(d.valor),
                      style: const TextStyle(
                        color: AppColors.statusError,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: _badge(
                      d.status[0].toUpperCase() + d.status.substring(1),
                      statusColor,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ABA 2 — AGENDAMENTOS
// ═══════════════════════════════════════════════════════════════════════════
class _LazerAgendamentos extends StatefulWidget {
  final DateTime mes;
  final bool isDark;
  const _LazerAgendamentos({required this.mes, required this.isDark});

  @override
  State<_LazerAgendamentos> createState() => _LazerAgendamentosState();
}

class _LazerAgendamentosState extends State<_LazerAgendamentos> {
  String _statusFiltro = 'todos';

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    final m = widget.mes.month;
    final a = widget.mes.year;
    final isDark = widget.isDark;

    var reservas = reservasPorMes(mes: m, ano: a);
    if (_statusFiltro != 'todos') {
      reservas =
          reservas.where((r) => r.statusReserva == _statusFiltro).toList();
    }
    reservas.sort((x, y) => x.data.compareTo(y.data));

    final totalMes = reservasPorMes(mes: m, ano: a)
        .where((r) => r.statusReserva == 'realizada')
        .fold(0.0, (s, r) => s + r.valor);
    final canceladas = reservasPorMes(mes: m, ano: a)
        .where((r) => r.statusReserva == 'cancelada')
        .length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: BookableAreaKpiCard(
                  label: 'Reservas no Mês',
                  value: '${reservasPorMes(mes: m, ano: a).length}',
                  icon: LucideIcons.calendarDays,
                  iconColor: AppColors.statusInfo,
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: BookableAreaKpiCard(
                  label: 'Receita Realizada',
                  value: fmt.format(totalMes),
                  icon: LucideIcons.dollarSign,
                  iconColor: AppColors.statusSuccess,
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: BookableAreaKpiCard(
                  label: 'Cancelamentos',
                  value: '$canceladas',
                  icon: LucideIcons.xCircle,
                  iconColor: AppColors.statusError,
                  isDark: isDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'Status:',
                style: TextStyle(
                  color: isDark ? Colors.white70 : AppColors.textSecondaryLight,
                  fontSize: 13,
                ),
              ),
              ...['todos', 'confirmada', 'realizada', 'cancelada'].map(
                (s) => BookableAreaFilterChip(
                  label: s[0].toUpperCase() + s.substring(1),
                  active: _statusFiltro == s,
                  isDark: isDark,
                  onTap: () => setState(() => _statusFiltro = s),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '${reservas.length} registro(s)',
            style: TextStyle(
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          if (reservas.isEmpty)
            BookableAreaEmptyState(
              message: 'Nenhuma reserva encontrada',
              icon: LucideIcons.calendarOff,
              isDark: isDark,
            )
          else
            _ReservasTable(reservas: reservas, fmt: fmt, isDark: isDark),
        ],
      ),
    );
  }
}

class _ReservasTable extends StatelessWidget {
  final List<ReservaLazer> reservas;
  final NumberFormat fmt;
  final bool isDark;
  const _ReservasTable({
    required this.reservas,
    required this.fmt,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? AppColors.surfaceDark : AppColors.surfaceLight;
    final border = isDark ? AppColors.borderDark : AppColors.borderLight;
    final headerBg =
        isDark ? AppColors.surfaceElevatedDark : AppColors.surfaceElevatedLight;
    final dateFmt = DateFormat('dd/MM (EEE)', 'pt_BR');

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: headerBg,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: const Row(
              children: [
                BookableAreaTableCol('Data', flex: 2),
                BookableAreaTableCol('Cliente', flex: 3),
                BookableAreaTableCol('Evento', flex: 3),
                BookableAreaTableCol('Valor', flex: 2),
                BookableAreaTableCol('Reserva', flex: 2),
                BookableAreaTableCol('Limpeza', flex: 2),
              ],
            ),
          ),
          ...reservas.asMap().entries.map((e) {
            final r = e.value;
            final rowBg = e.key % 2 == 1
                ? (isDark
                    ? Colors.white.withValues(alpha: 0.02)
                    : Colors.black.withValues(alpha: 0.02))
                : Colors.transparent;
            return Container(
              color: rowBg,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Text(
                      dateFmt.format(r.data),
                      style: TextStyle(
                        color: isDark
                            ? Colors.white70
                            : AppColors.textSecondaryLight,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(
                      r.cliente,
                      style: TextStyle(
                        color:
                            isDark ? Colors.white : AppColors.textPrimaryLight,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(
                      r.tipoEvento,
                      style: TextStyle(
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      fmt.format(r.valor),
                      style: const TextStyle(
                        color: AppColors.statusSuccess,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  Expanded(flex: 2, child: _statusReserva(r.statusReserva)),
                  Expanded(flex: 2, child: _statusLimpeza(r.statusLimpeza)),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ABA 3 — CONSOLIDADO ANUAL
// ═══════════════════════════════════════════════════════════════════════════
class _LazerConsolidado extends StatelessWidget {
  final int ano;
  final bool isDark;
  const _LazerConsolidado({required this.ano, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    final mesNomes = [
      'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
      'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro',
    ];

    double receitaTotal = 0;
    double despesasTotal = 0;
    int reservasTotal = 0;

    final rows = List.generate(12, (i) {
      final m = i + 1;
      final rec = receitaMesLazer(mes: m, ano: ano);
      final desp = despesasMesLazer(mes: m, ano: ano);
      final lucro = rec - desp;
      final reservas = reservasPorMes(mes: m, ano: ano)
          .where((r) => r.statusReserva != 'cancelada')
          .length;
      final ocup = ocupacaoPercMesLazer(mes: m, ano: ano);

      receitaTotal += rec;
      despesasTotal += desp;
      reservasTotal += reservas;

      return (
        mes: mesNomes[i],
        receita: rec,
        despesas: desp,
        lucro: lucro,
        reservas: reservas,
        ocupacao: ocup,
      );
    });

    final lucroTotal = receitaTotal - despesasTotal;

    final bg = isDark ? AppColors.surfaceDark : AppColors.surfaceLight;
    final border = isDark ? AppColors.borderDark : AppColors.borderLight;
    final headerBg =
        isDark ? AppColors.surfaceElevatedDark : AppColors.surfaceElevatedLight;
    final textPrimary =
        isDark ? Colors.white : AppColors.textPrimaryLight;
    final textSec =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Consolidado $ano',
            style: TextStyle(
              color: textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 16),
          // ── KPIs anuais ──
          LayoutBuilder(
            builder: (ctx, c) {
              final w = (c.maxWidth - 48) / 4;
              return Row(
                children: [
                  SizedBox(
                    width: w,
                    child: BookableAreaKpiCard(
                      label: 'Receita do Ano',
                      value: fmt.format(receitaTotal),
                      icon: LucideIcons.trendingUp,
                      iconColor: AppColors.statusSuccess,
                      isDark: isDark,
                    ),
                  ),
                  const SizedBox(width: 16),
                  SizedBox(
                    width: w,
                    child: BookableAreaKpiCard(
                      label: 'Despesas do Ano',
                      value: fmt.format(despesasTotal),
                      icon: LucideIcons.trendingDown,
                      iconColor: AppColors.statusError,
                      isDark: isDark,
                    ),
                  ),
                  const SizedBox(width: 16),
                  SizedBox(
                    width: w,
                    child: BookableAreaKpiCard(
                      label: 'Lucro Líquido',
                      value: fmt.format(lucroTotal),
                      icon: LucideIcons.dollarSign,
                      iconColor: lucroTotal >= 0
                          ? AppColors.statusSuccess
                          : AppColors.statusError,
                      isDark: isDark,
                    ),
                  ),
                  const SizedBox(width: 16),
                  SizedBox(
                    width: w,
                    child: BookableAreaKpiCard(
                      label: 'Reservas Realizadas',
                      value: '$reservasTotal',
                      icon: LucideIcons.calendarCheck,
                      iconColor: AppColors.atrOrange,
                      isDark: isDark,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),
          // ── Tabela por mês ──
          Container(
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: border),
            ),
            child: Column(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: headerBg,
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(12),),
                  ),
                  child: const Row(
                    children: [
                      BookableAreaTableCol('Mês', flex: 3),
                      BookableAreaTableCol('Receita', flex: 3),
                      BookableAreaTableCol('Despesas', flex: 3),
                      BookableAreaTableCol('Lucro', flex: 3),
                      BookableAreaTableCol('Reservas', flex: 2),
                      BookableAreaTableCol('Ocup.%', flex: 2),
                    ],
                  ),
                ),
                ...rows.asMap().entries.map((e) {
                  final r = e.value;
                  final rowBg = e.key % 2 == 1
                      ? (isDark
                          ? Colors.white.withValues(alpha: 0.02)
                          : Colors.black.withValues(alpha: 0.02))
                      : Colors.transparent;
                  final lucroColor = r.lucro >= 0
                      ? AppColors.statusSuccess
                      : AppColors.statusError;
                  return Container(
                    color: rowBg,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12,),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: Text(
                            r.mes,
                            style: TextStyle(
                              color: textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: Text(
                            fmt.format(r.receita),
                            style: const TextStyle(
                              color: AppColors.statusSuccess,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: Text(
                            fmt.format(r.despesas),
                            style: const TextStyle(
                              color: AppColors.statusError,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: Text(
                            fmt.format(r.lucro),
                            style: TextStyle(
                              color: lucroColor,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            '${r.reservas}',
                            style: TextStyle(color: textSec, fontSize: 13),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            '${r.ocupacao.toStringAsFixed(1)}%',
                            style: const TextStyle(
                              color: AppColors.atrOrange,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                // ── Rodapé totais ──
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12,),
                  decoration: BoxDecoration(
                    color: AppColors.atrOrange.withValues(alpha: 0.06),
                    borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(12),),
                    border: Border(top: BorderSide(color: border)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Text(
                          'TOTAL',
                          style: TextStyle(
                            color: textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Text(
                          fmt.format(receitaTotal),
                          style: const TextStyle(
                            color: AppColors.statusSuccess,
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Text(
                          fmt.format(despesasTotal),
                          style: const TextStyle(
                            color: AppColors.statusError,
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Text(
                          fmt.format(lucroTotal),
                          style: TextStyle(
                            color: lucroTotal >= 0
                                ? AppColors.statusSuccess
                                : AppColors.statusError,
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          '$reservasTotal',
                          style: TextStyle(
                            color: textPrimary,
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const Expanded(flex: 2, child: SizedBox()),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
