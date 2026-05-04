import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/data/fleet_data.dart';
import '../../../core/data/locacao_models.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/theme/app_colors.dart';
import '../locacao_provider.dart';

final _dateFmt = DateFormat('dd/MM/yyyy');

class ContratoFormSheet extends StatefulWidget {
  final Contrato? contrato;
  const ContratoFormSheet({super.key, this.contrato});

  @override
  State<ContratoFormSheet> createState() => _ContratoFormSheetState();
}

class _ContratoFormSheetState extends State<ContratoFormSheet> {
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;

  late final TextEditingController _numeroCtrl;
  late final TextEditingController _clienteNomeCtrl;
  late final TextEditingController _clienteCnpjCtrl;
  late final TextEditingController _clienteContatoCtrl;
  late final TextEditingController _slaKmCtrl;
  late final TextEditingController _valorMensalCtrl;
  late final TextEditingController _obsCtrl;

  String? _veiculoPlacaSelecionada;
  DateTime _dataInicio = DateTime.now();
  DateTime _dataFim = DateTime.now().add(const Duration(days: 365));
  ContratoStatus _status = ContratoStatus.rascunho;

  bool get _isEditing => widget.contrato != null;

  @override
  void initState() {
    super.initState();
    final c = widget.contrato;
    _numeroCtrl = TextEditingController(text: c?.numero ?? _gerarNumero());
    _clienteNomeCtrl = TextEditingController(text: c?.clienteNome ?? '');
    _clienteCnpjCtrl = TextEditingController(text: c?.clienteCnpj ?? '');
    _clienteContatoCtrl = TextEditingController(text: c?.clienteContato ?? '');
    _slaKmCtrl = TextEditingController(text: c?.slaKmMes.toString() ?? '');
    _valorMensalCtrl = TextEditingController(
        text: c?.valorMensal.toStringAsFixed(2) ?? '',);
    _obsCtrl = TextEditingController(text: c?.observacoes ?? '');
    if (c != null) {
      _veiculoPlacaSelecionada = c.veiculoPlaca;
      _dataInicio = c.dataInicio;
      _dataFim = c.dataFim;
      _status = c.status;
    }
  }

  String _gerarNumero() {
    final ano = DateTime.now().year;
    final seq = DateTime.now().millisecondsSinceEpoch % 1000;
    return 'CTR-$ano-${seq.toString().padLeft(3, '0')}';
  }

