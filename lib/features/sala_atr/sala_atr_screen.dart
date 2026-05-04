import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/data/sala_atr_data.dart';
import '../../core/widgets/bookable_area_shared.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SALA ATR — 3 abas: Dashboard, Despesas, Agendamentos
// ─────────────────────────────────────────────────────────────────────────────
class SalaAtrScreen extends StatefulWidget {
  const SalaAtrScreen({super.key});

  @override
  State<SalaAtrScreen> createState() => _SalaAtrScreenState();
}

class _SalaAtrScreenState extends State<SalaAtrScreen> {
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
                title: 'Sala ATR',
                subtitle: 'Gestão de Espaços',
                icon: LucideIcons.building2,
                titleFontSize: 15,
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
                          _SalaAtrDashboard(mes: _mesFiltro, isDark: isDark),
                          _SalaAtrDespesas(mes: _mesFiltro, isDark: isDark),
                          _SalaAtrAgendamentos(mes: _mesFiltro, isDark: isDark),
                          _SalaAtrConsolidado(ano: _mesFiltro.year, isDark: isDark),
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

// ── Helpers de status ──────────────────────────────────────────────────────
Widget _buildStatusBadge(String label, Color color) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withValues(alpha: 0.3)),
    ),
    child: Text(
      label,
      style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
    ),
  );
}

Widget _statusAgendamento(StatusAgendamento status) {
  switch (status) {
    case StatusAgendamento.confirmado:
      return _buildStatusBadge('Confirmado', AppColors.statusInfo);
    case StatusAgendamento.realizado:
      return _buildStatusBadge('Realizado', AppColors.statusSuccess);
    case StatusAgendamento.cancelado:
      return _buildStatusBadge('Cancelado', AppColors.statusError);
    case StatusAgendamento.pendente:
      return _buildStatusBadge('Pendente', AppColors.statusWarning);
  }
}

Widget _statusPagamento(StatusPagamento status) {
  switch (status) {
    case StatusPagamento.pago:
      return _buildStatusBadge('Pago', AppColors.statusSuccess);
    case StatusPagamento.pendente:
      return _buildStatusBadge('Pendente', AppColors.statusWarning);
    case StatusPagamento.atrasado:
      return _buildStatusBadge('Atrasado', AppColors.statusError);
  }
}

String _nomesSala(int id) =>
    salasAtr.firstWhere((s) => s.id == id, orElse: () => salasAtr.first).nome;

