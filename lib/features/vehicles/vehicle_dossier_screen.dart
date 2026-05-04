import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../../core/widgets/app_sidebar.dart';
import '../../core/widgets/bento_card.dart';
import '../../core/widgets/status_badge.dart';
import '../../core/theme/app_colors.dart';
import '../../core/data/fleet_data.dart';

class _VehicleHistoryEntry {
  final DateTime data;
  final String titulo;
  final String descricao;
  final double valor;
  final IconData icone;
  final Color cor;
  final int? kmNoServico;

  const _VehicleHistoryEntry({
    required this.data,
    required this.titulo,
    required this.descricao,
    required this.valor,
    required this.icone,
    required this.cor,
    this.kmNoServico,
  });
}

class VehicleDossierScreen extends StatefulWidget {
  final String plateId;
  const VehicleDossierScreen({super.key, required this.plateId});

  @override
  State<VehicleDossierScreen> createState() => _VehicleDossierScreenState();
}

class _VehicleDossierScreenState extends State<VehicleDossierScreen> {
  @override
  Widget build(BuildContext context) {
    final repo = context.watch<FleetRepository>();
    final v = repo.getVehicleByPlate(widget.plateId);
    if (v == null) {
      return AppSidebar(
          child: Scaffold(
              body: Center(
                  child: Text('Veículo ${widget.plateId} não encontrado'),),),);
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final width = MediaQuery.of(context).size.width;
    final isCompact = width < 1100;

    return AppSidebar(
      child: Scaffold(
        body: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(width < 600 ? 16.0 : 32.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildBreadcrumbs(context, v),
                const SizedBox(height: 8),
                _buildHeader(context, v, width),
                const SizedBox(height: 32),
                _buildKPIs(context, v, width),
                const SizedBox(height: 32),
                if (isCompact) ...[
                  _buildProfile(context, v, isDark),
                  const SizedBox(height: 24),
                  _buildComplianceHub(context, v, isDark, width),
                  const SizedBox(height: 24),
                  _buildAssetIntelligence(context, v, isDark),
                  const SizedBox(height: 24),
                  _buildMaintenanceHistory(context, v, isDark),
                ] else ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                          flex: 3,
                          child: Column(
                            children: [
                              _buildProfile(context, v, isDark),
                              const SizedBox(height: 24),
                              _buildComplianceHub(context, v, isDark, width),
                            ],
                          ),),
                      const SizedBox(width: 24),
                      Expanded(
                          flex: 4,
                          child: Column(
                            children: [
                              _buildAssetIntelligence(context, v, isDark),
                              const SizedBox(height: 24),
                              _buildMaintenanceHistory(context, v, isDark),
                            ],
                          ),),
                    ],
                  ),
                ],
                if (v.isFinanciado) ...[
                  const SizedBox(height: 32),
                  _buildFinancingCard(context, v, isDark, width),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBreadcrumbs(BuildContext context, VehicleData v) {
    return Row(
      children: [
        Text('Home',
            style: TextStyle(
                color: AppColors.textSecondaryLight.withValues(alpha: 0.6),
                fontSize: 12,),),
        Icon(LucideIcons.chevronRight,
            size: 12,
            color: AppColors.textSecondaryLight.withValues(alpha: 0.4),),
        Text('Veículos',
            style: TextStyle(
                color: AppColors.textSecondaryLight.withValues(alpha: 0.6),
                fontSize: 12,),),
        Icon(LucideIcons.chevronRight,
            size: 12,
            color: AppColors.textSecondaryLight.withValues(alpha: 0.4),),
        Text(v.placa,
            style: const TextStyle(
                color: AppColors.atrOrange,
                fontSize: 12,
                fontWeight: FontWeight.bold,),),
      ],
    );
  }

  Widget _buildHeader(BuildContext context, VehicleData v, double width) {
    final isMobile = width < 600;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [v.cor1, v.cor2]),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(LucideIcons.car, color: Colors.white, size: 22),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(mainAxisSize: MainAxisSize.min, children: [
                Flexible(
                    child: Text(v.nome,
                        style: Theme.of(context)
                            .textTheme
                            .displayLarge
                            ?.copyWith(fontSize: isMobile ? 20 : 24),
                        overflow: TextOverflow.ellipsis,),),
                const SizedBox(width: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: Theme.of(context).dividerTheme.color!,),),
                  child: Text(v.placa,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                          letterSpacing: 1,),),
                ),
              ],),
              const SizedBox(height: 4),
              Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(LucideIcons.user,
                    size: 13, color: AppColors.textSecondaryLight,),
                const SizedBox(width: 4),
                Text(v.motorista,
                    style: Theme.of(context).textTheme.bodyMedium,),
                const SizedBox(width: 16),
                const Icon(LucideIcons.gauge,
                    size: 13, color: AppColors.textSecondaryLight,),
                const SizedBox(width: 4),
                Text(formatKm(v.kmAtual),
                    style: Theme.of(context).textTheme.bodyMedium,),
              ],),
            ],
          ),
        ),
        _buildStatusSelector(context, v),
        if (v.isFinanciado) ...[
          const SizedBox(width: 12),
          const StatusBadge(text: 'FINANCIADO', type: BadgeType.info),
        ],
      ],
    );
  }

  Widget _buildStatusSelector(BuildContext context, VehicleData v) {
    return PopupMenuButton<VehicleStatus>(
      onSelected: (VehicleStatus status) {
        final updated = context.read<FleetRepository>().updateVehicleStatus(
              placa: v.placa,
              status: status,
            );
        if (!updated && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content:
                    Text('Não foi possível atualizar o status do veículo.'),),
          );
          return;
        }
      },
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      itemBuilder: (BuildContext context) {
        return VehicleStatus.values.map((VehicleStatus choice) {
          return PopupMenuItem<VehicleStatus>(
            value: choice,
            child: Text(choice.label,
                style:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),),
          );
        }).toList();
      },
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: StatusBadge(
            text: v.status.label,
            type: v.status == VehicleStatus.emRota
                ? BadgeType.success
                : (v.status == VehicleStatus.emOficina
                    ? BadgeType.error
                    : BadgeType.warning),),
      ),
    );
  }

  Widget _buildKPIs(BuildContext context, VehicleData v, double width) {
    final totalIpva = _sumByCategoria(v, 'IPVA');
    final totalSeguro = _sumByCategoria(v, 'Seguro');
    final totalMultas = _sumByCategoria(v, 'Multa');
    final lucroColor = v.lucroPrejuizoAteAgora >= 0
        ? AppColors.statusSuccess
        : AppColors.statusError;
    final lucroLabel = v.lucroPrejuizoAteAgora >= 0 ? 'Lucro' : 'Prejuízo';
    final primeiroReceb =
        v.dataPrimeiroRecebimento != null ? formatDate(v.dataPrimeiroRecebimento!) : '--';
    final primeiroGasto =
        v.dataPrimeiroGasto != null ? formatDate(v.dataPrimeiroGasto!) : '--';

    if (width < 1100) {
      return Wrap(
        spacing: 20,
        runSpacing: 20,
        children: [
          _kpi(
              context,
              'KM Rodados',
              formatKm(v.kmAtual),
              '${v.kmPorMes.toInt()} km/mês',
              LucideIcons.gauge,
              AppColors.statusInfo,
              0,
              width,),
              _kpi(
                context,
                '$lucroLabel até Agora',
                formatCurrency(v.lucroPrejuizoAteAgora),
                'Recebe desde $primeiroReceb | Gasta desde $primeiroGasto',
                v.lucroPrejuizoAteAgora >= 0
                  ? LucideIcons.trendingUp
                  : LucideIcons.trendingDown,
                lucroColor,
                100,
                width,),
          _kpi(
              context,
              'Custo Manutenção',
              formatCurrency(v.custoTotalManutencao),
                '${v.totalRevisoes} revisões | Próx. revisão em ${formatKm(v.kmParaProxRevisao)}',
              LucideIcons.receipt,
              AppColors.statusError,
              200,
              width,),
          _kpi(
              context,
                'Gasto Total Veículo',
                formatCurrency(v.gastoTotalVeiculoKpi),
                'IPVA ${formatCurrency(totalIpva)} | Seguro ${formatCurrency(totalSeguro)} | Multas ${formatCurrency(totalMultas)}',
                LucideIcons.wallet,
                AppColors.atrOrange,
              300,
              width,),
        ],
      );
    }

    return Row(
      children: [
        Expanded(
            child: _kpi(
                context,
                'KM Rodados',
                formatKm(v.kmAtual),
                '${v.kmPorMes.toInt()} km/mês',
                LucideIcons.gauge,
                AppColors.statusInfo,
                0,
                width,
                useExpanded: true,),),
        const SizedBox(width: 20),
        Expanded(
            child: _kpi(
                context,
            '$lucroLabel até Agora',
            formatCurrency(v.lucroPrejuizoAteAgora),
            'Recebe desde $primeiroReceb | Gasta desde $primeiroGasto',
            v.lucroPrejuizoAteAgora >= 0
              ? LucideIcons.trendingUp
              : LucideIcons.trendingDown,
            lucroColor,
                100,
                width,
                useExpanded: true,),),
        const SizedBox(width: 20),
        Expanded(
            child: _kpi(
                context,
                'Custo Manutenção',
                formatCurrency(v.custoTotalManutencao),
                '${v.totalRevisoes} revisões | Próx. revisão em ${formatKm(v.kmParaProxRevisao)}',
                LucideIcons.receipt,
                AppColors.statusError,
                200,
                width,
                useExpanded: true,),),
        const SizedBox(width: 20),
        Expanded(
            child: _kpi(
                context,
              'Gasto Total Veículo',
              formatCurrency(v.gastoTotalVeiculoKpi),
              'IPVA ${formatCurrency(totalIpva)} | Seguro ${formatCurrency(totalSeguro)} | Multas ${formatCurrency(totalMultas)}',
              LucideIcons.wallet,
              AppColors.atrOrange,
                300,
                width,
                useExpanded: true,),),
      ],
    );
  }

  Widget _kpi(BuildContext context, String title, String value, String sub,
      IconData icon, Color color, int delay, double width,
      {bool useExpanded = false,}) {
    double itemWidth = (width - 64 - 60) / 4;
    if (width < 1100) itemWidth = (width - 64 - 20) / 2;
    if (width < 600) itemWidth = width - 32;

    return SizedBox(
      width: useExpanded ? null : itemWidth,
      child: BentoCard(
        animationDelay: delay,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Flexible(
                child: Text(title,
                    style: Theme.of(context).textTheme.bodyMedium,
                    overflow: TextOverflow.ellipsis,),),
            Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),),
                child: Icon(icon, color: color, size: 18),),
          ],),
          const SizedBox(height: 12),
          FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(value,
                  style: Theme.of(context)
                      .textTheme
                      .displayLarge
                      ?.copyWith(fontSize: 24, color: color),),),
          const SizedBox(height: 4),
          Text(sub,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600),),
        ],),
      ),
    );
  }

  Widget _buildProfile(BuildContext context, VehicleData v, bool isDark) {
    return BentoCard(
      animationDelay: 400,
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Container(
            height: 200,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
              gradient: v.imagemAsset == null
                  ? LinearGradient(
                      colors: [v.cor1, v.cor2],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,)
                  : null,
              image: v.imagemAsset != null
                  ? DecorationImage(
                      image: AssetImage(v.imagemAsset!), fit: BoxFit.cover,)
                  : null,
            ),
            child: Container(
              decoration: BoxDecoration(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(20)),
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.6],
                ),
              ),
              alignment: Alignment.bottomLeft,
              padding: const EdgeInsets.all(24),
              child: v.imagemAsset == null
                  ? Icon(LucideIcons.car,
                      size: 48, color: Colors.white.withValues(alpha: 0.5),)
                  : null,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(children: [
              _profileRow(context, 'Veículo', v.nome),
              _profileRow(context, 'Placa', v.placa),
              _profileRow(context, 'Motorista', v.motorista),
              _profileRow(context, 'Telefone', v.telefoneMotorista),
              _profileRow(context, 'KM Atual', formatKm(v.kmAtual)),
              _profileRow(
                  context, 'Meses em Serviço', '${v.mesesEmServico} meses',),
              _profileRow(context, 'Custo Total Manut.',
                  formatCurrency(v.custoTotalManutencao),),
              if (v.isFinanciado) ...[
                const SizedBox(height: 8),
                Divider(
                    color:
                        isDark ? AppColors.borderDark : AppColors.borderLight,),
                const SizedBox(height: 8),
                _profileRow(context, 'Financiado',
                    'Sim - ${v.financiamento!.totalParcelas}x',),
                _profileRow(context, 'Parcela',
                    formatCurrency(v.financiamento!.valorParcela),),
                _profileRow(context, 'Progresso',
                    '${(v.financiamento!.progressoFinanciamento * 100).toStringAsFixed(0)}%',),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      context.go('/financial-admin/${v.placa}');
                    },
                    icon: const Icon(LucideIcons.landmark, size: 16),
                    label: const Text('Ver Financiamento'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.atrOrange,
                      side: BorderSide(
                          color: AppColors.atrOrange.withValues(alpha: 0.3),),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ],),
          ),
        ],
      ),
    );
  }

  Widget _profileRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          Flexible(
              child: Text(value,
                  style: Theme.of(context)
                      .textTheme
                      .bodyLarge
                      ?.copyWith(fontWeight: FontWeight.w600),
                  textAlign: TextAlign.right,
                  overflow: TextOverflow.ellipsis,),),
        ],
      ),
    );
  }

  Widget _buildMaintenanceHistory(
      BuildContext context, VehicleData v, bool isDark,) {
    final historico = _buildCostHistory(v);
    return BentoCard(
      animationDelay: 500,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Histórico de Gastos do Veículo',
                  style: Theme.of(context).textTheme.titleLarge,),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                    color: AppColors.atrOrange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),),
                child: Text(
                    '${historico.length} lançamentos | ${formatCurrency(v.gastoTotalVeiculoKpi)}',
                    style: const TextStyle(
                        color: AppColors.atrOrange,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,),),
              ),
            ],
          ),
          const SizedBox(height: 24),
          ...historico.map((m) => _buildMaintenanceItem(context, m, isDark)),
          if (historico.isEmpty)
            Center(
                child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text('Nenhum gasto não cíclico registrado',
                  style: Theme.of(context).textTheme.bodyMedium,),
            ),),
        ],
      ),
    );
  }

  double _sumByCategoria(VehicleData v, String categoria) {
    return v.gastosNaoCiclicos
        .where((e) => e.categoria.toLowerCase() == categoria.toLowerCase())
        .fold(0.0, (s, e) => s + e.valor);
  }

  List<_VehicleHistoryEntry> _buildCostHistory(VehicleData v) {
    final manutencoes = v.manutencoes
        .map(
          (m) => _VehicleHistoryEntry(
            data: m.data,
            titulo: m.tipo,
            descricao: m.descricao,
            valor: m.custo,
            icone: LucideIcons.wrench,
            cor: AppColors.atrOrange,
            kmNoServico: m.kmNoServico,
          ),
        )
        .toList();

    final adicionais = v.gastosNaoCiclicos
        .map(
          (c) => _VehicleHistoryEntry(
            data: c.data,
            titulo: c.categoria,
            descricao: c.descricao,
            valor: c.valor,
            icone: c.categoria.toLowerCase() == 'multa'
                ? LucideIcons.alertTriangle
                : (c.categoria.toLowerCase() == 'seguro'
                    ? LucideIcons.shield
                    : LucideIcons.receipt),
            cor: c.categoria.toLowerCase() == 'multa'
                ? AppColors.statusError
                : (c.categoria.toLowerCase() == 'seguro'
                    ? AppColors.statusInfo
                    : AppColors.statusSuccess),
          ),
        )
        .toList();

    final todos = <_VehicleHistoryEntry>[...manutencoes, ...adicionais];
    todos.sort((a, b) => b.data.compareTo(a.data));
    return todos;
  }

  Widget _buildMaintenanceItem(
      BuildContext context, _VehicleHistoryEntry m, bool isDark,) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:
            isDark ? AppColors.surfaceElevatedDark : AppColors.backgroundLight,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: m.cor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(m.icone, size: 16, color: m.cor),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${m.titulo} • ${m.descricao}',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(LucideIcons.calendar,
                          size: 11, color: AppColors.textSecondaryLight,),
                      const SizedBox(width: 4),
                      Text(formatDate(m.data),
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(fontSize: 12),),
                    ],),
                    if (m.kmNoServico != null)
                      Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(LucideIcons.gauge,
                            size: 11, color: AppColors.textSecondaryLight,),
                        const SizedBox(width: 4),
                        Text(
                            '${m.kmNoServico.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (mt) => '${mt[1]}.')} km',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(fontSize: 12),),
                      ],),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
            Text(formatCurrency(m.valor),
              style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: AppColors.statusError,),),
        ],
      ),
    );
  }

  Widget _buildFinancingCard(
      BuildContext context, VehicleData v, bool isDark, double width,) {
    final f = v.financiamento!;
    return BentoCard(
      animationDelay: 600,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                  child: Text('Resumo do Financiamento',
                      style: Theme.of(context).textTheme.titleLarge,
                      overflow: TextOverflow.ellipsis,),),
              StatusBadge(
                  text:
                      '${(f.progressoFinanciamento * 100).toStringAsFixed(0)}% QUITADO',
                  type: f.progressoFinanciamento > 0.7
                      ? BadgeType.success
                      : BadgeType.info,),
            ],
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 20,
            runSpacing: 20,
            children: [
              _finStat(context, 'Valor Total', formatCurrency(f.valorTotal),
                  AppColors.textSecondaryLight, width,),
              _finStat(context, 'Entrada', formatCurrency(f.valorEntrada),
                  AppColors.statusWarning, width,),
              _finStat(context, 'Parcela (Price)',
                  formatCurrency(f.valorParcela), AppColors.statusError, width,),
              _finStat(
                  context,
                  'Pagas',
                  '${f.parcelasPagas}/${f.totalParcelas}',
                  AppColors.statusSuccess,
                  width,),
              _finStat(context, 'Falta Pagar', formatCurrency(f.totalRestante),
                  AppColors.statusWarning, width,),
              _finStat(context, 'Juros Total', formatCurrency(f.totalJuros),
                  AppColors.statusError, width,),
            ],
          ),
        ],
      ),
    );
  }

  Widget _finStat(BuildContext context, String label, String value, Color color,
      double width,) {
    double itemWidth = (width - 64 - 100) / 6;
    if (width < 1200) itemWidth = (width - 64 - 40) / 3;
    if (width < 600) itemWidth = (width - 64 - 20) / 2;

    return SizedBox(
      width: itemWidth,
      child: Column(
        children: [
          Text(label,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(fontSize: 11),
              textAlign: TextAlign.center,),
          const SizedBox(height: 6),
          FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(value,
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: color,),),),
        ],
      ),
    );
  }

  Widget _buildComplianceHub(
      BuildContext context, VehicleData v, bool isDark, double width,) {
    return BentoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.shieldCheck,
                  color: AppColors.statusSuccess, size: 18,),
              const SizedBox(width: 10),
              Text('Compliance Hub',
                  style: Theme.of(context).textTheme.titleLarge,),
            ],
          ),
          const SizedBox(height: 20),
          _docRow(context, 'IPVA 2026', v.vencimentoIPVA, isDark),
          _docRow(context, 'Seguro Auto', v.vencimentoSeguro, isDark),
          _docRow(context, 'Licenciamento', v.vencimentoLicenciamento, isDark),
        ],
      ),
    );
  }

  Widget _docRow(
      BuildContext context, String label, DateTime data, bool isDark,) {
    final hoje = DateTime.now();
    final dias = data.difference(hoje).inDays;
    final color = dias < 15
        ? AppColors.statusError
        : (dias < 30 ? AppColors.statusWarning : AppColors.statusSuccess);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
              child: Text(label,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 13,),),),
          Text(formatDate(data),
              style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white54 : Colors.black54,),),
          const SizedBox(width: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),),
            child: Text(
                dias < 0
                    ? 'Vencido'
                    : (dias == 0 ? 'Vence Hoje' : '$dias dias'),
                style: TextStyle(
                    color: color, fontWeight: FontWeight.bold, fontSize: 10,),),
          ),
        ],
      ),
    );
  }

  Widget _buildAssetIntelligence(
      BuildContext context, VehicleData v, bool isDark,) {
    return BentoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.brainCircuit,
                  color: AppColors.atrOrange, size: 20,),
              const SizedBox(width: 10),
              Text('Inteligência de Ativos',
                  style: Theme.of(context).textTheme.titleLarge,),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _intelStat(context, 'ROI Real', '${v.roi.toStringAsFixed(1)}%',
                  'Retorno s/ Investimento',),
              const SizedBox(width: 24),
              _intelStat(context, 'Lucro Gerado',
                  formatCurrency(v.lucroAbsoluto), 'Receita - Custos',),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.atrOrange.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
              border:
                  Border.all(color: AppColors.atrOrange.withValues(alpha: 0.1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('ANÁLISE DE SAÚDE OPERACIONAL ATR',
                    style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: AppColors.atrOrange,
                        fontSize: 10,
                        letterSpacing: 1,),),
                const SizedBox(height: 8),
                Text(v.sugestaoVenda,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14,),),
                const SizedBox(height: 4),
                Text(
                    'Baseado na depreciação acumulada vs custos de manutenção do período.',
                    style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white38 : Colors.black45,),),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _intelStat(
      BuildContext context, String label, String value, String sub,) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 11, color: AppColors.textSecondaryLight,),),
        Text(value,
            style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 18,
                color: AppColors.statusSuccess,),),
        Text(sub,
            style: const TextStyle(
                fontSize: 9, color: AppColors.textSecondaryLight,),),
      ],
    );
  }
}
