import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/data/locacao_models.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/atr_button.dart';
import '../locacao_provider.dart';

/// Itens padrao de inspecao do checklist com estado inicial N/A.
const Map<String, String> kChecklistItemsPadrao = {
  'Pneus': 'N/A',
  'Farois': 'N/A',
  'Vidros': 'N/A',
  'Retrovisores': 'N/A',
  'Lataria': 'N/A',
  'Interior': 'N/A',
  'Ar Condicionado': 'N/A',
  'Freios': 'N/A',
  'Estepe': 'N/A',
  'Documentos': 'N/A',
  'Limpeza': 'N/A',
  'Tapetes': 'N/A',
};

const _estados = ['OK', 'Avaria', 'N/A'];

class ChecklistFormSheet extends StatefulWidget {
  final String contratoId;
  final ChecklistEvento? evento;
  const ChecklistFormSheet({super.key, required this.contratoId, this.evento});

  bool get isEditing => evento != null;

  @override
  State<ChecklistFormSheet> createState() => _ChecklistFormSheetState();
}

class _ChecklistFormSheetState extends State<ChecklistFormSheet> {
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;

  late ChecklistTipo _tipo;
  late final TextEditingController _kmCtrl;
  late final TextEditingController _kmPercorridosCtrl;
  late final TextEditingController _obsCtrl;
  late double _combustivelPct;
  late Map<String, String> _itens;

  @override
  void initState() {
    super.initState();
    final e = widget.evento;
    _tipo = e?.tipo ?? ChecklistTipo.checkIn;
    _kmCtrl = TextEditingController(text: (e?.kmOdometro ?? 0) > 0 ? '${e!.kmOdometro}' : '');
    _kmPercorridosCtrl = TextEditingController(
      text: e?.kmPercorridos != null ? '${e!.kmPercorridos}' : '',
    );
    _obsCtrl = TextEditingController(text: e?.observacoes ?? '');
    _combustivelPct = (e?.combustivelPct ?? 100).toDouble();
    _itens = _parseItens(e?.itens);
  }

  Map<String, String> _parseItens(Map<String, dynamic>? json) {
    if (json == null || json.isEmpty) {
      return Map<String, String>.from(kChecklistItemsPadrao);
    }
    final result = <String, String>{};
    for (final entry in kChecklistItemsPadrao.entries) {
      final valor = json[entry.key] as String?;
      result[entry.key] = (valor != null && _estados.contains(valor)) ? valor : 'N/A';
    }
    return result;
  }

