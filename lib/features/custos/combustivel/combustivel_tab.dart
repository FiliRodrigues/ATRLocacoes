import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../../../core/data/combustivel_models.dart';
import '../../../core/data/fleet_data.dart';
import '../../../core/providers/combustivel_provider.dart';
import '../../../core/services/auth_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/export_csv_stub.dart'
    if (dart.library.html) '../../../core/utils/export_csv_html.dart'
    if (dart.library.io) '../../../core/utils/export_csv_io.dart';
import '../../../core/widgets/atr_button.dart';
import '../../../core/widgets/bento_card.dart';

// ═══════════════════════════════════════════════════════════════════════
// Aba de Combustível — parte do CustosScreen (DefaultTabController)
// ═══════════════════════════════════════════════════════════════════════

enum _Periodo { todos, esteMes, mesPassado, ultimos3Meses }

class CombustivelTab extends StatefulWidget {
  final DateTime? selectedMonth;
  const CombustivelTab({super.key, this.selectedMonth});

  @override
  State<CombustivelTab> createState() => _CombustivelTabState();
}

class _CombustivelTabState extends State<CombustivelTab> {
  static final _brl = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
  static final _dateFmt = DateFormat('dd/MM/yyyy');
  static final _km = NumberFormat('#,###', 'pt_BR');

  String? _filtroPlaca;
  _Periodo _periodo = _Periodo.todos;

  static const _tipoLabel = {
    TipoCombustivel.gasolina: 'Gasolina',
    TipoCombustivel.etanol: 'Etanol',
    TipoCombustivel.diesel: 'Diesel',
    TipoCombustivel.gnv: 'GNV',
    TipoCombustivel.eletrico: 'Elétrico',
  };

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final provider = context.watch<CombustivelProvider>();
    final fleet = context.watch<FleetRepository>();
    final kpis = provider.kpisPorVeiculo(fleet);

    final ref = widget.selectedMonth ?? DateTime.now();
    final totalMes = provider.totalMes(ref.year, ref.month);
    final totalGeral = provider.abastecimentos.fold(0.0, (s, a) => s + a.valorTotal);
    final totalLitros = provider.abastecimentos.fold(0.0, (s, a) => s + a.litros);

