import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/data/locacao_models.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/atr_button.dart';
import '../locacao_provider.dart';

class OcorrenciaFormSheet extends StatefulWidget {
  final String contratoId;
  final Ocorrencia? ocorrencia;
  const OcorrenciaFormSheet({super.key, required this.contratoId, this.ocorrencia});

  bool get isEditing => ocorrencia != null;

  @override
  State<OcorrenciaFormSheet> createState() => _OcorrenciaFormSheetState();
}

class _OcorrenciaFormSheetState extends State<OcorrenciaFormSheet> {
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;

  late OcorrenciaTipo _tipo;
  late String _responsavel;
  late final TextEditingController _descricaoCtrl;
  late final TextEditingController _valorCtrl;
  late final TextEditingController _impactoCtrl;
  late final TextEditingController _obsCtrl;
  late DateTime _dataOcorrencia;

  @override
  void initState() {
    super.initState();
    final o = widget.ocorrencia;
    _tipo = o?.tipo ?? OcorrenciaTipo.multa;
    _responsavel = o?.responsavelPagamento ?? 'cliente';
    _descricaoCtrl = TextEditingController(text: o?.descricao ?? '');
    _valorCtrl = TextEditingController(
      text: (o?.valorEstimado ?? 0) > 0 ? o!.valorEstimado.toStringAsFixed(2) : '',
    );
    _impactoCtrl = TextEditingController(
      text: (o?.impactoFinanceiro ?? 0) > 0 ? o!.impactoFinanceiro.toStringAsFixed(2) : '',
    );
    _obsCtrl = TextEditingController(text: o?.observacoes ?? '');
    _dataOcorrencia = o?.dataOcorrencia ?? DateTime.now();
  }

  @override
  void dispose() {
    _descricaoCtrl.dispose();
    _valorCtrl.dispose();
    _impactoCtrl.dispose();
    _obsCtrl.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final username =
          context.read<AuthService>().currentUser?.username ?? 'desconhecido';
      final ocorrencia = Ocorrencia(
        id: widget.ocorrencia?.id ?? '',
        contratoId: widget.contratoId,
        tipo: _tipo,
        descricao: _descricaoCtrl.text.trim(),
        dataOcorrencia: _dataOcorrencia,
        valorEstimado:
            double.tryParse(_valorCtrl.text.replaceAll(',', '.')) ?? 0.0,
        impactoFinanceiro:
            double.tryParse(_impactoCtrl.text.replaceAll(',', '.')) ?? 0.0,
        responsavelPagamento: _responsavel,
        fotos: widget.ocorrencia?.fotos ?? const [],
        observacoes: _obsCtrl.text.trim(),
        registradoPor: widget.ocorrencia?.registradoPor ?? username,
        status: widget.ocorrencia?.status ?? OcorrenciaStatus.aberta,
        valorFinal: widget.ocorrencia?.valorFinal,
        resolvidoPor: widget.ocorrencia?.resolvidoPor,
        dataResolucao: widget.ocorrencia?.dataResolucao,
        createdAt: widget.ocorrencia?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );
      if (widget.isEditing) {
        await context.read<LocacaoProvider>().atualizarOcorrencia(ocorrencia);
      } else {
        await context.read<LocacaoProvider>().criarOcorrencia(ocorrencia);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao ${widget.isEditing ? 'atualizar' : 'registrar'}: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickData() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dataOcorrencia,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _dataOcorrencia = picked);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.97,
      builder: (ctx, scrollController) => Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Form(
          key: _formKey,
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 40),
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              Text(widget.isEditing ? 'Editar Ocorrência' : 'Nova Ocorrência',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 20),

              // Tipo de ocorrência
              _SectionLabel('Tipo de Ocorrência'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: OcorrenciaTipo.values
                    .map((t) => ChoiceChip(
                          label: Text(t.label),
                          selected: _tipo == t,
                          selectedColor: t.color.withValues(alpha: 0.2),
                          onSelected: (_) => setState(() => _tipo = t),
                          labelStyle: TextStyle(
                            color: _tipo == t ? t.color : null,
                            fontWeight: _tipo == t
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _descricaoCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Descrição da Ocorrência',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Campo obrigatório' : null,
              ),
              const SizedBox(height: 12),

              // Data
              InkWell(
                onTap: _pickData,
                borderRadius: BorderRadius.circular(10),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Data da Ocorrência',
                    border: OutlineInputBorder(),
                  ),
                  child: Text(
                    '${_dataOcorrencia.day.toString().padLeft(2, '0')}/${_dataOcorrencia.month.toString().padLeft(2, '0')}/${_dataOcorrencia.year}',
                  ),
                ),
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _valorCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Valor Estimado (R\$)',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          (v == null || v.isEmpty) ? 'Campo obrigatório' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _impactoCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Impacto Financeiro (R\$)',
                        border: OutlineInputBorder(),
                        helperText: 'Valor deduzido do contrato',
                      ),
                      validator: (v) =>
                          (v == null || v.isEmpty) ? 'Campo obrigatório' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              _SectionLabel('Responsável pelo Pagamento'),
              Wrap(
                spacing: 8,
                children: [
                  for (final r in ['cliente', 'seguro', 'atr'])
                    ChoiceChip(
                      label: Text(r.toUpperCase()),
                      selected: _responsavel == r,
                      selectedColor: AppColors.atrOrange.withValues(alpha: 0.2),
                      onSelected: (_) => setState(() => _responsavel = r),
                      labelStyle: TextStyle(
                        color: _responsavel == r ? AppColors.atrOrange : null,
                        fontWeight: _responsavel == r
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _obsCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Observações',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 28),

              AtrPrimaryButton(
                label: widget.isEditing ? 'Atualizar Ocorrência' : 'Registrar Ocorrência',
                loading: _saving,
                onPressed: _salvar,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
          color: AppColors.atrOrange,
        ),
      ),
    );
  }
}