  @override
  void dispose() {
    _kmCtrl.dispose();
    _kmPercorridosCtrl.dispose();
    _obsCtrl.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final username =
          context.read<AuthService>().currentUser?.username ?? 'desconhecido';
      final evento = ChecklistEvento(
        id: widget.evento?.id ?? '',
        contratoId: widget.contratoId,
        tipo: _tipo,
        kmOdometro: int.tryParse(_kmCtrl.text) ?? 0,
        kmPercorridos: _kmPercorridosCtrl.text.isNotEmpty
            ? int.tryParse(_kmPercorridosCtrl.text)
            : null,
        combustivelPct: _combustivelPct.toInt(),
        observacoes: _obsCtrl.text.trim(),
        fotos: widget.evento?.fotos ?? const [],
        docUrl: widget.evento?.docUrl,
        assinaturaUrl: widget.evento?.assinaturaUrl,
        realizadoPor: widget.evento?.realizadoPor ?? username,
        createdAt: widget.evento?.createdAt ?? DateTime.now(),
        itens: Map<String, String>.from(_itens),
      );
      if (widget.isEditing) {
        await context.read<LocacaoProvider>().atualizarChecklist(evento);
      } else {
        await context.read<LocacaoProvider>().registrarChecklist(evento);
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
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
              Text(widget.isEditing ? 'Editar Evento' : 'Registrar Evento',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 20),

              // Tipo
              Row(
                children: ChecklistTipo.values
                    .map((t) => Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(
                                right: t == ChecklistTipo.checkIn ? 8 : 0),
                            child: _TipoButton(
                              tipo: t,
                              isSelected: _tipo == t,
                              onTap: () => setState(() => _tipo = t),
                            ),
                          ),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 20),

              TextFormField(
                controller: _kmCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'Hodometro Atual (km)',
                  prefixIcon: Icon(Icons.speed, size: 18),
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Campo obrigatorio' : null,
              ),
              const SizedBox(height: 12),

              if (_tipo == ChecklistTipo.checkOut)
                TextFormField(
                  controller: _kmPercorridosCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'KM Percorridos no Periodo',
                    prefixIcon: Icon(Icons.alt_route, size: 18),
                    border: OutlineInputBorder(),
                  ),
                ),
              if (_tipo == ChecklistTipo.checkOut) const SizedBox(height: 12),

              // Combustivel
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Nivel de Combustivel: ${_combustivelPct.toInt()}%',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Slider(
                    value: _combustivelPct,
                    min: 0,
                    max: 100,
                    divisions: 10,
                    activeColor: AppColors.atrOrange,
                    label: '${_combustivelPct.toInt()}%',
                    onChanged: (v) => setState(() => _combustivelPct = v),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Itens de Inspecao
              const Text('Itens de Inspecao',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              ..._itens.entries.map((entry) {
                final item = entry.key;
                final estado = entry.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Card(
                    margin: EdgeInsets.zero,
                    color: isDark ? AppColors.surfaceElevatedDark : Colors.grey.shade50,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(item,
                                style: const TextStyle(
                                    fontSize: 13, fontWeight: FontWeight.w500)),
                          ),
                          ..._estados.map((e) => Padding(
                                padding: const EdgeInsets.only(left: 4),
                                child: ChoiceChip(
                                  label: Text(e,
                                      style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: estado == e
                                              ? _chipTextColor(e)
                                              : AppColors.textSecondaryDark)),
                                  selected: estado == e,
                                  selectedColor: _chipColor(e),
                                  backgroundColor: Colors.transparent,
                                  side: BorderSide(
                                      color: estado == e
                                          ? _chipColor(e)
                                          : Colors.grey.withValues(alpha: 0.2)),
                                  materialTapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                  onSelected: (_) =>
                                      setState(() => _itens[item] = e),
                                ),
                              )),
                        ],
                      ),
                    ),
                  ),
                );
              }),
              const SizedBox(height: 12),

              TextFormField(
                controller: _obsCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Observacoes',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 28),

              AtrPrimaryButton(
                label: widget.isEditing ? 'Atualizar ${_tipo.label}' : 'Registrar ${_tipo.label}',
                loading: _saving,
                onPressed: _salvar,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _chipColor(String estado) {
    switch (estado) {
      case 'OK':
        return AppColors.statusSuccess;
      case 'Avaria':
        return AppColors.statusError;
      default:
        return AppColors.textMutedDark;
    }
  }

  Color _chipTextColor(String estado) {
    switch (estado) {
      case 'OK':
        return Colors.white;
      case 'Avaria':
        return Colors.white;
      default:
        return AppColors.textSecondaryDark;
    }
  }
}

class _TipoButton extends StatelessWidget {
  final ChecklistTipo tipo;
  final bool isSelected;
  final VoidCallback onTap;
  const _TipoButton({required this.tipo, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isIn = tipo == ChecklistTipo.checkIn;
    final color = isIn ? AppColors.statusSuccess : AppColors.statusWarning;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: isSelected ? color : Colors.grey.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isIn ? LucideIcons.logIn : LucideIcons.logOut,
              size: 18,
              color: isSelected ? color : Colors.grey,
            ),
            const SizedBox(width: 8),
            Text(
              tipo.label,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: isSelected ? color : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
