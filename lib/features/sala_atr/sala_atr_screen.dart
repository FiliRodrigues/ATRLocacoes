import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/data/sala_atr_data.dart';

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
              _SalaAtrSidebar(
                tabIndex: _tabIndex,
                onTabChange: (i) => setState(() => _tabIndex = i),
                onBack: () => context.go('/selector'),
                isDark: isDark,
              ),
              Expanded(
                child: Column(
                  children: [
                    _SalaAtrHeader(
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

// ── Sidebar ────────────────────────────────────────────────────────────────
class _SalaAtrSidebar extends StatelessWidget {
  final int tabIndex;
  final ValueChanged<int> onTabChange;
  final VoidCallback onBack;
  final bool isDark;

  const _SalaAtrSidebar({
    required this.tabIndex,
    required this.onTabChange,
    required this.onBack,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final tabs = [
      (icon: LucideIcons.layoutDashboard, label: 'Dashboard'),
      (icon: LucideIcons.receipt, label: 'Despesas'),
      (icon: LucideIcons.calendarDays, label: 'Agendamentos'),
    ];
    final bg = isDark ? AppColors.surfaceDark : AppColors.surfaceLight;
    final border = isDark ? AppColors.borderDark : AppColors.borderLight;
    const activeColor = AppColors.atrOrange;
    final inactiveColor =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    return Container(
      width: 200,
      decoration: BoxDecoration(
        color: bg,
        border: Border(right: BorderSide(color: border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.atrOrange.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        LucideIcons.building2,
                        color: AppColors.atrOrange,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Sala ATR',
                        style: TextStyle(
                          color: isDark
                              ? Colors.white
                              : AppColors.textPrimaryLight,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Gestão de Espaços',
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
          const SizedBox(height: 28),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              'NAVEGAÇÃO',
              style: TextStyle(
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
                fontSize: 10,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 8),
          ...List.generate(tabs.length, (i) {
            final tab = tabs[i];
            final active = i == tabIndex;
            return GestureDetector(
              onTap: () => onTabChange(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: active
                      ? AppColors.atrOrange.withValues(alpha: 0.12)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: active
                        ? AppColors.atrOrange.withValues(alpha: 0.3)
                        : Colors.transparent,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      tab.icon,
                      size: 16,
                      color: active ? activeColor : inactiveColor,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      tab.label,
                      style: TextStyle(
                        color: active ? activeColor : inactiveColor,
                        fontSize: 13,
                        fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.all(12),
            child: GestureDetector(
              onTap: onBack,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.surfaceElevatedDark
                      : AppColors.surfaceElevatedLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      LucideIcons.arrowLeft,
                      size: 15,
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Voltar',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Header com seletor de mês ──────────────────────────────────────────────
class _SalaAtrHeader extends StatelessWidget {
  final DateTime mesFiltro;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final bool isDark;

  const _SalaAtrHeader({
    required this.mesFiltro,
    required this.onPrev,
    required this.onNext,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? AppColors.surfaceDark : AppColors.surfaceLight;
    final border = isDark ? AppColors.borderDark : AppColors.borderLight;
    final mesLabel = DateFormat('MMMM yyyy', 'pt_BR').format(mesFiltro);

    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: bg,
        border: Border(bottom: BorderSide(color: border)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          Text(
            mesLabel[0].toUpperCase() + mesLabel.substring(1),
            style: TextStyle(
              color: isDark ? Colors.white : AppColors.textPrimaryLight,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 12),
          _NavBtn(icon: LucideIcons.chevronLeft, onTap: onPrev, isDark: isDark),
          const SizedBox(width: 4),
          _NavBtn(
            icon: LucideIcons.chevronRight,
            onTap: onNext,
            isDark: isDark,
          ),
          const Spacer(),
        ],
      ),
    );
  }
}

class _NavBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool isDark;
  const _NavBtn({
    required this.icon,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: isDark
              ? AppColors.surfaceElevatedDark
              : AppColors.surfaceElevatedLight,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(
          icon,
          size: 14,
          color: isDark ? Colors.white70 : AppColors.textSecondaryLight,
        ),
      ),
    );
  }
}

// ── KPI Card ──────────────────────────────────────────────────────────────
class _KpiCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color iconColor;
  final bool isDark;

  const _KpiCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.iconColor,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? AppColors.surfaceDark : AppColors.surfaceLight;
    final border = isDark ? AppColors.borderDark : AppColors.borderLight;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: iconColor),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              color: isDark ? Colors.white : AppColors.textPrimaryLight,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
              fontSize: 12,
            ),
          ),
        ],
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

// ── TableCol helper ──────────────────────────────────────────────────────
class _Col extends StatelessWidget {
  final String label;
  final int flex;
  const _Col(this.label, {this.flex = 1});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.textSecondaryDark,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

// ── Empty state ──────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final String message;
  final IconData icon;
  final bool isDark;
  const _EmptyState({
    required this.message,
    required this.icon,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          Icon(
            icon,
            size: 36,
            color: isDark
                ? AppColors.textSecondaryDark
                : AppColors.textSecondaryLight,
          ),
          const SizedBox(height: 12),
          Text(
            message,
            style: TextStyle(
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Filter Chip ──────────────────────────────────────────────────────────
class _FilterChip extends StatelessWidget {
  final String label;
  final bool active;
  final bool isDark;
  final VoidCallback onTap;
  const _FilterChip({
    required this.label,
    required this.active,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: active
              ? AppColors.atrOrange
              : (isDark
                  ? AppColors.surfaceElevatedDark
                  : AppColors.surfaceElevatedLight),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active
                ? AppColors.atrOrange
                : (isDark ? AppColors.borderDark : AppColors.borderLight),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active
                ? Colors.white
                : (isDark ? Colors.white70 : AppColors.textSecondaryLight),
            fontSize: 12,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

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
                    child: _KpiCard(
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
                    child: _KpiCard(
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
                    child: _KpiCard(
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
                    child: _KpiCard(
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
            _EmptyState(
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
                child: _KpiCard(
                  label: 'Total de Despesas',
                  value: fmt.format(total),
                  icon: LucideIcons.receipt,
                  iconColor: AppColors.statusError,
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _KpiCard(
                  label: 'Lançamentos',
                  value: '${dsps.length}',
                  icon: LucideIcons.fileText,
                  iconColor: AppColors.statusInfo,
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _KpiCard(
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
            _EmptyState(
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
                _Col('Data', flex: 2),
                _Col('Descrição', flex: 4),
                _Col('Categoria', flex: 2),
                _Col('Valor', flex: 2),
                _Col('Status', flex: 2),
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
                child: _KpiCard(
                  label: 'Agendamentos',
                  value: '${agendamentosPorMes(mes: m, ano: a).length}',
                  icon: LucideIcons.calendarDays,
                  iconColor: AppColors.statusInfo,
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _KpiCard(
                  label: 'Receita do Mês',
                  value: fmt.format(totalMes),
                  icon: LucideIcons.dollarSign,
                  iconColor: AppColors.statusSuccess,
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _KpiCard(
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
              _FilterChip(
                label: 'Todas',
                active: _salaFiltro == null,
                isDark: isDark,
                onTap: () => setState(() => _salaFiltro = null),
              ),
              ...salasAtr.map(
                (s) => _FilterChip(
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
                (s) => _FilterChip(
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
            _EmptyState(
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
                _Col('Início', flex: 2),
                _Col('Cliente', flex: 3),
                _Col('Sala', flex: 3),
                _Col('Tipo', flex: 2),
                _Col('Valor', flex: 2),
                _Col('Status', flex: 2),
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
