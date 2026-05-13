import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/app_logger.dart';
import '../../core/constants.dart';
import '../../core/widgets/atr_page_background.dart';
import '../../core/widgets/atr_top_bar.dart';
import '../../core/widgets/app_sidebar.dart';
import '../../core/widgets/atr_button.dart';
import '../../core/widgets/bento_card.dart';
import '../../core/data/fleet_data.dart';
import '../../core/services/audit_service.dart';
import '../../core/services/supabase_service.dart';
import '../custos/expenses/expense_form_modal.dart';
import '../custos/custos_provider.dart';

// ═══════════════════════════════════════════════════════════════════
// FrotaDashboardScreen — Tela exclusiva para o login "Frota"
//
// Responsabilidade única: permitir ao funcionário de frota:
//   1. Atualizar KM semanal (pendências com contagem de dias)
//   2. Lançar despesas / manutenções
//   3. Lançar multas associando veículo + motorista

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

  // ── Estado — aba Multas ──
  List<Map<String, dynamic>> _multasRecords = [];
  bool _loadingMultas = false;
  List<Map<String, dynamic>> _veiculosOptions = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadMultas();
      _loadVeiculosOptions();
    });
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
        body: AtrPageBackground(
          grid: true,
          child: Column(
          children: [
            // ── Header ──
            Builder(builder: (ctx) {
              final frota = context.read<FleetRepository>().frota;
              final pendentes = frota
                  .where((v) => !_foiAtualizadoNaSemana(v.ultimaAtualizacaoKm))
                  .length;
              return AtrTopBar(
                title: 'Controle de Frota',
                subtitle: 'Semana fecha em $_diasRestantesSemana dia(s)',
                actions: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: pendentes > 0
                                ? AppColors.statusWarning
                                : AppColors.statusSuccess,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ).animate().fadeIn(duration: 400.ms).moveY(begin: -8, end: 0);
            }),
            // ── TabBar ──
            Container(
              color: isDark ? AppColors.atrNavyDarker : Colors.white,
              child: TabBar(
                controller: _tabController,
                labelColor: AppColors.atrOrange,
                unselectedLabelColor: isDark ? AppColors.textSecondaryDark : Colors.black54,
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
      ),
    );
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
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: isDark ? AppColors.textSecondaryDark : Colors.black54,
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
                      AtrPrimaryButton(
                        label: 'Atualizar KM',
                        icon: LucideIcons.edit2,
                        onPressed: () => _showUpdateKmDialog(v),
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
          AtrGhostButton(
            label: 'Cancelar',
            onPressed: () => Navigator.pop(ctx, false),
          ),
          const SizedBox(width: 8),
          AtrPrimaryButton(
            label: 'Confirmar',
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final novoKm = int.tryParse(ctrl.text) ?? v.kmAtual.toInt();

      // Atualiza estado local imediatamente para UX responsiva
      context
          .read<FleetRepository>()
          .updateVehicleKm(placa: v.placa, km: novoKm.toDouble());

      // Persiste no Supabase de forma assíncrona
      final registradoPor = AuditService.currentTenantId != null
          ? (AuditService.currentTenantId!)
          : 'frota';
      FleetSupabaseService.updateVehicleKm(
        placa: v.placa,
        km: novoKm,
        registradoPor: registradoPor,
      ).then((_) {
        AuditService.log(
          action: AuditAction.atualizarKm,
          entity: AuditEntity.veiculo,
          entityId: v.placa,
          payload: {'km': novoKm, 'placa': v.placa},
        );
      }).catchError((Object err) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: Colors.red.shade700,
              content: Text('Erro ao salvar KM no servidor: $err'),
            ),
          );
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'KM do ${v.placa} atualizado para ${NumberFormat('#,###', 'pt_BR').format(novoKm)} km',
            ),
          ),
        );
      }
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
            d.tipo == 'Manutenção' || d.tipo == 'Revisão' || d.tipo == 'Outros')
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
              d.data.month == _filtroMesDespesa!.month)
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
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: hasFilters
                              ? AppColors.atrOrange
                              : (isDark ? AppColors.textSecondaryDark : Colors.black54),
                          fontWeight: hasFilters
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              AtrPrimaryButton(
                label: 'Novo Lançamento',
                icon: LucideIcons.plus,
                onPressed: () => _lancarNovaDespesa(tipo: 'Manutenção'),
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
                  AtrGhostButton(
                    label: 'Limpar filtros',
                    icon: LucideIcons.x,
                    onPressed: () => setState(() {
                      _filtroVeiculoPlaca = null;
                      _filtroTipoDespesa = null;
                      _filtroMesDespesa = null;
                    }),
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
  // ABA 3 — MULTAS (tabela dedicada `multas`, não mais `despesas`)
  // ─────────────────────────────────────────────────────────
  Widget _buildMultasTab(bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
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
                    child: const Icon(LucideIcons.fileWarning, color: AppColors.atrOrange, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Gestão de Multas',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Registre as infrações de trânsito associando ao veículo.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: isDark ? AppColors.textSecondaryDark : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              AtrPrimaryButton(
                label: 'Lançar Multa',
                icon: LucideIcons.plus,
                onPressed: _showAddMultaDialog,
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Lista
          Expanded(
            child: _loadingMultas
                ? const Center(child: CircularProgressIndicator())
                : BentoCard(
                    padding: EdgeInsets.zero,
                    child: _multasRecords.isEmpty
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
                                  'Nenhuma multa registrada.',
                                  style: TextStyle(color: AppColors.textSecondaryLight),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            itemCount: _multasRecords.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (ctx, i) {
                              final m = _multasRecords[i];
                              final veiculo = m['veiculos'] as Map<String, dynamic>?;
                              final placa = veiculo?['placa'] as String? ?? '';
                              final modelo = veiculo?['modelo'] as String? ?? '';
                              final descricao = m['descricao'] as String? ?? '';
                              final valor = (m['valor'] as num?)?.toDouble() ?? 0.0;
                              final dataInfracao = _parseDate(m['data_infracao']);
                              final dataVencimento = _parseDate(m['data_vencimento']);
                              final status = m['status_pagamento'] as String? ?? 'Pendente';
                              final isPago = status == 'Pago';

                              return ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                                leading: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: isPago
                                        ? AppColors.statusSuccess.withValues(alpha: 0.1)
                                        : AppColors.statusError.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    isPago ? LucideIcons.checkCircle2 : LucideIcons.fileWarning,
                                    color: isPago ? AppColors.statusSuccess : AppColors.statusError,
                                    size: 20,
                                  ),
                                ),
                                title: Text(
                                  placa + (modelo.isNotEmpty ? ' ($modelo)' : ''),
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (descricao.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(bottom: 4),
                                        child: Text(descricao, style: const TextStyle(fontSize: 12)),
                                      ),
                                    Row(
                                      children: [
                                        _buildMultaInfoBadge(
                                          icon: LucideIcons.calendar,
                                          label: dataInfracao != null
                                              ? 'Infração: ${DateFormat('dd/MM/yyyy').format(dataInfracao)}'
                                              : 'Sem data',
                                        ),
                                        const SizedBox(width: 8),
                                        _buildMultaInfoBadge(
                                          icon: LucideIcons.calendarClock,
                                          label: dataVencimento != null
                                              ? 'Vence: ${DateFormat('dd/MM/yyyy').format(dataVencimento)}'
                                              : 'Sem vencimento',
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          NumberFormat.currency(locale: 'pt_BR', symbol: r'R$').format(valor),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                            color: AppColors.statusError,
                                            fontSize: 15,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        GestureDetector(
                                          onTap: () => _toggleMultaStatus(m),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: isPago
                                                  ? AppColors.statusSuccess.withValues(alpha: 0.15)
                                                  : AppColors.statusWarning.withValues(alpha: 0.15),
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(
                                                color: isPago
                                                    ? AppColors.statusSuccess.withValues(alpha: 0.3)
                                                    : AppColors.statusWarning.withValues(alpha: 0.3),
                                              ),
                                            ),
                                            child: Text(
                                              status,
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                                color: isPago ? AppColors.statusSuccess : AppColors.statusWarning,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
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

  /// Mini-badge informativo para datas na linha da multa.
  Widget _buildMultaInfoBadge({required IconData icon, required String label}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11, color: AppColors.textMutedDark),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textMutedDark)),
      ],
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
  // MULTAS — carregamento, toggle e formulário inline
  // ─────────────────────────────────────────────────────────

  Future<void> _loadMultas() async {
    if (_loadingMultas) return;
    setState(() => _loadingMultas = true);
    try {
      final tenantId = Supabase.instance.client.auth.currentUser
              ?.appMetadata['tenant_id'] as String? ??
          kDefaultTenantId;
      final data = await Supabase.instance.client
          .from('multas')
          .select('*, veiculos(placa, modelo)')
          .eq('tenant_id', tenantId)
          .order('data_vencimento', ascending: false);
      if (mounted) {
        setState(() {
          _multasRecords = (data as List<dynamic>).cast<Map<String, dynamic>>();
          _loadingMultas = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingMultas = false);
      }
    }
  }

  Future<void> _loadVeiculosOptions() async {
    try {
      final tenantId = Supabase.instance.client.auth.currentUser
              ?.appMetadata['tenant_id'] as String? ??
          kDefaultTenantId;
      final data = await Supabase.instance.client
          .from('veiculos')
          .select('id, placa, marca, modelo')
          .eq('tenant_id', tenantId)
          .order('placa');
      if (mounted) {
        setState(() {
          _veiculosOptions =
              (data as List<dynamic>).cast<Map<String, dynamic>>();
        });
      }
    } catch (e) { AppLogger.warning('FrotaDashboard veiculosOptions: $e'); }
  }

  Future<void> _toggleMultaStatus(Map<String, dynamic> multa) async {
    final currentStatus = multa['status_pagamento'] as String? ?? 'Pendente';
    final novoStatus = currentStatus == 'Pago' ? 'Pendente' : 'Pago';
    final id = multa['id'] as String;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Alterar Status'),
        content: Text('Marcar multa como "$novoStatus"?'),
        actions: [
          AtrGhostButton(
              label: 'Cancelar', onPressed: () => Navigator.pop(ctx, false)),
          const SizedBox(width: 8),
          AtrPrimaryButton(
              label: 'Confirmar', onPressed: () => Navigator.pop(ctx, true)),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final updates = <String, dynamic>{
          'status_pagamento': novoStatus,
        };
        if (novoStatus == 'Pago') {
          updates['data_pagamento'] =
              DateFormat('yyyy-MM-dd').format(DateTime.now());
        } else {
          updates['data_pagamento'] = null;
        }
        await Supabase.instance.client
            .from('multas')
            .update(updates)
            .eq('id', id);
        await _loadMultas();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro ao atualizar status: $e')),
          );
        }
      }
    }
  }

  Future<void> _showAddMultaDialog() async {
    if (_veiculosOptions.isEmpty) {
      await _loadVeiculosOptions();
      if (_veiculosOptions.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Nenhum veículo disponível.')),
          );
        }
        return;
      }
    }

    String? selectedVeiculoId;
    final anoCtrl =
        TextEditingController(text: DateTime.now().year.toString());
    final mesCtrl = TextEditingController();
    final valorCtrl = TextEditingController();
    final descricaoCtrl = TextEditingController();
    DateTime dataInfracao = DateTime.now();
    DateTime dataVencimento = DateTime.now().add(const Duration(days: 30));

    const meses = [
      'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
      'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro',
    ];

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(LucideIcons.fileWarning, color: AppColors.atrOrange),
              SizedBox(width: 10),
              Expanded(
                  child: Text('Lançar Multa',
                      style: TextStyle(fontSize: 18))),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Veículo
                DropdownButtonFormField<String>(
                  initialValue: selectedVeiculoId,
                  decoration: _multaInputDecoration('Veículo', LucideIcons.truck),
                  items: _veiculosOptions.map((v) {
                    final placa = v['placa'] as String? ?? '';
                    final marca = v['marca'] as String? ?? '';
                    final modelo = v['modelo'] as String? ?? '';
                    return DropdownMenuItem<String>(
                      value: v['id'] as String,
                      child: Text(
                        '$placa - $marca $modelo'.trim(),
                        style: const TextStyle(fontSize: 13),
                      ),
                    );
                  }).toList(),
                  onChanged: (v) => setDialogState(() => selectedVeiculoId = v),
                ),
                const SizedBox(height: 16),
                // Ano + Mês
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: anoCtrl,
                        keyboardType: TextInputType.number,
                        decoration:
                            _multaInputDecoration('Ano Ref.', LucideIcons.calendar),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue:
                            meses.contains(mesCtrl.text) ? mesCtrl.text : null,
                        decoration:
                            _multaInputDecoration('Mês', LucideIcons.calendarDays),
                        items: meses
                            .map((m) => DropdownMenuItem(
                                value: m,
                                child: Text(m,
                                    style: const TextStyle(fontSize: 13))))
                            .toList(),
                        onChanged: (v) {
                          mesCtrl.text = v ?? '';
                          setDialogState(() {});
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Valor
                TextField(
                  controller: valorCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: _multaInputDecoration('Valor (R\$)', LucideIcons.dollarSign),
                ),
                const SizedBox(height: 16),
                // Descrição
                TextField(
                  controller: descricaoCtrl,
                  maxLines: 2,
                  decoration: _multaInputDecoration('Descrição', LucideIcons.fileText),
                ),
                const SizedBox(height: 16),
                // Datas
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: ctx,
                            initialDate: dataInfracao,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2030),
                          );
                          if (picked != null) {
                            setDialogState(() => dataInfracao = picked);
                          }
                        },
                        child: InputDecorator(
                          decoration: _multaInputDecoration(
                              'Data Infração', LucideIcons.calendar),
                          child: Text(
                            DateFormat('dd/MM/yyyy').format(dataInfracao),
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: ctx,
                            initialDate: dataVencimento,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2030),
                          );
                          if (picked != null) {
                            setDialogState(() => dataVencimento = picked);
                          }
                        },
                        child: InputDecorator(
                          decoration: _multaInputDecoration(
                              'Data Vencimento', LucideIcons.calendarClock),
                          child: Text(
                            DateFormat('dd/MM/yyyy').format(dataVencimento),
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            AtrGhostButton(
                label: 'Cancelar', onPressed: () => Navigator.pop(ctx, false)),
            const SizedBox(width: 8),
            AtrPrimaryButton(
              label: 'Salvar',
              onPressed: () {
                if (selectedVeiculoId == null) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('Selecione um veículo.')),
                  );
                  return;
                }
                if (valorCtrl.text.isEmpty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('Informe o valor da multa.')),
                  );
                  return;
                }
                Navigator.pop(ctx, true);
              },
            ),
          ],
        ),
      ),
    );

    if (confirm == true && mounted) {
      try {
        final tenantId = Supabase.instance.client.auth.currentUser
                ?.appMetadata['tenant_id'] as String? ??
            kDefaultTenantId;
        await Supabase.instance.client.from('multas').insert({
          'veiculo_id': selectedVeiculoId,
          'ano_referencia':
              int.tryParse(anoCtrl.text) ?? DateTime.now().year,
          'mes': mesCtrl.text.isNotEmpty
              ? mesCtrl.text
              : meses[DateTime.now().month - 1],
          'valor':
              double.tryParse(valorCtrl.text.replaceAll(',', '.')) ?? 0.0,
          'descricao': descricaoCtrl.text,
          'data_infracao': DateFormat('yyyy-MM-dd').format(dataInfracao),
          'data_vencimento':
              DateFormat('yyyy-MM-dd').format(dataVencimento),
          'status_pagamento': 'Pendente',
          'tenant_id': tenantId,
        });
        await _loadMultas();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Multa registrada com sucesso!')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro ao registrar multa: $e')),
          );
        }
      }
    }
  }

  InputDecoration _multaInputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, size: 18),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    );
  }

  DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
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
                      color: AppColors.atrOrange)
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
                        color: AppColors.atrOrange)
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
          _filtroVeiculoPlaca = placa == 'TODOS' ? null : placa);
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
                      color: AppColors.atrOrange)
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
                        color: AppColors.atrOrange)
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
          () => _filtroTipoDespesa = tipo == 'TODOS' ? null : tipo);
    }
  }

  Future<void> _mostrarSeletorMes({
    required ValueChanged<DateTime?> onSelected,
  }) async {
    final now = DateTime.now();
    final meses = List.generate(
      12,
      (i) => DateTime(now.year, now.month - i, 1),
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
              onTap: () => Navigator.pop(ctx, null),
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
