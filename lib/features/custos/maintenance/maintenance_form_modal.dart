import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/data/custos_models.dart';
import '../../../core/data/fleet_data.dart';
import '../../../core/enums/kanban_column.dart';
import '../../../core/enums/maintenance_priority.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/app_logger.dart';
import '../../../core/widgets/atr_button.dart';

class MaintenanceFormModal {
  static Future<ManutencaoItem?> show(
    BuildContext context, {
    required FleetRepository fleet,
    ManutencaoItem? item,
    String? veiculoPre,
  }) {
    return showDialog<ManutencaoItem>(
      context: context,
      barrierColor: Colors.transparent,
      builder: (ctx) => _MaintenanceFormDialog(fleet: fleet, item: item, veiculoPre: veiculoPre),
    );
  }
}

class _MaintenanceFormDialog extends StatefulWidget {
  final FleetRepository fleet;
  final ManutencaoItem? item;
  final String? veiculoPre;

  const _MaintenanceFormDialog({required this.fleet, this.item, this.veiculoPre});

  @override
  State<_MaintenanceFormDialog> createState() => _MaintenanceFormDialogState();
}

class _MaintenanceFormDialogState extends State<_MaintenanceFormDialog>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late AnimationController _anim;
  late Animation<double> _scale;

  // Controllers
  final _tituloCtrl = TextEditingController();
  final _descricaoCtrl = TextEditingController();
  final _kmCtrl = TextEditingController();
  final _custoCtrl = TextEditingController();
  final _fornecedorCtrl = TextEditingController();
  final _numeroOSCtrl = TextEditingController();

  // State
  String? _veiculoPlaca;
  String? _veiculoNome;
  String _tipo = 'Revisão';
  DateTime _data = DateTime.now();
  DateTime? _dataConclusao;
  bool _isPreventiva = true;
  MaintenancePriority _prioridade = MaintenancePriority.media;
  KanbanColumn _coluna = KanbanColumn.pendentes;
  bool _veiculoFixo = false;
  File? _anexoFile;
  bool _uploading = false;

  static final _dateFmt = DateFormat('dd/MM/yyyy');
  static const _tipos = [
    'Revisão',
    'Troca de Óleo',
    'Pneus',
    'Freios',
    'Correia Dentada',
    'Elétrica',
    'Funilaria',
    'Suspensão',
    'Ar-Condicionado',
    'Filtros',
    'Outro',
  ];

  static final _inputBorder = (Color focusColor) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(9),
        borderSide: BorderSide(color: focusColor),
      );

  static InputDecoration _dec(String label, {String? prefix, String? suffix, IconData? prefixIcon, String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixText: prefix,
      suffixText: suffix,
      prefixIcon: prefixIcon != null ? Icon(prefixIcon, size: 16) : null,
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.04),
      border: _inputBorder(const Color(0x12FFFFFF)),
      enabledBorder: _inputBorder(const Color(0x12FFFFFF)),
      focusedBorder: _inputBorder(AppColors.atrOrange.withValues(alpha: 0.45)),
      labelStyle: const TextStyle(fontSize: 12, color: AppColors.textMutedDark),
    );
  }

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 220));
    _scale = Tween<double>(begin: 0.94, end: 1.0).animate(
      CurvedAnimation(parent: _anim, curve: const Cubic(0.34, 1.56, 0.64, 1)),
    );
    _anim.forward();

    final item = widget.item;
    if (item != null) {
      _tituloCtrl.text = item.titulo;
      _descricaoCtrl.text = item.descricao;
      _kmCtrl.text = item.kmNoServico > 0 ? item.kmNoServico.toString() : item.odometro.toString();
      _custoCtrl.text = item.custo > 0 ? item.custo.toStringAsFixed(2) : '';
      _fornecedorCtrl.text = item.fornecedor;
      _numeroOSCtrl.text = item.numeroOS;
      _veiculoPlaca = item.veiculoPlaca;
      _veiculoNome = item.veiculoNome;
      _tipo = item.tipo;
      _data = item.data;
      _dataConclusao = item.dataConclusao;
      _isPreventiva = item.isPreventiva;
      _prioridade = item.prioridade == MaintenancePriority.ok ? MaintenancePriority.baixa : item.prioridade;
      _coluna = item.coluna;
    } else {
      if (widget.veiculoPre != null) {
        _veiculoPlaca = widget.veiculoPre;
        _veiculoFixo = true;
        final v = widget.fleet.frota.firstWhere((v) => v.placa == widget.veiculoPre);
        _veiculoNome = v.nome;
      } else if (widget.fleet.frota.isNotEmpty) {
        _veiculoPlaca = widget.fleet.frota.first.placa;
        _veiculoNome = widget.fleet.frota.first.nome;
      }
    }
  }

  @override
  void dispose() {
    _anim.dispose();
    _tituloCtrl.dispose();
    _descricaoCtrl.dispose();
    _kmCtrl.dispose();
    _custoCtrl.dispose();
    _fornecedorCtrl.dispose();
    _numeroOSCtrl.dispose();
    super.dispose();
  }

  Future<String?> _uploadAnexo() async {
    if (_anexoFile == null) return null;
    try {
      final tenantId = Supabase.instance.client.auth.currentUser
          ?.appMetadata['tenant_id'] as String?;
      final prefix = tenantId ?? 'public';
      final ext = _anexoFile!.path.split('.').last;
      final fileName = 'manutencoes/${DateTime.now().millisecondsSinceEpoch}.$ext';
      final path = '$prefix/$fileName';
      await Supabase.instance.client.storage
          .from('atr-attachments')
          .upload(path, _anexoFile!, fileOptions: const FileOptions(upsert: true));
      return Supabase.instance.client.storage
          .from('atr-attachments')
          .getPublicUrl(path);
    } catch (e, s) {
      AppLogger.error('Falha no upload de anexo de manutencao', e, s);
      return null;
    }
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_uploading) return;

    double parseVal(String ctrl) {
      final v = ctrl.replaceAll(',', '.').trim();
      if (v.isEmpty) return 0;
      return double.tryParse(v) ?? 0;
    }

    setState(() => _uploading = true);

    // Upload attachment if present
    String nomeAnexo = widget.item?.nomeAnexo ?? '';
    if (_anexoFile != null) {
      final url = await _uploadAnexo();
      if (url != null) {
        nomeAnexo = nomeAnexo.isNotEmpty ? '$nomeAnexo, $url' : url;
      }
    }

    if (!mounted) return;

    final id = widget.item?.id ?? '';
    Navigator.pop(
      context,
      ManutencaoItem(
        id: id,
        veiculoPlaca: _veiculoPlaca ?? '',
        veiculoNome: _veiculoNome ?? '',
        titulo: _tituloCtrl.text.trim(),
        descricao: _descricaoCtrl.text.trim(),
        tipo: _tipo,
        data: _data,
        kmNoServico: parseVal(_kmCtrl.text).toInt(),
        custo: parseVal(_custoCtrl.text),
        prioridade: _prioridade,
        coluna: _coluna,
        fornecedor: _fornecedorCtrl.text.trim(),
        numeroOS: _numeroOSCtrl.text.trim(),
        nomeAnexo: nomeAnexo,
        isPreventiva: _isPreventiva,
        dataConclusao: _coluna == KanbanColumn.concluidos ? _dataConclusao : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final isEditing = widget.item != null;

    return Stack(
      children: [
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
            child: Container(color: Colors.black.withValues(alpha: 0.5)),
          ),
        ),
        Center(
          child: ScaleTransition(
            scale: _scale,
            child: Container(
              width: 560,
              constraints: BoxConstraints(maxHeight: screenHeight * 0.88),
              decoration: BoxDecoration(
                color: AppColors.surfaceDark,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0x12FFFFFF)),
              ),
              clipBehavior: Clip.antiAlias,
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildHeader(isEditing),
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildIdentificacao(),
                            const SizedBox(height: 20),
                            _buildAgendamento(),
                            const SizedBox(height: 20),
                            _buildPrioridadeStatus(),
                            const SizedBox(height: 20),
                            _buildObservacoes(),
                          ],
                        ),
                      ),
                    ),
                    _buildFooter(isEditing),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(bool isEditing) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 16, 16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0x12FFFFFF))),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.atrOrange.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(LucideIcons.wrench, size: 18, color: AppColors.atrOrange),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isEditing ? 'Editar OS' : 'Nova Ordem de Serviço',
                  style: GoogleFonts.syne(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimaryDark),
                ),
                const SizedBox(height: 2),
                Text(
                  isEditing ? 'Edite os dados da manutenção' : 'Registre uma nova manutenção na frota',
                  style: const TextStyle(fontSize: 12, color: AppColors.textMutedDark),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(LucideIcons.x, size: 18, color: AppColors.textMutedDark),
          ),
        ],
      ),
    );
  }

  Widget _buildIdentificacao() {
    return _section('Identificação', [
      Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: const Color(0x12FFFFFF)),
              ),
              child: DropdownButtonFormField<String>(
                initialValue: _veiculoPlaca,
                decoration: InputDecoration(
                  labelText: _veiculoFixo ? 'Veículo (pré-selecionado)' : 'Veículo *',
                  border: InputBorder.none,
                  labelStyle: const TextStyle(fontSize: 12, color: AppColors.textMutedDark),
                ),
                items: _veiculoFixo
                    ? [DropdownMenuItem(value: _veiculoPlaca, child: Text(_veiculoNome ?? _veiculoPlaca ?? ''))]
                    : widget.fleet.frota.map((v) => DropdownMenuItem(value: v.placa, child: Text('${v.nome} (${v.placa})'))).toList(),
                onChanged: _veiculoFixo ? null : (v) => setState(() => _veiculoPlaca = v),
                validator: (v) => v == null ? 'Selecione um veículo' : null,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: const Color(0x12FFFFFF)),
              ),
              child: DropdownButtonFormField<String>(
                initialValue: _tipos.contains(_tipo) ? _tipo : 'Outro',
                decoration: const InputDecoration(
                  labelText: 'Tipo de Serviço *',
                  border: InputBorder.none,
                  labelStyle: TextStyle(fontSize: 12, color: AppColors.textMutedDark),
                ),
                items: _tipos.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                onChanged: (v) => setState(() => _tipo = v ?? 'Revisão'),
                validator: (v) => v == null ? 'Selecione o tipo' : null,
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      TextFormField(
        controller: _tituloCtrl,
        decoration: _dec('Título da OS *', hint: 'Ex: Revisão 10.000 km'),
        validator: (v) => v == null || v.trim().isEmpty ? 'Obrigatório' : null,
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(
            child: _segBtn('Preventiva', _isPreventiva, () => setState(() => _isPreventiva = true)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _segBtn('Corretiva', !_isPreventiva, () => setState(() => _isPreventiva = false)),
          ),
        ],
      ),
    ]);
  }

  Widget _segBtn(String label, bool ativo, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(9),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: ativo ? AppColors.atrOrange.withValues(alpha: 0.12) : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: ativo ? AppColors.atrOrange.withValues(alpha: 0.4) : const Color(0x12FFFFFF)),
        ),
        child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: ativo ? AppColors.atrOrange : AppColors.textMutedDark)),
      ),
    );
  }

  Widget _buildAgendamento() {
    return _section('Agendamento & Custo', [
      Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () async {
                final picked = await showDatePicker(context: context, initialDate: _data, firstDate: DateTime(2020), lastDate: DateTime.now().add(const Duration(days: 365)));
                if (picked != null) setState(() => _data = picked);
              },
              child: InputDecorator(
                decoration: _dec('Data *', prefixIcon: LucideIcons.calendar),
                child: Text(_dateFmt.format(_data), style: const TextStyle(fontSize: 12)),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextFormField(
              controller: _kmCtrl,
              decoration: _dec('Hodômetro (km)', suffix: 'km', prefixIcon: LucideIcons.gauge),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextFormField(
              controller: _custoCtrl,
              decoration: _dec('Custo estimado', prefix: 'R\$ ', prefixIcon: LucideIcons.dollarSign),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      TextFormField(
        controller: _fornecedorCtrl,
        decoration: _dec('Fornecedor / Oficina', prefixIcon: LucideIcons.building),
      ),
      const SizedBox(height: 12),
      TextFormField(
        controller: _numeroOSCtrl,
        decoration: _dec('Nº OS (opcional)', prefixIcon: LucideIcons.hash),
      ),
    ]);
  }

  Widget _buildPrioridadeStatus() {
    return _section('Prioridade & Status', [
      Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Prioridade', style: TextStyle(fontSize: 10, letterSpacing: 0.3, color: AppColors.textMutedDark)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _segBtn('Alta', _prioridade == MaintenancePriority.alta, () => setState(() => _prioridade = MaintenancePriority.alta)),
                    const SizedBox(width: 6),
                    _segBtn('Média', _prioridade == MaintenancePriority.media, () => setState(() => _prioridade = MaintenancePriority.media)),
                    const SizedBox(width: 6),
                    _segBtn('Baixa', _prioridade == MaintenancePriority.baixa, () => setState(() => _prioridade = MaintenancePriority.baixa)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: const Color(0x12FFFFFF)),
              ),
              child: DropdownButtonFormField<KanbanColumn>(
                initialValue: _coluna,
                decoration: const InputDecoration(
                  labelText: 'Status',
                  border: InputBorder.none,
                  labelStyle: TextStyle(fontSize: 12, color: AppColors.textMutedDark),
                ),
                items: KanbanColumn.values.map((c) => DropdownMenuItem(value: c, child: Text(c.label))).toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _coluna = v);
                },
              ),
            ),
          ),
        ],
      ),
      if (_coluna == KanbanColumn.concluidos) ...[
        const SizedBox(height: 12),
        InkWell(
          onTap: () async {
            final picked = await showDatePicker(context: context, initialDate: _dataConclusao ?? DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime.now());
            if (picked != null) setState(() => _dataConclusao = picked);
          },
          child: InputDecorator(
            decoration: _dec('Data de Conclusão', prefixIcon: LucideIcons.checkCircle),
            child: Text(_dataConclusao != null ? _dateFmt.format(_dataConclusao!) : 'Selecionar', style: const TextStyle(fontSize: 12)),
          ),
        ),
      ],
    ]);
  }

  Widget _buildObservacoes() {
    return _section('Observações & Anexos', [
      TextFormField(
        controller: _descricaoCtrl,
        decoration: _dec('Observações', hint: 'Detalhes da manutenção, peças trocadas...'),
        minLines: 3,
        maxLines: 6,
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _uploading
                  ? null
                  : () async {
                      final picker = ImagePicker();
                      final picked = await picker.pickImage(
                        source: ImageSource.gallery,
                        maxWidth: 1600,
                        imageQuality: 85,
                      );
                      if (picked != null) {
                        setState(() => _anexoFile = File(picked.path));
                      }
                    },
              icon: Icon(_anexoFile != null ? LucideIcons.paperclip : LucideIcons.upload, size: 16),
              label: Text(
                _uploading
                    ? 'Enviando...'
                    : _anexoFile != null
                        ? 'Arquivo selecionado'
                        : 'Anexar arquivo',
                style: const TextStyle(fontSize: 12),
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
            ),
          ),
          if (_anexoFile != null) ...[
            const SizedBox(width: 8),
            IconButton(
              onPressed: () => setState(() => _anexoFile = null),
              icon: const Icon(LucideIcons.x, size: 16),
              tooltip: 'Remover anexo',
            ),
          ],
        ],
      ),
      if (widget.item != null && widget.item!.nomeAnexo.isNotEmpty) ...[
        const SizedBox(height: 8),
        Builder(builder: (context) {
          final anexos = widget.item!.nomeAnexo.split(', ');
          return GestureDetector(
            onTap: () {
              for (final url in anexos) {
                final uri = Uri.tryParse(url.trim());
                if (uri != null) launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
            child: Row(
              children: [
                const Icon(LucideIcons.paperclip, size: 14, color: AppColors.atrOrange),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${anexos.length} anexo(s) — toque para abrir',
                  style: const TextStyle(fontSize: 11, color: AppColors.atrOrange),
                ),
              ),
            ],
          ),
        );
      }),
      ],
    ]);
  }

  Widget _section(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: GoogleFonts.syne(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimaryDark)),
        const SizedBox(height: 10),
        ...children,
      ],
    );
  }

  Widget _buildFooter(bool isEditing) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0x12FFFFFF))),
      ),
      child: Row(
        children: [
          Expanded(
            child: AtrGhostButton(label: 'Cancelar', onPressed: () => Navigator.pop(context)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: AtrPrimaryButton(
              label: isEditing ? 'Salvar' : 'Criar OS',
              icon: LucideIcons.check,
              onPressed: _submit,
            ),
          ),
        ],
      ),
    );
  }
}
