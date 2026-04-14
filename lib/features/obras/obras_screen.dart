import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/data/obras_data.dart';

// ═══════════════════════════════════════════════════════════════════════
// OBRAS SCREEN — Dashboard de Sinalização Viária e Acessibilidade
// ═══════════════════════════════════════════════════════════════════════

class ObrasScreen extends StatefulWidget {
  const ObrasScreen({super.key});

  @override
  State<ObrasScreen> createState() => _ObrasScreenState();
}

class _ObrasScreenState extends State<ObrasScreen> {
  // ── Filtros ────────────────────────────────────────────────────────
  String? _cidade;
  String? _equipeFiltro;
  String? _servicoFiltro;
  DateTime? _drillDia;
  bool _rankPorMedia = false;
  int? _mesFiltro;

  // ── Raio-X: justificativas (dia → texto) ────────────────────────
  final Map<String, String> _justificativas = {};
  final Map<String, TextEditingController> _controllers = {};

  // ── Formatadores ──────────────────────────────────────────────────
  final _fmtDec = NumberFormat('#,##0.00', 'pt_BR');
  final _fmtInt = NumberFormat('#,##0', 'pt_BR');
  final _fmtDate = DateFormat('dd/MM/yy');
  final _fmtDateLong = DateFormat('EEEE, dd/MM/yyyy', 'pt_BR');

  static const _coresCidade = {
    'Dourados': Color(0xFF34D399),
    'Paulínia': Color(0xFF60A5FA),
    'Jarinu': Color(0xFFA78BFA),
    'Indaiatuba': Color(0xFFFB923C),
    'Salto': Color(0xFF2DD4BF),
  };

  // ── Limpar tudo ───────────────────────────────────────────────────
  void _limparFiltros() => setState(() {
        _cidade = null;
        _equipeFiltro = null;
        _servicoFiltro = null;
        _drillDia = null;
        _mesFiltro = null;
      });

  // ── Getters fáceis ─────────────────────────────────────────────────
  ObrasResumo get _resumo =>
      obrasResumo(cidade: _cidade, equipe: _equipeFiltro, mes: _mesFiltro);

  List<MapEntry<DateTime, double>> get _dadosDiarios => obrasDiaPorServico(
        cidade: _cidade,
        equipe: _equipeFiltro,
        servico: _servicoFiltro,
        mes: _mesFiltro,
      );

  List<EquipeRanking> get _ranking => obrasRanking(
        cidade: _cidade,
        servico: _servicoFiltro,
        porMedia: _rankPorMedia,
        mes: _mesFiltro,
      );

  List<LocalRanking> get _locaisRanking => obrasLocaisRanking(
        cidade: _cidade,
        equipe: _equipeFiltro,
        mes: _mesFiltro,
      );

