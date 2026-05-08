import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/atr_button.dart';
import '../../core/widgets/atr_page_background.dart';
import '../../core/data/sala_atr_data.dart';
import '../../core/widgets/bookable_area_shared.dart';

class SalaAtrScreen extends StatefulWidget {
  const SalaAtrScreen({super.key});

  @override
  State<SalaAtrScreen> createState() => _SalaAtrScreenState();
}

class _SalaAtrScreenState extends State<SalaAtrScreen> {
  int _tabIndex = 0;
  DateTime _dataFiltro = DateTime.now();
  bool _resumoMostrado = false;

  void _changeDate(int dias) {
    setState(() => _dataFiltro = _dataFiltro.add(Duration(days: dias)));
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _mostrarResumoDiario());
  }

  void _mostrarResumoDiario() {
    if (_resumoMostrado) return;
    _resumoMostrado = true;
    final resumo = SalaAtrState.instance.resumoDiario(DateTime.now());
    if (resumo.totalSessoes == 0) return;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => _ResumoDiarioDialog(resumo: resumo, isDark: isDark),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: AtrPageBackground(grid: true, child: Container(
        decoration: BoxDecoration(
          gradient: isDark
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.backgroundDark, AppColors.surfaceDeepNavy, AppColors.backgroundDark],
                  stops: [0, 0.5, 1],
                )
              : const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFF8FAFB), Color(0xFFF0F2F5), Color(0xFFF8FAFB)],
                  stops: [0, 0.5, 1],
                ),
        ),
        child: SafeArea(
          child: Row(
            children: [
              BookableAreaSidebar(
                title: 'Sala ATR',
                subtitle: 'Premium',
                icon: LucideIcons.sparkles,
                titleFontSize: 15,
                tabIndex: _tabIndex,
                onTabChange: (i) => setState(() => _tabIndex = i),
                onBack: () => context.go('/selector'),
                isDark: isDark,
                customTabs: const [
                  (icon: LucideIcons.layoutDashboard, label: 'Dashboard'),
                  (icon: LucideIcons.calendarDays, label: 'Agenda'),
                  (icon: LucideIcons.users, label: 'CRM'),
                  (icon: LucideIcons.receipt, label: 'Financeiro'),
                  (icon: LucideIcons.calendarClock, label: 'Recebimentos'),
                ],
              ),
              Expanded(
                child: Column(
                  children: [
                    _buildHeader(isDark),
                    Expanded(
                      child: ListenableBuilder(
                        listenable: SalaAtrState.instance,
                        builder: (context, _) {
                          switch (_tabIndex) {
                            case 0: return _SalaDashboard(data: _dataFiltro, isDark: isDark);
                            case 1: return _SalaAgenda(data: _dataFiltro, isDark: isDark);
                            case 2: return _SalaCrm(isDark: isDark);
                            case 3: return _SalaFinanceiro(data: _dataFiltro, isDark: isDark);
                            case 4: return _SalaRecebimentosFuturos(isDark: isDark);
                            default: return const SizedBox();
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      )),
    );
  }

  Widget _buildHeader(bool isDark) {
    String titulo;
    switch (_tabIndex) {
      case 1:
        titulo = DateFormat("EEEE, d 'de' MMMM", 'pt_BR').format(_dataFiltro).toUpperCase();
        break;
      default:
        titulo = DateFormat("MMMM 'de' yyyy", 'pt_BR').format(_dataFiltro).toUpperCase();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceCardDark : Colors.white,
        border: Border(bottom: BorderSide(color: isDark ? AppColors.surfaceHoverDark : AppColors.borderLightHex)),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black26 : AppColors.textMutedDark.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Text(
            titulo,
            style: TextStyle(
              color: isDark ? Colors.white : AppColors.surfaceCardDark,
              fontSize: 17,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
          const Spacer(),
          if (_tabIndex == 1 || _tabIndex == 0 || _tabIndex == 3 || _tabIndex == 4) ...[
            _HeaderButton(
              icon: LucideIcons.chevronLeft,
              onTap: () => _changeDate(_tabIndex == 1 ? -1 : -30),
              isDark: isDark,
            ),
            if (_tabIndex != 1)
              _HeaderButton(
                icon: LucideIcons.calendar,
                onTap: () async {
                  final data = await showDatePicker(
                    context: context,
                    initialDate: _dataFiltro,
                    firstDate: DateTime(2025),
                    lastDate: DateTime(2030),
                  );
                  if (data != null) setState(() => _dataFiltro = data);
                },
                isDark: isDark,
                isPrimary: true,
              ),
            _HeaderButton(
              icon: LucideIcons.chevronRight,
              onTap: () => _changeDate(_tabIndex == 1 ? 1 : 30),
              isDark: isDark,
            ),
          ],
          if (_tabIndex == 1) ...[
            const SizedBox(width: 16),
            Container(width: 1, height: 24, color: isDark ? AppColors.surfaceElevatedDark : AppColors.borderLightHex),
            const SizedBox(width: 16),
            AtrSecondaryButton(
              label: 'Mês',
              icon: LucideIcons.calendarDays,
              onPressed: () async {
                final data = await showDatePicker(
                  context: context,
                  initialDate: _dataFiltro,
                  firstDate: DateTime(2025),
                  lastDate: DateTime(2030),
                  helpText: 'ESCOLHA UM DIA DO MÊS',
                );
                if (data != null) setState(() => _dataFiltro = data);
              },
            ),
            const SizedBox(width: 8),
            AtrSecondaryButton(
              label: 'Hoje',
              icon: LucideIcons.listTodo,
              onPressed: () => setState(() => _dataFiltro = DateTime.now()),
            ),
          ],
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// HEADER WIDGETS
// ═══════════════════════════════════════════════════════════════════════════

class _HeaderButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool isDark;
  final bool isPrimary;
  const _HeaderButton({required this.icon, required this.onTap, required this.isDark, this.isPrimary = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: isPrimary
                ? AppColors.atrOrange.withValues(alpha: 0.12)
                : (isDark ? AppColors.surfaceHoverDark : const Color(0xFFF3F4F6)),
            borderRadius: BorderRadius.circular(10),
            border: isPrimary
                ? Border.all(color: AppColors.atrOrange.withValues(alpha: 0.2))
                : null,
          ),
          child: Icon(icon, size: 18, color: isPrimary ? AppColors.atrOrange : (isDark ? AppColors.textPrimaryDark : const Color(0xFF6B7280))),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// 9. RESUMO DIÁRIO MATINAL
// ═══════════════════════════════════════════════════════════════════════════

class _ResumoDiarioDialog extends StatelessWidget {
  final ResumoDiario resumo;
  final bool isDark;
  const _ResumoDiarioDialog({required this.resumo, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: isDark
              ? const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [AppColors.surfaceCardDark, AppColors.surfaceDarkAlt])
              : const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Colors.white, Color(0xFFF8FAFC)]),
          border: Border.all(color: isDark ? AppColors.surfaceHoverDark : AppColors.borderLightHex),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 30, offset: const Offset(0, 12)),
            BoxShadow(color: AppColors.atrOrange.withValues(alpha: 0.06), blurRadius: 60, offset: const Offset(0, 20)),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.atrOrange.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(LucideIcons.sun, color: AppColors.atrOrange, size: 22),
                ),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Bom dia! ☀️', style: TextStyle(color: isDark ? Colors.white : AppColors.surfaceCardDark, fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.3)),
                    Text(DateFormat("EEEE, d 'de' MMMM", 'pt_BR').format(resumo.data).toUpperCase(),
                        style: TextStyle(color: isDark ? AppColors.textSecondaryDark : AppColors.textMutedDark, fontSize: 12, fontWeight: FontWeight.w600)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? AppColors.backgroundDark : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? AppColors.surfaceHoverDark : AppColors.borderLightHex),
              ),
              child: Row(
                children: [
                  _MiniStat(icon: LucideIcons.calendarCheck, value: '${resumo.totalSessoes}', label: 'sessões hoje', color: AppColors.atrOrange, isDark: isDark),
                  Container(width: 1, height: 40, color: isDark ? AppColors.surfaceElevatedDark : AppColors.borderLightHex),

                  _MiniStat(icon: LucideIcons.checkCircle2, value: '${resumo.confirmadas}', label: 'confirmadas', color: AppColors.statusSuccess, isDark: isDark),
                  Container(width: 1, height: 40, color: isDark ? AppColors.surfaceElevatedDark : AppColors.borderLightHex),

                  _MiniStat(icon: LucideIcons.dollarSign, value: fmt.format(resumo.receitaParticularHoje), label: 'receita particular', color: AppColors.statusInfo, isDark: isDark),
                ],
              ),
            ),
            if (resumo.proximaSessao != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.statusSuccess.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.statusSuccess.withValues(alpha: 0.15)),
                ),
                child: Row(
                  children: [
                    const Icon(LucideIcons.arrowRightCircle, color: AppColors.statusSuccess, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Próximo: ${resumo.proximaSessao!.clienteNome}', style: TextStyle(color: isDark ? Colors.white : AppColors.surfaceCardDark, fontWeight: FontWeight.w600)),
                          Text('${DateFormat('HH:mm').format(resumo.proximaSessao!.inicio)} • ${resumo.proximaSessao!.tipoPagamento.nome}', style: TextStyle(color: isDark ? AppColors.textSecondaryDark : AppColors.textMutedDark, fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (resumo.aniversariantes.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.pink.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.pink.withValues(alpha: 0.15)),
                ),
                child: Row(
                  children: [
                    const Icon(LucideIcons.cake, color: Colors.pink, size: 16),
                    const SizedBox(width: 10),
                    Text('🎂 ${resumo.aniversariantes.join(', ')} faz aniversário hoje!',
                        style: TextStyle(color: isDark ? AppColors.textPrimaryDark : AppColors.textMutedDark, fontSize: 13)),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
            AtrPrimaryButton(
              label: 'Ver Agenda Completa',
              width: double.infinity,
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    ).animate().scaleXY(begin: 0.9, end: 1).fadeIn();
  }
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;
  final bool isDark;
  const _MiniStat({required this.icon, required this.value, required this.label, required this.color, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(color: isDark ? Colors.white : AppColors.surfaceCardDark, fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -0.3)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(color: isDark ? Colors.white38 : AppColors.textTertiaryDark, fontSize: 11, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// 1. DASHBOARD (melhorado com comparativos e pacotes)
// ═══════════════════════════════════════════════════════════════════════════
class _SalaDashboard extends StatelessWidget {
  final DateTime data;
  final bool isDark;
  const _SalaDashboard({required this.data, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final state = SalaAtrState.instance;
    final fmt = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

    final lucro = state.lucroLiquidoMes(data.month, data.year);
    final variacao = state.variacaoLucro(data.month, data.year);
    final ocupacao = state.ocupacaoPerc(data.month, data.year);
    final ocupacaoAnt = state.ocupacaoPercMesAnterior(data.month, data.year);
    final inadimplencia = state.inadimplenciaMes(data.month, data.year);
    final proximo = state.proximoCliente();
    final receitaPacotes = state.totalRecebidoPacotes();
    final sessoesPacotes = state.totalSessoesPacotesAtivas();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // KPI Row 1
          Row(
            children: [
              Expanded(
                child: _KpiPremiumCard(
                  label: 'Lucro Líquido',
                  value: fmt.format(lucro),
                  icon: LucideIcons.dollarSign,
                  iconColor: lucro >= 0 ? AppColors.statusSuccess : AppColors.statusError,
                  trend: variacao,
                  isDark: isDark,
                ).animate().fadeIn().slideX(begin: -20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _KpiPremiumCard(
                  label: 'Taxa de Ocupação',
                  value: '${ocupacao.toStringAsFixed(1)}%',
                  icon: LucideIcons.pieChart,
                  iconColor: AppColors.atrOrange,
                  subtitle: 'Mês ant.: ${ocupacaoAnt.toStringAsFixed(1)}%',
                  isDark: isDark,
                ).animate().fadeIn(delay: 80.ms).slideX(begin: -20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _KpiPremiumCard(
                  label: 'Inadimplência',
                  value: fmt.format(inadimplencia),
                  icon: LucideIcons.alertTriangle,
                  iconColor: inadimplencia > 0 ? AppColors.statusError : AppColors.statusSuccess,
                  isDark: isDark,
                ).animate().fadeIn(delay: 160.ms).slideX(begin: -20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _KpiPremiumCard(
                  label: 'Pacotes Ativos',
                  value: '$sessoesPacotes sessões',
                  icon: LucideIcons.package,
                  iconColor: AppColors.statusInfo,
                  subtitle: 'R\$ ${fmt.format(receitaPacotes)} recebido',
                  isDark: isDark,
                ).animate().fadeIn(delay: 240.ms).slideX(begin: -20),
              ),
            ],
          ),
          const SizedBox(height: 32),

          // Próximo Atendimento
          Row(
            children: [
              Text('Próximo Atendimento', style: TextStyle(color: isDark ? Colors.white : AppColors.surfaceCardDark, fontSize: 17, fontWeight: FontWeight.w700, letterSpacing: -0.3)),
              const Spacer(),
              if (proximo != null)
                AtrSecondaryButton(icon: LucideIcons.messageCircle, label: 'WhatsApp', onPressed: () => _abrirWhatsApp(context, proximo.whatsappUrl)),
            ],
          ),
          const SizedBox(height: 14),
          if (proximo != null)
            _ProximoClienteCard(proximo: proximo, isDark: isDark).animate().slideY(begin: 24, end: 0).fadeIn()
          else
            BookableAreaEmptyState(message: 'Nenhum paciente agendado', icon: LucideIcons.coffee, isDark: isDark),

          const SizedBox(height: 32),

          // Pacotes ativos
          if (state.pacotes.where((p) => p.ativo && !p.isEsgotado).isNotEmpty) ...[
            Row(
              children: [
                Text('Pacotes de Sessões', style: TextStyle(color: isDark ? Colors.white : AppColors.surfaceCardDark, fontSize: 17, fontWeight: FontWeight.w700, letterSpacing: -0.3)),
                const Spacer(),
                AtrSecondaryButton(
                  icon: LucideIcons.plus,
                  label: 'Novo Pacote',
                  onPressed: () => _abrirCriarPacote(context, isDark),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ...state.pacotes
                .where((p) => p.ativo && !p.isEsgotado)
                .map((p) => _PacoteCard(pacote: p, isDark: isDark)),
          ],
        ],
      ),
    );
  }
}

class _KpiPremiumCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color iconColor;
  final double? trend;
  final String? subtitle;
  final bool isDark;

  const _KpiPremiumCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.iconColor,
    this.trend,
    this.subtitle,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: isDark
            ? const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [AppColors.surfaceCardDark, AppColors.surfaceDarkAlt])
            : const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Colors.white, Color(0xFFF8FAFC)]),
        border: Border.all(color: isDark ? AppColors.surfaceHoverDark : const Color(0xFFF1F5F9)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04), blurRadius: 12, offset: const Offset(0, 4)),
          BoxShadow(color: iconColor.withValues(alpha: 0.04), blurRadius: 40, offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: iconColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, size: 18, color: iconColor),
              ),
              const Spacer(),
              if (trend != null)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(trend! >= 0 ? LucideIcons.trendingUp : LucideIcons.trendingDown, size: 14, color: trend! >= 0 ? AppColors.statusSuccess : AppColors.statusError),
                    const SizedBox(width: 2),
                    Text('${trend!.abs().toStringAsFixed(0)}%', style: TextStyle(color: trend! >= 0 ? AppColors.statusSuccess : AppColors.statusError, fontSize: 12, fontWeight: FontWeight.w700)),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 14),
          Text(value, style: TextStyle(color: isDark ? Colors.white : AppColors.surfaceCardDark, fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: isDark ? AppColors.textSecondaryDark : AppColors.textMutedDark, fontSize: 12, fontWeight: FontWeight.w500)),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(subtitle!, style: TextStyle(color: isDark ? Colors.white38 : AppColors.textTertiaryDark, fontSize: 11)),
          ],
        ],
      ),
    );
  }
}

class _ProximoClienteCard extends StatelessWidget {
  final AgendamentoSalaAtr proximo;
  final bool isDark;
  const _ProximoClienteCard({required this.proximo, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final corStatus = _corStatus(proximo.status);
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: isDark
            ? const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [AppColors.surfaceCardDark, AppColors.surfaceDeepNavy])
            : const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Colors.white, Color(0xFFFAFAFA)]),
        border: Border.all(color: AppColors.atrOrange.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(color: AppColors.atrOrange.withValues(alpha: 0.06), blurRadius: 24, offset: const Offset(0, 6)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.atrOrange.withValues(alpha: 0.1),
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.atrOrange.withValues(alpha: 0.2)),
            ),
            child: const Icon(LucideIcons.user, color: AppColors.atrOrange, size: 28),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(proximo.clienteNome, style: TextStyle(color: isDark ? Colors.white : AppColors.surfaceCardDark, fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: -0.3)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(LucideIcons.clock, size: 13, color: corStatus),
                    const SizedBox(width: 4),
                    Text('${DateFormat('HH:mm').format(proximo.inicio)} • ${proximo.tipoPagamento.nome}',
                        style: TextStyle(color: corStatus, fontSize: 13, fontWeight: FontWeight.w600)),
                  ],
                ),
              ],
            ),
          ),
          Column(
            children: [
              _StatusBadge(status: proximo.status),
              const SizedBox(height: 8),
              if (proximo.lembrete24h || proximo.lembrete1h)
                Row(
                  children: [
                    if (proximo.lembrete24h) ...[
                      Icon(LucideIcons.bell, size: 12, color: AppColors.statusSuccess.withValues(alpha: 0.6)),
                      const SizedBox(width: 2),
                      Text('24h', style: TextStyle(color: AppColors.statusSuccess.withValues(alpha: 0.6), fontSize: 10, fontWeight: FontWeight.w600)),
                    ],
                    if (proximo.lembrete24h && proximo.lembrete1h) const SizedBox(width: 6),
                    if (proximo.lembrete1h) ...[
                      Icon(LucideIcons.bellRing, size: 12, color: AppColors.atrOrange.withValues(alpha: 0.6)),
                      const SizedBox(width: 2),
                      Text('1h', style: TextStyle(color: AppColors.atrOrange.withValues(alpha: 0.6), fontSize: 10, fontWeight: FontWeight.w600)),
                    ],
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PacoteCard extends StatelessWidget {
  final PacoteSessao pacote;
  final bool isDark;
  const _PacoteCard({required this.pacote, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final progresso = pacote.progressoUso;
    final fmt = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: isDark
            ? const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [AppColors.surfaceCardDark, AppColors.surfaceDeepNavy])
            : const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Colors.white, Color(0xFFF8FAFC)]),
        border: Border.all(color: isDark ? AppColors.surfaceHoverDark : AppColors.borderLightHex),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: AppColors.statusInfo.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                child: const Icon(LucideIcons.package, size: 16, color: AppColors.statusInfo),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(pacote.clienteNome, style: TextStyle(color: isDark ? Colors.white : AppColors.surfaceCardDark, fontWeight: FontWeight.w700)),
                    Text('${pacote.totalSessoes} sessões • ${fmt.format(pacote.valorPago)}', style: TextStyle(color: isDark ? AppColors.textSecondaryDark : AppColors.textMutedDark, fontSize: 12)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('${pacote.sessoesRestantes} restantes', style: const TextStyle(color: AppColors.statusInfo, fontWeight: FontWeight.w700, fontSize: 13)),
                  Text('Economia: ${fmt.format(pacote.economiaVsAvulso)}', style: TextStyle(color: AppColors.statusSuccess.withValues(alpha: 0.7), fontSize: 10)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progresso,
              backgroundColor: isDark ? AppColors.surfaceHoverDark : const Color(0xFFF1F5F9),
              valueColor: AlwaysStoppedAnimation<Color>(progresso > 0.8 ? AppColors.statusWarning : AppColors.statusInfo),
              minHeight: 4,
            ),
          ),
          const SizedBox(height: 4),
          Text('${(progresso * 100).toStringAsFixed(0)}% utilizado', style: TextStyle(color: isDark ? Colors.white38 : AppColors.textTertiaryDark, fontSize: 10)),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// 2. AGENDA (com ações rápidas inline #1 e lembretes #2)
// ═══════════════════════════════════════════════════════════════════════════
class _SalaAgenda extends StatelessWidget {
  final DateTime data;
  final bool isDark;
  const _SalaAgenda({required this.data, required this.isDark});

  void _abrirBookingSheet(BuildContext context, DateTime inicio) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AdvancedBookingSheet(inicio: inicio, isDark: isDark),
    );
  }

  void _abrirNotaSheet(BuildContext context, AgendamentoSalaAtr ag) {
    final ctrl = TextEditingController(text: ag.notaSessao?.texto ?? '');
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceCardDark : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('Notas da Sessão', style: TextStyle(color: isDark ? Colors.white : AppColors.surfaceCardDark, fontSize: 18, fontWeight: FontWeight.w700)),
                  const Spacer(),
                  Text(ag.clienteNome, style: const TextStyle(color: AppColors.atrOrange, fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: 6),
              Text(DateFormat("dd/MM/yyyy 'às' HH:mm", 'pt_BR').format(ag.inicio), style: TextStyle(color: isDark ? AppColors.textSecondaryDark : AppColors.textMutedDark, fontSize: 13)),
              const SizedBox(height: 16),
              TextField(
                controller: ctrl,
                autofocus: true,
                maxLines: 4,
                style: TextStyle(color: isDark ? Colors.white : AppColors.surfaceCardDark, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Regista aqui as notas da sessão...',
                  hintStyle: TextStyle(color: isDark ? Colors.white24 : AppColors.textTertiaryDark),
                  filled: true,
                  fillColor: isDark ? AppColors.backgroundDark : const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDark ? AppColors.surfaceElevatedDark : AppColors.borderLightHex)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDark ? AppColors.surfaceElevatedDark : AppColors.borderLightHex)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.atrOrange)),
                ),
              ),
              const SizedBox(height: 20),
              AtrPrimaryButton(
                label: 'Salvar Nota',
                width: double.infinity,
                onPressed: () {
                  SalaAtrState.instance.adicionarNotaSessao(ag.id, ctrl.text);
                  Navigator.pop(ctx);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final agendamentosDoDia = SalaAtrState.instance.agendamentosDoDia(data);

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      itemCount: 13,
      itemBuilder: (context, index) {
        final hora = 8 + index;
        final horarioBloco = DateTime(data.year, data.month, data.day, hora, 0);

        final agendamento = agendamentosDoDia.where((a) {
          final hInicio = a.inicio.hour;
          final hFim = a.fim.minute > 0 ? a.fim.hour : a.fim.hour - 1;
          return hora >= hInicio && hora <= hFim;
        }).firstOrNull;

        final isPassado = horarioBloco.isBefore(DateTime.now()) && agendamento == null;
        if (agendamento != null && agendamento.inicio.hour != hora) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 56,
                child: Text(
                  '${hora.toString().padLeft(2, '0')}:00',
                  style: TextStyle(
                    color: isDark ? Colors.white38 : AppColors.textTertiaryDark,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: agendamento != null
                    ? _BlocoOcupadoPremium(
                        ag: agendamento,
                        isDark: isDark,
                        onMarkPaid: () {
                          SalaAtrState.instance.atualizarStatus(agendamento.id, StatusAgendamento.pago);
                        },
                        onMarkNoShow: () {
                          SalaAtrState.instance.atualizarStatus(agendamento.id, StatusAgendamento.cancelado_noshow);
                        },
                        onNota: () => _abrirNotaSheet(context, agendamento),
                        onWhatsApp: () => _abrirWhatsApp(context, agendamento.whatsappUrlConfirmacao),
                        onToggleLembrete: () => SalaAtrState.instance.toggleLembrete24h(agendamento.id),
                      ).animate().fadeIn()
                    : _BlocoLivrePremium(isDark: isDark, isPassado: isPassado, onTap: isPassado ? null : () => _abrirBookingSheet(context, horarioBloco)),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// BLOCO OCUPADO PREMIUM — Ações rápidas inline (#1)
// ═══════════════════════════════════════════════════════════════════════════
class _BlocoOcupadoPremium extends StatelessWidget {
  final AgendamentoSalaAtr ag;
  final bool isDark;
  final VoidCallback onMarkPaid;
  final VoidCallback onMarkNoShow;
  final VoidCallback onNota;
  final VoidCallback onWhatsApp;
  final VoidCallback onToggleLembrete;

  const _BlocoOcupadoPremium({
    required this.ag,
    required this.isDark,
    required this.onMarkPaid,
    required this.onMarkNoShow,
    required this.onNota,
    required this.onWhatsApp,
    required this.onToggleLembrete,
  });

  @override
  Widget build(BuildContext context) {
    final corBase = _corStatus(ag.status);
    final minutosT = ag.fim.difference(ag.inicio).inMinutes;
    final alturaBase = (minutosT / 60) * 78.0;
    final isFuturo = ag.status == StatusAgendamento.pendente || ag.status == StatusAgendamento.confirmado || ag.status == StatusAgendamento.pago;
    final temPacote = SalaAtrState.instance.pacoteAtivoDoCliente(ag.clienteId) != null;

    return Container(
      // ignore: avoid_print
      height: alturaBase > 78 ? alturaBase : null,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: isDark
            ? LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [corBase.withValues(alpha: 0.1), corBase.withValues(alpha: 0.04)])
            : LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [corBase.withValues(alpha: 0.08), corBase.withValues(alpha: 0.02)]),
        border: Border(left: BorderSide(color: corBase, width: 4)),
        boxShadow: [
          BoxShadow(color: corBase.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Nome + Status + Ações rápidas
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(ag.clienteNome, style: TextStyle(color: isDark ? Colors.white : AppColors.surfaceCardDark, fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: -0.2)),
                        ),
                        if (temPacote) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: AppColors.statusInfo.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(LucideIcons.package, size: 10, color: AppColors.statusInfo),
                                const SizedBox(width: 3),
                                Text('Pacote', style: TextStyle(color: AppColors.statusInfo, fontSize: 9, fontWeight: FontWeight.w700)),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(LucideIcons.clock, size: 11, color: corBase),
                        const SizedBox(width: 4),
                        Text('${DateFormat('HH:mm').format(ag.inicio)} às ${DateFormat('HH:mm').format(ag.fim)}', style: TextStyle(color: corBase, fontSize: 12, fontWeight: FontWeight.w600)),
                        const SizedBox(width: 8),
                        _StatusBadge(status: ag.status),
                      ],
                    ),
                    if (ag.notaSessao != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(LucideIcons.fileText, size: 10, color: AppColors.atrOrange),
                          const SizedBox(width: 4),
                          Flexible(child: Text(ag.notaSessao!.texto, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: AppColors.atrOrange.withValues(alpha: 0.7), fontSize: 10, fontStyle: FontStyle.italic))),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              // Indicadores de lembrete
              if (ag.lembrete24h || ag.lembrete1h)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Row(
                    children: [
                      if (ag.lembrete24h)
                        Icon(LucideIcons.bell, size: 11, color: corBase.withValues(alpha: 0.5)),
                      if (ag.lembrete24h && ag.lembrete1h) const SizedBox(width: 3),
                      if (ag.lembrete1h)
                        Icon(LucideIcons.bellRing, size: 11, color: corBase.withValues(alpha: 0.5)),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          // Barra de ações rápidas inline (#1)
          if (isFuturo) ...[
            Row(
              children: [
                _AcaoRapida(icon: LucideIcons.checkCircle2, label: 'Pago', color: AppColors.statusSuccess, onTap: onMarkPaid),
                const SizedBox(width: 8),
                _AcaoRapida(icon: LucideIcons.xOctagon, label: 'No-Show', color: AppColors.statusError, onTap: onMarkNoShow),
                const SizedBox(width: 8),
                _AcaoRapida(icon: LucideIcons.fileText, label: 'Nota', color: AppColors.atrOrange, onTap: onNota),
                const SizedBox(width: 8),
                _AcaoRapida(icon: LucideIcons.messageCircle, label: 'Zap', color: Colors.green, onTap: onWhatsApp),
                const Spacer(),
                InkWell(
                  onTap: onToggleLembrete,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(
                      color: (ag.lembrete24h || ag.lembrete1h) ? AppColors.statusSuccess.withValues(alpha: 0.1) : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: (ag.lembrete24h || ag.lembrete1h) ? AppColors.statusSuccess.withValues(alpha: 0.2) : (isDark ? AppColors.surfaceElevatedDark : AppColors.borderLightHex)),
                    ),
                    child: Icon(LucideIcons.bellOff, size: 13, color: (ag.lembrete24h || ag.lembrete1h) ? AppColors.statusSuccess : (isDark ? Colors.white24 : AppColors.textTertiaryDark)),
                  ),
                ),
              ],
            ),
          ],
          if (!isFuturo && ag.status == StatusAgendamento.realizado && ag.notaSessao == null) ...[
            InkWell(
              onTap: onNota,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(color: AppColors.atrOrange.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.atrOrange.withValues(alpha: 0.1))),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(LucideIcons.pencil, size: 12, color: AppColors.atrOrange),
                    const SizedBox(width: 6),
                    const Text('Adicionar nota da sessão', style: TextStyle(color: AppColors.atrOrange, fontSize: 11, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AcaoRapida extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _AcaoRapida({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.15)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

class _BlocoLivrePremium extends StatelessWidget {
  final bool isDark;
  final bool isPassado;
  final VoidCallback? onTap;
  const _BlocoLivrePremium({required this.isDark, required this.isPassado, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        height: 65,
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDarkAlt : const Color(0xFFFAFAFA),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isDark ? AppColors.surfaceHoverDark : AppColors.borderLightHex, style: BorderStyle.solid),
        ),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Icon(
              isPassado ? LucideIcons.clock : LucideIcons.plus,
              size: 16,
              color: isPassado ? (isDark ? Colors.white12 : const Color(0xFFD1D5DB)) : AppColors.atrOrange,
            ),
            const SizedBox(width: 8),
            Text(
              isPassado ? 'Horário passado' : 'Toque para agendar',
              style: TextStyle(
                color: isPassado ? (isDark ? Colors.white12 : const Color(0xFFD1D5DB)) : AppColors.atrOrange.withValues(alpha: 0.7),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// BOOKING SHEET (com lembretes #2 e pacotes #5)
// ═══════════════════════════════════════════════════════════════════════════
class _AdvancedBookingSheet extends StatefulWidget {
  final DateTime inicio;
  final bool isDark;
  const _AdvancedBookingSheet({required this.inicio, required this.isDark});

  @override
  State<_AdvancedBookingSheet> createState() => _AdvancedBookingSheetState();
}

class _AdvancedBookingSheetState extends State<_AdvancedBookingSheet> {
  final _nomeCtrl = TextEditingController();
  final _telCtrl = TextEditingController(text: '(11) 9');
  final _valorCtrl = TextEditingController(text: '150.00');

  int _duracao = 1;
  int _vezesRecorrencia = 1;
  int _diasIntervalo = 7;
  TipoPagamento _tipoPagamento = TipoPagamento.particular;
  bool _lembrete24h = true;
  bool _lembrete1h = true;
  String get _clienteId => 'cli_${_nomeCtrl.text.replaceAll(' ', '_').toLowerCase()}';

  @override
  Widget build(BuildContext context) {
    final bg = widget.isDark ? AppColors.surfaceCardDark : Colors.white;
    final txtColor = widget.isDark ? Colors.white : AppColors.surfaceCardDark;
    final pacote = _nomeCtrl.text.isNotEmpty ? SalaAtrState.instance.pacoteAtivoDoCliente(_clienteId) : null;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 30, offset: const Offset(0, -8))],
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: AppColors.atrOrange.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                    child: const Icon(LucideIcons.calendarPlus, color: AppColors.atrOrange, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Novo Agendamento', style: TextStyle(color: txtColor, fontSize: 19, fontWeight: FontWeight.w700, letterSpacing: -0.3)),
                        Text('${DateFormat("dd/MM/yyyy").format(widget.inicio)} às ${DateFormat("HH:mm").format(widget.inicio)}', style: const TextStyle(color: AppColors.atrOrange, fontSize: 14, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Nome paciente
              _CampoPremium(controller: _nomeCtrl, label: 'Nome do Paciente', hint: 'Ex: Maria Silva', icon: LucideIcons.user, txtColor: txtColor, isDark: widget.isDark),
              const SizedBox(height: 14),
              // Telefone
              _CampoPremium(controller: _telCtrl, label: 'WhatsApp', hint: '(11) 99999-0000', icon: LucideIcons.phone, txtColor: txtColor, isDark: widget.isDark, keyboardType: TextInputType.phone),
              const SizedBox(height: 14),
              // Valor
              _CampoPremium(controller: _valorCtrl, label: 'Valor por Hora (R\$)', hint: '150.00', icon: LucideIcons.dollarSign, txtColor: txtColor, isDark: widget.isDark, keyboardType: TextInputType.number),
              const SizedBox(height: 20),

              // Duração
              _SecaoTitulo(label: 'Duração', txtColor: txtColor),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [1, 2, 4].map((h) => ChoiceChip(
                  label: Text('${h}h', style: TextStyle(color: _duracao == h ? Colors.white : txtColor, fontWeight: FontWeight.w600, fontSize: 13)),
                  selectedColor: AppColors.atrOrange,
                  backgroundColor: widget.isDark ? AppColors.surfaceHoverDark : const Color(0xFFF3F4F6),
                  selected: _duracao == h,
                  onSelected: (s) => setState(() => _duracao = h),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  side: BorderSide.none,
                )).toList(),
              ),
              const SizedBox(height: 18),

              // Pagamento
              _SecaoTitulo(label: 'Forma de Pagamento', txtColor: txtColor),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: TipoPagamento.values.map((t) => ChoiceChip(
                  label: Text(t.nome, style: TextStyle(color: _tipoPagamento == t ? Colors.white : txtColor, fontSize: 11, fontWeight: FontWeight.w600)),
                  selectedColor: AppColors.statusSuccess,
                  backgroundColor: widget.isDark ? AppColors.surfaceHoverDark : const Color(0xFFF3F4F6),
                  selected: _tipoPagamento == t,
                  onSelected: (s) => setState(() => _tipoPagamento = t),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  side: BorderSide.none,
                )).toList(),
              ),
              const SizedBox(height: 18),

              // Pacote do cliente
              if (pacote != null) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.statusInfo.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.statusInfo.withValues(alpha: 0.15)),
                  ),
                  child: Row(
                    children: [
                      const Icon(LucideIcons.package, color: AppColors.statusInfo, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Pacote ativo: ${pacote.sessoesRestantes} sessões restantes', style: const TextStyle(color: AppColors.statusInfo, fontWeight: FontWeight.w700, fontSize: 13)),
                            Text('Será deduzido automaticamente ao marcar como Pago', style: TextStyle(color: widget.isDark ? Colors.white38 : AppColors.textTertiaryDark, fontSize: 11)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
              ],

              // Recorrência
              _SecaoTitulo(label: 'Recorrência', txtColor: txtColor),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: Text('Única', style: TextStyle(color: _vezesRecorrencia == 1 ? Colors.white : txtColor, fontWeight: FontWeight.w600, fontSize: 12)),
                    selectedColor: AppColors.atrOrange,
                    backgroundColor: widget.isDark ? AppColors.surfaceHoverDark : const Color(0xFFF3F4F6),
                    selected: _vezesRecorrencia == 1,
                    onSelected: (s) => setState(() { _vezesRecorrencia = 1; }),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    side: BorderSide.none,
                  ),
                  ChoiceChip(
                    label: const Text('4 Sessões', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                    selectedColor: AppColors.atrOrange,
                    backgroundColor: widget.isDark ? AppColors.surfaceHoverDark : const Color(0xFFF3F4F6),
                    selected: _vezesRecorrencia == 4,
                    onSelected: (s) => setState(() { _vezesRecorrencia = 4; }),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    side: BorderSide.none,
                  ),
                ],
              ),
              if (_vezesRecorrencia > 1) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      label: Text('Semanal', style: TextStyle(color: _diasIntervalo == 7 ? Colors.white : txtColor, fontWeight: FontWeight.w600, fontSize: 12)),
                      selectedColor: AppColors.accentBlue,
                      backgroundColor: widget.isDark ? AppColors.surfaceHoverDark : const Color(0xFFF3F4F6),
                      selected: _diasIntervalo == 7,
                      onSelected: (s) => setState(() { _diasIntervalo = 7; }),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      side: BorderSide.none,
                    ),
                    ChoiceChip(
                      label: Text('Quinzenal', style: TextStyle(color: _diasIntervalo == 15 ? Colors.white : txtColor, fontWeight: FontWeight.w600, fontSize: 12)),
                      selectedColor: AppColors.accentBlue,
                      backgroundColor: widget.isDark ? AppColors.surfaceHoverDark : const Color(0xFFF3F4F6),
                      selected: _diasIntervalo == 15,
                      onSelected: (s) => setState(() { _diasIntervalo = 15; }),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      side: BorderSide.none,
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 20),

              // Lembretes (#2)
              _SecaoTitulo(label: 'Lembretes WhatsApp', txtColor: txtColor),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: widget.isDark ? AppColors.surfaceDarkAlt : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: widget.isDark ? AppColors.surfaceHoverDark : AppColors.borderLightHex),
                ),
                child: Column(
                  children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: Text('Lembrete 24h antes', style: TextStyle(color: txtColor, fontSize: 13, fontWeight: FontWeight.w600)),
                      subtitle: Text('O paciente recebe um WhatsApp automático', style: TextStyle(color: widget.isDark ? Colors.white38 : AppColors.textTertiaryDark, fontSize: 11)),
                      value: _lembrete24h,
                      activeThumbColor: AppColors.statusSuccess,
                      onChanged: (v) => setState(() => _lembrete24h = v),
                    ),
                    const Divider(height: 1),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: Text('Lembrete 1h antes', style: TextStyle(color: txtColor, fontSize: 13, fontWeight: FontWeight.w600)),
                      subtitle: Text('Reforço próximo ao horário da sessão', style: TextStyle(color: widget.isDark ? Colors.white38 : AppColors.textTertiaryDark, fontSize: 11)),
                      value: _lembrete1h,
                      activeThumbColor: AppColors.atrOrange,
                      onChanged: (v) => setState(() => _lembrete1h = v),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),
              AtrPrimaryButton(
                label: 'Confirmar Agendamento',
                width: double.infinity,
                onPressed: () {
                  if (_nomeCtrl.text.trim().isEmpty) return;
                  SalaAtrState.instance.adicionarAgendamento(
                    inicio: widget.inicio,
                    duracaoHoras: _duracao,
                    clienteNome: _nomeCtrl.text.trim(),
                    clienteTelefone: _telCtrl.text.trim(),
                    valorPorHora: double.tryParse(_valorCtrl.text) ?? 150.0,
                    tipoPagamento: _tipoPagamento,
                    vezesRecorrencia: _vezesRecorrencia,
                    diasIntervalo: _diasIntervalo,
                    lembrete24h: _lembrete24h,
                    lembrete1h: _lembrete1h,
                  );
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// UTILITÁRIOS DO BOOKING SHEET
// ═══════════════════════════════════════════════════════════════════════════

class _SecaoTitulo extends StatelessWidget {
  final String label;
  final Color txtColor;
  const _SecaoTitulo({required this.label, required this.txtColor});

  @override
  Widget build(BuildContext context) {
    return Text(label, style: TextStyle(color: txtColor, fontWeight: FontWeight.w700, fontSize: 13, letterSpacing: 0.3));
  }
}

class _CampoPremium extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final Color txtColor;
  final bool isDark;
  final TextInputType? keyboardType;

  const _CampoPremium({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    required this.txtColor,
    required this.isDark,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: TextStyle(color: txtColor, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: const TextStyle(color: AppColors.atrOrange, fontSize: 12, fontWeight: FontWeight.w600),
        hintStyle: TextStyle(color: isDark ? Colors.white24 : AppColors.textTertiaryDark, fontSize: 13),
        prefixIcon: Icon(icon, size: 18, color: AppColors.atrOrange.withValues(alpha: 0.6)),
        filled: true,
        fillColor: isDark ? AppColors.surfaceDarkAlt : const Color(0xFFF8FAFC),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDark ? AppColors.surfaceElevatedDark : AppColors.borderLightHex)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDark ? AppColors.surfaceElevatedDark : AppColors.borderLightHex)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.atrOrange, width: 1.5)),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// 3. CRM (com pacotes #5)
// ═══════════════════════════════════════════════════════════════════════════
class _SalaCrm extends StatelessWidget {
  final bool isDark;
  const _SalaCrm({required this.isDark});

  @override
  Widget build(BuildContext context) {
    final clientes = SalaAtrState.instance.gerarCRM();
    final fmt = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

    if (clientes.isEmpty) {
      return BookableAreaEmptyState(message: 'Nenhum cliente registado', icon: LucideIcons.users, isDark: isDark);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: clientes.length,
      itemBuilder: (ctx, i) {
        final c = clientes[i];
        final taxaNoShow = c.qtdeAgendamentos > 0 ? (c.qtdeNoShows / c.qtdeAgendamentos * 100) : 0.0;

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: isDark
                ? const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [AppColors.surfaceCardDark, AppColors.surfaceDarkAlt])
                : const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Colors.white, Color(0xFFFAFAFA)]),
            border: Border.all(color: isDark ? AppColors.surfaceHoverDark : const Color(0xFFF1F5F9)),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03), blurRadius: 8, offset: const Offset(0, 3))],
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [AppColors.atrOrange, Color(0xFFEA580C)]),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(child: Text(c.nome[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18))),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(c.nome, style: TextStyle(color: isDark ? Colors.white : AppColors.surfaceCardDark, fontWeight: FontWeight.w700, fontSize: 15, letterSpacing: -0.2)),
                        const SizedBox(height: 2),
                        Text(c.telefone, style: TextStyle(color: isDark ? AppColors.textSecondaryDark : AppColors.textMutedDark, fontSize: 12)),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('LTV: ${fmt.format(c.totalGasto)}', style: const TextStyle(color: AppColors.statusSuccess, fontWeight: FontWeight.bold, fontSize: 14)),
                      Text('${c.qtdeAgendamentos} sessões', style: TextStyle(color: isDark ? Colors.white38 : AppColors.textTertiaryDark, fontSize: 11)),
                      if (c.qtdeNoShows > 0)
                        Text('${c.qtdeNoShows} faltas (${taxaNoShow.toStringAsFixed(0)}%)', style: const TextStyle(color: AppColors.statusError, fontSize: 11, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ],
              ),
              // Pacotes ativos do cliente
              if (c.pacotesAtivos.isNotEmpty) ...[
                const SizedBox(height: 12),
                ...c.pacotesAtivos.map((p) => Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.statusInfo.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.statusInfo.withValues(alpha: 0.1)),
                  ),
                  child: Row(
                    children: [
                      const Icon(LucideIcons.package, size: 14, color: AppColors.statusInfo),
                      const SizedBox(width: 8),
                      Text('Pacote: ${p.sessoesRestantes}/${p.totalSessoes} restantes', style: const TextStyle(color: AppColors.statusInfo, fontSize: 12, fontWeight: FontWeight.w600)),
                      const Spacer(),
                      Text(fmt.format(p.valorPago), style: const TextStyle(color: AppColors.statusInfo, fontSize: 12, fontWeight: FontWeight.w700)),
                    ],
                  ),
                )),
              ],
              if (c.pacotesAtivos.isEmpty && c.totalGasto > 500) ...[
                const SizedBox(height: 10),
                InkWell(
                  onTap: () => _abrirCriarPacoteParaCliente(context, c.clienteId, c.nome, isDark),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(color: AppColors.atrOrange.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(8)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(LucideIcons.plus, size: 12, color: AppColors.atrOrange),
                        SizedBox(width: 4),
                        Text('Oferecer Pacote', style: TextStyle(color: AppColors.atrOrange, fontSize: 11, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// CRIAÇÃO DE PACOTE (Bottom Sheet)
// ═══════════════════════════════════════════════════════════════════════════

void _abrirCriarPacote(BuildContext context, bool isDark) {
  _abrirCriarPacoteParaCliente(context, '', '', isDark);
}

void _abrirCriarPacoteParaCliente(BuildContext context, String clienteId, String clienteNome, bool isDark) {
  final nomeCtrl = TextEditingController(text: clienteNome);
  final sessoesCtrl = TextEditingController(text: '10');
  final valorCtrl = TextEditingController(text: '1200.00');
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceCardDark : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: AppColors.statusInfo.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                  child: const Icon(LucideIcons.package, color: AppColors.statusInfo, size: 20),
                ),
                const SizedBox(width: 12),
                Text('Criar Pacote de Sessões', style: TextStyle(color: isDark ? Colors.white : AppColors.surfaceCardDark, fontSize: 19, fontWeight: FontWeight.w700)),
              ],
            ),

            const SizedBox(height: 24),
            TextField(
              controller: nomeCtrl,
              style: TextStyle(color: isDark ? Colors.white : AppColors.surfaceCardDark),
              decoration: InputDecoration(
                labelText: 'Paciente',
                prefixIcon: const Icon(LucideIcons.user, size: 18),
                filled: true,
                fillColor: isDark ? AppColors.surfaceDarkAlt : const Color(0xFFF8FAFC),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: sessoesCtrl,
                    keyboardType: TextInputType.number,
                    style: TextStyle(color: isDark ? Colors.white : AppColors.surfaceCardDark),
                    decoration: InputDecoration(
                      labelText: 'Nº de Sessões',
                      filled: true,
                      fillColor: isDark ? AppColors.surfaceDarkAlt : const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: valorCtrl,
                    keyboardType: TextInputType.number,
                    style: TextStyle(color: isDark ? Colors.white : AppColors.surfaceCardDark),
                    decoration: InputDecoration(
                      labelText: 'Valor do Pacote (R\$)',
                      filled: true,
                      fillColor: isDark ? AppColors.surfaceDarkAlt : const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('Valor avulso: R\$ 150,00/sessão • Desconto aplicado automaticamente',
                style: TextStyle(color: isDark ? Colors.white38 : AppColors.textTertiaryDark, fontSize: 11)),
            const SizedBox(height: 24),
            AtrPrimaryButton(
              label: 'Criar Pacote',
              width: double.infinity,
              onPressed: () {
                if (nomeCtrl.text.trim().isEmpty) return;
                final total = int.tryParse(sessoesCtrl.text) ?? 10;
                final valor = double.tryParse(valorCtrl.text) ?? 1200;
                SalaAtrState.instance.criarPacote(
                  clienteId: 'cli_${nomeCtrl.text.replaceAll(' ', '_').toLowerCase()}',
                  clienteNome: nomeCtrl.text.trim(),
                  totalSessoes: total,
                  valorPago: valor,
                  valorAvulso: 150.0,
                );
                Navigator.pop(ctx);
              },
            ),
          ],
        ),
      ),
    ),
  );
}

// ═══════════════════════════════════════════════════════════════════════════
// 4. FINANCEIRO (melhorado)
// ═══════════════════════════════════════════════════════════════════════════
class _SalaFinanceiro extends StatelessWidget {
  final DateTime data;
  final bool isDark;
  const _SalaFinanceiro({required this.data, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final state = SalaAtrState.instance;
    final fmt = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

    final receita = state.lucroLiquidoMes(data.month, data.year) + state.despesasMes(data.month, data.year);
    final despesas = state.despesasMes(data.month, data.year);
    final listDespesas = state.despesas.where((d) => d.data.month == data.month && d.data.year == data.year).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: _KpiPremiumCard(label: 'Receita Operacional', value: fmt.format(receita), icon: LucideIcons.arrowUpCircle, iconColor: AppColors.statusSuccess, isDark: isDark)),
              const SizedBox(width: 14),
              Expanded(child: _KpiPremiumCard(label: 'Despesas Fixas', value: fmt.format(despesas), icon: LucideIcons.arrowDownCircle, iconColor: AppColors.statusError, isDark: isDark)),
              const SizedBox(width: 14),
              Expanded(child: _KpiPremiumCard(
                label: 'Resultado',
                value: fmt.format(receita - despesas),
                icon: LucideIcons.scale,
                iconColor: (receita - despesas) >= 0 ? AppColors.statusSuccess : AppColors.statusError,
                isDark: isDark,
              )),
            ],
          ),
          const SizedBox(height: 24),
          Text('Extrato de Despesas', style: TextStyle(color: isDark ? Colors.white : AppColors.surfaceCardDark, fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          ...listDespesas.map((d) => Container(
            margin: const EdgeInsets.only(bottom: 6),
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: AppColors.statusError.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
                child: const Icon(LucideIcons.receipt, color: AppColors.statusError, size: 18),
              ),
              title: Text(d.descricao, style: TextStyle(color: isDark ? Colors.white : AppColors.surfaceCardDark, fontWeight: FontWeight.w600)),
              subtitle: Text(DateFormat('dd/MM/yyyy').format(d.data), style: TextStyle(color: isDark ? AppColors.textSecondaryDark : AppColors.textMutedDark)),
              trailing: Text(fmt.format(d.valor), style: const TextStyle(color: AppColors.statusError, fontWeight: FontWeight.bold, fontSize: 15)),
            ),
          )),
          if (listDespesas.isEmpty)
            BookableAreaEmptyState(message: 'Nenhuma despesa neste mês', icon: LucideIcons.receipt, isDark: isDark),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// 5. RECEBIMENTOS FUTUROS
// ═══════════════════════════════════════════════════════════════════════════
class _SalaRecebimentosFuturos extends StatelessWidget {
  final bool isDark;
  const _SalaRecebimentosFuturos({required this.isDark});

  @override
  Widget build(BuildContext context) {
    final recebimentos = SalaAtrState.instance.gerarRecebimentosFuturos();
    final fmt = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

    if (recebimentos.isEmpty) {
      return BookableAreaEmptyState(message: 'Nenhum recebimento futuro projetado', icon: LucideIcons.banknote, isDark: isDark);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: recebimentos.length,
      itemBuilder: (ctx, i) {
        final r = recebimentos[i];
        return Padding(
          padding: const EdgeInsets.only(bottom: 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(r.mesFormatado.toUpperCase(), style: const TextStyle(color: AppColors.atrOrange, fontWeight: FontWeight.w800, fontSize: 13)),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: isDark
                      ? const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [AppColors.surfaceCardDark, AppColors.surfaceDarkAlt])
                      : const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Colors.white, Color(0xFFFAFAFA)]),
                  border: Border.all(color: isDark ? AppColors.surfaceHoverDark : const Color(0xFFF1F5F9)),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.statusSuccess.withValues(alpha: 0.06),
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Projeção Total', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                          Text(fmt.format(r.valorTotal), style: const TextStyle(color: AppColors.statusSuccess, fontWeight: FontWeight.w800, fontSize: 16)),
                        ],
                      ),
                    ),
                    ...r.itens.map((ag) => ListTile(
                      title: Text(ag.clienteNome, style: TextStyle(color: isDark ? Colors.white : AppColors.surfaceCardDark, fontSize: 14, fontWeight: FontWeight.w600)),
                      subtitle: Text('${ag.tipoPagamento.nome} • Atendido em ${DateFormat('dd/MM/yy').format(ag.inicio)}',
                          style: TextStyle(color: isDark ? AppColors.textSecondaryDark : AppColors.textMutedDark, fontSize: 12)),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(fmt.format(ag.valorTotal), style: TextStyle(color: isDark ? Colors.white : AppColors.surfaceCardDark, fontWeight: FontWeight.bold)),
                          Text('Recebe: ${DateFormat('dd/MM/yy').format(ag.dataRecebimento)}',
                              style: const TextStyle(color: AppColors.statusSuccess, fontSize: 11, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    )),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// WIDGETS COMPARTILHADOS
// ═══════════════════════════════════════════════════════════════════════════

Color _corStatus(StatusAgendamento s) {
  switch (s) {
    case StatusAgendamento.pago:
    case StatusAgendamento.realizado:
      return AppColors.statusSuccess;
    case StatusAgendamento.confirmado:
      return AppColors.statusInfo;
    case StatusAgendamento.pendente:
      return AppColors.statusWarning;
    case StatusAgendamento.cancelado_noshow:
      return AppColors.statusError;
  }
}

Future<void> _abrirWhatsApp(BuildContext context, String url) async {
  try {
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível abrir o WhatsApp'), duration: Duration(seconds: 2)),
      );
    }
  }
}

class _StatusBadge extends StatelessWidget {
  final StatusAgendamento status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color cor;
    String txt;
    switch (status) {
      case StatusAgendamento.pendente: cor = AppColors.statusWarning; txt = 'Pendente'; break;
      case StatusAgendamento.confirmado: cor = AppColors.statusInfo; txt = 'Confirmado'; break;
      case StatusAgendamento.pago: cor = AppColors.statusSuccess; txt = 'Pago'; break;
      case StatusAgendamento.realizado: cor = AppColors.statusInfo; txt = 'Realizado'; break;
      case StatusAgendamento.cancelado_noshow: cor = AppColors.statusError; txt = 'No-Show'; break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: cor.withValues(alpha: 0.2)),
      ),
      child: Text(txt, style: TextStyle(color: cor, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.3)),
    );
  }
}