// ═══════════════════════════════════════════════════════════════════════════
// ABA 0 — DASHBOARD
// ═══════════════════════════════════════════════════════════════════════════
class _SalaAtrDashboard extends StatelessWidget {
  final DateTime mes;
  final bool isDark;
  const _SalaAtrDashboard({required this.mes, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    final m = mes.month;
    final a = mes.year;

    final receita = receitaMes(mes: m, ano: a);
    final despesas = despesasMes(mes: m, ano: a);
    final lucro = receita - despesas;
    final ocupacao = ocupacaoPercMes(mes: m, ano: a);
    final agendHoje = agendamentosHoje;

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
                      label: '% Ocupação',
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
          // ── Cards das salas ──
          Text(
            'Espaços',
            style: TextStyle(
              color: isDark ? Colors.white : AppColors.textPrimaryLight,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 2.6,
            ),
            itemCount: salasAtr.length,
            itemBuilder: (ctx, i) {
              final sala = salasAtr[i];
              final count = agendamentosPorMes(mes: m, ano: a, salaId: sala.id)
                  .where((ag) => ag.status != StatusAgendamento.cancelado)
                  .length;
              return _SalaCard(sala: sala, agendamentos: count, isDark: isDark);
            },
          ),
          const SizedBox(height: 24),
          // ── Agenda Hoje ──
          Text(
            'Agenda de Hoje',
            style: TextStyle(
              color: isDark ? Colors.white : AppColors.textPrimaryLight,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          if (agendHoje.isEmpty)
            BookableAreaEmptyState(
              message: 'Nenhum agendamento para hoje',
              icon: LucideIcons.calendarOff,
              isDark: isDark,
            )
          else
            ...agendHoje.map((ag) => _AgendRow(ag: ag, isDark: isDark)),
          const SizedBox(height: 24),
          // ── Próximos ──
          Text(
            'Próximos Agendamentos',
            style: TextStyle(
              color: isDark ? Colors.white : AppColors.textPrimaryLight,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          ...proximosAgendamentos
              .take(8)
              .map((ag) => _AgendRow(ag: ag, isDark: isDark)),
        ],
      ),
    );
  }
}

class _SalaCard extends StatelessWidget {
  final SalaComercial sala;
  final int agendamentos;
  final bool isDark;
  const _SalaCard({
    required this.sala,
    required this.agendamentos,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    final bg = isDark ? AppColors.surfaceDark : AppColors.surfaceLight;
    final border = isDark ? AppColors.borderDark : AppColors.borderLight;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Text(sala.imagemEmoji, style: const TextStyle(fontSize: 28)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  sala.nome,
                  style: TextStyle(
                    color: isDark ? Colors.white : AppColors.textPrimaryLight,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${fmt.format(sala.valorHora)}/h  •  ${sala.capacidadePessoas} pessoas',
                  style: TextStyle(
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(
                      LucideIcons.calendarCheck,
                      size: 11,
                      color: AppColors.atrOrange,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$agendamentos agend. no mês',
                      style: const TextStyle(
                        color: AppColors.atrOrange,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AgendRow extends StatelessWidget {
  final AgendamentoSala ag;
  final bool isDark;
  const _AgendRow({required this.ag, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    final timeFmt = DateFormat('dd/MM HH:mm');
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
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ag.cliente,
                  style: TextStyle(
                    color: isDark ? Colors.white : AppColors.textPrimaryLight,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  _nomesSala(ag.salaId),
                  style: TextStyle(
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              '${timeFmt.format(ag.inicio)} → ${DateFormat('HH:mm').format(ag.fim)}',
              style: TextStyle(
                color: isDark ? Colors.white70 : AppColors.textSecondaryLight,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: Text(
              fmt.format(ag.valorTotal),
              style: const TextStyle(
                color: AppColors.statusSuccess,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
          _statusAgendamento(ag.status),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ABA 1 — DESPESAS
// ═══════════════════════════════════════════════════════════════════════════
class _SalaAtrDespesas extends StatelessWidget {
  final DateTime mes;
  final bool isDark;
  const _SalaAtrDespesas({required this.mes, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    final m = mes.month;
    final a = mes.year;
    final dsps = despesasSala
        .where((d) => d.data.month == m && d.data.year == a)
        .toList();
    final total = dsps.fold(0.0, (s, d) => s + d.valor);
    final pendente = dsps
        .where((d) => d.status != StatusPagamento.pago)
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
  final List<DespesaSala> despesas;
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
      'marketing': AppColors.statusSuccess,
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
                  Expanded(flex: 2, child: _statusPagamento(d.status)),
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
class _SalaAtrAgendamentos extends StatefulWidget {
  final DateTime mes;
  final bool isDark;
  const _SalaAtrAgendamentos({required this.mes, required this.isDark});

  @override
  State<_SalaAtrAgendamentos> createState() => _SalaAtrAgendamentosState();
}

class _SalaAtrAgendamentosState extends State<_SalaAtrAgendamentos> {
  int? _salaFiltro;
  String _statusFiltro = 'todos';

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    final m = widget.mes.month;
    final a = widget.mes.year;
    final isDark = widget.isDark;

    var agends = agendamentosPorMes(mes: m, ano: a, salaId: _salaFiltro);
    if (_statusFiltro != 'todos') {
      agends = agends.where((ag) => ag.status.name == _statusFiltro).toList();
    }
    agends.sort((x, y) => x.inicio.compareTo(y.inicio));

    final totalMes = agendamentosPorMes(mes: m, ano: a)
        .where((ag) => ag.status != StatusAgendamento.cancelado)
        .fold(0.0, (s, ag) => s + ag.valorTotal);
    final cancelados = agendamentosPorMes(mes: m, ano: a)
        .where((ag) => ag.status == StatusAgendamento.cancelado)
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
                  label: 'Agendamentos',
                  value: '${agendamentosPorMes(mes: m, ano: a).length}',
                  icon: LucideIcons.calendarDays,
                  iconColor: AppColors.statusInfo,
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: BookableAreaKpiCard(
                  label: 'Receita do Mês',
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
                  value: '$cancelados',
                  icon: LucideIcons.xCircle,
                  iconColor: AppColors.statusError,
                  isDark: isDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // ── Filtros ──
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'Sala:',
                style: TextStyle(
                  color: isDark ? Colors.white70 : AppColors.textSecondaryLight,
                  fontSize: 13,
                ),
              ),
              BookableAreaFilterChip(
                label: 'Todas',
                active: _salaFiltro == null,
                isDark: isDark,
                onTap: () => setState(() => _salaFiltro = null),
              ),
              ...salasAtr.map(
                (s) => BookableAreaFilterChip(
                  label: '${s.imagemEmoji} ${s.nome.split(' ').first}',
                  active: _salaFiltro == s.id,
                  isDark: isDark,
                  onTap: () => setState(
                    () => _salaFiltro = _salaFiltro == s.id ? null : s.id,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Status:',
                style: TextStyle(
                  color: isDark ? Colors.white70 : AppColors.textSecondaryLight,
                  fontSize: 13,
                ),
              ),
              ...['todos', 'confirmado', 'realizado', 'cancelado', 'pendente']
                  .map(
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
            '${agends.length} registro(s)',
            style: TextStyle(
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          if (agends.isEmpty)
            BookableAreaEmptyState(
              message: 'Nenhum agendamento encontrado',
              icon: LucideIcons.calendarOff,
              isDark: isDark,
            )
          else
            _AgendamentosTable(agendamentos: agends, fmt: fmt, isDark: isDark),
        ],
      ),
    );
  }
}

class _AgendamentosTable extends StatelessWidget {
  final List<AgendamentoSala> agendamentos;
  final NumberFormat fmt;
  final bool isDark;
  const _AgendamentosTable({
    required this.agendamentos,
    required this.fmt,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? AppColors.surfaceDark : AppColors.surfaceLight;
    final border = isDark ? AppColors.borderDark : AppColors.borderLight;
    final headerBg =
        isDark ? AppColors.surfaceElevatedDark : AppColors.surfaceElevatedLight;
    final timeFmt = DateFormat('dd/MM HH:mm');

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
                BookableAreaTableCol('Início', flex: 2),
                BookableAreaTableCol('Cliente', flex: 3),
                BookableAreaTableCol('Sala', flex: 3),
                BookableAreaTableCol('Tipo', flex: 2),
                BookableAreaTableCol('Valor', flex: 2),
                BookableAreaTableCol('Status', flex: 2),
              ],
            ),
          ),
          ...agendamentos.asMap().entries.map((e) {
            final ag = e.value;
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
                      timeFmt.format(ag.inicio),
                      style: TextStyle(
                        color: isDark
                            ? Colors.white70
                            : AppColors.textSecondaryLight,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(
                      ag.cliente,
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
                      _nomesSala(ag.salaId),
                      style: TextStyle(
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                        fontSize: 12,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      ag.tipo == TipoLocacao.diaria ? 'Diária' : 'Por hora',
                      style: TextStyle(
                        color: isDark
                            ? Colors.white60
                            : AppColors.textSecondaryLight,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      fmt.format(ag.valorTotal),
                      style: const TextStyle(
                        color: AppColors.statusSuccess,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  Expanded(flex: 2, child: _statusAgendamento(ag.status)),
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
class _SalaAtrConsolidado extends StatelessWidget {
  final int ano;
  final bool isDark;
  const _SalaAtrConsolidado({required this.ano, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    final mesNomes = [
      'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
      'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro',
    ];

    double receitaTotal = 0;
    double despesasTotal = 0;
    int agendamentosTotal = 0;

    final rows = List.generate(12, (i) {
      final m = i + 1;
      final rec = receitaMes(mes: m, ano: ano);
      final desp = despesasMes(mes: m, ano: ano);
      final lucro = rec - desp;
      final agends = agendamentosPorMes(mes: m, ano: ano)
          .where((ag) => ag.status != StatusAgendamento.cancelado)
          .length;
      final ocup = ocupacaoPercMes(mes: m, ano: ano);

      receitaTotal += rec;
      despesasTotal += desp;
      agendamentosTotal += agends;

      return (
        mes: mesNomes[i],
        receita: rec,
        despesas: desp,
        lucro: lucro,
        agendamentos: agends,
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
                      label: 'Agendamentos',
                      value: '$agendamentosTotal',
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
                      BookableAreaTableCol('Agend.', flex: 2),
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
                            '${r.agendamentos}',
                            style: TextStyle(
                              color: textSec,
                              fontSize: 13,
                            ),
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
                    border: Border(
                      top: BorderSide(color: border),
                    ),
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
                          '$agendamentosTotal',
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