    final filtrados = _filtrar(provider.abastecimentos);
    final placasUnicas = <String>{};
    for (final a in provider.abastecimentos) {
      placasUnicas.add(a.veiculoPlaca);
    }
    final placas = placasUnicas.toList()..sort();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Barra de ações
        Row(
          children: [
            Expanded(child: _buildKpiHeader(isDark, totalMes, totalGeral, totalLitros)),
            const SizedBox(width: 16),
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'csv') {
                  _exportCsv(provider.abastecimentos);
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
              ],
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  border: Border.all(color: isDark ? Colors.white24 : Colors.black26),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(LucideIcons.download, size: 16, color: AppColors.textSecondaryDark),
                    SizedBox(width: 8),
                    Text(
                      'Exportar',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondaryDark,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            AtrPrimaryButton(
              label: 'Registrar',
              icon: LucideIcons.plus,
              onPressed: () => _showForm(fleet),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Filtros
        _buildFiltros(isDark, placas),
        const SizedBox(height: 16),

        if (provider.isLoading)
          const Center(child: CircularProgressIndicator())
        else if (provider.abastecimentos.isEmpty)
          _buildEmpty(isDark)
        else if (filtrados.isEmpty)
          _buildEmptyFiltrado(isDark)
        else ...[
          // KPIs por veículo
          if (kpis.isNotEmpty) ...[
            Text(
              'Consumo por Veículo',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 15,
                color: isDark ? AppColors.textPrimaryDark : Colors.black87,
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 110,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: kpis.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (_, i) => _KpiCard(kpi: kpis[i], isDark: isDark, brl: _brl),
              ),
            ),
            const SizedBox(height: 20),
          ],

          // Histórico
          Row(
            children: [
              Text(
                'Histórico de Abastecimentos',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  color: isDark ? AppColors.textPrimaryDark : Colors.black87,
                ),
              ),
              const Spacer(),
              Text(
                '${filtrados.length} registros',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white38 : Colors.black38,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.separated(
              itemCount: filtrados.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) => _AbastecimentoTile(
                a: filtrados[i],
                isDark: isDark,
                brl: _brl,
                dateFmt: _dateFmt,
                km: _km,
                onEdit: () => _showForm(fleet, existing: filtrados[i]),
                onDelete: () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Excluir abastecimento?'),
                          content: const Text('Esta ação não pode ser desfeita.'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('Cancelar'),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              style: FilledButton.styleFrom(backgroundColor: AppColors.statusError),
                              child: const Text('Excluir'),
                            ),
                          ],
                        ),
                      );
                      if (confirmed != true) return;
                      final savedData = filtrados[i].toRow();
                      await context.read<CombustivelProvider>().deleteAbastecimento(
                        filtrados[i].id,
                      );
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Abastecimento excluído'),
                          action: SnackBarAction(
                            label: 'Desfazer',
                            onPressed: () async {
                              await Supabase.instance.client.from('abastecimentos').insert(savedData);
                              if (context.mounted) {
                                await context.read<CombustivelProvider>().refresh();
                              }
                            },
                          ),
                          duration: const Duration(seconds: 5),
                        ),
                      );
                    },
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildKpiHeader(bool isDark, double totalMes, double totalGeral, double totalLitros) {
    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children: [
        _headerKpi(isDark, 'Este mês', _brl.format(totalMes), AppColors.atrOrange),
        _headerKpi(isDark, 'Total geral', _brl.format(totalGeral), AppColors.statusInfo),
        _headerKpi(isDark, 'Total litros', '${totalLitros.toStringAsFixed(0)} L', AppColors.statusSuccess),
      ],
    );
  }

  Widget _headerKpi(bool isDark, String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 11, color: isDark ? Colors.white38 : Colors.black38),
        ),
        Text(
          value,
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: color),
        ),
      ],
    );
  }

  Widget _buildEmpty(bool isDark) {
    return Expanded(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.fuel, size: 48, color: isDark ? Colors.white24 : Colors.black26),
            const SizedBox(height: 12),
            Text(
              'Nenhum abastecimento registrado',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.textSecondaryDark : Colors.black54,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Clique em "Registrar" para adicionar o primeiro',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white38 : Colors.black38,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyFiltrado(bool isDark) {
    return Expanded(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.filter, size: 48, color: isDark ? Colors.white24 : Colors.black26),
            const SizedBox(height: 12),
            Text(
              'Nenhum resultado para os filtros selecionados',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.textSecondaryDark : Colors.black54,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Tente limpar ou alterar os filtros',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white38 : Colors.black38,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Abastecimento> _filtrar(List<Abastecimento> lista) {
    var result = lista;
    final now = DateTime.now();

    switch (_periodo) {
      case _Periodo.esteMes:
        result = result.where((a) => a.data.year == now.year && a.data.month == now.month).toList();
      case _Periodo.mesPassado:
        final prev = now.month == 1
            ? DateTime(now.year - 1, 12)
            : DateTime(now.year, now.month - 1);
        result = result.where((a) => a.data.year == prev.year && a.data.month == prev.month).toList();
      case _Periodo.ultimos3Meses:
        final tresMesesAtras = DateTime(now.year, now.month - 2);
        result = result.where((a) => !a.data.isBefore(tresMesesAtras)).toList();
      case _Periodo.todos:
        break;
    }

    if (_filtroPlaca != null) {
      result = result.where((a) => a.veiculoPlaca == _filtroPlaca).toList();
    }

    return result;
  }

  Widget _buildFiltros(bool isDark, List<String> placas) {
    final now = DateTime.now();
    final mesAtual = DateFormat('MMM/yy', 'pt_BR').format(now);
    final prev = now.month == 1
        ? DateTime(now.year - 1, 12)
        : DateTime(now.year, now.month - 1);
    final mesPassadoStr = DateFormat('MMM/yy', 'pt_BR').format(prev);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Vehicle dropdown
        Row(
          children: [
            const Icon(LucideIcons.car, size: 14, color: AppColors.textSecondaryDark),
            const SizedBox(width: 8),
            const Text(
              'Veículo',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textMutedDark,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.08),
                  ),
                ),
                child: DropdownButton<String?>(
                  value: _filtroPlaca,
                  isExpanded: true,
                  underline: const SizedBox.shrink(),
                  dropdownColor: isDark ? AppColors.surfaceElevatedDark : Colors.white,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.textPrimaryDark : Colors.black87,
                  ),
                  hint: Text(
                    'Todos os veículos',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? AppColors.textSecondaryDark : Colors.black54,
                    ),
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Todos os veículos'),
                    ),
                    ...placas.map((p) => DropdownMenuItem<String?>(
                          value: p,
                          child: Text(p),
                        )),
                  ],
                  onChanged: (v) => setState(() => _filtroPlaca = v),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        // Period chips
        Row(
          children: [
            const Icon(LucideIcons.calendar, size: 14, color: AppColors.textSecondaryDark),
            const SizedBox(width: 8),
            const Text(
              'Período',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textMutedDark,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildPeriodoChip('Todos', _Periodo.todos, isDark),
                    const SizedBox(width: 6),
                    _buildPeriodoChip(mesAtual, _Periodo.esteMes, isDark),
                    const SizedBox(width: 6),
                    _buildPeriodoChip(mesPassadoStr, _Periodo.mesPassado, isDark),
                    const SizedBox(width: 6),
                    _buildPeriodoChip('3 meses', _Periodo.ultimos3Meses, isDark),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPeriodoChip(String label, _Periodo periodo, bool isDark) {
    final ativo = _periodo == periodo;
    const cor = AppColors.atrOrange;
    return GestureDetector(
      onTap: () => setState(() => _periodo = periodo),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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

  Future<String?> _uploadFoto(File file) async {
    try {
      final tenantId = Supabase.instance.client.auth.currentUser
          ?.appMetadata['tenant_id'] as String?;
      final prefix = tenantId ?? 'public';
      final fileName = 'abastecimentos/${DateTime.now().millisecondsSinceEpoch}.jpg';
      final path = '$prefix/$fileName';
      await Supabase.instance.client.storage
          .from('atr-attachments')
          .upload(path, file, fileOptions: const FileOptions(upsert: true));
      return Supabase.instance.client.storage
          .from('atr-attachments')
          .getPublicUrl(path);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao enviar foto: $e')),
        );
      }
      return null;
    }
  }

  Future<void> _showForm(FleetRepository fleet, {Abastecimento? existing}) async {
    final provider = context.read<CombustivelProvider>();
    final auth = context.read<AuthService>();
    final result = await AbastecimentoFormDialog.show(context, fleet: fleet, existing: existing);
    if (result == null) return;

    String? fotoUrl = existing?.fotoUrl;
    final fotoFile = result.fotoFile;
    if (fotoFile != null) {
      fotoUrl = await _uploadFoto(fotoFile);
    }

    if (result.existingId != null) {
      final updateData = <String, dynamic>{
        'veiculo_placa': result.veiculoPlaca,
        'data': result.data.toIso8601String(),
        'litros': result.litros,
        'valor_total': result.valorTotal,
        'km_odometro': result.kmOdometro,
        'tipo': result.tipo.name,
        'posto': result.posto,
      };
      if (fotoUrl != null) updateData['foto_url'] = fotoUrl;
      await Supabase.instance.client
          .from('abastecimentos')
          .update(updateData)
          .eq('id', result.existingId!);
      await provider.refresh();
    } else {
      final a = provider.buildNovo(
        veiculoPlaca: result.veiculoPlaca,
        data: result.data,
        litros: result.litros,
        valorTotal: result.valorTotal,
        kmOdometro: result.kmOdometro,
        tipo: result.tipo,
        posto: result.posto,
        registradoPor: auth.currentUser?.username ?? 'sistema',
        fotoUrl: fotoUrl,
      );
      await provider.addAbastecimento(a);
    }
  }

  Future<void> _exportCsv(List<Abastecimento> itens) async {
    final buffer = StringBuffer();
    buffer.writeln(
      '"PLACA";"DATA";"LITROS";"VALOR TOTAL";"KM ODÔMETRO";"TIPO";"POSTO";"REGISTRADO POR"',
    );

    for (final a in itens) {
      final dateStr = _dateFmt.format(a.data);
      final litrosStr = a.litros.toStringAsFixed(1).replaceAll('.', ',');
      final valorStr = a.valorTotal.toStringAsFixed(2).replaceAll('.', ',');
      final kmStr = a.kmOdometro.toInt().toString();
      final tipoStr = _tipoLabel[a.tipo] ?? a.tipo.name;
      final postoStr = a.posto ?? '';
      buffer.writeln(
        '${_csvField(a.veiculoPlaca)};${_csvField(dateStr)};${_csvField(litrosStr)};${_csvField(valorStr)};${_csvField(kmStr)};${_csvField(tipoStr)};${_csvField(postoStr)};${_csvField(a.registradoPor)}',
      );
    }

    try {
      final fileName =
          'abastecimentos_export_${DateTime.now().millisecondsSinceEpoch}.csv';
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
}

// ─────────────────────────────────────────────────────────────────────
// Card de KPI por veículo
// ─────────────────────────────────────────────────────────────────────

class _KpiCard extends StatelessWidget {
  final CombustivelKpi kpi;
  final bool isDark;
  final NumberFormat brl;

  const _KpiCard({required this.kpi, required this.isDark, required this.brl});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 160,
      child: BentoCard(
        padding: EdgeInsets.zero,
        child: Container(
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: AppColors.atrOrange, width: 3)),
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                kpi.veiculoPlaca,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
              ),
              const SizedBox(height: 6),
              _row(isDark, LucideIcons.fuel, brl.format(kpi.totalGasto), AppColors.statusError),
              const SizedBox(height: 4),
              _row(
                isDark,
                LucideIcons.gauge,
                kpi.kmMedia > 0 ? '${kpi.kmMedia.toStringAsFixed(1)} km/l' : '—',
                AppColors.statusSuccess,
              ),
              const SizedBox(height: 4),
              _row(
                isDark,
                LucideIcons.circleDollarSign,
                'R\$ ${kpi.custoKm.toStringAsFixed(2)}/km',
                AppColors.atrOrange,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(bool isDark, IconData icon, String text, Color color) {
    return Row(
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Tile de abastecimento individual
// ─────────────────────────────────────────────────────────────────────

class _AbastecimentoTile extends StatelessWidget {
  final Abastecimento a;
  final bool isDark;
  final NumberFormat brl;
  final DateFormat dateFmt;
  final NumberFormat km;
  final VoidCallback onDelete;
  final VoidCallback? onEdit;

  const _AbastecimentoTile({
    required this.a,
    required this.isDark,
    required this.brl,
    required this.dateFmt,
    required this.km,
    required this.onDelete,
    this.onEdit,
  });

  static const _tipoLabel = {
    TipoCombustivel.gasolina: 'Gasolina',
    TipoCombustivel.etanol: 'Etanol',
    TipoCombustivel.diesel: 'Diesel',
    TipoCombustivel.gnv: 'GNV',
    TipoCombustivel.eletrico: 'Elétrico',
  };

  static const _tipoColor = {
    TipoCombustivel.gasolina: AppColors.statusWarning,
    TipoCombustivel.etanol: AppColors.statusSuccess,
    TipoCombustivel.diesel: AppColors.statusInfo,
    TipoCombustivel.gnv: Colors.teal,
    TipoCombustivel.eletrico: Colors.deepPurple,
  };

  @override
  Widget build(BuildContext context) {
    final tipoColor = _tipoColor[a.tipo] ?? AppColors.atrOrange;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.03)
            : Colors.black.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.06),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: tipoColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(LucideIcons.fuel, size: 16, color: tipoColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      a.veiculoPlaca,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: tipoColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _tipoLabel[a.tipo] ?? a.tipo.name,
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: tipoColor),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${a.litros.toStringAsFixed(1)} L · ${km.format(a.kmOdometro.toInt())} km'
                  '${a.posto != null ? ' · ${a.posto}' : ''}',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppColors.textSecondaryDark : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
          if (a.fotoUrl != null)
            GestureDetector(
              onTap: () => launchUrl(Uri.parse(a.fotoUrl!), mode: LaunchMode.externalApplication),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  a.fotoUrl!,
                  width: 42,
                  height: 42,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Icon(LucideIcons.image, size: 16),
                ),
              ),
            ),
          if (a.fotoUrl != null) const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                brl.format(a.valorTotal),
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
              ),
              Text(
                dateFmt.format(a.data),
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? Colors.white38 : Colors.black38,
                ),
              ),
            ],
          ),
          const SizedBox(width: 6),
          if (onEdit != null)
            IconButton(
              icon: const Icon(LucideIcons.pencil, size: 15),
              onPressed: onEdit,
              tooltip: 'Editar',
            ),
          IconButton(
            icon: Icon(LucideIcons.trash2, size: 15, color: Colors.red.shade400),
            onPressed: onDelete,
            tooltip: 'Excluir',
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Dialog de registro de abastecimento
// ─────────────────────────────────────────────────────────────────────

class _AbastecimentoFormData {
  final String? existingId;
  final String veiculoPlaca;
  final DateTime data;
  final double litros;
  final double valorTotal;
  final double kmOdometro;
  final TipoCombustivel tipo;
  final String? posto;
  final File? fotoFile;

  const _AbastecimentoFormData({
    this.existingId,
    required this.veiculoPlaca,
    required this.data,
    required this.litros,
    required this.valorTotal,
    required this.kmOdometro,
    required this.tipo,
    this.posto,
    this.fotoFile,
  });
}

class AbastecimentoFormDialog extends StatefulWidget {
  final FleetRepository fleet;
  final Abastecimento? existing;
  const AbastecimentoFormDialog({super.key, required this.fleet, this.existing});

  static Future<_AbastecimentoFormData?> show(
    BuildContext context, {
    required FleetRepository fleet,
    Abastecimento? existing,
  }) {
    return showDialog<_AbastecimentoFormData>(
      context: context,
      builder: (_) => AbastecimentoFormDialog(fleet: fleet, existing: existing),
    );
  }

  @override
  State<AbastecimentoFormDialog> createState() => _AbastecimentoFormDialogState();
}

class _AbastecimentoFormDialogState extends State<AbastecimentoFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _litrosCtrl = TextEditingController();
  final _valorCtrl = TextEditingController();
  final _kmCtrl = TextEditingController();
  final _postoCtrl = TextEditingController();

  String? _veiculoPlaca;
  DateTime _data = DateTime.now();
  TipoCombustivel _tipo = TipoCombustivel.gasolina;
  File? _fotoFile;

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      final e = widget.existing!;
      _veiculoPlaca = e.veiculoPlaca;
      _data = e.data;
      _tipo = e.tipo;
      _litrosCtrl.text = e.litros.toString().replaceAll('.', ',');
      _valorCtrl.text = e.valorTotal.toStringAsFixed(2).replaceAll('.', ',');
      _kmCtrl.text = e.kmOdometro.toInt().toString();
      _postoCtrl.text = e.posto ?? '';
    } else if (widget.fleet.frota.isNotEmpty) {
      _veiculoPlaca = widget.fleet.frota.first.placa;
    }
  }

  @override
  void dispose() {
    _litrosCtrl.dispose();
    _valorCtrl.dispose();
    _kmCtrl.dispose();
    _postoCtrl.dispose();
    super.dispose();
  }

  static const _tipoLabel = {
    TipoCombustivel.gasolina: 'Gasolina',
    TipoCombustivel.etanol: 'Etanol',
    TipoCombustivel.diesel: 'Diesel',
    TipoCombustivel.gnv: 'GNV',
    TipoCombustivel.eletrico: 'Elétrico',
  };

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(LucideIcons.fuel, color: AppColors.atrOrange, size: 20),
          const SizedBox(width: 10),
          Text(widget.existing != null ? 'Editar Abastecimento' : 'Registrar Abastecimento'),
        ],
      ),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Veículo
                DropdownButtonFormField<String>(
                  initialValue: _veiculoPlaca,
                  decoration: const InputDecoration(
                    labelText: 'Veículo *',
                    border: OutlineInputBorder(),
                  ),
                  items: widget.fleet.frota
                      .map((v) => DropdownMenuItem(
                            value: v.placa,
                            child: Text('${v.nome} (${v.placa})'),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => _veiculoPlaca = v),
                  validator: (v) => v == null ? 'Selecione um veículo' : null,
                ),
                const SizedBox(height: 12),

                // Data
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _data,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) setState(() => _data = picked);
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Data',
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(LucideIcons.calendar, size: 16),
                    ),
                    child: Text(DateFormat('dd/MM/yyyy').format(_data)),
                  ),
                ),
                const SizedBox(height: 12),

                // Tipo de combustível
                DropdownButtonFormField<TipoCombustivel>(
                  initialValue: _tipo,
                  decoration: const InputDecoration(
                    labelText: 'Tipo *',
                    border: OutlineInputBorder(),
                  ),
                  items: TipoCombustivel.values
                      .map((t) => DropdownMenuItem(
                            value: t,
                            child: Text(_tipoLabel[t] ?? t.name),
                          ))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _tipo = v);
                  },
                ),
                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _litrosCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Litros *',
                          border: OutlineInputBorder(),
                          suffixText: 'L',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Obrigatório';
                          if (double.tryParse(v.replaceAll(',', '.')) == null) return 'Inválido';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _valorCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Valor total *',
                          border: OutlineInputBorder(),
                          prefixText: 'R\$ ',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Obrigatório';
                          if (double.tryParse(v.replaceAll(',', '.')) == null) return 'Inválido';
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                TextFormField(
                  controller: _kmCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Odômetro (km) *',
                    border: OutlineInputBorder(),
                    suffixText: 'km',
                    prefixIcon: Icon(LucideIcons.gauge, size: 16),
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Obrigatório';
                    if (double.tryParse(v) == null) return 'Inválido';
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                // Foto do recibo
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final picker = ImagePicker();
                          final picked = await picker.pickImage(
                            source: ImageSource.gallery,
                            maxWidth: 1024,
                            imageQuality: 85,
                          );
                          if (picked != null) {
                            setState(() => _fotoFile = File(picked.path));
                          }
                        },
                        icon: const Icon(LucideIcons.camera, size: 16),
                        label: Text(
                          _fotoFile != null ? 'Foto selecionada' : 'Foto do recibo',
                          style: const TextStyle(fontSize: 12),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                      ),
                    ),
                    if (_fotoFile != null) ...[
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: () {
                          setState(() => _fotoFile = null);
                        },
                        icon: const Icon(LucideIcons.x, size: 16),
                        tooltip: 'Remover foto',
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),

                TextFormField(
                  controller: _postoCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Posto (opcional)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(LucideIcons.mapPin, size: 16),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        AtrGhostButton(
          label: 'Cancelar',
          onPressed: () => Navigator.pop(context),
        ),
        const SizedBox(width: 8),
        AtrPrimaryButton(
          label: 'Salvar',
          onPressed: _submit,
        ),
      ],
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      _AbastecimentoFormData(
        existingId: widget.existing?.id,
        veiculoPlaca: _veiculoPlaca!,
        data: _data,
        litros: double.parse(_litrosCtrl.text.replaceAll(',', '.')),
        valorTotal: double.parse(_valorCtrl.text.replaceAll(',', '.')),
        kmOdometro: double.parse(_kmCtrl.text),
        tipo: _tipo,
        posto: _postoCtrl.text.trim().isEmpty ? null : _postoCtrl.text.trim(),
        fotoFile: _fotoFile,
      ),
    );
  }
}
