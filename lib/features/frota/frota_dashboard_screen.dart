import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_sidebar.dart';
import '../../core/widgets/bento_card.dart';
import '../../core/data/fleet_data.dart';
import '../../core/data/custos_models.dart';
import '../custos/expenses/expense_form_modal.dart';
import '../custos/custos_provider.dart';

// ═══════════════════════════════════════════════════════════════════
// FrotaDashboardScreen — Tela exclusiva para o login "Frota"
//
// Responsabilidade única: permitir ao funcionário de frota:
//   1. Atualizar KM semanal (pendências com contagem de dias)
//   2. Lançar despesas / manutenções
//   3. Lançar multas associando veículo + motorista
//
// Trade-off: estado de KM atualizado é mantido em memória (Map local).
// Em produção, isso viria de um backend/SharedPreferences persistido.
// ═══════════════════════════════════════════════════════════════════

class FrotaDashboardScreen extends StatefulWidget {
  const FrotaDashboardScreen({super.key});

  @override
  State<FrotaDashboardScreen> createState() => _FrotaDashboardScreenState();
}

class _FrotaDashboardScreenState extends State<FrotaDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // ── Filtros — aba Despesas ──
  String? _filtroVeiculoPlaca;
  String? _filtroTipoDespesa;
  DateTime? _filtroMesDespesa;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  bool _foiAtualizadoNaSemana(DateTime? datetime) {
    if (datetime == null) return false;
    final now = DateTime.now();
    // Encontra o início da semana (segunda-feira)
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1)).copyWith(
          hour: 0,
          minute: 0,
          second: 0,
          millisecond: 0,
          microsecond: 0,
        );
    return datetime.isAfter(startOfWeek) ||
        datetime.isAtSameMomentAs(startOfWeek);
  }

  /// Calcula quantos dias faltam para fechar a semana (seg-dom).
  int get _diasRestantesSemana {
    final now = DateTime.now();
    // weekday: 1=seg … 7=dom → dias até domingo
    return 7 - now.weekday;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AppSidebar(
      child: Scaffold(
        backgroundColor:
            isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
        body: Column(
          children: [
            // ── Header customizado ──
            _buildTopHeader(context, isDark),
            // ── TabBar ──
            Container(
              color: isDark ? AppColors.atrNavyDarker : Colors.white,
              child: TabBar(
                controller: _tabController,
                labelColor: AppColors.atrOrange,
                unselectedLabelColor: isDark ? Colors.white54 : Colors.black54,
                indicatorColor: AppColors.atrOrange,
                indicatorWeight: 3,
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
                tabs: const [
                  Tab(
                    icon: Icon(LucideIcons.listTodo, size: 18),
                    text: 'Pendências KM',
                  ),
                  Tab(
                    icon: Icon(LucideIcons.wrench, size: 18),
                    text: 'Despesas / Manutenção',
                  ),
                  Tab(
                    icon: Icon(LucideIcons.fileWarning, size: 18),
                    text: 'Lançar Multas',
                  ),
                ],
              ),
            ),
            // ── Conteúdo ──
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildPendenciasTab(isDark),
                  _buildDespesasTab(isDark),
                  _buildMultasTab(isDark),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  // HEADER
  // ─────────────────────────────────────────────────────────
  Widget _buildTopHeader(BuildContext context, bool isDark) {
    final frota = context.read<FleetRepository>().frota;
    final pendentes = frota
        .where((v) => !_foiAtualizadoNaSemana(v.ultimaAtualizacaoKm))
        .length;

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
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.atrOrange.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              LucideIcons.truck,
              color: AppColors.atrOrange,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Controle de Frota',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.3,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Semana fecha em $_diasRestantesSemana dia(s)',
                  style: TextStyle(
                    color: isDark ? Colors.white54 : Colors.black54,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          // Badge de pendências
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 8,
            ),
            decoration: BoxDecoration(
              color: pendentes > 0
                  ? AppColors.statusWarning.withValues(alpha: 0.12)
                  : AppColors.statusSuccess.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: pendentes > 0
                    ? AppColors.statusWarning.withValues(alpha: 0.3)
                    : AppColors.statusSuccess.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  pendentes > 0
                      ? LucideIcons.alertTriangle
                      : LucideIcons.checkCircle2,
                  size: 16,
                  color: pendentes > 0
                      ? AppColors.statusWarning
                      : AppColors.statusSuccess,
                ),
                const SizedBox(width: 8),
                Text(
                  pendentes > 0 ? '$pendentes pendente(s)' : 'Tudo atualizado!',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    color: pendentes > 0
                        ? AppColors.statusWarning
                        : AppColors.statusSuccess,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).moveY(begin: -8, end: 0);
  }

  // ─────────────────────────────────────────────────────────
  // ABA 1 — PENDÊNCIAS DE KM
  // ─────────────────────────────────────────────────────────
  Widget _buildPendenciasTab(bool isDark) {
    final frota = context.read<FleetRepository>().frota;

    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: frota.length,
      itemBuilder: (context, index) {
        final v = frota[index];
        final atualizado = _foiAtualizadoNaSemana(v.ultimaAtualizacaoKm);
        final kmDisplay = v.kmAtual.toInt();

        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: BentoCard(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                // Ícone de status
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: atualizado
                        ? AppColors.statusSuccess.withValues(alpha: 0.1)
                        : AppColors.statusWarning.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    atualizado
                        ? LucideIcons.checkCircle
                        : LucideIcons.alertCircle,
                    color: atualizado
                        ? AppColors.statusSuccess
                        : AppColors.statusWarning,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                // Info do veículo
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            v.placa,
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: v.cor1.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              v.nome,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: v.cor1,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Motorista: ${v.motorista}',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white54 : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
                // KM + Ação
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${NumberFormat('#,###', 'pt_BR').format(kmDisplay)} km',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (!atualizado)
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.atrOrange,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: () => _showUpdateKmDialog(v),
                        icon: const Icon(LucideIcons.edit2, size: 14),
                        label: const Text(
                          'Atualizar KM',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.statusSuccess.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              LucideIcons.check,
                              size: 14,
                              color: AppColors.statusSuccess,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Atualizado',
                              style: TextStyle(
                                color: AppColors.statusSuccess,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ).animate(delay: (index * 80).ms).fadeIn(duration: 300.ms).moveX(
              begin: 20,
              end: 0,
              curve: Curves.easeOutCubic,
            );
      },
    );
  }

  // ─────────────────────────────────────────────────────────
  // DIALOG DE ATUALIZAÇÃO DE KM
  // ─────────────────────────────────────────────────────────
  Future<void> _showUpdateKmDialog(VehicleData v) async {
    final ctrl = TextEditingController(
      text: v.kmAtual.toInt().toString(),
    );

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            const Icon(LucideIcons.gauge, color: AppColors.atrOrange),
            const SizedBox(width: 10),
            Text('Atualizar KM — ${v.placa}'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.statusInfo.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.statusInfo.withValues(alpha: 0.2),
                  ),
                ),
                child: const Row(
                  children: [
                    Icon(
                      LucideIcons.info,
                      size: 16,
                      color: AppColors.statusInfo,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'A atualização semanal é obrigatória para manter revisões em dia.',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: ctrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Quilometragem atual',
                  prefixIcon: const Icon(LucideIcons.gauge, size: 18),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Checklist Rápido:',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 8),
              _checkItem('Nível de óleo e água'),
              _checkItem('Estado dos pneus'),
              _checkItem('Limpeza e avarias na lataria'),
              _checkItem('Estepe, macaco e triângulo'),
              _checkItem('Luzes e setas funcionando'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.atrOrange,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final novoKm = int.tryParse(ctrl.text) ?? v.kmAtual.toInt();
      context
          .read<FleetRepository>()
          .updateVehicleKm(placa: v.placa, km: novoKm.toDouble());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'KM do ${v.placa} atualizado para ${NumberFormat('#,###', 'pt_BR').format(novoKm)} km',
          ),
        ),
      );
    }
  }

  Widget _checkItem(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(
            LucideIcons.checkSquare,
            size: 14,
            color: AppColors.statusSuccess.withValues(alpha: 0.6),
          ),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  // ABA 2 — DESPESAS / MANUTENÇÃO (com filtros)
  // ─────────────────────────────────────────────────────────
  Widget _buildDespesasTab(bool isDark) {
    final provider = context.watch<CustosProvider>();
    final frota = context.watch<FleetRepository>().frota;

    var despesas = provider.despesas
        .where((d) =>
            d.tipo == 'Manutenção' || d.tipo == 'Revisão' || d.tipo == 'Outros',)
        .toList();

    if (_filtroVeiculoPlaca != null) {
      despesas =
          despesas.where((d) => d.veiculoPlaca == _filtroVeiculoPlaca).toList();
    }
    if (_filtroTipoDespesa != null) {
      despesas =
          despesas.where((d) => d.tipo == _filtroTipoDespesa).toList();
    }
    if (_filtroMesDespesa != null) {
      despesas = despesas
          .where((d) =>
              d.data.year == _filtroMesDespesa!.year &&
              d.data.month == _filtroMesDespesa!.month,)
          .toList();
    }
    despesas.sort((a, b) => b.data.compareTo(a.data));

    final hasFilters = _filtroVeiculoPlaca != null ||
        _filtroTipoDespesa != null ||
        _filtroMesDespesa != null;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.atrOrange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      LucideIcons.wrench,
                      color: AppColors.atrOrange,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Despesas e Manutenções',
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        hasFilters
                            ? '${despesas.length} resultado(s) filtrado(s)'
                            : 'Lance os gastos com revisões, peças e serviços.',
                        style: TextStyle(
                          color: hasFilters
                              ? AppColors.atrOrange
                              : (isDark ? Colors.white54 : Colors.black54),
                          fontSize: 12,
                          fontWeight: hasFilters
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.atrOrange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () => _lancarNovaDespesa(tipo: 'Manutenção'),
                icon: const Icon(LucideIcons.plus, size: 18),
                label: const Text(
                  'Novo Lançamento',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // ── Barra de filtros ──
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip(
                  label: _filtroVeiculoPlaca ?? 'Todos os veículos',
                  icon: LucideIcons.truck,
                  isActive: _filtroVeiculoPlaca != null,
                  isDark: isDark,
                  onTap: () => _mostrarSeletorVeiculo(frota),
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  label: _filtroTipoDespesa ?? 'Todos os tipos',
                  icon: LucideIcons.tag,
                  isActive: _filtroTipoDespesa != null,
                  isDark: isDark,
                  onTap: _mostrarSeletorTipo,
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  label: _filtroMesDespesa != null
                      ? DateFormat('MMM/yyyy', 'pt_BR')
                          .format(_filtroMesDespesa!)
                      : 'Todos os meses',
                  icon: LucideIcons.calendarDays,
                  isActive: _filtroMesDespesa != null,
                  isDark: isDark,
                  onTap: () => _mostrarSeletorMes(
                    onSelected: (dt) =>
                        setState(() => _filtroMesDespesa = dt),
                  ),
                ),
                if (hasFilters) ...[
                  const SizedBox(width: 8),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.statusError,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    onPressed: () => setState(() {
                      _filtroVeiculoPlaca = null;
                      _filtroTipoDespesa = null;
                      _filtroMesDespesa = null;
                    }),
                    icon: const Icon(LucideIcons.x, size: 14),
                    label: const Text(
                      'Limpar filtros',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          // ── Lista ──
          Expanded(
            child: BentoCard(
              padding: EdgeInsets.zero,
              child: despesas.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            hasFilters
                                ? LucideIcons.searchSlash
                                : LucideIcons.inbox,
                            size: 48,
                            color: isDark ? Colors.white24 : Colors.black26,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            hasFilters
                                ? 'Nenhum resultado para os filtros selecionados.'
                                : 'Nenhum registro encontrado.',
                            style: const TextStyle(
                              color: AppColors.textSecondaryLight,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: despesas.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (ctx, i) {
                        final d = despesas[i];
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 8,
                          ),
                          leading: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.atrOrange
                                  .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              d.tipo == 'Multa'
                                  ? LucideIcons.fileWarning
                                  : LucideIcons.wrench,
                              color: AppColors.atrOrange,
                              size: 20,
                            ),
                          ),
                          title: Text(
                            d.descricao.isEmpty ? d.tipo : d.descricao,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          subtitle: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.atrOrange
                                      .withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  d.tipo,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.atrOrange,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '${d.veiculoPlaca} • ${DateFormat('dd/MM/yyyy').format(d.data)}',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                          trailing: Text(
                            NumberFormat.currency(
                              locale: 'pt_BR',
                              symbol: r'R$',
                            ).format(d.valor),
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              color: AppColors.statusError,
                              fontSize: 15,
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  // ABA 3 — MULTAS
  // ─────────────────────────────────────────────────────────
  Widget _buildMultasTab(bool isDark) {
    final provider = context.watch<CustosProvider>();
    final multas = provider.despesas.where((d) => d.tipo == 'Multa').toList();

    return _buildListLayout(
      isDark: isDark,
      icon: LucideIcons.fileWarning,
      title: 'Gestão de Multas',
      subtitle: 'Registre as infrações associando ao veículo e motorista.',
      items: multas,
      onLancar: () => _lancarNovaDespesa(tipo: 'Multa'),
    );
  }

  // ─────────────────────────────────────────────────────────
  // LAYOUT REUTILIZÁVEL PARA ABAS 2 E 3
  // ─────────────────────────────────────────────────────────
  Widget _buildListLayout({
    required bool isDark,
    required IconData icon,
    required String title,
    required String subtitle,
    required List<DespesaItem> items,
    required VoidCallback onLancar,
  }) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header da aba
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.atrOrange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: AppColors.atrOrange, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: isDark ? Colors.white54 : Colors.black54,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.atrOrange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: onLancar,
                icon: const Icon(LucideIcons.plus, size: 18),
                label: const Text(
                  'Novo Lançamento',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Lista
          Expanded(
            child: BentoCard(
              padding: EdgeInsets.zero,
              child: items.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            LucideIcons.inbox,
                            size: 48,
                            color: isDark ? Colors.white24 : Colors.black26,
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Nenhum registro encontrado.',
                            style: TextStyle(
                              color: AppColors.textSecondaryLight,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (ctx, i) {
                        final d = items[i];
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 8,
                          ),
                          leading: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.atrOrange.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              d.tipo == 'Multa'
                                  ? LucideIcons.fileWarning
                                  : LucideIcons.wrench,
                              color: AppColors.atrOrange,
                              size: 20,
                            ),
                          ),
                          title: Text(
                            d.descricao.isEmpty ? d.tipo : d.descricao,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          subtitle: Text(
                            '${d.veiculoPlaca} • ${d.motorista} • ${DateFormat('dd/MM/yyyy').format(d.data)}',
                            style: const TextStyle(fontSize: 12),
                          ),
                          trailing: Text(
                            NumberFormat.currency(
                              locale: 'pt_BR',
                              symbol: r'R$',
                            ).format(d.valor),
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              color: AppColors.statusError,
                              fontSize: 15,
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  // LANÇAMENTO DE DESPESA (reutiliza ExpenseFormModal)
  // ─────────────────────────────────────────────────────────
  Future<void> _lancarNovaDespesa({String? tipo}) async {
    final newItem = await ExpenseFormModal.show(context, initialTipo: tipo);
    if (newItem != null && mounted) {
      context.read<CustosProvider>().addDespesa(newItem);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lançamento adicionado com sucesso!'),
        ),
      );
    }
  }

  // ─────────────────────────────────────────────────────────
  // HELPERS — chips + seletores de filtro
  // ─────────────────────────────────────────────────────────
  Widget _buildFilterChip({
    required String label,
    required IconData icon,
    required bool isActive,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isActive
              ? AppColors.atrOrange.withValues(alpha: 0.12)
              : (isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.black.withValues(alpha: 0.05)),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive
                ? AppColors.atrOrange.withValues(alpha: 0.4)
                : Colors.transparent,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isActive
                  ? AppColors.atrOrange
                  : (isDark ? Colors.white60 : Colors.black54),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight:
                    isActive ? FontWeight.w700 : FontWeight.normal,
                color: isActive
                    ? AppColors.atrOrange
                    : (isDark ? Colors.white60 : Colors.black54),
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              LucideIcons.chevronDown,
              size: 12,
              color: isActive
                  ? AppColors.atrOrange
                  : (isDark ? Colors.white38 : Colors.black38),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _mostrarSeletorVeiculo(List<VehicleData> frota) async {
    final placa = await showModalBottomSheet<String?>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Filtrar por Veículo',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(LucideIcons.truck),
              title: const Text('Todos os veículos'),
              trailing: _filtroVeiculoPlaca == null
                  ? const Icon(LucideIcons.check,
                      color: AppColors.atrOrange,)
                  : null,
              onTap: () => Navigator.pop(ctx, 'TODOS'),
            ),
            const Divider(height: 1),
            ...frota.map(
              (v) => ListTile(
                leading: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: v.cor1.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      v.placa.substring(0, 2),
                      style: TextStyle(
                        color: v.cor1,
                        fontWeight: FontWeight.w900,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ),
                title: Text(v.placa),
                subtitle:
                    Text(v.nome, style: const TextStyle(fontSize: 12)),
                trailing: _filtroVeiculoPlaca == v.placa
                    ? const Icon(LucideIcons.check,
                        color: AppColors.atrOrange,)
                    : null,
                onTap: () => Navigator.pop(ctx, v.placa),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
    if (placa != null && mounted) {
      setState(() =>
          _filtroVeiculoPlaca = placa == 'TODOS' ? null : placa,);
    }
  }

  Future<void> _mostrarSeletorTipo() async {
    const tipos = ['Manutenção', 'Revisão', 'Outros'];
    final tipo = await showModalBottomSheet<String?>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Filtrar por Tipo',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(LucideIcons.tag),
              title: const Text('Todos os tipos'),
              trailing: _filtroTipoDespesa == null
                  ? const Icon(LucideIcons.check,
                      color: AppColors.atrOrange,)
                  : null,
              onTap: () => Navigator.pop(ctx, 'TODOS'),
            ),
            const Divider(height: 1),
            ...tipos.map(
              (t) => ListTile(
                leading: const Icon(LucideIcons.wrench),
                title: Text(t),
                trailing: _filtroTipoDespesa == t
                    ? const Icon(LucideIcons.check,
                        color: AppColors.atrOrange,)
                    : null,
                onTap: () => Navigator.pop(ctx, t),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
    if (tipo != null && mounted) {
      setState(
          () => _filtroTipoDespesa = tipo == 'TODOS' ? null : tipo,);
    }
  }

  Future<void> _mostrarSeletorMes({
    required ValueChanged<DateTime?> onSelected,
  }) async {
    final now = DateTime.now();
    final meses = List.generate(
      12,
      (i) => DateTime(now.year, now.month - i),
    );
    final mes = await showModalBottomSheet<DateTime?>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Filtrar por Mês',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(LucideIcons.calendar),
              title: const Text('Todos os meses'),
              onTap: () => Navigator.pop(ctx),
            ),
            const Divider(height: 1),
            SizedBox(
              height: 240,
              child: ListView.builder(
                itemCount: meses.length,
                itemBuilder: (_, i) {
                  final m = meses[i];
                  final label =
                      DateFormat('MMMM yyyy', 'pt_BR').format(m);
                  return ListTile(
                    leading: const Icon(LucideIcons.calendar),
                    title: Text(label),
                    onTap: () => Navigator.pop(ctx, m),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
    if (mounted) onSelected(mes);
  }
}
