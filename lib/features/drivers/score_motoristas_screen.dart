import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../../core/data/fleet_data.dart';
import '../../core/data/score_motorista_models.dart';
import '../../core/enums/cnh_status.dart';
import '../../core/providers/score_motorista_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/atr_page_background.dart';
import '../../core/widgets/atr_top_bar.dart';
import '../../core/widgets/app_sidebar.dart';

import '../../core/utils/export_csv_stub.dart'
    if (dart.library.html) '../../core/utils/export_csv_html.dart'
    if (dart.library.io) '../../core/utils/export_csv_io.dart';

// ═══════════════════════════════════════════════════════════════════════
// Tela de Score de Motoristas
// ═══════════════════════════════════════════════════════════════════════

enum _PeriodoScore { todos }

class ScoreMotoristaScreen extends StatefulWidget {
  const ScoreMotoristaScreen({super.key});

  @override
  State<ScoreMotoristaScreen> createState() => _ScoreMotoristaScreenState();
}

class _ScoreMotoristaScreenState extends State<ScoreMotoristaScreen> {
  _PeriodoScore _periodo = _PeriodoScore.todos;

  // Os scores são calculados com base em dados atuais (CNH, total
  // de multas, kmPorMes) que não possuem recorte temporal histórico.
  // O filtro de período está oculto até que dados de multas por data
  // e hodometro por período estejam integrados ao cálculo.

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fleet = context.watch<FleetRepository>();
    final provider = context.watch<ScoreMotoristaProvider>();
    final scores = provider.calcularScores(fleet);

    final nExcelente = scores.where((s) => s.classificacao == 'Excelente').length;
    final nBom = scores.where((s) => s.classificacao == 'Bom').length;
    final nRegular = scores.where((s) => s.classificacao == 'Regular').length;
    final nCritico = scores.where((s) => s.classificacao == 'Crítico').length;

