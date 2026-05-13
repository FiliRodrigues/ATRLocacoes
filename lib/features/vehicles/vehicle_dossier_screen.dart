import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/widgets/app_sidebar.dart';
import '../../core/widgets/atr_button.dart';
import '../../core/widgets/bento_card.dart';
import '../../core/widgets/status_badge.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/atr_page_background.dart';
import '../../core/data/fleet_data.dart';
import '../../core/data/custos_models.dart';
import '../../core/enums/maintenance_priority.dart';
import '../../core/services/relatorio_service.dart';
import '../custos/custos_provider.dart';
import '../custos/maintenance/maintenance_form_modal.dart';
import 'vehicle_form_modal.dart';

import '../../core/utils/export_csv_stub.dart'
    if (dart.library.html) '../../core/utils/export_csv_html.dart'
    if (dart.library.io) '../../core/utils/export_csv_io.dart';

class VehicleDossierScreen extends StatefulWidget {
  final String plateId;
  const VehicleDossierScreen({super.key, required this.plateId});

  @override
  State<VehicleDossierScreen> createState() => _VehicleDossierScreenState();
}

class _VehicleDossierScreenState extends State<VehicleDossierScreen> {
  bool _maintenanceExpanded = false;
  List<Map<String, dynamic>> _ipvaRecords = [];
  List<Map<String, dynamic>> _licenciamentoRecords = [];
  List<Map<String, dynamic>> _recebimentosRecords = [];
  List<Map<String, dynamic>> _segurosRecords = [];
  Map<String, List<Map<String, dynamic>>> _parcelasSeguroBySeguroId = {};

  @override
  void initState() {
    super.initState();
    _loadComplianceData();
  }

  Future<void> _loadComplianceData() async {
    final tenantId = Supabase.instance.client.auth.currentUser
        ?.appMetadata['tenant_id'] as String?;
    if (tenantId == null) return;
    final veicRow = await Supabase.instance.client
        .from('veiculos')
        .select('id')
        .eq('placa', widget.plateId)
        .eq('tenant_id', tenantId)
        .maybeSingle();
    final vid = veicRow?['id'] as String?;
    if (vid == null) return;
    final results = await Future.wait([
      Supabase.instance.client
          .from('ipva')
          .select('id, ano_referencia, valor_total, data_vencimento, data_pagamento, status_pagamento')
          .eq('veiculo_id', vid)
          .eq('tenant_id', tenantId)
          .order('data_vencimento', ascending: true),
      Supabase.instance.client
          .from('licenciamento')
          .select('id, ano_referencia, valor_total, data_vencimento, data_pagamento, status_pagamento')
          .eq('veiculo_id', vid)
          .eq('tenant_id', tenantId)
          .order('data_vencimento', ascending: true),
      Supabase.instance.client
          .from('seguros')
          .select('*')
          .eq('veiculo_id', vid)
          .eq('tenant_id', tenantId)
          .order('data_inicio', ascending: true),
    ]);
    final recebimentosData = await Supabase.instance.client
        .from('recebimentos')
        .select('*')
        .eq('veiculo_id', vid)
        .eq('tenant_id', tenantId)
        .order('data_vencimento');
    final segurosList = (results[2] as List<dynamic>).cast<Map<String, dynamic>>();
    final Map<String, List<Map<String, dynamic>>> parcelasBySeguro = {};
    for (final seguro in segurosList) {
      final seguroId = seguro['id'] as String;
      final parcelasData = await Supabase.instance.client
          .from('parcelas_seguro')
          .select('*')
          .eq('seguro_id', seguroId)
          .eq('tenant_id', tenantId)
          .order('numero_parcela');
      parcelasBySeguro[seguroId] = (parcelasData as List<dynamic>).cast<Map<String, dynamic>>();
    }
    if (!mounted) return;
    setState(() {
      _ipvaRecords = (results[0] as List<dynamic>).cast<Map<String, dynamic>>();
      _licenciamentoRecords = (results[1] as List<dynamic>).cast<Map<String, dynamic>>();
      _recebimentosRecords = (recebimentosData as List<dynamic>).cast<Map<String, dynamic>>();
      _segurosRecords = segurosList;
      _parcelasSeguroBySeguroId = parcelasBySeguro;
    });
  }