  @override
  void dispose() {
    _numeroCtrl.dispose();
    _clienteNomeCtrl.dispose();
    _clienteCnpjCtrl.dispose();
    _clienteContatoCtrl.dispose();
    _slaKmCtrl.dispose();
    _valorMensalCtrl.dispose();
    _obsCtrl.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;
    if (_veiculoPlacaSelecionada == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione um veículo')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final username =
          context.read<AuthService>().currentUser?.username ?? 'desconhecido';
      final provider = context.read<LocacaoProvider>();
      final now = DateTime.now();

      final novoContrato = Contrato(
        id: widget.contrato?.id ?? '',
        numero: _numeroCtrl.text.trim(),
        clienteNome: _clienteNomeCtrl.text.trim(),
        clienteCnpj: _clienteCnpjCtrl.text.trim(),
        clienteContato: _clienteContatoCtrl.text.trim(),
        veiculoPlaca: _veiculoPlacaSelecionada!,
        dataInicio: _dataInicio,
        dataFim: _dataFim,
        slaKmMes: int.tryParse(_slaKmCtrl.text) ?? 0,
        valorMensal: double.tryParse(
                _valorMensalCtrl.text.replaceAll(',', '.'),) ??
            0.0,
        status: _status,
        observacoes: _obsCtrl.text.trim(),
        criadoPor: username,
        createdAt: widget.contrato?.createdAt ?? now,
        updatedAt: now,
      );

      if (_isEditing) {
        await provider.atualizarContrato(novoContrato);
      } else {
        await provider.criarContrato(novoContrato);
      }

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao salvar: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickDate({required bool isInicio}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isInicio ? _dataInicio : _dataFim,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked == null) return;
    setState(() {
      if (isInicio) {
        _dataInicio = picked;
      } else {
        _dataFim = picked;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final frota = context.read<FleetRepository>().frota;

    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.6,
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
              // Handle
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
              Text(
                _isEditing ? 'Editar Contrato' : 'Novo Contrato',
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w800,),
              ),
              const SizedBox(height: 24),

              const _SectionLabel('Identificação'),
              _FieldRow(children: [
                _FormField(
                  controller: _numeroCtrl,
                  label: 'Nº Contrato',
                  isDark: isDark,
                  validator: _requiredValidator,
                ),
                _FormField(
                  controller: _clienteNomeCtrl,
                  label: 'Nome do Cliente',
                  isDark: isDark,
                  validator: _requiredValidator,
                ),
              ],),
              const SizedBox(height: 12),
              _FieldRow(children: [
                _FormField(
                  controller: _clienteCnpjCtrl,
                  label: 'CNPJ',
                  isDark: isDark,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: _requiredValidator,
                ),
                _FormField(
                  controller: _clienteContatoCtrl,
                  label: 'Contato / E-mail',
                  isDark: isDark,
                ),
              ],),
              const SizedBox(height: 20),

              const _SectionLabel('Veículo'),
              DropdownButtonFormField<String>(
                initialValue: _veiculoPlacaSelecionada,
                decoration: _inputDecoration('Placa do Veículo', isDark),
                items: frota
                    .map((v) => DropdownMenuItem(
                          value: v.placa,
                          child: Text('${v.placa} — ${v.nome}'),
                        ),)
                    .toList(),
                onChanged: (v) =>
                    setState(() => _veiculoPlacaSelecionada = v),
                validator: (v) =>
                    v == null ? 'Selecione um veículo' : null,
              ),
              const SizedBox(height: 20),

              const _SectionLabel('Vigência e Valores'),
              _FieldRow(children: [
                _DatePickerField(
                  label: 'Início',
                  date: _dataInicio,
                  isDark: isDark,
                  onTap: () => _pickDate(isInicio: true),
                ),
                _DatePickerField(
                  label: 'Fim',
                  date: _dataFim,
                  isDark: isDark,
                  onTap: () => _pickDate(isInicio: false),
                ),
              ],),
              const SizedBox(height: 12),
              _FieldRow(children: [
                _FormField(
                  controller: _valorMensalCtrl,
                  label: 'Valor Mensal (R\$)',
                  isDark: isDark,
                  keyboardType: TextInputType.number,
                  validator: _requiredValidator,
                ),
                _FormField(
                  controller: _slaKmCtrl,
                  label: 'SLA KM / Mês',
                  isDark: isDark,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
              ],),
              const SizedBox(height: 20),

              const _SectionLabel('Status'),
              Wrap(
                spacing: 8,
                children: ContratoStatus.values
                    .map((s) => ChoiceChip(
                          label: Text(s.label),
                          selected: _status == s,
                          selectedColor: s.color.withValues(alpha: 0.2),
                          onSelected: (_) => setState(() => _status = s),
                          labelStyle: TextStyle(
                            color: _status == s ? s.color : null,
                            fontWeight: _status == s
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),)
                    .toList(),
              ),
              const SizedBox(height: 20),

              const _SectionLabel('Observações'),
              TextFormField(
                controller: _obsCtrl,
                maxLines: 3,
                decoration: _inputDecoration('Observações opcionais', isDark),
              ),
              const SizedBox(height: 28),

              SizedBox(
                height: 48,
                child: FilledButton(
                  onPressed: _saving ? null : _salvar,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.atrOrange,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          _isEditing ? 'Salvar Alterações' : 'Criar Contrato',
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 15,),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String? _requiredValidator(String? v) =>
    (v == null || v.trim().isEmpty) ? 'Campo obrigatório' : null;

InputDecoration _inputDecoration(String label, bool isDark) {
  return InputDecoration(
    labelText: label,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
  );
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

class _FieldRow extends StatelessWidget {
  final List<Widget> children;
  const _FieldRow({required this.children});
  @override
  Widget build(BuildContext context) {
    return Row(
      children: children
          .map((c) => Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                      right: c == children.last ? 0 : 12,),
                  child: c,
                ),
              ),)
          .toList(),
    );
  }
}

class _FormField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool isDark;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final String? Function(String?)? validator;
  const _FormField({
    required this.controller,
    required this.label,
    required this.isDark,
    this.keyboardType,
    this.inputFormatters,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator: validator,
      decoration: _inputDecoration(label, isDark),
    );
  }
}

class _DatePickerField extends StatelessWidget {
  final String label;
  final DateTime date;
  final bool isDark;
  final VoidCallback onTap;
  const _DatePickerField({
    required this.label,
    required this.date,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: InputDecorator(
        decoration: _inputDecoration(label, isDark),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(_dateFmt.format(date)),
            const Icon(LucideIcons.calendar, size: 16),
          ],
        ),
      ),
    );
  }
}