  // ── KPI config ────────────────────────────────────────────────────
  List<Map<String, dynamic>> _kpis(ObrasResumo r) {
    return [
      if (r.pinturaFria > 0)
        {
          'label': 'Pintura Fria',
          'valor': _fmtDec.format(r.pinturaFria),
          'unit': 'm²',
          'cor': const Color(0xFF60A5FA),
          'icon': LucideIcons.paintbrush,
          'servico': 'Pintura Fria',
        },
      if (r.pinturaQuente > 0)
        {
          'label': 'Pintura Quente',
          'valor': _fmtDec.format(r.pinturaQuente),
          'unit': 'm²',
          'cor': const Color(0xFFF87171),
          'icon': LucideIcons.flame,
          'servico': 'Pintura Quente',
          'sub':
              'Hotspray: ${_fmtDec.format(r.hotspray)} | Extrudado: ${_fmtDec.format(r.extrudado)}',
        },
      if (r.fresa > 0)
        {
          'label': 'Fresa',
          'valor': _fmtDec.format(r.fresa),
          'unit': 'm²',
          'cor': const Color(0xFF2DD4BF),
          'icon': LucideIcons.shovel,
          'servico': 'Fresa',
        },
      if (r.pinturaGuia > 0)
        {
          'label': 'Pintura de Guia',
          'valor': _fmtDec.format(r.pinturaGuia),
          'unit': 'm',
          'cor': const Color(0xFFF59E0B),
          'icon': LucideIcons.minus,
          'servico': 'Pintura de Guia',
        },
      if (r.sinalVertArea > 0)
        {
          'label': 'Sinal. Vertical (Área)',
          'valor': _fmtDec.format(r.sinalVertArea),
          'unit': 'm²',
          'cor': const Color(0xFFA78BFA),
          'icon': LucideIcons.triangle,
          'servico': 'Sinalização Vertical (Área)',
        },
      if (r.sinalVertQtd > 0)
        {
          'label': 'Sinal. Vertical (Qtd)',
          'valor': _fmtInt.format(r.sinalVertQtd),
          'unit': 'uni',
          'cor': const Color(0xFF8B5CF6),
          'icon': LucideIcons.arrowUpCircle,
          'servico': 'Sinalização Vertical (Qtd)',
        },
      if (r.acessVolume > 0)
        {
          'label': 'Acessibilidade (Vol)',
          'valor': _fmtDec.format(r.acessVolume),
          'unit': 'm³',
          'cor': const Color(0xFF34D399),
          'icon': LucideIcons.accessibility,
          'servico': 'Acessibilidade (Volume)',
        },
      if (r.acessQtd > 0)
        {
          'label': 'Acessibilidade (Qtd)',
          'valor': _fmtInt.format(r.acessQtd),
          'unit': 'uni',
          'cor': const Color(0xFF6EE7B7),
          'icon': LucideIcons.accessibility,
          'servico': 'Acessibilidade (Qtd)',
        },
      if (r.semaforica > 0)
        {
          'label': 'Semafórica',
          'valor': _fmtInt.format(r.semaforica),
          'unit': 'uni',
          'cor': const Color(0xFFFBBF24),
          'icon': LucideIcons.construction,
          'servico': 'Semafórica',
        },
      if (r.dispAuxiliares > 0)
        {
          'label': 'Dispositivos Aux.',
          'valor': _fmtInt.format(r.dispAuxiliares),
          'unit': 'uni',
          'cor': const Color(0xFFFB923C),
          'icon': LucideIcons.alertTriangle,
          'servico': 'Dispositivos Auxiliares',
        },
    ];
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  // ════════════════════════════════════════════════════════════════
  // BUILD
  // ════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final resumo = _resumo;
    final alertas =
        obrasAlertas(cidade: _cidade, equipe: _equipeFiltro, mes: _mesFiltro);
    final kpis = _kpis(resumo);

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
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(context, isDark),
                const SizedBox(height: 24),

                // ── Alertas ──
                if (alertas.isNotEmpty) ...[
                  _buildAlertas(alertas, isDark),
                  const SizedBox(height: 24),
                ],

                // ── Banner de filtro ativo ──
                if (_equipeFiltro != null) _buildEquipeBanner(isDark),
                if (_equipeFiltro != null) const SizedBox(height: 16),

                // ── KPIs ──
                _buildKpis(kpis, isDark),
                const SizedBox(height: 32),

                // ── Filtro por cidade ──
                _buildCidadeFiltro(isDark),
                const SizedBox(height: 32),

                // ── Detalhe Pintura Quente (se selecionado) ──
                if (_servicoFiltro == 'Pintura Quente') ...[
                  _buildPinturaQuenteDetalhe(resumo, isDark),
                  const SizedBox(height: 32),
                ],

                // ── Painel de detalhamento por serviço ──
                if (_servicoFiltro != null &&
                    _servicoFiltro != 'Pintura Fria' &&
                    _servicoFiltro != 'Pintura Quente' &&
                    _servicoFiltro != 'Fresa' &&
                    _servicoFiltro != 'Pintura de Guia') ...[
                  _buildDetalhePorServico(isDark),
                  const SizedBox(height: 32),
                ],

                // ── Gráfico principal ──
                _buildGrafico(isDark),
                const SizedBox(height: 32),

                // ── Drill-down tabela ──
                if (_drillDia != null) ...[
                  _buildDrillDown(isDark),
                  const SizedBox(height: 32),
                ],

                // ── Raio-X (diagnóstico) ──
                _buildRaioX(isDark),
                const SizedBox(height: 32),

                // ── Rankings lado a lado ──
                _buildRankings(context, isDark),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  // HEADER
  // ════════════════════════════════════════════════════════════════
  Widget _buildHeader(BuildContext context, bool isDark) {
    return Row(
      children: [
        IconButton(
          icon: Icon(
            LucideIcons.arrowLeft,
            color: isDark ? Colors.white70 : Colors.black54,
          ),
          onPressed: () => context.go('/selector'),
          tooltip: 'Voltar',
        ),
        const SizedBox(width: 8),
        const Icon(LucideIcons.hardHat, color: AppColors.atrOrange, size: 26),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Gestão de Obras',
                style: TextStyle(
                  color: isDark ? Colors.white : AppColors.textPrimaryLight,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                _mesFiltro != null
                    ? '${[
                        '',
                        'Jan',
                        'Fev',
                        'Mar',
                        'Abr',
                      ][_mesFiltro!]} 2026${_equipeFiltro != null ? ' · $_equipeFiltro' : ''}${_cidade != null ? ' · $_cidade' : ''}'
                    : _equipeFiltro != null
                        ? 'Visão: $_equipeFiltro'
                        : _cidade != null
                            ? 'Filtro: $_cidade'
                            : 'Jan — Abr 2026 · Consolidado',
                style: TextStyle(
                  color: isDark ? Colors.white54 : AppColors.textSecondaryLight,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        if (_cidade != null ||
            _equipeFiltro != null ||
            _servicoFiltro != null ||
            _mesFiltro != null)
          TextButton.icon(
            onPressed: _limparFiltros,
            icon: const Icon(LucideIcons.x, size: 14),
            label: const Text('Limpar Filtro'),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.statusError,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          ),
      ],
    );
  }

  // ════════════════════════════════════════════════════════════════
  // ALERTAS
  // ════════════════════════════════════════════════════════════════
  Widget _buildAlertas(List<ObrasAnomalia> alertas, bool isDark) {
    final cores = {
      'success': AppColors.statusSuccess,
      'warning': AppColors.statusWarning,
      'info': AppColors.statusInfo,
    };
    final icones = {
      'success': LucideIcons.trophy,
      'warning': LucideIcons.alertTriangle,
      'info': LucideIcons.mapPin,
    };

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: alertas.map((a) {
        final cor = cores[a.tipo]!;
        final ico = icones[a.tipo]!;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: cor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: cor.withValues(alpha: 0.25)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(ico, size: 16, color: cor),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    a.mensagem,
                    style: TextStyle(
                      color: cor,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (a.detalhe != null)
                    Text(
                      a.detalhe!,
                      style: TextStyle(
                        color: isDark
                            ? Colors.white54
                            : AppColors.textSecondaryLight,
                        fontSize: 11,
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    ).animate().fadeIn(duration: 350.ms);
  }

  // ════════════════════════════════════════════════════════════════
  // BANNER VISÃO DE EQUIPE
  // ════════════════════════════════════════════════════════════════
  Widget _buildEquipeBanner(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.atrOrange.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.atrOrange.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(LucideIcons.users, size: 18, color: AppColors.atrOrange),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Visão de Equipe — $_equipeFiltro',
              style: const TextStyle(
                color: AppColors.atrOrange,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
          TextButton(
            onPressed: () => setState(() {
              _equipeFiltro = null;
              _drillDia = null;
            }),
            child: const Text(
              'Sair da Visão',
              style: TextStyle(color: AppColors.atrOrange, fontSize: 12),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms);
  }

  // ════════════════════════════════════════════════════════════════
  // KPIs
  // ════════════════════════════════════════════════════════════════
  Widget _buildKpis(List<Map<String, dynamic>> kpis, bool isDark) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final cols = w > 1100 ? 5 : (w > 750 ? 3 : 2);
        const spacing = 14.0;
        final cardW = (w - spacing * (cols - 1)) / cols;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: kpis.map((k) {
            final isSelected = _servicoFiltro == k['servico'];
            final cor = k['cor'] as Color;
            final sub = k['sub'] as String?;

            return MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () => setState(() {
                  _servicoFiltro = isSelected ? null : k['servico'] as String;
                  _drillDia = null;
                }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: cardW,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? cor.withValues(alpha: 0.12)
                        : (isDark
                            ? AppColors.surfaceDark
                            : AppColors.surfaceLight),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected
                          ? cor
                          : (isDark
                              ? AppColors.borderDark
                              : AppColors.borderLight),
                      width: isSelected ? 2 : 1,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: cor.withValues(alpha: 0.18),
                              blurRadius: 14,
                            ),
                          ]
                        : [],
                  ),
                  clipBehavior: Clip.hardEdge,
                  child: IntrinsicHeight(
                    child: Row(
                      children: [
                        Container(width: 4, color: cor),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 14,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        (k['label'] as String).toUpperCase(),
                                        style: TextStyle(
                                          color: isSelected
                                              ? cor
                                              : (isDark
                                                  ? Colors.white54
                                                  : AppColors
                                                      .textSecondaryLight),
                                          fontSize: 9,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 0.5,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Icon(
                                      k['icon'] as IconData,
                                      size: 16,
                                      color: isSelected
                                          ? cor
                                          : cor.withValues(alpha: 0.5),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.baseline,
                                  textBaseline: TextBaseline.alphabetic,
                                  children: [
                                    Flexible(
                                      child: Text(
                                        k['valor'] as String,
                                        style: TextStyle(
                                          color: isDark
                                              ? Colors.white
                                              : AppColors.textPrimaryLight,
                                          fontSize: 20,
                                          fontWeight: FontWeight.w900,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      k['unit'] as String,
                                      style: TextStyle(
                                        color: isDark
                                            ? Colors.white54
                                            : AppColors.textSecondaryLight,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                                if (sub != null && isSelected) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    sub,
                                    style: TextStyle(
                                      color: isDark
                                          ? Colors.white54
                                          : AppColors.textSecondaryLight,
                                      fontSize: 9,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ).animate().fadeIn(duration: 350.ms).moveY(
                      begin: 10,
                      end: 0,
                      duration: 300.ms,
                      curve: Curves.easeOut,
                    ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  // ════════════════════════════════════════════════════════════════
  // FILTRO POR CIDADE
  // ════════════════════════════════════════════════════════════════
  Widget _buildCidadeFiltro(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              LucideIcons.mapPin,
              size: 15,
              color: isDark ? Colors.white54 : AppColors.textSecondaryLight,
            ),
            const SizedBox(width: 8),
            Text(
              'Filtrar por Cidade',
              style: TextStyle(
                color: isDark ? Colors.white54 : AppColors.textSecondaryLight,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: obrasCidades.map((cidade) {
            final selecionada = _cidade == cidade;
            final cor = _coresCidade[cidade]!;
            final resumoCidade = obrasResumo(cidade: cidade, mes: _mesFiltro);
            return MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () => setState(() {
                  _cidade = selecionada ? null : cidade;
                  _drillDia = null;
                }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: selecionada
                        ? cor.withValues(alpha: 0.15)
                        : (isDark
                            ? AppColors.surfaceDark
                            : AppColors.surfaceLight),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: selecionada
                          ? cor
                          : (isDark
                              ? AppColors.borderDark
                              : AppColors.borderLight),
                      width: selecionada ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        cidade.toUpperCase(),
                        style: TextStyle(
                          color: selecionada
                              ? cor
                              : (isDark
                                  ? Colors.white
                                  : AppColors.textPrimaryLight),
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${_fmtDec.format(resumoCidade.pinturaFria + resumoCidade.pinturaQuente)} m² pintura',
                        style: TextStyle(
                          color: isDark
                              ? Colors.white54
                              : AppColors.textSecondaryLight,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    ).animate().fadeIn(delay: 100.ms, duration: 350.ms);
  }

  // ════════════════════════════════════════════════════════════════
  // DETALHE PINTURA QUENTE
  // ════════════════════════════════════════════════════════════════
  Widget _buildPinturaQuenteDetalhe(ObrasResumo r, bool isDark) {
    final total = r.pinturaQuente;
    final pHot = total > 0 ? r.hotspray / total : 0.5;
    final pExt = 1 - pHot;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFF87171).withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.flame, size: 16, color: Color(0xFFF87171)),
              const SizedBox(width: 8),
              Text(
                'Detalhamento Pintura Quente',
                style: TextStyle(
                  color: isDark ? Colors.white : AppColors.textPrimaryLight,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (ctx, constraints) {
              final w = constraints.maxWidth;
              return Row(
                children: [
                  _subCard(
                    'Hotspray',
                    r.hotspray,
                    'm²',
                    const Color(0xFFFC8181),
                    isDark,
                    w / 2 - 8,
                  ),
                  const SizedBox(width: 16),
                  _subCard(
                    'Extrudado',
                    r.extrudado,
                    'm²',
                    const Color(0xFFF97316),
                    isDark,
                    w / 2 - 8,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 14),
          // barra proporcional
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Row(
              children: [
                Flexible(
                  flex: (pHot * 100).round(),
                  child: Container(
                    height: 10,
                    color: const Color(0xFFFC8181),
                  ),
                ),
                Flexible(
                  flex: (pExt * 100).round(),
                  child: Container(
                    height: 10,
                    color: const Color(0xFFF97316),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Hotspray ${(pHot * 100).toStringAsFixed(0)}%',
                style: const TextStyle(
                  color: Color(0xFFFC8181),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                'Extrudado ${(pExt * 100).toStringAsFixed(0)}%',
                style: const TextStyle(
                  color: Color(0xFFF97316),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms);
  }

  Widget _subCard(
    String label,
    double val,
    String unit,
    Color cor,
    bool isDark,
    double width,
  ) {
    return SizedBox(
      width: width,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cor.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: cor,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Flexible(
                  child: Text(
                    _fmtDec.format(val),
                    style: TextStyle(
                      color: isDark ? Colors.white : AppColors.textPrimaryLight,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  unit,
                  style: TextStyle(
                    color:
                        isDark ? Colors.white54 : AppColors.textSecondaryLight,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  // PAINEL DETALHAMENTO POR SERVIÇO
  // ════════════════════════════════════════════════════════════════
  Widget _buildDetalhePorServico(bool isDark) {
    switch (_servicoFiltro) {
      case 'Sinalização Vertical (Área)':
      case 'Sinalização Vertical (Qtd)':
        return _buildDetalheVertical(isDark);
      case 'Acessibilidade (Volume)':
      case 'Acessibilidade (Qtd)':
        return _buildDetalheAcessibilidade(isDark);
      case 'Semafórica':
        return _buildDetalheSemaforica(isDark);
      case 'Dispositivos Auxiliares':
        return _buildDetalheDispositivos(isDark);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildDetalheVertical(bool isDark) {
    final placas = obrasVerticalDetalhe(cidade: _cidade, equipe: _equipeFiltro);
    final ferragens = obrasFerragens(cidade: _cidade, equipe: _equipeFiltro);
    final totalUnid = placas.values.fold(0.0, (s, v) => s + (v['qtd'] ?? 0));
    final totalArea = placas.values.fold(0.0, (s, v) => s + (v['area'] ?? 0));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(
          'Sinalização Vertical — Placas Instaladas',
          LucideIcons.triangle,
          const Color(0xFFA78BFA),
          isDark,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _miniKpi(
              'Total Unidades',
              '${totalUnid.toStringAsFixed(0)} uni',
              const Color(0xFFA78BFA),
              isDark,
            ),
            const SizedBox(width: 12),
            _miniKpi(
              'Área Total',
              '${_fmtDec.format(totalArea)} m²',
              const Color(0xFF8B5CF6),
              isDark,
            ),
          ],
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (ctx, constraints) {
            final w = constraints.maxWidth;
            final cols = w > 800 ? 3 : 2;
            const spacing = 12.0;
            final cardW = (w - spacing * (cols - 1)) / cols;
            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: placas.entries.map((e) {
                return SizedBox(
                  width: cardW,
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.surfaceDark
                          : AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark
                            ? AppColors.borderDark
                            : AppColors.borderLight,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          e.key,
                          style: TextStyle(
                            color: isDark
                                ? Colors.white
                                : AppColors.textPrimaryLight,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 2,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Text(
                              '${(e.value['qtd'] ?? 0).toStringAsFixed(0)} uni',
                              style: const TextStyle(
                                color: Color(0xFFA78BFA),
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${_fmtDec.format(e.value['area'] ?? 0)} m²',
                              style: TextStyle(
                                color: isDark
                                    ? Colors.white54
                                    : AppColors.textSecondaryLight,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
        const SizedBox(height: 20),
        _sectionTitle(
          'Ferragens e Materiais Auxiliares',
          LucideIcons.wrench,
          const Color(0xFF94A3B8),
          isDark,
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (ctx, constraints) {
            final w = constraints.maxWidth;
            final cols = w > 600 ? 3 : 2;
            const spacing = 12.0;
            final cardW = (w - spacing * (cols - 1)) / cols;
            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: ferragens.entries.map((e) {
                return SizedBox(
                  width: cardW,
                  child: _itemCard(
                    e.key,
                    '${e.value.toStringAsFixed(0)} uni',
                    const Color(0xFF94A3B8),
                    isDark,
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    ).animate().fadeIn(duration: 300.ms);
  }

  Widget _buildDetalheAcessibilidade(bool isDark) {
    final itens = obrasAcessDetalhe(cidade: _cidade, equipe: _equipeFiltro);
    final totalVol = itens.values.fold(0.0, (s, v) => s + (v['volume'] ?? 0));
    final totalQtd = itens.values.fold(0.0, (s, v) => s + (v['qtd'] ?? 0));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(
          'Acessibilidade — Itens Executados',
          LucideIcons.accessibility,
          const Color(0xFF34D399),
          isDark,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _miniKpi(
              'Volume Total',
              '${_fmtDec.format(totalVol)} m³',
              const Color(0xFF34D399),
              isDark,
            ),
            const SizedBox(width: 12),
            _miniKpi(
              'Qtd Total',
              '${totalQtd.toStringAsFixed(0)} uni',
              const Color(0xFF6EE7B7),
              isDark,
            ),
          ],
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (ctx, constraints) {
            final w = constraints.maxWidth;
            final cols = w > 700 ? 3 : 2;
            const spacing = 12.0;
            final cardW = (w - spacing * (cols - 1)) / cols;
            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: itens.entries.map((e) {
                return SizedBox(
                  width: cardW,
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.surfaceDark
                          : AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark
                            ? AppColors.borderDark
                            : AppColors.borderLight,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          e.key,
                          style: TextStyle(
                            color: isDark
                                ? Colors.white
                                : AppColors.textPrimaryLight,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${(e.value['qtd'] ?? 0).toStringAsFixed(0)} uni · ${_fmtDec.format(e.value['volume'] ?? 0)} m³',
                          style: const TextStyle(
                            color: Color(0xFF34D399),
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    ).animate().fadeIn(duration: 300.ms);
  }

  Widget _buildDetalheSemaforica(bool isDark) {
    final itens =
        obrasSemaforicaDetalhe(cidade: _cidade, equipe: _equipeFiltro);
    final total = itens.values.fold(0.0, (a, b) => a + b);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(
          'Semafórica — Itens Instalados',
          LucideIcons.construction,
          const Color(0xFFFBBF24),
          isDark,
        ),
        const SizedBox(height: 8),
        _miniKpi(
          'Total Instalado',
          '${total.toStringAsFixed(0)} uni',
          const Color(0xFFFBBF24),
          isDark,
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (ctx, constraints) {
            final w = constraints.maxWidth;
            final cols = w > 700 ? 3 : 2;
            const spacing = 12.0;
            final cardW = (w - spacing * (cols - 1)) / cols;
            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: itens.entries
                  .map(
                    (e) => SizedBox(
                      width: cardW,
                      child: _itemCard(
                        e.key,
                        '${e.value.toStringAsFixed(0)} uni',
                        const Color(0xFFFBBF24),
                        isDark,
                      ),
                    ),
                  )
                  .toList(),
            );
          },
        ),
      ],
    ).animate().fadeIn(duration: 300.ms);
  }

  Widget _buildDetalheDispositivos(bool isDark) {
    final itens =
        obrasDispositivosDetalhe(cidade: _cidade, equipe: _equipeFiltro);
    final total = itens.values.fold(0.0, (a, b) => a + b);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(
          'Dispositivos Auxiliares',
          LucideIcons.alertTriangle,
          const Color(0xFFFB923C),
          isDark,
        ),
        const SizedBox(height: 8),
        _miniKpi(
          'Total Dispositivos',
          '${total.toStringAsFixed(0)} uni',
          const Color(0xFFFB923C),
          isDark,
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (ctx, constraints) {
            final w = constraints.maxWidth;
            final cols = w > 700 ? 3 : 2;
            const spacing = 12.0;
            final cardW = (w - spacing * (cols - 1)) / cols;
            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: itens.entries
                  .map(
                    (e) => SizedBox(
                      width: cardW,
                      child: _itemCard(
                        e.key,
                        '${e.value.toStringAsFixed(0)} uni',
                        const Color(0xFFFB923C),
                        isDark,
                      ),
                    ),
                  )
                  .toList(),
            );
          },
        ),
      ],
    ).animate().fadeIn(duration: 300.ms);
  }

  Widget _sectionTitle(String titulo, IconData icon, Color cor, bool isDark) {
    return Row(
      children: [
        Icon(icon, size: 16, color: cor),
        const SizedBox(width: 8),
        Text(
          titulo,
          style: TextStyle(
            color: isDark ? Colors.white : AppColors.textPrimaryLight,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _miniKpi(String label, String valor, Color cor, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cor.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: isDark ? Colors.white54 : AppColors.textSecondaryLight,
              fontSize: 11,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            valor,
            style: TextStyle(
              color: cor,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _itemCard(String nome, String valor, Color cor, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            nome,
            style: TextStyle(
              color: isDark ? Colors.white : AppColors.textPrimaryLight,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
          ),
          const SizedBox(height: 6),
          Text(
            valor,
            style: TextStyle(
              color: cor,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  // GRÁFICO PRINCIPAL
  // ════════════════════════════════════════════════════════════════
  String _nomeMes(int mes) {
    const nomes = [
      '',
      'Jan',
      'Fev',
      'Mar',
      'Abr',
      'Mai',
      'Jun',
      'Jul',
      'Ago',
      'Set',
      'Out',
      'Nov',
      'Dez',
    ];
    return nomes[mes];
  }

  Widget _buildGrafico(bool isDark) {
    final dadosDiarios = _dadosDiarios;
    final titulo = _servicoFiltro ?? 'Produção Total';
    final unidade = _getUnidade(_servicoFiltro);
    final total = dadosDiarios.fold(0.0, (s, e) => s + e.value);

    // Quando sem filtro de mês → agrega por mês (4 barras); com filtro → diário
    final bool exibirMensal = _mesFiltro == null;
    final List<MapEntry<DateTime, double>> dadosExibidos;
    if (exibirMensal) {
      final Map<int, double> porMes = {};
      for (final e in dadosDiarios) {
        porMes[e.key.month] = (porMes[e.key.month] ?? 0) + e.value;
      }
      dadosExibidos = porMes.entries
          .map((e) => MapEntry(DateTime(2026, e.key), e.value))
          .toList()
        ..sort((a, b) => a.key.compareTo(b.key));
    } else {
      dadosExibidos = dadosDiarios;
    }

    final maxVal = dadosExibidos.isEmpty
        ? 1.0
        : dadosExibidos.map((e) => e.value).reduce((a, b) => a > b ? a : b);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Cabeçalho ──
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titulo,
                      style: TextStyle(
                        color:
                            isDark ? Colors.white : AppColors.textPrimaryLight,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Total${_mesFiltro != null ? " ${_nomeMes(_mesFiltro!)}" : ""}: ${unidade == "uni" || unidade == "m" ? total.toStringAsFixed(0) : _fmtDec.format(total)} $unidade',
                      style: TextStyle(
                        color: isDark
                            ? Colors.white54
                            : AppColors.textSecondaryLight,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (_drillDia != null)
                TextButton.icon(
                  onPressed: () => setState(() => _drillDia = null),
                  icon: const Icon(LucideIcons.x, size: 13),
                  label: const Text(
                    'Fechar detalhe',
                    style: TextStyle(fontSize: 11),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.atrOrange,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          // ── Filtro de mês ──
          Row(
            children: [
              Icon(
                LucideIcons.calendarDays,
                size: 13,
                color: isDark ? Colors.white38 : AppColors.textSecondaryLight,
              ),
              const SizedBox(width: 6),
              Text(
                'Período:',
                style: TextStyle(
                  color: isDark ? Colors.white38 : AppColors.textSecondaryLight,
                  fontSize: 11,
                ),
              ),
              const SizedBox(width: 10),
              Wrap(
                spacing: 6,
                children: [
                  _mesChip(null, 'Geral', isDark),
                  _mesChip(1, 'Jan', isDark),
                  _mesChip(2, 'Fev', isDark),
                  _mesChip(3, 'Mar', isDark),
                  _mesChip(4, 'Abr', isDark),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          // ── Área do gráfico ──
          if (dadosExibidos.isEmpty)
            SizedBox(
              height: 140,
              child: Center(
                child: Text(
                  'Nenhum dado para exibir',
                  style: TextStyle(
                    color:
                        isDark ? Colors.white54 : AppColors.textSecondaryLight,
                  ),
                ),
              ),
            )
          else
            SizedBox(
              height: 260,
              child: exibirMensal
                  ? _buildBarrasMensais(dadosExibidos, maxVal, unidade, isDark)
                  : _buildBarrasDiarias(dadosExibidos, maxVal, unidade, isDark),
            ),
          // ── Dica de interação ──
          if (dadosExibidos.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                exibirMensal
                    ? 'Toque em um mês para ver o detalhamento diário'
                    : 'Toque em um dia para detalhar os registros',
                style: TextStyle(
                  color: isDark ? Colors.white24 : Colors.black26,
                  fontSize: 10,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
        ],
      ),
    ).animate().fadeIn(delay: 150.ms, duration: 400.ms);
  }

  Widget _mesChip(int? mes, String label, bool isDark) {
    final ativo = _mesFiltro == mes;
    return GestureDetector(
      onTap: () => setState(() {
        _mesFiltro = mes;
        _drillDia = null;
      }),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: ativo
                ? AppColors.atrOrange
                : (isDark
                    ? AppColors.surfaceElevatedDark
                    : AppColors.surfaceElevatedLight),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: ativo
                  ? AppColors.atrOrange
                  : (isDark ? AppColors.borderDark : AppColors.borderLight),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: ativo
                  ? Colors.white
                  : (isDark ? Colors.white54 : AppColors.textSecondaryLight),
              fontSize: 11,
              fontWeight: ativo ? FontWeight.w800 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBarrasMensais(
    List<MapEntry<DateTime, double>> dados,
    double maxVal,
    String unidade,
    bool isDark,
  ) {
    const nomesAbr = {1: 'Jan', 2: 'Fev', 3: 'Mar', 4: 'Abr'};
    const nomesFull = {1: 'Janeiro', 2: 'Fevereiro', 3: 'Março', 4: 'Abril'};
    return LayoutBuilder(
      builder: (ctx, constraints) {
        final barW =
            ((constraints.maxWidth / dados.length) - 24).clamp(50.0, 140.0);
        return Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: dados.map((entry) {
            final fator =
                maxVal > 0 ? (entry.value / maxVal).clamp(0.0, 1.0) : 0.0;
            final mes = entry.key.month;
            final abr = nomesAbr[mes] ?? '?';
            final full = nomesFull[mes] ?? '?';
            final valorLabel = unidade == 'uni' || unidade == 'm'
                ? entry.value.toStringAsFixed(0)
                : _fmtDec.format(entry.value);
            return GestureDetector(
              onTap: () => setState(() {
                _mesFiltro = mes;
                _drillDia = null;
              }),
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: Tooltip(
                  message: '$full: $valorLabel $unidade',
                  child: SizedBox(
                    width: barW,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          valorLabel,
                          style: const TextStyle(
                            color: AppColors.atrOrange,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                        ),
                        Text(
                          unidade,
                          style: TextStyle(
                            color: isDark
                                ? Colors.white38
                                : AppColors.textSecondaryLight,
                            fontSize: 9,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 6),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 350),
                          curve: Curves.easeOut,
                          width: barW - 12,
                          height: (145 * fator).clamp(4.0, 145.0),
                          decoration: BoxDecoration(
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(8),
                            ),
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [
                                AppColors.atrOrange.withValues(alpha: 0.45),
                                AppColors.atrOrange,
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color:
                                    AppColors.atrOrange.withValues(alpha: 0.3),
                                blurRadius: 12,
                                offset: const Offset(0, -3),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          abr,
                          style: TextStyle(
                            color: isDark
                                ? Colors.white70
                                : AppColors.textPrimaryLight,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          "'26",
                          style: TextStyle(
                            color: isDark
                                ? Colors.white38
                                : AppColors.textSecondaryLight,
                            fontSize: 9,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildBarrasDiarias(
    List<MapEntry<DateTime, double>> dados,
    double maxVal,
    String unidade,
    bool isDark,
  ) {
    return LayoutBuilder(
      builder: (ctx, constraints) {
        final availW = constraints.maxWidth;
        // calcula largura da barra para preencher o espaço; mínimo 8px (scroll)
        const minBarW = 8.0;
        final idealBarW = (availW / dados.length) - 6;
        final useScroll = idealBarW < minBarW;
        final barW = useScroll ? minBarW : idealBarW.clamp(10.0, 40.0);
        final totalW = useScroll ? dados.length * (barW + 6) : availW;
        final showValues = barW >= 22;

        final Widget bars = SizedBox(
          width: totalW,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: useScroll
                ? MainAxisAlignment.start
                : MainAxisAlignment.spaceEvenly,
            children: dados.map((entry) {
              final fator =
                  maxVal > 0 ? (entry.value / maxVal).clamp(0.0, 1.0) : 0.0;
              final isDrill = _drillDia != null &&
                  _drillDia!.year == entry.key.year &&
                  _drillDia!.month == entry.key.month &&
                  _drillDia!.day == entry.key.day;
              return GestureDetector(
                onTap: () => setState(() {
                  _drillDia = isDrill ? null : entry.key;
                }),
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Tooltip(
                    message:
                        '${entry.key.day.toString().padLeft(2, '0')}/${entry.key.month.toString().padLeft(2, '0')}: ${entry.value.toStringAsFixed(0)} $unidade',
                    child: Padding(
                      padding:
                          EdgeInsets.symmetric(horizontal: barW >= 16 ? 3 : 1),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (showValues) ...[
                            Text(
                              entry.value.toStringAsFixed(0),
                              style: TextStyle(
                                color: isDrill
                                    ? AppColors.atrOrange
                                    : AppColors.statusInfo,
                                fontSize: 8,
                                fontWeight: FontWeight.w700,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                          ],
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: barW,
                            height: (175 * fator).clamp(2.0, 175.0),
                            decoration: BoxDecoration(
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(5),
                              ),
                              gradient: LinearGradient(
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                                colors: isDrill
                                    ? [
                                        AppColors.atrOrange
                                            .withValues(alpha: 0.7),
                                        AppColors.atrOrange,
                                      ]
                                    : [
                                        const Color(0xFF3B82F6)
                                            .withValues(alpha: 0.55),
                                        const Color(0xFF60A5FA),
                                      ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: (isDrill
                                          ? AppColors.atrOrange
                                          : const Color(0xFF60A5FA))
                                      .withValues(alpha: isDrill ? 0.45 : 0.2),
                                  blurRadius: isDrill ? 12 : 6,
                                  offset: const Offset(0, -2),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 4),
                          RotatedBox(
                            quarterTurns: 3,
                            child: Text(
                              '${entry.key.day.toString().padLeft(2, '0')}/${entry.key.month.toString().padLeft(2, '0')}',
                              style: TextStyle(
                                color: isDrill
                                    ? AppColors.atrOrange
                                    : (isDark
                                        ? Colors.white38
                                        : AppColors.textSecondaryLight),
                                fontSize: 8,
                                fontWeight: isDrill
                                    ? FontWeight.w800
                                    : FontWeight.normal,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        );

        return useScroll
            ? SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: bars,
              )
            : bars;
      },
    );
  }

  String _getUnidade(String? servico) {
    switch (servico) {
      case 'Pintura de Guia':
        return 'm';
      case 'Sinalização Vertical (Qtd)':
      case 'Acessibilidade (Qtd)':
      case 'Semafórica':
      case 'Dispositivos Auxiliares':
        return 'uni';
      case 'Acessibilidade (Volume)':
        return 'm³';
      default:
        return 'm²';
    }
  }

  // ════════════════════════════════════════════════════════════════
  // DRILL-DOWN TABELA
  // ════════════════════════════════════════════════════════════════
  Widget _buildDrillDown(bool isDark) {
    final registros = obrasDetalheDia(
      _drillDia!,
      cidade: _cidade,
      equipe: _equipeFiltro,
    );

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.atrOrange.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                LucideIcons.calendarDays,
                size: 16,
                color: AppColors.atrOrange,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _fmtDateLong.format(_drillDia!),
                  style: TextStyle(
                    color: isDark ? Colors.white : AppColors.textPrimaryLight,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '${registros.length} registros',
                style: TextStyle(
                  color: isDark ? Colors.white54 : AppColors.textSecondaryLight,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (registros.isEmpty)
            Text(
              'Nenhum registro neste dia.',
              style: TextStyle(
                color: isDark ? Colors.white54 : AppColors.textSecondaryLight,
              ),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                horizontalMargin: 0,
                columnSpacing: 20,
                headingRowHeight: 36,
                dataRowMinHeight: 40,
                dataRowMaxHeight: 52,
                headingTextStyle: TextStyle(
                  color: isDark ? Colors.white54 : AppColors.textSecondaryLight,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
                dataTextStyle: TextStyle(
                  color: isDark ? Colors.white70 : AppColors.textPrimaryLight,
                  fontSize: 11,
                ),
                columns: const [
                  DataColumn(label: Text('Equipe')),
                  DataColumn(label: Text('Serviço')),
                  DataColumn(label: Text('Local / Endereço')),
                  DataColumn(label: Text('Item / Especificação')),
                  DataColumn(label: Text('Qtd'), numeric: true),
                  DataColumn(label: Text('m² / m³'), numeric: true),
                ],
                rows: registros.map((r) {
                  return DataRow(
                    cells: [
                      DataCell(
                        Text(
                          r.equipe.replaceFirst('Equipe ', ''),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      DataCell(
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.atrOrange.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            r.servico,
                            style: const TextStyle(
                              color: AppColors.atrOrange,
                              fontWeight: FontWeight.w700,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ),
                      DataCell(Text(r.local)),
                      DataCell(Text(r.item)),
                      DataCell(Text(r.qtd.toStringAsFixed(0))),
                      DataCell(Text(_fmtDec.format(r.medida))),
                    ],
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms);
  }

  // ════════════════════════════════════════════════════════════════
  // RANKINGS
  // ════════════════════════════════════════════════════════════════
  Widget _buildRankings(BuildContext context, bool isDark) {
    final rankEquipes = _ranking;
    final rankLocais = _locaisRanking;

    return LayoutBuilder(
      builder: (ctx, constraints) {
        final w = constraints.maxWidth;
        final wide = w > 900;
        if (wide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 3, child: _buildRankEquipes(rankEquipes, isDark)),
              const SizedBox(width: 24),
              Expanded(flex: 2, child: _buildRankLocais(rankLocais, isDark)),
            ],
          );
        } else {
          return Column(
            children: [
              _buildRankEquipes(rankEquipes, isDark),
              const SizedBox(height: 24),
              _buildRankLocais(rankLocais, isDark),
            ],
          );
        }
      },
    );
  }

  Widget _buildRankEquipes(List<EquipeRanking> ranking, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              LucideIcons.trophy,
              size: 16,
              color: AppColors.atrOrange,
            ),
            const SizedBox(width: 8),
            Text(
              'Ranking de Equipes',
              style: TextStyle(
                color: isDark ? Colors.white : AppColors.textPrimaryLight,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            // Toggle Volume / Média
            Container(
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.surfaceElevatedDark
                    : AppColors.surfaceElevatedLight,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isDark ? AppColors.borderDark : AppColors.borderLight,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _tabBtn('Volume', !_rankPorMedia, isDark, () {
                    setState(() => _rankPorMedia = false);
                  }),
                  _tabBtn('Média/Dia', _rankPorMedia, isDark, () {
                    setState(() => _rankPorMedia = true);
                  }),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (ranking.isEmpty)
          Text(
            'Sem dados',
            style: TextStyle(
              color: isDark ? Colors.white54 : AppColors.textSecondaryLight,
            ),
          )
        else ...[
          // Pódio top 3
          if (ranking.length >= 3)
            _buildPodio(ranking.take(3).toList(), isDark),
          const SizedBox(height: 16),
          // Lista 4+
          ...ranking.skip(3).toList().asMap().entries.map((e) {
            return _rankRow(e.key + 4, e.value, isDark);
          }),
        ],
      ],
    );
  }

  Widget _tabBtn(String label, bool ativo, bool isDark, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: ativo ? AppColors.atrOrange : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: ativo
                ? Colors.white
                : (isDark ? Colors.white54 : AppColors.textSecondaryLight),
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _buildPodio(List<EquipeRanking> top3, bool isDark) {
    final ordem = [top3[1], top3[0], top3[2]]; // prata | ouro | bronze
    final medal = ['🥈', '🥇', '🥉'];
    final alturas = [110.0, 140.0, 90.0];
    final cores = [
      const Color(0xFF94A3B8),
      const Color(0xFFFBBF24),
      const Color(0xFFCD7F32),
    ];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(3, (i) {
        final eq = ordem[i];
        final rank = top3.indexOf(eq);
        final val = _rankPorMedia ? eq.mediaDiaria : eq.volumeTotal;
        final cor = cores[i];
        return Expanded(
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () => setState(() {
                _equipeFiltro = _equipeFiltro == eq.equipe ? null : eq.equipe;
                _drillDia = null;
              }),
              child: Column(
                children: [
                  AnimatedContainer(
                    duration: 200.ms,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: cor.withValues(alpha: 0.15),
                      border: Border.all(
                        color: _equipeFiltro == eq.equipe
                            ? cor
                            : cor.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      eq.equipe.substring(0, 1).toUpperCase() +
                          eq.equipe
                              .split(' ')
                              .last
                              .substring(0, 2)
                              .toUpperCase(),
                      style: TextStyle(
                        color: cor,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(medal[i], style: const TextStyle(fontSize: 16)),
                  const SizedBox(height: 2),
                  Text(
                    eq.equipe.replaceFirst('Equipe ', ''),
                    style: TextStyle(
                      color: isDark ? Colors.white : AppColors.textPrimaryLight,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _rankPorMedia
                        ? '${_fmtDec.format(val)}/dia'
                        : _fmtDec.format(val),
                    style: TextStyle(
                      color: cor,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: alturas[i],
                    decoration: BoxDecoration(
                      color: cor.withValues(alpha: 0.15),
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(8)),
                      border: Border.all(color: cor.withValues(alpha: 0.4)),
                    ),
                    child: Center(
                      child: Text(
                        '#${rank + 1}',
                        style: TextStyle(
                          color: cor,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _rankRow(int pos, EquipeRanking eq, bool isDark) {
    final val = _rankPorMedia ? eq.mediaDiaria : eq.volumeTotal;
    final isSelected = _equipeFiltro == eq.equipe;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => setState(() {
          _equipeFiltro = isSelected ? null : eq.equipe;
          _drillDia = null;
        }),
        child: AnimatedContainer(
          duration: 150.ms,
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.atrOrange.withValues(alpha: 0.1)
                : (isDark ? AppColors.surfaceDark : AppColors.surfaceLight),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? AppColors.atrOrange.withValues(alpha: 0.4)
                  : (isDark ? AppColors.borderDark : AppColors.borderLight),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: (isDark
                      ? Colors.white10
                      : Colors.black.withValues(alpha: 0.07)),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '$pos',
                    style: TextStyle(
                      color: isDark
                          ? Colors.white54
                          : AppColors.textSecondaryLight,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      eq.equipe,
                      style: TextStyle(
                        color:
                            isDark ? Colors.white : AppColors.textPrimaryLight,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '${eq.diasTrabalhados} dias · ${eq.servicoPrincipal}',
                      style: TextStyle(
                        color: isDark
                            ? Colors.white54
                            : AppColors.textSecondaryLight,
                        fontSize: 10,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.atrOrange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _rankPorMedia
                      ? '${_fmtDec.format(val)}/dia'
                      : _fmtDec.format(val),
                  style: const TextStyle(
                    color: AppColors.atrOrange,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRankLocais(List<LocalRanking> locais, bool isDark) {
    if (locais.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? AppColors.borderDark : AppColors.borderLight,
          ),
        ),
        child: Text(
          'Sem dados',
          style: TextStyle(
            color: isDark ? Colors.white54 : AppColors.textSecondaryLight,
          ),
        ),
      );
    }

    final top3 = locais.take(3).toList();
    final resto = locais.skip(3).take(10).toList();
    final medalhas = ['🥇', '🥈', '🥉'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              LucideIcons.mapPin,
              size: 16,
              color: AppColors.statusInfo,
            ),
            const SizedBox(width: 8),
            Text(
              'Top Locais de Execução',
              style: TextStyle(
                color: isDark ? Colors.white : AppColors.textPrimaryLight,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        // Pódio de locais
        ...top3.asMap().entries.map((e) {
          final local = e.value;
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? AppColors.borderDark : AppColors.borderLight,
              ),
            ),
            child: Row(
              children: [
                Text(medalhas[e.key], style: const TextStyle(fontSize: 20)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        local.local,
                        style: TextStyle(
                          color: isDark
                              ? Colors.white
                              : AppColors.textPrimaryLight,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        local.cidade,
                        style: TextStyle(
                          color: isDark
                              ? Colors.white54
                              : AppColors.textSecondaryLight,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  _fmtDec.format(local.volumeTotal),
                  style: const TextStyle(
                    color: AppColors.statusInfo,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          );
        }),
        // Demais locais
        ...resto.asMap().entries.map((e) {
          final local = e.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white10
                        : Colors.black.withValues(alpha: 0.07),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '${e.key + 4}',
                      style: TextStyle(
                        color: isDark
                            ? Colors.white54
                            : AppColors.textSecondaryLight,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${local.local} · ${local.cidade}',
                    style: TextStyle(
                      color:
                          isDark ? Colors.white70 : AppColors.textPrimaryLight,
                      fontSize: 11,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  _fmtDec.format(local.volumeTotal),
                  style: TextStyle(
                    color:
                        isDark ? Colors.white54 : AppColors.textSecondaryLight,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  // ════════════════════════════════════════════════════════════════
  // RAIO-X DE PRODUÇÃO
  // ════════════════════════════════════════════════════════════════
  Widget _buildRaioX(bool isDark) {
    final semProd = getDiasSemProducao(
      cidade: _cidade,
      equipe: _equipeFiltro,
      mes: _mesFiltro,
    );
    final pAbaixo = getDiasComPinturaAbaixo100(
      cidade: _cidade,
      equipe: _equipeFiltro,
      mes: _mesFiltro,
    );
    final semPintura = getDiasSemPintura(
      cidade: _cidade,
      equipe: _equipeFiltro,
      mes: _mesFiltro,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              LucideIcons.scanLine,
              size: 18,
              color: AppColors.atrOrange,
            ),
            const SizedBox(width: 10),
            Text(
              'Ferramenta Raio-X de Produção',
              style: TextStyle(
                color: isDark ? Colors.white : AppColors.textPrimaryLight,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (ctx, constraints) {
            final w = constraints.maxWidth;
            final cols = w > 900 ? 3 : 1;
            const spacing = 16.0;
            final cardW = (w - spacing * (cols - 1)) / cols;

            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: [
                SizedBox(
                  width: cardW,
                  child: _raioXCard(
                    'Dias SEM Produção',
                    semProd,
                    AppColors.statusError,
                    LucideIcons.calendarOff,
                    isDark,
                  ),
                ),
                SizedBox(
                  width: cardW,
                  child: _raioXCard(
                    'Pintura < 100 m²',
                    pAbaixo,
                    AppColors.statusWarning,
                    LucideIcons.alertCircle,
                    isDark,
                  ),
                ),
                SizedBox(
                  width: cardW,
                  child: _raioXCard(
                    'Dias SEM Pintura',
                    semPintura,
                    AppColors.statusInfo,
                    LucideIcons.paintbrush,
                    isDark,
                  ),
                ),
              ],
            );
          },
        ),
      ],
    ).animate().fadeIn(delay: 200.ms, duration: 400.ms);
  }

  Widget _raioXCard(
    String titulo,
    List<DateTime> dias,
    Color cor,
    IconData icon,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cor.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: cor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  titulo,
                  style: TextStyle(
                    color: isDark ? Colors.white : AppColors.textPrimaryLight,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: cor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${dias.length}',
                  style: TextStyle(
                    color: cor,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (dias.isEmpty)
            Text(
              'Nenhuma ocorrência',
              style: TextStyle(
                color: isDark ? Colors.white38 : AppColors.textSecondaryLight,
                fontSize: 11,
                fontStyle: FontStyle.italic,
              ),
            )
          else
            ...dias.take(8).map((d) {
              final key = '${d.year}-${d.month}-${d.day}';
              _controllers.putIfAbsent(
                key,
                () => TextEditingController(text: _justificativas[key] ?? ''),
              );
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      margin: const EdgeInsets.only(top: 2, right: 8),
                      decoration:
                          BoxDecoration(shape: BoxShape.circle, color: cor),
                    ),
                    Text(
                      _fmtDate.format(d) +
                          (d.weekday == DateTime.saturday ? ' (Sáb)' : ''),
                      style: TextStyle(
                        color: isDark
                            ? Colors.white70
                            : AppColors.textPrimaryLight,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _controllers[key],
                        style: TextStyle(
                          fontSize: 10,
                          color: isDark
                              ? Colors.white60
                              : AppColors.textSecondaryLight,
                        ),
                        onSubmitted: (val) => setState(() {
                          _justificativas[key] = val;
                        }),
                        decoration: InputDecoration(
                          hintText: 'justificar...',
                          hintStyle: TextStyle(
                            fontSize: 10,
                            color: isDark ? Colors.white24 : Colors.black26,
                          ),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                            borderSide:
                                BorderSide(color: cor.withValues(alpha: 0.3)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                            borderSide: BorderSide(
                              color: isDark
                                  ? AppColors.borderDark
                                  : AppColors.borderLight,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                            borderSide: BorderSide(color: cor),
                          ),
                          filled: true,
                          fillColor: isDark
                              ? AppColors.surfaceElevatedDark
                              : AppColors.surfaceElevatedLight,
                        ),
                      ),
                    ),
                    if ((_controllers[key]?.text.isNotEmpty) == true)
                      GestureDetector(
                        onTap: () => setState(() {
                          _controllers[key]?.clear();
                          _justificativas.remove(key);
                        }),
                        child: Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: Icon(
                            LucideIcons.x,
                            size: 12,
                            color: cor.withValues(alpha: 0.6),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            }),
          if (dias.length > 8) ...[
            const SizedBox(height: 4),
            Text(
              '... e mais ${dias.length - 8} dias',
              style: TextStyle(
                color: isDark ? Colors.white38 : AppColors.textSecondaryLight,
                fontSize: 10,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