  Future<void> _togglePaymentStatus(String table, String recordId, String currentStatus) async {
    final novoStatus = currentStatus == 'Pago' ? 'Pendente' : 'Pago';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(currentStatus == 'Pago' ? 'Marcar como Pendente?' : 'Marcar como Pago?'),
        content: Text('Deseja alterar o status de pagamento para $novoStatus?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Confirmar')),
        ],
      ),
    );
    if (confirmed != true) return;
    final updates = <String, dynamic>{'status_pagamento': novoStatus};
    if (novoStatus == 'Pago') {
      updates['data_pagamento'] = DateTime.now().toIso8601String();
    } else {
      updates['data_pagamento'] = null;
    }
    await Supabase.instance.client.from(table).update(updates).eq('id', recordId);
    await _loadComplianceData();
  }

  Future<void> _toggleRecebimentoStatus(String recordId, String currentStatus,
      double valorPrevisto, String locatario, int numeroParcela) async {
    final isPago = currentStatus == 'Pago';
    if (!isPago) {
      final valorCtrl = TextEditingController(
          text: valorPrevisto.toStringAsFixed(2));
      final valor = await showDialog<double>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Confirmar recebimento'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('$locatario - Parcela $numeroParcela',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              TextFormField(
                controller: valorCtrl,
                decoration: const InputDecoration(labelText: 'Valor Recebido (R\$)'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            FilledButton(
              onPressed: () {
                final v = double.tryParse(valorCtrl.text.replaceAll(',', '.'));
                Navigator.pop(ctx, v ?? valorPrevisto);
              },
              child: const Text('Confirmar'),
            ),
          ],
        ),
      );
      if (valor == null) return;
      await Supabase.instance.client
          .from('recebimentos')
          .update({
            'status_pagamento': 'Pago',
            'data_recebimento': DateTime.now().toIso8601String().substring(0, 10),
            'valor_recebido': valor,
          })
          .eq('id', recordId);
    } else {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Desfazer pagamento?'),
          content: Text(
            '$locatario - Parcela $numeroParcela - ${formatCurrency(valorPrevisto)}\n\nIsso voltara o status para Pendente.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(backgroundColor: AppColors.statusWarning),
              child: const Text('Desfazer'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
      await Supabase.instance.client
          .from('recebimentos')
          .update({
            'status_pagamento': 'Pendente',
            'data_recebimento': null,
            'valor_recebido': null,
          })
          .eq('id', recordId);
    }
    await _loadComplianceData();
  }

  Future<void> _toggleParcelaSeguroStatus(
      String recordId, String currentStatus, double valorParcela, int numeroParcela) async {
    final isPago = currentStatus == 'Pago';
    if (!isPago) {
      final valorCtrl = TextEditingController(
          text: valorParcela.toStringAsFixed(2));
      final valor = await showDialog<double>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Confirmar pagamento'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Parcela $numeroParcela',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              TextFormField(
                controller: valorCtrl,
                decoration: const InputDecoration(labelText: 'Valor Pago (R\$)'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            FilledButton(
              onPressed: () {
                final v = double.tryParse(valorCtrl.text.replaceAll(',', '.'));
                Navigator.pop(ctx, v ?? valorParcela);
              },
              child: const Text('Confirmar'),
            ),
          ],
        ),
      );
      if (valor == null) return;
      await Supabase.instance.client
          .from('parcelas_seguro')
          .update({
            'status_pagamento': 'Pago',
            'data_pagamento': DateTime.now().toIso8601String().substring(0, 10),
            'valor_parcela': valor,
          })
          .eq('id', recordId);
    } else {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Desfazer pagamento?'),
          content: Text(
            'Parcela $numeroParcela - ${formatCurrency(valorParcela)}\n\n'
            'Isso voltará o status para Pendente.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(backgroundColor: AppColors.statusWarning),
              child: const Text('Desfazer'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
      await Supabase.instance.client
          .from('parcelas_seguro')
          .update({
            'status_pagamento': 'Pendente',
            'data_pagamento': null,
          })
          .eq('id', recordId);
    }
    await _loadComplianceData();
  }

  Future<void> _exportCsv(VehicleData v) async {
    final provider = context.read<CustosProvider>();
    final manutencoes = [
      ...provider.pendentes,
      ...provider.emOficina,
      ...provider.concluidos,
    ].where((m) => m.veiculoPlaca == v.placa)
     .toList()
     ..sort((a, b) => b.data.compareTo(a.data));

    final priorityLabel = (ManutencaoItem m) {
      switch (m.prioridade) {
        case MaintenancePriority.alta:
          return 'Alta';
        case MaintenancePriority.media:
          return 'Media';
        case MaintenancePriority.baixa:
          return 'Baixa';
        case MaintenancePriority.ok:
          return 'OK';
      }
    };

    final buffer = StringBuffer();
    buffer.writeln(
      '"TITULO";"TIPO";"DATA";"FORNECEDOR";"CUSTO";"KM";"PRIORIDADE"',
    );

    for (final m in manutencoes) {
      final custoStr = m.custo.toStringAsFixed(2).replaceAll('.', ',');
      buffer.writeln(
        '${_csvField(m.titulo)};${_csvField(m.tipo)};${_csvField(formatDate(m.data))};${_csvField(m.fornecedor)};${_csvField(custoStr)};${_csvField(m.kmNoServico.toString())};${_csvField(priorityLabel(m))}',
      );
    }

    try {
      final fileName =
          'manutencoes_${v.placa}_${DateTime.now().millisecondsSinceEpoch}.csv';
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

  Future<void> _exportPdf(VehicleData v) async {
    final provider = context.read<CustosProvider>();
    final manutencoes = [
      ...provider.pendentes,
      ...provider.emOficina,
      ...provider.concluidos,
    ].where((m) => m.veiculoPlaca == v.placa)
     .toList()
     ..sort((a, b) => b.data.compareTo(a.data));

    final priorityLabel = (ManutencaoItem m) {
      switch (m.prioridade) {
        case MaintenancePriority.alta:
          return 'Alta';
        case MaintenancePriority.media:
          return 'Media';
        case MaintenancePriority.baixa:
          return 'Baixa';
        case MaintenancePriority.ok:
          return 'OK';
      }
    };

    final data = VeiculoPdfData(
      placa: v.placa,
      nome: v.nome,
      motorista: v.motorista,
      kmAtual: v.kmAtual,
      custoTotalManutencao: v.custoTotalManutencao,
      totalRevisoes: v.totalRevisoes,
      manutencoes: manutencoes.map((m) => VeiculoManutencaoPdfRow(
        titulo: m.titulo,
        tipo: m.tipo,
        data: m.data,
        fornecedor: m.fornecedor,
        custo: m.custo,
        km: m.kmNoServico.toInt(),
        prioridade: priorityLabel(m),
        isPreventiva: m.isPreventiva,
      )).toList(),
    );

    try {
      final bytes = await RelatorioService.gerarPdfVeiculo(data);
      await Printing.sharePdf(
        bytes: bytes,
        filename: 'dossie_${v.placa}_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao exportar PDF: $e')),
        );
      }
    }
  }

  String _csvField(String value) {
    final escaped = value.replaceAll('"', '""');
    return '"$escaped"';
  }

  Future<void> _editarVeiculo(VehicleData v) async {
    await VehicleFormModal.show(context, vehicle: v);
  }

  Future<void> _deletarVeiculo(VehicleData v) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Excluir veículo?'),
        content: Text('O veículo ${v.placa} será marcado como inativo.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.statusError),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (ok != true || !mounted) return;

    final deleted = await FleetRepository.instance.deleteVehicle(v.placa);
    if (!mounted) return;

    if (deleted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veículo marcado como inativo.')),
      );
      context.pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.statusError,
          content: Text(
            FleetRepository.instance.loadError ?? 'Não foi possível excluir o veículo.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<FleetRepository>();
    final provider = context.watch<CustosProvider>();
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
        body: AtrPageBackground(
          grid: true,
          child: SafeArea(
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
                  _buildMaintenanceHistory(context, v, isDark, provider),
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
                              _buildMaintenanceHistory(context, v, isDark, provider),
                            ],
                          ),),
                    ],
                  ),
                ],
                if (v.isFinanciado) ...[
                  const SizedBox(height: 32),
                  _buildFinancingCard(context, v, isDark, width),
                ],
                const SizedBox(height: 32),
                _buildRecebimentosSection(context, isDark),
              ],
            ),
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
        const SizedBox(width: 8),
        PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'csv') {
              _exportCsv(v);
            } else if (value == 'pdf') {
              _exportPdf(v);
            }
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
            PopupMenuItem(
              value: 'pdf',
              child: Row(
                children: [
                  Icon(LucideIcons.fileText, size: 16),
                  SizedBox(width: 8),
                  Text('Exportar PDF'),
                ],
              ),
            ),
          ],
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.borderLight),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(LucideIcons.download, size: 16, color: AppColors.textSecondaryLight),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          tooltip: 'Editar veículo',
          onPressed: () => _editarVeiculo(v),
          icon: const Icon(LucideIcons.pencil, size: 18),
        ),
        IconButton(
          tooltip: 'Excluir veículo',
          onPressed: () => _deletarVeiculo(v),
          icon: const Icon(LucideIcons.trash2, size: 18),
          color: AppColors.statusError,
        ),
        if (v.isFinanciado) ...[
          const SizedBox(width: 12),
          const StatusBadge(text: 'FINANCIADO', type: BadgeType.info),
        ],
      ],
    );
  }

  Widget _buildStatusSelector(BuildContext context, VehicleData v) {
    return PopupMenuButton<VehicleStatus>(
      onSelected: (VehicleStatus status) async {
        final updated = await context.read<FleetRepository>().updateVehicleStatus(
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
    final totalParcelas = v.financiamento?.totalPago ?? 0;
    final parcelasInfo = v.financiamento != null
        ? '${v.financiamento!.parcelasPagas}/${v.financiamento!.totalParcelas} parc. | ${formatCurrency(v.financiamento!.valorParcela)}/mês'
        : 'Sem financiamento';
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
          _kpi(context, 'KM Rodados', formatKm(v.kmAtual),
              '${v.kmPorMes.toInt()} km/mês', LucideIcons.gauge, AppColors.statusInfo, 0, width),
          _kpi(context, 'Valor Pago', formatCurrency(totalParcelas), parcelasInfo,
              LucideIcons.landmark, AppColors.statusWarning, 50, width),
          _kpi(context, 'Custo Manutenção', formatCurrency(v.custoTotalManutencao),
              '${v.totalRevisoes} revisões | Próx. ${formatKm(v.kmParaProxRevisao)}',
              LucideIcons.receipt, AppColors.statusError, 100, width),
          _kpi(context, 'Gasto Total Veículo', formatCurrency(v.gastoTotalVeiculoKpi),
              'IPVA ${formatCurrency(totalIpva)} | Seguro ${formatCurrency(totalSeguro)} | Parcelas ${formatCurrency(totalParcelas)}',
              LucideIcons.wallet, AppColors.atrOrange, 150, width),
          _kpi(context, '$lucroLabel até Agora', formatCurrency(v.lucroPrejuizoAteAgora),
              'Recebe desde $primeiroReceb | Gasta desde $primeiroGasto',
              v.lucroPrejuizoAteAgora >= 0 ? LucideIcons.trendingUp : LucideIcons.trendingDown,
              lucroColor, 200, width),
        ],
      );
    }

    return Row(
      children: [
        Expanded(
            child: _kpi(context, 'KM Rodados', formatKm(v.kmAtual),
                '${v.kmPorMes.toInt()} km/mês', LucideIcons.gauge, AppColors.statusInfo, 0, width,
                useExpanded: true)),
        const SizedBox(width: 16),
        Expanded(
            child: _kpi(context, 'Valor Pago', formatCurrency(totalParcelas), parcelasInfo,
                LucideIcons.landmark, AppColors.statusWarning, 50, width,
                useExpanded: true)),
        const SizedBox(width: 16),
        Expanded(
            child: _kpi(context, 'Custo Manutenção', formatCurrency(v.custoTotalManutencao),
                '${v.totalRevisoes} revisões | Próx. ${formatKm(v.kmParaProxRevisao)}',
                LucideIcons.receipt, AppColors.statusError, 100, width,
                useExpanded: true)),
        const SizedBox(width: 16),
        Expanded(
            child: _kpi(context, 'Gasto Total Veículo', formatCurrency(v.gastoTotalVeiculoKpi),
                'IPVA ${formatCurrency(totalIpva)} | Seguro ${formatCurrency(totalSeguro)} | Parcelas ${formatCurrency(totalParcelas)}',
                LucideIcons.wallet, AppColors.atrOrange, 150, width,
                useExpanded: true)),
        const SizedBox(width: 16),
        Expanded(
            child: _kpi(context, '$lucroLabel até Agora', formatCurrency(v.lucroPrejuizoAteAgora),
                'Recebe desde $primeiroReceb | Gasta desde $primeiroGasto',
                v.lucroPrejuizoAteAgora >= 0 ? LucideIcons.trendingUp : LucideIcons.trendingDown,
                lucroColor, 200, width,
                useExpanded: true)),
      ],
    );
  }

  Widget _kpi(BuildContext context, String title, String value, String sub,
      IconData icon, Color color, int delay, double width,
      {bool useExpanded = false,}) {
    double itemWidth = (width - 64 - 60) / 4;
    if (width < 1100) itemWidth = (width - 64 - 20) / 2;
    if (width < 600) itemWidth = width - 32;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SizedBox(
      width: useExpanded ? null : itemWidth,
      child: BentoCard(
        animationDelay: delay,
        padding: EdgeInsets.zero,
        child: Container(
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: color, width: 3)),
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppColors.textPrimaryDark : Colors.black87,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          color.withValues(alpha: 0.2),
                          color.withValues(alpha: 0.08),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, color: color, size: 13),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: color,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                sub,
                style: TextStyle(
                  fontSize: 10,
                  color: isDark
                      ? Colors.white38
                      : AppColors.textSecondaryLight,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
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
                AtrSecondaryButton(
                  label: 'Ver Financiamento',
                  icon: LucideIcons.landmark,
                  width: double.infinity,
                  onPressed: () {
                    context.go('/financial-admin/${v.placa}');
                  },
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
      BuildContext context, VehicleData v, bool isDark, CustosProvider provider,) {
    final manutencoes = [
      ...provider.pendentes,
      ...provider.emOficina,
      ...provider.concluidos,
    ].where((m) => m.veiculoPlaca == v.placa)
     .toList()
     ..sort((a, b) => b.data.compareTo(a.data));

    final totalCusto = manutencoes.fold(0.0, (s, m) => s + m.custo);
    final totalRevisoes = manutencoes.length;
    final ultimaData = manutencoes.isNotEmpty ? manutencoes.first.data : null;

    final fleet = context.read<FleetRepository>();
    final mostrados = _maintenanceExpanded ? manutencoes : manutencoes.take(5).toList();

    return BentoCard(
      animationDelay: 500,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Historico de Manutencoes',
                  style: Theme.of(context).textTheme.titleLarge,),
              AtrPrimaryButton(
                label: 'Nova',
                icon: LucideIcons.plus,
                onPressed: () async {
                  final result = await MaintenanceFormModal.show(
                    context,
                    fleet: fleet,
                    veiculoPre: v.placa,
                  );
                  if (result != null && context.mounted) {
                    await context.read<CustosProvider>().addManutencao(result);
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _mKpi(context, 'Total', formatCurrency(totalCusto),
                  LucideIcons.dollarSign, AppColors.statusError, isDark),
              const SizedBox(width: 16),
              _mKpi(context, 'Revisoes', '$totalRevisoes',
                  LucideIcons.wrench, AppColors.atrOrange, isDark),
              const SizedBox(width: 16),
              _mKpi(context, 'Ultima',
                  ultimaData != null ? formatDate(ultimaData) : '--',
                  LucideIcons.calendar, AppColors.statusInfo, isDark),
            ],
          ),
          if (manutencoes.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            ...mostrados.map((m) => _buildManutencaoRow(context, m, isDark, provider)),
            if (manutencoes.length > 5)
              Align(
                alignment: Alignment.center,
                child: AtrGhostButton(
                  label: _maintenanceExpanded
                      ? 'Mostrar menos'
                      : 'Mostrar todas as ${manutencoes.length} manutencoes',
                  onPressed: () {
                    setState(() => _maintenanceExpanded = !_maintenanceExpanded);
                  },
                ),
              ),
          ] else
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text('Nenhuma manutencao registrada',
                    style: Theme.of(context).textTheme.bodyMedium,),
              ),
            ),
        ],
      ),
    );
  }

  Widget _mKpi(BuildContext context, String label, String value,
      IconData icon, Color color, bool isDark,) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          fontSize: 10, color: AppColors.textSecondaryLight,),),
                  Text(value,
                      style: TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 13, color: color,),),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildManutencaoRow(BuildContext context, ManutencaoItem m,
      bool isDark, CustosProvider provider,) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceElevatedDark : AppColors.backgroundLight,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: (m.isPreventiva
                      ? AppColors.statusInfo
                      : AppColors.statusWarning)
                  .withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              m.isPreventiva ? 'PREV' : 'CORR',
              style: TextStyle(
                fontSize: 8,
                fontWeight: FontWeight.w800,
                color: m.isPreventiva
                    ? AppColors.statusInfo
                    : AppColors.statusWarning,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(m.titulo,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 12,),
                    overflow: TextOverflow.ellipsis,),
                Text(formatDate(m.data),
                    style: const TextStyle(
                        fontSize: 10, color: AppColors.textSecondaryLight,),),
              ],
            ),
          ),
          if (m.kmNoServico > 0) ...[
            const SizedBox(width: 8),
            Text(
              '${NumberFormat('#,###').format(m.kmNoServico)} km',
              style: const TextStyle(
                  fontSize: 10, color: AppColors.textSecondaryLight,),
            ),
          ],
          const SizedBox(width: 12),
          Text(
            formatCurrency(m.custo),
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 12,
              color: m.custo > 0 ? AppColors.statusSuccess : AppColors.textSecondaryLight,
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            iconSize: 12,
            visualDensity: VisualDensity.compact,
            icon: const Icon(LucideIcons.edit2, size: 12,
                color: AppColors.textSecondaryLight,),
            onPressed: () async {
              final fleet = context.read<FleetRepository>();
              final result = await MaintenanceFormModal.show(
                context,
                fleet: fleet,
                item: m,
              );
              if (result != null && context.mounted) {
                await provider.updateManutencao(result);
              }
            },
          ),
          IconButton(
            iconSize: 12,
            visualDensity: VisualDensity.compact,
            icon: const Icon(LucideIcons.trash2, size: 12,
                color: AppColors.statusError,),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Confirmar exclusao'),
                  content: Text("Excluir OS '${m.titulo}'?"),
                  actions: [
                    AtrGhostButton(
                      label: 'Cancelar',
                      onPressed: () => Navigator.of(ctx).pop(false),
                    ),
                    const SizedBox(width: 8),
                    AtrPrimaryButton(
                      label: 'Excluir',
                      onPressed: () => Navigator.of(ctx).pop(true),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                await provider.deleteManutencao(m.id);
              }
            },
          ),
        ],
      ),
    );
  }

  double _sumByCategoria(VehicleData v, String categoria) {
    return v.gastosNaoCiclicos
        .where((e) => e.categoria.toLowerCase() == categoria.toLowerCase())
        .fold(0.0, (s, e) => s + e.valor);
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
          if (_ipvaRecords.isEmpty && _licenciamentoRecords.isEmpty && _segurosRecords.isEmpty) ...[
            _docRow(context, 'IPVA 2026', v.vencimentoIPVA, isDark),
            _docRow(context, 'Seguro Auto', v.vencimentoSeguro, isDark),
            _docRow(context, 'Licenciamento', v.vencimentoLicenciamento, isDark),
          ] else ...[
            ..._ipvaRecords.map((r) => _complianceRecordRow(
              context,
              'IPVA ${r['ano_referencia']}',
              r,
              isDark,
              'ipva',
            )),
            ..._licenciamentoRecords.map((r) => _complianceRecordRow(
              context,
              'Licenciamento ${r['ano_referencia']}',
              r,
              isDark,
              'licenciamento',
            )),
            ..._segurosRecords.expand((s) {
              final seguroId = s['id'] as String;
              final parcelas = _parcelasSeguroBySeguroId[seguroId] ?? [];
              final empresa = s['empresa'] as String? ?? 'Seguradora';
              final ano = s['ano_referencia'] as int? ?? DateTime.now().year;
              final valorApolice = ((s['valor_apolice'] ?? 0) as num).toDouble();
              return [
                Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 4),
                  child: Row(
                    children: [
                      const Icon(LucideIcons.shield, size: 14, color: AppColors.statusInfo),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text('$empresa - $ano - ${formatCurrency(valorApolice)}',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                ),
                if (parcelas.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(left: 20, bottom: 8),
                    child: Text('Nenhuma parcela registrada',
                        style: TextStyle(fontSize: 11, color: AppColors.textMutedDark)),
                  )
                else
                  ...parcelas.map((p) {
                    final statusPg = p['status_pagamento'] as String? ?? 'Pendente';
                    final pago = statusPg == 'Pago';
                    final valorParcela = ((p['valor_parcela'] ?? 0) as num).toDouble();
                    final numParcela = (p['numero_parcela'] as int?) ?? 0;
                    final dataVenc = DateTime.tryParse((p['data_vencimento'] ?? '').toString());
                    return InkWell(
                      onTap: () => _toggleParcelaSeguroStatus(
                          p['id'] as String, statusPg, valorParcela, numParcela),
                      child: Container(
                        padding: const EdgeInsets.only(left: 20, top: 6, bottom: 6),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 60,
                              child: Text('#$numParcela',
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                            ),
                            Expanded(
                              child: Text(formatCurrency(valorParcela),
                                  style: const TextStyle(fontSize: 11)),
                            ),
                            Text(
                              dataVenc != null ? formatDate(dataVenc) : '--',
                              style: const TextStyle(fontSize: 11, color: AppColors.textSecondaryLight),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: pago
                                    ? AppColors.statusSuccess.withValues(alpha: 0.15)
                                    : AppColors.statusWarning.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                pago ? 'Pago' : 'Pendente',
                                style: TextStyle(
                                  fontSize: 10, fontWeight: FontWeight.w600,
                                  color: pago ? AppColors.statusSuccess : AppColors.statusWarning,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
              ];
            }),
          ],
        ],
      ),
    );
  }

  Widget _complianceRecordRow(
    BuildContext context,
    String label,
    Map<String, dynamic> record,
    bool isDark,
    String table,
  ) {
    final dataVencimento = DateTime.tryParse((record['data_vencimento'] ?? '').toString());
    final statusPg = (record['status_pagamento'] as String?) ?? 'Pendente';
    final pago = statusPg == 'Pago';
    final statusColor = pago ? AppColors.statusSuccess : AppColors.statusWarning;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
              child: Text(label,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 13,),),),
          Text(dataVencimento != null ? formatDate(dataVencimento) : '--',
              style: TextStyle(
                  fontSize: 12,
                  color: isDark ? AppColors.textSecondaryDark : Colors.black54,),),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: () => _togglePaymentStatus(table, record['id'] as String, statusPg),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: statusColor.withValues(alpha: 0.3)),
              ),
              child: Text(
                statusPg,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: statusColor,
                ),
              ),
            ),
          ),
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
                  color: isDark ? AppColors.textSecondaryDark : Colors.black54,),),
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

  Widget _buildRecebimentosSection(BuildContext context, bool isDark) {
    return BentoCard(
      animationDelay: 700,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
            child: Text('Recebimentos',
                style: Theme.of(context).textTheme.titleLarge),
          ),
          const SizedBox(height: 16),
          if (_recebimentosRecords.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(
                child: Text('Nenhum recebimento registrado.',
                    style: TextStyle(color: AppColors.textSecondaryLight)),
              ),
            )
          else ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              color: isDark ? AppColors.surfaceElevatedDark : AppColors.backgroundLight,
              child: Row(
                children: [
                  Expanded(flex: 2, child: Text('LOCATARIO', style: _rhs())),
                  Expanded(child: Text('#', style: _rhs(), textAlign: TextAlign.center)),
                  Expanded(flex: 2, child: Text('VALOR', style: _rhs(), textAlign: TextAlign.right)),
                  Expanded(flex: 2, child: Text('RECEBIDO', style: _rhs(), textAlign: TextAlign.right)),
                  Expanded(flex: 2, child: Text('VENCIMENTO', style: _rhs(), textAlign: TextAlign.right)),
                  Expanded(child: Text('STATUS', style: _rhs(), textAlign: TextAlign.center)),
                ],
              ),
            ),
            ..._recebimentosRecords.map((r) {
              final statusPg = (r['status_pagamento'] as String?) ?? 'Pendente';
              final pago = statusPg == 'Pago';
              final valorPrevisto = ((r['valor_previsto'] ?? 0) as num).toDouble();
              final valorRecebido = (r['valor_recebido'] as num?)?.toDouble();
              final dataVencto = DateTime.tryParse((r['data_vencimento'] ?? '').toString());
              final locatario = r['locatario'] as String? ?? '--';
              final parcela = (r['numero_parcela'] as int?) ?? 0;
              return InkWell(
                onTap: () => _toggleRecebimentoStatus(
                    r['id'] as String, statusPg, valorPrevisto, locatario, parcela),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(
                        color: isDark ? AppColors.borderDark : AppColors.borderLight,
                        width: 0.5)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Text(locatario,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis),
                      ),
                      Expanded(
                        child: Text('$parcela',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(formatCurrency(valorPrevisto),
                            textAlign: TextAlign.right,
                            style: const TextStyle(fontSize: 12)),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          valorRecebido != null ? formatCurrency(valorRecebido) : '--',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600,
                            color: pago ? AppColors.statusSuccess : AppColors.textSecondaryLight,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(dataVencto != null ? formatDate(dataVencto) : '--',
                            textAlign: TextAlign.right,
                            style: const TextStyle(fontSize: 11, color: AppColors.textSecondaryLight)),
                      ),
                      Expanded(
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: (pago ? AppColors.statusSuccess : AppColors.statusWarning)
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              statusPg,
                              style: TextStyle(
                                fontSize: 9, fontWeight: FontWeight.w700,
                                color: pago ? AppColors.statusSuccess : AppColors.statusWarning,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              color: isDark ? AppColors.surfaceElevatedDark : AppColors.backgroundLight,
              child: Row(
                children: [
                  const Expanded(flex: 2, child: SizedBox()),
                  const Expanded(child: SizedBox()),
                  Expanded(
                    flex: 2,
                    child: Text(
                      formatCurrency(_recebimentosRecords.fold(
                          0.0, (s, r) => s + (((r['valor_previsto'] ?? 0) as num).toDouble()))),
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      formatCurrency(_recebimentosRecords.fold(
                          0.0, (s, r) => s + (((r['valor_recebido'] ?? 0) as num).toDouble()))),
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w800,
                          color: AppColors.statusSuccess),
                    ),
                  ),
                  const Expanded(flex: 2, child: SizedBox()),
                  const Expanded(
                    child: Text('TOTAL',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800,
                            color: AppColors.textSecondaryLight)),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  TextStyle _rhs() => const TextStyle(
      fontSize: 9.5, fontWeight: FontWeight.w700,
      color: AppColors.textSecondaryLight, letterSpacing: 0.4);

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
