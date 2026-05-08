import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../../../core/data/fleet_data.dart';
import '../../../core/data/regras_manutencao_models.dart';
import '../../../core/enums/maintenance_priority.dart';
import '../../../core/providers/regras_manutencao_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/atr_button.dart';

class RegrasManutencaoSheet extends StatelessWidget {
  const RegrasManutencaoSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => ChangeNotifierProvider.value(
        value: context.read<RegrasManutencaoProvider>(),
        child: const RegrasManutencaoSheet(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final provider = context.watch<RegrasManutencaoProvider>();

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      expand: false,
      builder: (ctx, scrollCtrl) {
        return Column(
          children: [
            _buildHandle(),
            _buildHeader(context, isDark),
            const Divider(height: 1),
            if (provider.isLoading)
              const Expanded(
                child: Center(child: CircularProgressIndicator()),
              )
            else
              Expanded(
                child: provider.regras.isEmpty
                    ? _buildEmpty(context, isDark)
                    : ListView.separated(
                        controller: scrollCtrl,
                        padding: const EdgeInsets.symmetric(
                            vertical: 12, horizontal: 16),
                        itemCount: provider.regras.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (_, i) => _RegraTile(
                          regra: provider.regras[i],
                          isDark: isDark,
                        ),
                      ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildHandle() {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 4),
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: Colors.grey.shade400,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 12, 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.atrOrange.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              LucideIcons.alarmClock,
              color: AppColors.atrOrange,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Regras Preventivas',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                Text(
                  'OS geradas automaticamente quando KM ou prazo é atingido',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? AppColors.textSecondaryDark : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
          AtrPrimaryButton(
            label: 'Adicionar',
            icon: LucideIcons.plus,
            onPressed: () => _showAddRegra(context),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty(BuildContext context, bool isDark) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            LucideIcons.alarmClock,
            size: 48,
            color: isDark ? Colors.white24 : Colors.black26,
          ),
          const SizedBox(height: 12),
          Text(
            'Nenhuma regra configurada',
            style: TextStyle(
              color: isDark ? AppColors.textSecondaryDark : Colors.black54,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Adicione regras para gerar OS automaticamente',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white38 : Colors.black38,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddRegra(BuildContext context) async {
    final provider = context.read<RegrasManutencaoProvider>();
    final fleet = context.read<FleetRepository>();
    final regra = await _RegraFormDialog.show(context, fleet: fleet);
    if (regra != null) {
      await provider.addRegra(regra);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────
// Tile de uma regra individual
// ─────────────────────────────────────────────────────────────────────

class _RegraTile extends StatelessWidget {
  final RegraManutencao regra;
  final bool isDark;

  const _RegraTile({required this.regra, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final provider = context.read<RegrasManutencaoProvider>();

    final criterio = [
      if (regra.intervaloKm != null)
        'a cada ${_fmt(regra.intervaloKm!)} km',
      if (regra.intervaloDias != null)
        'a cada ${regra.intervaloDias} dias',
    ].join(' ou ');

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.04)
            : Colors.black.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: regra.isAtiva
              ? AppColors.atrOrange.withValues(alpha: 0.25)
              : Colors.grey.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _prioColor(regra.prioridade).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              LucideIcons.wrench,
              size: 16,
              color: _prioColor(regra.prioridade),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        regra.titulo,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: regra.isAtiva
                              ? null
                              : (isDark ? Colors.white38 : Colors.black38),
                        ),
                      ),
                    ),
                    _PriorityBadge(regra.prioridade),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  criterio,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppColors.textSecondaryDark : Colors.black54,
                  ),
                ),
                if (regra.veiculoPlaca != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Row(
                      children: [
                        const Icon(LucideIcons.truck,
                            size: 11,
                            color: AppColors.atrOrange),
                        const SizedBox(width: 4),
                        Text(
                          'Apenas ${regra.veiculoPlaca}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.atrOrange,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (regra.dataUltimaExecucao != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Última OS: ${_fmtDate(regra.dataUltimaExecucao!)}',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white38 : Colors.black38,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            children: [
              Switch(
                value: regra.isAtiva,
                activeThumbColor: AppColors.atrOrange,
                onChanged: (_) => provider.toggleRegra(regra.id),
              ),
              IconButton(
                onPressed: () => _confirmDelete(context, provider),
                icon: Icon(
                  LucideIcons.trash2,
                  size: 16,
                  color: Colors.red.shade400,
                ),
                tooltip: 'Excluir regra',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, RegrasManutencaoProvider provider) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Excluir Regra'),
        content: Text('Deseja excluir a regra "${regra.titulo}"?'),
        actions: [
          AtrGhostButton(
            label: 'Cancelar',
            onPressed: () => Navigator.pop(context, false),
          ),
          const SizedBox(width: 8),
          AtrGhostButton(
            label: 'Excluir',
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );
    if (ok == true) await provider.deleteRegra(regra.id);
  }

  Color _prioColor(MaintenancePriority p) {
    switch (p) {
      case MaintenancePriority.alta:
        return AppColors.statusError;
      case MaintenancePriority.media:
        return AppColors.statusWarning;
      case MaintenancePriority.baixa:
        return AppColors.statusInfo;
      case MaintenancePriority.ok:
        return AppColors.statusSuccess;
    }
  }

  String _fmt(int n) {
    final s = n.toString();
    if (s.length <= 3) return s;
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

// ─────────────────────────────────────────────────────────────────────
// Badge de prioridade
// ─────────────────────────────────────────────────────────────────────

class _PriorityBadge extends StatelessWidget {
  final MaintenancePriority prioridade;
  const _PriorityBadge(this.prioridade);

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (prioridade) {
      MaintenancePriority.alta => ('Alta', AppColors.statusError),
      MaintenancePriority.media => ('Média', AppColors.statusWarning),
      MaintenancePriority.baixa => ('Baixa', AppColors.statusInfo),
      MaintenancePriority.ok => ('OK', AppColors.statusSuccess),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Dialog de criação de nova regra
// ─────────────────────────────────────────────────────────────────────

class _RegraFormDialog extends StatefulWidget {
  final FleetRepository fleet;
  const _RegraFormDialog({required this.fleet});

  static Future<RegraManutencao?> show(
    BuildContext context, {
    required FleetRepository fleet,
  }) {
    return showDialog<RegraManutencao>(
      context: context,
      builder: (_) => _RegraFormDialog(fleet: fleet),
    );
  }

  @override
  State<_RegraFormDialog> createState() => _RegraFormDialogState();
}

class _RegraFormDialogState extends State<_RegraFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _tituloCtrl = TextEditingController();
  final _tipoCtrl = TextEditingController();
  final _custoCtrl = TextEditingController(text: '0');
  final _kmCtrl = TextEditingController();
  final _diasCtrl = TextEditingController();

  MaintenancePriority _prioridade = MaintenancePriority.media;
  String? _veiculoPlaca;

  static const _tipos = [
    'Troca de Óleo',
    'Revisão Periódica',
    'Pneus',
    'Freios',
    'Correia Dentada',
    'Ar-Condicionado',
    'Filtros',
    'Suspensão',
    'Outro',
  ];

  @override
  void dispose() {
    _tituloCtrl.dispose();
    _tipoCtrl.dispose();
    _custoCtrl.dispose();
    _kmCtrl.dispose();
    _diasCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AlertDialog(
      title: const Row(
        children: [
          Icon(LucideIcons.alarmClock, color: AppColors.atrOrange, size: 20),
          SizedBox(width: 10),
          Text('Nova Regra Preventiva'),
        ],
      ),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Título
                TextFormField(
                  controller: _tituloCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Título da OS *',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Campo obrigatório' : null,
                ),
                const SizedBox(height: 12),

                // Tipo (autocomplete)
                Autocomplete<String>(
                  optionsBuilder: (textEditingValue) {
                    if (textEditingValue.text.isEmpty) return _tipos;
                    return _tipos.where((t) => t
                        .toLowerCase()
                        .contains(textEditingValue.text.toLowerCase()));
                  },
                  onSelected: (v) => _tipoCtrl.text = v,
                  fieldViewBuilder:
                      (_, ctrl, focusNode, onSubmit) => TextFormField(
                    controller: ctrl,
                    focusNode: focusNode,
                    decoration: const InputDecoration(
                      labelText: 'Tipo de Serviço *',
                      border: OutlineInputBorder(),
                      hintText: 'ex: Troca de Óleo',
                    ),
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'Campo obrigatório'
                        : null,
                    onFieldSubmitted: (_) => onSubmit(),
                  ),
                ),
                const SizedBox(height: 12),

                // Veículo específico
                DropdownButtonFormField<String?>(
                  initialValue: _veiculoPlaca,
                  decoration: const InputDecoration(
                    labelText: 'Veículo (opcional)',
                    border: OutlineInputBorder(),
                    helperText: 'Deixe em branco para aplicar a toda a frota',
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Todos os veículos'),
                    ),
                    ...widget.fleet.frota.map(
                      (v) => DropdownMenuItem<String?>(
                        value: v.placa,
                        child: Text('${v.nome} (${v.placa})'),
                      ),
                    ),
                  ],
                  onChanged: (v) => setState(() => _veiculoPlaca = v),
                ),
                const SizedBox(height: 12),

                // Critérios
                Text(
                  'Critério de disparo *',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: isDark ? AppColors.textPrimaryDark : Colors.black87,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _kmCtrl,
                        decoration: const InputDecoration(
                          labelText: 'A cada (km)',
                          border: OutlineInputBorder(),
                          hintText: 'ex: 10000',
                          prefixIcon:
                              Icon(LucideIcons.gauge, size: 16),
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        'ou',
                        style: TextStyle(
                          color: isDark ? AppColors.textSecondaryDark : Colors.black54,
                        ),
                      ),
                    ),
                    Expanded(
                      child: TextFormField(
                        controller: _diasCtrl,
                        decoration: const InputDecoration(
                          labelText: 'A cada (dias)',
                          border: OutlineInputBorder(),
                          hintText: 'ex: 180',
                          prefixIcon:
                              Icon(LucideIcons.calendar, size: 16),
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Custo estimado
                TextFormField(
                  controller: _custoCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Custo estimado (R\$)',
                    border: OutlineInputBorder(),
                    prefixIcon:
                        Icon(LucideIcons.circleDollarSign, size: 16),
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 12),

                // Prioridade
                DropdownButtonFormField<MaintenancePriority>(
                  initialValue: _prioridade,
                  decoration: const InputDecoration(
                    labelText: 'Prioridade',
                    border: OutlineInputBorder(),
                  ),
                  items: MaintenancePriority.values
                      .map(
                        (p) => DropdownMenuItem(
                          value: p,
                          child: Text(p.name[0].toUpperCase() +
                              p.name.substring(1)),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _prioridade = v);
                  },
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
          label: 'Criar Regra',
          onPressed: _submit,
        ),
      ],
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final intervaloKm =
        _kmCtrl.text.trim().isNotEmpty ? int.tryParse(_kmCtrl.text) : null;
    final intervaloDias =
        _diasCtrl.text.trim().isNotEmpty ? int.tryParse(_diasCtrl.text) : null;

    if (intervaloKm == null && intervaloDias == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Informe ao menos um critério (km ou dias)'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final regra = RegraManutencao(
      id: 'regra_${DateTime.now().millisecondsSinceEpoch}',
      titulo: _tituloCtrl.text.trim(),
      tipo: _tipoCtrl.text.trim(),
      veiculoPlaca: _veiculoPlaca,
      intervaloKm: intervaloKm,
      intervaloDias: intervaloDias,
      custoEstimado:
          double.tryParse(_custoCtrl.text.replaceAll(',', '.')) ?? 0.0,
      prioridade: _prioridade,
    );

    Navigator.pop(context, regra);
  }
}
