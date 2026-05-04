import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/data/locacao_models.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/theme/app_colors.dart';
import '../locacao_provider.dart';

class ChecklistFormSheet extends StatefulWidget {
  final String contratoId;
  const ChecklistFormSheet({super.key, required this.contratoId});

  @override
  State<ChecklistFormSheet> createState() => _ChecklistFormSheetState();
}

class _ChecklistFormSheetState extends State<ChecklistFormSheet> {
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;

  ChecklistTipo _tipo = ChecklistTipo.checkIn;
  final _kmCtrl = TextEditingController();
  final _kmPercorridosCtrl = TextEditingController();
  final _obsCtrl = TextEditingController();
  double _combustivelPct = 100;

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
        id: '',
        contratoId: widget.contratoId,
        tipo: _tipo,
        kmOdometro: int.tryParse(_kmCtrl.text) ?? 0,
        kmPercorridos: _kmPercorridosCtrl.text.isNotEmpty
            ? int.tryParse(_kmPercorridosCtrl.text)
            : null,
        combustivelPct: _combustivelPct.toInt(),
        observacoes: _obsCtrl.text.trim(),
        realizadoPor: username,
        createdAt: DateTime.now(),
      );
      await context.read<LocacaoProvider>().registrarChecklist(evento);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao registrar: $e')),
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
              const Text('Registrar Evento',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),),
              const SizedBox(height: 20),

              // Tipo
              Row(
                children: ChecklistTipo.values
                    .map((t) => Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(
                                right: t == ChecklistTipo.checkIn ? 8 : 0,),
                            child: _TipoButton(
                              tipo: t,
                              isSelected: _tipo == t,
                              onTap: () => setState(() => _tipo = t),
                            ),
                          ),
                        ),)
                    .toList(),
              ),
              const SizedBox(height: 20),

              TextFormField(
                controller: _kmCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'Hodômetro Atual (km)',
                  prefixIcon: Icon(Icons.speed, size: 18),
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Campo obrigatório' : null,
              ),
              const SizedBox(height: 12),

              if (_tipo == ChecklistTipo.checkOut)
                TextFormField(
                  controller: _kmPercorridosCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'KM Percorridos no Período',
                    prefixIcon: Icon(Icons.alt_route, size: 18),
                    border: OutlineInputBorder(),
                  ),
                ),
              if (_tipo == ChecklistTipo.checkOut) const SizedBox(height: 12),

              // Combustível
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Nível de Combustível: ${_combustivelPct.toInt()}%',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Slider(
                    value: _combustivelPct,
                    max: 100,
                    divisions: 10,
                    activeColor: AppColors.atrOrange,
                    label: '${_combustivelPct.toInt()}%',
                    onChanged: (v) => setState(() => _combustivelPct = v),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _obsCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Observações',
                  border: OutlineInputBorder(),
                ),
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
                              strokeWidth: 2, color: Colors.white,),
                        )
                      : Text(
                          'Registrar ${_tipo.label}',
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
              color: isSelected ? color : Colors.grey.withValues(alpha: 0.3),),
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
