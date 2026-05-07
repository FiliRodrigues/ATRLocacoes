import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../../core/data/fleet_data.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_sidebar.dart';
import '../../core/widgets/bento_card.dart';

// ═══════════════════════════════════════════════════════════════════════
// Painel de Vencimentos Consolidado
// Agrega IPVA, Seguro, Licenciamento por veículo + CNH por motorista
// Semáforo: ≤7d vermelho · 8–30d amarelo · >30d verde
// ═══════════════════════════════════════════════════════════════════════

enum _VencTipo { ipva, seguro, licenciamento, cnh }

enum _VencStatus { vencido, critico, alerta, ok }

class _VencItem {
  final _VencTipo tipo;
  final String entidade; // placa do veículo ou nome do motorista
  final String subtitulo; // nome do veículo ou "CNH"
  final DateTime vencimento;
  final _VencStatus status;
  final int diasRestantes;

  const _VencItem({
    required this.tipo,
    required this.entidade,
    required this.subtitulo,
    required this.vencimento,
    required this.status,
    required this.diasRestantes,
  });

  static _VencStatus _calcStatus(int dias) {
    if (dias < 0) return _VencStatus.vencido;
    if (dias <= 7) return _VencStatus.critico;
    if (dias <= 30) return _VencStatus.alerta;
    return _VencStatus.ok;
  }

  factory _VencItem.veiculo({
    required _VencTipo tipo,
    required VehicleData v,
    required DateTime vencimento,
  }) {
    final hoje = DateTime.now();
    final dias = vencimento.difference(DateTime(hoje.year, hoje.month, hoje.day)).inDays;
    return _VencItem(
      tipo: tipo,
      entidade: v.placa,
      subtitulo: v.nome,
      vencimento: vencimento,
      status: _calcStatus(dias),
      diasRestantes: dias,
    );
  }

