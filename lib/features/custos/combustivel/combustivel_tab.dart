import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../../../core/data/combustivel_models.dart';
import '../../../core/data/fleet_data.dart';
import '../../../core/providers/combustivel_provider.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/atr_button.dart';
import '../../../core/widgets/bento_card.dart';

// ═══════════════════════════════════════════════════════════════════════
// Aba de Combustível — parte do CustosScreen (DefaultTabController)
// ═══════════════════════════════════════════════════════════════════════

class CombustivelTab extends StatelessWidget {
  const CombustivelTab({super.key});

  static final _brl = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
  static final _dateFmt = DateFormat('dd/MM/yyyy');
  static final _km = NumberFormat('#,###', 'pt_BR');

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final provider = context.watch<CombustivelProvider>();
    final fleet = context.watch<FleetRepository>();
    final kpis = provider.kpisPorVeiculo(fleet);

    final totalMes = provider.totalMes(DateTime.now().year, DateTime.now().month);
    final totalGeral = provider.abastecimentos.fold(0.0, (s, a) => s + a.valorTotal);
    final totalLitros = provider.abastecimentos.fold(0.0, (s, a) => s + a.litros);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Barra de ações
        Row(
          children: [
            Expanded(child: _buildKpiHeader(isDark, totalMes, totalGeral, totalLitros)),
            const SizedBox(width: 16),
            AtrPrimaryButton(
              label: 'Registrar',
              icon: LucideIcons.plus,
              onPressed: () => _showForm(context, fleet),
            ),
          ],
        ),
        const SizedBox(height: 20),

        if (provider.isLoading)
          const Center(child: CircularProgressIndicator())
        else if (provider.abastecimentos.isEmpty)
          _buildEmpty(isDark)
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
                '${provider.abastecimentos.length} registros',
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
              itemCount: provider.abastecimentos.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) => _AbastecimentoTile(
                a: provider.abastecimentos[i],
                isDark: isDark,
                brl: _brl,
                dateFmt: _dateFmt,
                km: _km,
                onDelete: () => context.read<CombustivelProvider>().deleteAbastecimento(
                      provider.abastecimentos[i].id,
                    ),
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

  Future<void> _showForm(BuildContext context, FleetRepository fleet) async {
    final provider = context.read<CombustivelProvider>();
    final auth = context.read<AuthService>();
    final result = await AbastecimentoFormDialog.show(context, fleet: fleet);
    if (result == null) return;
    final a = provider.buildNovo(
      veiculoPlaca: result.veiculoPlaca,
      data: result.data,
      litros: result.litros,
      valorTotal: result.valorTotal,
      kmOdometro: result.kmOdometro,
      tipo: result.tipo,
      posto: result.posto,
      registradoPor: auth.currentUser?.username ?? 'sistema',
    );
    await provider.addAbastecimento(a);
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

  const _AbastecimentoTile({
    required this.a,
    required this.isDark,
    required this.brl,
    required this.dateFmt,
    required this.km,
    required this.onDelete,
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
  final String veiculoPlaca;
  final DateTime data;
  final double litros;
  final double valorTotal;
  final double kmOdometro;
  final TipoCombustivel tipo;
  final String? posto;

  const _AbastecimentoFormData({
    required this.veiculoPlaca,
    required this.data,
    required this.litros,
    required this.valorTotal,
    required this.kmOdometro,
    required this.tipo,
    this.posto,
  });
}

class AbastecimentoFormDialog extends StatefulWidget {
  final FleetRepository fleet;
  const AbastecimentoFormDialog({super.key, required this.fleet});

  static Future<_AbastecimentoFormData?> show(
    BuildContext context, {
    required FleetRepository fleet,
  }) {
    return showDialog<_AbastecimentoFormData>(
      context: context,
      builder: (_) => AbastecimentoFormDialog(fleet: fleet),
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

  @override
  void initState() {
    super.initState();
    if (widget.fleet.frota.isNotEmpty) {
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
      title: const Row(
        children: [
          Icon(LucideIcons.fuel, color: AppColors.atrOrange, size: 20),
          SizedBox(width: 10),
          Text('Registrar Abastecimento'),
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
        veiculoPlaca: _veiculoPlaca!,
        data: _data,
        litros: double.parse(_litrosCtrl.text.replaceAll(',', '.')),
        valorTotal: double.parse(_valorCtrl.text.replaceAll(',', '.')),
        kmOdometro: double.parse(_kmCtrl.text),
        tipo: _tipo,
        posto: _postoCtrl.text.trim().isEmpty ? null : _postoCtrl.text.trim(),
      ),
    );
  }
}
