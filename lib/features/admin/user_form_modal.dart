import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../core/services/user_admin_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/atr_button.dart';

const Map<String, String> _featureLabels = {
  'dashboard': 'Dashboard Executivo',
  'frota': 'Controle de Frota',
  'vehicles': 'Veículos',
  'drivers': 'Motoristas',
  'custos': 'Custos da Frota',
  'contratos': 'Contratos B2B',
  'vencimentos': 'Vencimentos',
  'relatorios': 'Relatórios',
  'financial_admin': 'Adm Financeiro',
  'obras': 'Obras',
  'sala_atr': 'Sala ATR',
  'lazer': 'Lazer',
  'ai_assistant': 'Assistente IA',
};

class UserFormModal extends StatefulWidget {
  final AppUser? existing;

  const UserFormModal({super.key, this.existing});

  @override
  State<UserFormModal> createState() => _UserFormModalState();
}

class _UserFormModalState extends State<UserFormModal> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _userCtrl = TextEditingController();
  final _nomeCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  String _role = 'member';
  final Set<String> _selectedFeatures = {};
  bool _saving = false;
  String? _error;
  bool _obscurePass = true;
  bool _obscureConfirm = true;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      final u = widget.existing!;
      _userCtrl.text = u.username;
      _nomeCtrl.text = u.nomeCompleto;
      _role = u.role;
      _selectedFeatures.addAll(u.allowedFeatures);
    }
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _userCtrl.dispose();
    _nomeCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_role == 'member' && _selectedFeatures.isEmpty) {
      setState(() => _error = 'Selecione ao menos uma tela para o membro.');
      return;
    }

    setState(() { _saving = true; _error = null; });

    try {
      final service = UserAdminService();
      if (_isEditing) {
        await service.updateUser(
          id: widget.existing!.id!,
          username: _userCtrl.text.trim(),
          nomeCompleto: _nomeCtrl.text.trim(),
          role: _role,
          features: _role == 'admin' ? [] : _selectedFeatures.toList(),
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Usuário atualizado.'), backgroundColor: AppColors.statusSuccess),
          );
          Navigator.pop(context, true);
        }
      } else {
        await service.createUser(
          email: _emailCtrl.text.trim(),
          password: _passCtrl.text,
          username: _userCtrl.text.trim(),
          nomeCompleto: _nomeCtrl.text.trim(),
          role: _role,
          allowedFeatures: _role == 'admin' ? [] : _selectedFeatures.toList(),
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Usuário criado. Ele já pode fazer login com email e senha.'), backgroundColor: AppColors.statusSuccess),
          );
          Navigator.pop(context, true);
        }
      }
    } on UserAdminException catch (e) {
      if (mounted) setState(() { _error = e.message; _saving = false; });
    } catch (e) {
      if (mounted) setState(() { _error = 'Erro de conexão. Tente novamente.'; _saving = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surfaceDark,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.xxl)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 700),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.atrOrange.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          _isEditing ? LucideIcons.pencil : LucideIcons.userPlus,
                          color: AppColors.atrOrange, size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _isEditing ? 'Editar Usuário' : 'Novo Usuário',
                              style: const TextStyle(
                                fontFamily: 'Syne', fontSize: 20,
                                fontWeight: FontWeight.w800, color: AppColors.textPrimaryDark,
                              ),
                            ),
                            Text(
                              _isEditing ? 'Altere as permissões do usuário' : 'Preencha os dados para criar o login',
                              style: const TextStyle(fontSize: 12, color: AppColors.textSecondaryDark),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(LucideIcons.x, size: 20, color: AppColors.textSecondaryDark),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  if (!_isEditing) ...[
                    _buildField('Email', _emailCtrl, LucideIcons.mail, (v) {
                      if (v == null || v.trim().isEmpty) return 'Obrigatório';
                      if (!v.contains('@')) return 'Email inválido';
                      return null;
                    }),
                    const SizedBox(height: 14),
                  ],

                  _buildField('Username', _userCtrl, LucideIcons.user, (v) {
                    if (v == null || v.trim().isEmpty) return 'Obrigatório';
                    if (v.trim().length < 3) return 'Mínimo 3 caracteres';
                    return null;
                  }),
                  const SizedBox(height: 14),

                  _buildField('Nome completo', _nomeCtrl, LucideIcons.userCircle, null),
                  const SizedBox(height: 14),

                  if (!_isEditing) ...[
                    _buildField('Senha', _passCtrl, LucideIcons.lock, (v) {
                      if (v == null || v.isEmpty) return 'Obrigatório';
                      if (v.length < 12) return 'Mínimo 12 caracteres';
                      return null;
                    }, obscure: _obscurePass, suffix: IconButton(
                      icon: Icon(_obscurePass ? LucideIcons.eye : LucideIcons.eyeOff, size: 16, color: AppColors.textSecondaryDark),
                      onPressed: () => setState(() => _obscurePass = !_obscurePass),
                    )),
                    const SizedBox(height: 14),
                    _buildField('Confirmar senha', _confirmCtrl, LucideIcons.lock, (v) {
                      if (v != _passCtrl.text) return 'Senhas não conferem';
                      return null;
                    }, obscure: _obscureConfirm, suffix: IconButton(
                      icon: Icon(_obscureConfirm ? LucideIcons.eye : LucideIcons.eyeOff, size: 16, color: AppColors.textSecondaryDark),
                      onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                    )),
                    const SizedBox(height: 20),
                  ],

                  // Role selector
                  const Text('Função', style: TextStyle(color: AppColors.textSecondaryDark, fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  _buildRoleOption('admin', 'Administrador', 'Acesso total a todas as telas e gerenciamento de usuários'),
                  const SizedBox(height: 6),
                  _buildRoleOption('member', 'Membro Restrito', 'Acesso apenas às telas selecionadas abaixo'),

                  if (_role == 'member') ...[
                    const SizedBox(height: 20),
                    const Text('Telas permitidas', style: TextStyle(color: AppColors.textSecondaryDark, fontSize: 12, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: _featureLabels.entries.where((e) => e.key != 'users_admin').map((entry) {
                        final checked = _selectedFeatures.contains(entry.key);
                        return SizedBox(
                          width: 170,
                          child: CheckboxListTile(
                            dense: true,
                            value: checked,
                            contentPadding: EdgeInsets.zero,
                            activeColor: AppColors.atrOrange,
                            title: Text(entry.value, style: const TextStyle(fontSize: 12, color: AppColors.textPrimaryDark)),
                            controlAffinity: ListTileControlAffinity.leading,
                            onChanged: (v) {
                              setState(() {
                                if (v == true) _selectedFeatures.add(entry.key);
                                else _selectedFeatures.remove(entry.key);
                              });
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ] else ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.atrOrange.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.atrOrange.withValues(alpha: 0.15)),
                      ),
                      child: const Row(
                        children: [
                          Icon(LucideIcons.shieldCheck, color: AppColors.atrOrange, size: 16),
                          SizedBox(width: 8),
                          Expanded(child: Text('Admins têm acesso a todas as telas automaticamente', style: TextStyle(color: AppColors.atrOrange, fontSize: 12))),
                        ],
                      ),
                    ),
                  ],

                  if (_error != null) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.statusError.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.statusError.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        children: [
                          const Icon(LucideIcons.alertCircle, color: AppColors.statusError, size: 16),
                          const SizedBox(width: 8),
                          Expanded(child: Text(_error!, style: const TextStyle(color: AppColors.statusError, fontSize: 12))),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      AtrButton.ghost(label: 'Cancelar', onPressed: () => Navigator.pop(context)),
                      const SizedBox(width: 10),
                      AtrButton.primary(
                        label: _isEditing ? 'Salvar' : 'Criar Login',
                        icon: _isEditing ? LucideIcons.save : LucideIcons.userPlus,
                        loading: _saving,
                        onPressed: _submit,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildField(String label, TextEditingController ctrl, IconData icon,
      String? Function(String?)? validator, {bool readOnly = false, bool obscure = false, Widget? suffix}) {
    return TextFormField(
      controller: ctrl,
      readOnly: readOnly,
      obscureText: obscure,
      validator: validator,
      style: const TextStyle(color: AppColors.textPrimaryDark, fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppColors.textSecondaryDark, fontSize: 11),
        prefixIcon: Icon(icon, size: 16, color: AppColors.textSecondaryDark),
        suffixIcon: suffix,
        filled: true,
        fillColor: AppColors.surfaceDarkAlt,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.borderDark),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.borderDark),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.atrOrange),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.statusError),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }

  Widget _buildRoleOption(String value, String title, String desc) {
    final selected = _role == value;
    return GestureDetector(
      onTap: () => setState(() => _role = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? AppColors.atrOrange.withValues(alpha: 0.08) : AppColors.surfaceDarkAlt,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? AppColors.atrOrange.withValues(alpha: 0.3) : AppColors.borderDark,
          ),
        ),
        child: Row(
          children: [
            Icon(
              selected ? LucideIcons.checkCircle2 : LucideIcons.circle,
              color: selected ? AppColors.atrOrange : AppColors.textMutedDark,
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(color: selected ? AppColors.atrOrange : AppColors.textPrimaryDark, fontSize: 13, fontWeight: FontWeight.w600)),
                  Text(desc, style: const TextStyle(color: AppColors.textSecondaryDark, fontSize: 11)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