    return AppSidebar(
      child: Scaffold(
        body: AtrPageBackground(
          grid: true,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(32, 32, 32, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(scores),
                  _buildResumo(isDark, nExcelente, nBom, nRegular, nCritico),
                  const SizedBox(height: 20),
                  _buildPeriodoFiltro(),
                  const SizedBox(height: 20),
                  if (fleet.isLoading)
                    const Expanded(child: Center(child: CircularProgressIndicator()))
                  else if (scores.isEmpty)
                    _buildEmpty(isDark)
                  else
                    Expanded(
                      child: ListView.separated(
                        itemCount: scores.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, i) => _ScoreCard(
                          score: scores[i],
                          posicao: i + 1,
                          isDark: isDark,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(List<ScoreMotorista> scores) {
    return AtrTopBar(
      title: 'Score de Motoristas',
      subtitle: 'Ranking por desempenho e conformidade',
      actions: [
        PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'csv') _exportCsv(scores);
          },
          itemBuilder: (context) => const [
            PopupMenuItem(
              value: 'csv',
              child: Row(
                children: [
                  Icon(LucideIcons.fileSpreadsheet, size: 16),
                  SizedBox(width: 8),
                  Text('Exportar CSV'),
                ],
              ),
            ),
          ],
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppColors.atrOrange.withValues(alpha: 0.3),
              ),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(LucideIcons.download, size: 14, color: AppColors.atrOrange),
                SizedBox(width: 6),
                Text('Exportar', style: TextStyle(fontSize: 12, color: AppColors.atrOrange)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _exportCsv(List<ScoreMotorista> scores) async {
    final buffer = StringBuffer();
    buffer.writeln('"POSICAO";"MOTORISTA";"PONTUACAO";"CLASSIFICACAO";"MULTAS";"KM/MES";"CNH";"VEICULOS"');

    for (var i = 0; i < scores.length; i++) {
      final s = scores[i];
      final kmFmt = s.kmMedioMensal > 0 ? s.kmMedioMensal.toStringAsFixed(0) : '0';
      buffer.writeln(
        '${_csvField((i + 1).toString())};${_csvField(s.nomeMotorista)};${_csvField(s.pontuacaoTotal.toString())};${_csvField(s.classificacao)};${_csvField(s.multas.toString())};${_csvField(kmFmt)};${_csvField(s.statusCnh.name)};${_csvField(s.placasVeiculos.join(', '))}',
      );
    }

    try {
      final fileName = 'score_motoristas_${DateTime.now().millisecondsSinceEpoch}.csv';
      await exportCsv(fileName, buffer.toString());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('CSV exportado: $fileName')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao exportar CSV: $e')),
        );
      }
    }
  }

  String _csvField(String value) {
    final escaped = value.replaceAll('"', '""');
    return '"$escaped"';
  }

  Widget _buildPeriodoFiltro() {
    // O cálculo de scores usa dados agregados (total de multas, km médio)
    // sem recorte temporal. Os filtros de período ficam ocultos até que a
    // integração com multas.data_infracao e hodometros.created_at seja feita.
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildPeriodoChip('Todos', _PeriodoScore.todos),
        ],
      ),
    );
  }

  Widget _buildPeriodoChip(String label, _PeriodoScore periodo) {
    final ativo = _periodo == periodo;
    const cor = AppColors.atrOrange;
    return GestureDetector(
      onTap: () => setState(() => _periodo = periodo),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: ativo ? cor.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: ativo ? cor.withValues(alpha: 0.4) : Colors.white.withValues(alpha: 0.07),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: ativo ? cor : AppColors.textSecondaryDark,
          ),
        ),
      ),
    );
  }

  Widget _buildResumo(bool isDark, int nEx, int nBom, int nReg, int nCrit) {
    return Wrap(
      spacing: 10,
      runSpacing: 8,
      children: [
        _ResumoChip(label: 'Excelente', count: nEx, color: AppColors.statusSuccess),
        _ResumoChip(label: 'Bom', count: nBom, color: AppColors.statusInfo),
        _ResumoChip(label: 'Regular', count: nReg, color: AppColors.statusWarning),
        _ResumoChip(label: 'Crítico', count: nCrit, color: AppColors.statusError),
      ],
    );
  }

  Widget _buildEmpty(bool isDark) {
    return Expanded(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.users, size: 48,
                color: isDark ? Colors.white24 : Colors.black26),
            const SizedBox(height: 12),
            Text(
              'Nenhum motorista cadastrado',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.textSecondaryDark : Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Chip de resumo
// ─────────────────────────────────────────────────────────────────────

class _ResumoChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _ResumoChip({required this.label, required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 8, height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(
            '$label ($count)',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Card individual de motorista
// ─────────────────────────────────────────────────────────────────────

class _ScoreCard extends StatelessWidget {
  final ScoreMotorista score;
  final int posicao;
  final bool isDark;

  const _ScoreCard({
    required this.score,
    required this.posicao,
    required this.isDark,
  });

  static const _cnhLabel = {
    CnhStatus.ok: 'Válida',
    CnhStatus.vencendo: 'Vencendo',
    CnhStatus.vencida: 'Vencida',
  };

  Color _cor(String classificacao) {
    switch (classificacao) {
      case 'Excelente':
        return AppColors.statusSuccess;
      case 'Bom':
        return AppColors.statusInfo;
      case 'Regular':
        return AppColors.statusWarning;
      default:
        return AppColors.statusError;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cor = _cor(score.classificacao);
    final kmFmt = score.kmMedioMensal > 0
        ? '${score.kmMedioMensal.toStringAsFixed(0)} km/mês'
        : '— km/mês';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.03)
            : Colors.black.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.07)
              : Colors.black.withValues(alpha: 0.07),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Linha 1: posição + nome + classificação
          Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: cor.withValues(alpha: 0.15),
                child: Text(
                  '#$posicao',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: cor,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  score.nomeMotorista,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: cor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  score.classificacao,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: cor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Linha 2: barra de progresso
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: score.pontuacaoTotal / 100,
                    minHeight: 8,
                    backgroundColor: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.black.withValues(alpha: 0.08),
                    valueColor: AlwaysStoppedAnimation<Color>(cor),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '${score.pontuacaoTotal}/100',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Linha 3: mini-badges
          Wrap(
            spacing: 10,
            runSpacing: 6,
            children: [
              _MiniBadge(
                icon: LucideIcons.creditCard,
                label: 'CNH: ${_cnhLabel[score.statusCnh] ?? ''} · ${score.pontosCnh}pts',
                color: score.statusCnh == CnhStatus.ok
                    ? AppColors.statusSuccess
                    : score.statusCnh == CnhStatus.vencendo
                        ? AppColors.statusWarning
                        : AppColors.statusError,
                isDark: isDark,
              ),
              _MiniBadge(
                icon: LucideIcons.alertTriangle,
                label: '${score.multas} multa(s) · ${score.pontosMultas}pts',
                color: score.multas == 0
                    ? AppColors.statusSuccess
                    : score.multas <= 2
                        ? AppColors.statusWarning
                        : AppColors.statusError,
                isDark: isDark,
              ),
              _MiniBadge(
                icon: LucideIcons.gauge,
                label: '$kmFmt · ${score.pontosKm}pts',
                color: AppColors.statusInfo,
                isDark: isDark,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Mini-badge de métrica
// ─────────────────────────────────────────────────────────────────────

class _MiniBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool isDark;

  const _MiniBadge({
    required this.icon,
    required this.label,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