  factory _VencItem.motorista({
    required DriverData d,
    required DateTime vencimento,
  }) {
    final hoje = DateTime.now();
    final dias = vencimento.difference(DateTime(hoje.year, hoje.month, hoje.day)).inDays;
    return _VencItem(
      tipo: _VencTipo.cnh,
      entidade: d.nome,
      subtitulo: 'CNH',
      vencimento: vencimento,
      status: _calcStatus(dias),
      diasRestantes: dias,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────

enum _Filtro { todos, critico, alerta, ok }

class VencimentosScreen extends StatefulWidget {
  const VencimentosScreen({super.key});

  @override
  State<VencimentosScreen> createState() => _VencimentosScreenState();
}

class _VencimentosScreenState extends State<VencimentosScreen> {
  _Filtro _filtro = _Filtro.todos;

  static final _dateFmt = DateFormat('dd/MM/yyyy');

  List<_VencItem> _buildItens(FleetRepository repo) {
    final itens = <_VencItem>[];
    for (final v in repo.frota) {
      itens.add(_VencItem.veiculo(tipo: _VencTipo.ipva, v: v, vencimento: v.vencimentoIPVA));
      itens.add(_VencItem.veiculo(tipo: _VencTipo.seguro, v: v, vencimento: v.vencimentoSeguro));
      itens.add(_VencItem.veiculo(tipo: _VencTipo.licenciamento, v: v, vencimento: v.vencimentoLicenciamento));
    }
    for (final d in repo.motoristas) {
      itens.add(_VencItem.motorista(d: d, vencimento: d.vencimentoCNH));
    }
    // ordena por urgência (vencido primeiro, depois por data)
    itens.sort((a, b) => a.diasRestantes.compareTo(b.diasRestantes));
    return itens;
  }

  List<_VencItem> _aplicarFiltro(List<_VencItem> todos) {
    return switch (_filtro) {
      _Filtro.todos => todos,
      _Filtro.critico =>
        todos.where((e) => e.status == _VencStatus.vencido || e.status == _VencStatus.critico).toList(),
      _Filtro.alerta => todos.where((e) => e.status == _VencStatus.alerta).toList(),
      _Filtro.ok => todos.where((e) => e.status == _VencStatus.ok).toList(),
    };
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final repo = context.watch<FleetRepository>();
    final todos = _buildItens(repo);
    final filtrados = _aplicarFiltro(todos);

    final nVencido = todos.where((e) => e.status == _VencStatus.vencido).length;
    final nCritico = todos.where((e) => e.status == _VencStatus.critico).length;
    final nAlerta = todos.where((e) => e.status == _VencStatus.alerta).length;
    final nOk = todos.where((e) => e.status == _VencStatus.ok).length;

    return AppSidebar(
      child: Scaffold(
        backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
        body: Column(
          children: [
            _buildHeader(context, isDark, nVencido + nCritico),
            _buildSummaryRow(isDark, nVencido, nCritico, nAlerta, nOk, total: todos.length),
            _buildFilterBar(isDark, nVencido, nCritico, nAlerta, nOk),
            Expanded(
              child: filtrados.isEmpty
                  ? _buildEmpty(isDark)
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
                      itemCount: filtrados.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, i) => _VencCard(
                        item: filtrados[i],
                        isDark: isDark,
                        dateFmt: _dateFmt,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isDark, int nUrgentes) {
    return Container(
      padding: const EdgeInsets.fromLTRB(32, 28, 32, 16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.atrNavyDarker : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.06),
          ),
        ),
      ),
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: (nUrgentes > 0 ? AppColors.statusError : AppColors.statusSuccess)
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  LucideIcons.calendarClock,
                  color: nUrgentes > 0 ? AppColors.statusError : AppColors.statusSuccess,
                  size: 24,
                ),
              ),
              if (nUrgentes > 0)
                Positioned(
                  top: -4,
                  right: -4,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: AppColors.statusError,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                    child: Text(
                      '$nUrgentes',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Painel de Vencimentos',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.3,
                      ),
                ),
                Text(
                  'IPVA · Seguro · Licenciamento · CNH — tudo em um só lugar',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white54 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(
    bool isDark,
    int nVencido,
    int nCritico,
    int nAlerta,
    int nOk, {
    required int total,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: Row(
        children: [
          Expanded(
            child: _SummaryTile(
              label: 'Vencidos',
              count: nVencido,
              color: AppColors.statusError,
              icon: LucideIcons.xCircle,
              isDark: isDark,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _SummaryTile(
              label: 'Críticos (≤7d)',
              count: nCritico,
              color: Colors.deepOrange,
              icon: LucideIcons.alertTriangle,
              isDark: isDark,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _SummaryTile(
              label: 'Atenção (≤30d)',
              count: nAlerta,
              color: AppColors.statusWarning,
              icon: LucideIcons.alertCircle,
              isDark: isDark,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _SummaryTile(
              label: 'Em dia',
              count: nOk,
              color: AppColors.statusSuccess,
              icon: LucideIcons.checkCircle2,
              isDark: isDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar(bool isDark, int nVencido, int nCritico, int nAlerta, int nOk) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _filterChip(_Filtro.todos, 'Todos', null, isDark),
            const SizedBox(width: 8),
            _filterChip(_Filtro.critico, 'Urgentes', nVencido + nCritico > 0 ? nVencido + nCritico : null, isDark,
                activeColor: AppColors.statusError),
            const SizedBox(width: 8),
            _filterChip(_Filtro.alerta, 'Atenção', nAlerta > 0 ? nAlerta : null, isDark,
                activeColor: AppColors.statusWarning),
            const SizedBox(width: 8),
            _filterChip(_Filtro.ok, 'Em dia', null, isDark, activeColor: AppColors.statusSuccess),
          ],
        ),
      ),
    );
  }

  Widget _filterChip(
    _Filtro filtro,
    String label,
    int? count,
    bool isDark, {
    Color? activeColor,
  }) {
    final selected = _filtro == filtro;
    final color = activeColor ?? AppColors.atrOrange;
    return ChoiceChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          if (count != null && count > 0) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: selected ? Colors.white.withValues(alpha: 0.25) : color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: selected ? Colors.white : color,
                ),
              ),
            ),
          ],
        ],
      ),
      selected: selected,
      selectedColor: color,
      onSelected: (_) => setState(() => _filtro = filtro),
      labelStyle: TextStyle(color: selected ? Colors.white : null),
    );
  }

  Widget _buildEmpty(bool isDark) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.calendarCheck,
              size: 48, color: isDark ? Colors.white24 : Colors.black26),
          const SizedBox(height: 12),
          Text(
            'Nenhum item neste filtro',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white54 : Colors.black54,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Tile de resumo numérico
// ─────────────────────────────────────────────────────────────────────

class _SummaryTile extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final IconData icon;
  final bool isDark;

  const _SummaryTile({
    required this.label,
    required this.count,
    required this.color,
    required this.icon,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return BentoCard(
      padding: EdgeInsets.zero,
      child: Container(
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: color, width: 3)),
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    color.withValues(alpha: 0.2),
                    color.withValues(alpha: 0.08),
                  ],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 16),
            ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$count',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 22,
                    color: count > 0 ? color : (isDark ? Colors.white38 : Colors.black38),
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white54 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Card individual de vencimento
// ─────────────────────────────────────────────────────────────────────

class _VencCard extends StatelessWidget {
  final _VencItem item;
  final bool isDark;
  final DateFormat dateFmt;

  const _VencCard({required this.item, required this.isDark, required this.dateFmt});

  @override
  Widget build(BuildContext context) {
    final (icon, tipoLabel) = _tipoInfo(item.tipo);
    final (statusColor, statusLabel) = _statusInfo(item);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.03)
            : Colors.black.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: statusColor.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: statusColor),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      item.entidade,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        tipoLabel,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white54 : Colors.black54,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  item.subtitulo,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white54 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                dateFmt.format(item.vencimento),
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  (IconData, String) _tipoInfo(_VencTipo tipo) => switch (tipo) {
        _VencTipo.ipva => (LucideIcons.receipt, 'IPVA'),
        _VencTipo.seguro => (LucideIcons.shieldCheck, 'Seguro'),
        _VencTipo.licenciamento => (LucideIcons.clipboardList, 'Licenciamento'),
        _VencTipo.cnh => (LucideIcons.creditCard, 'CNH'),
      };

  (Color, String) _statusInfo(_VencItem e) {
    if (e.status == _VencStatus.vencido) {
      return (AppColors.statusError, 'VENCIDO há ${e.diasRestantes.abs()}d');
    }
    if (e.status == _VencStatus.critico) {
      return (Colors.deepOrange, 'CRÍTICO — ${e.diasRestantes}d');
    }
    if (e.status == _VencStatus.alerta) {
      return (AppColors.statusWarning, 'Atenção — ${e.diasRestantes}d');
    }
    return (AppColors.statusSuccess, '${e.diasRestantes}d restantes');
  }
}
