import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/atr_button.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentPassCtrl = TextEditingController();
  final _newPassCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();
  bool _loading = false;
  String? _error;
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _currentPassCtrl.dispose();
    _newPassCtrl.dispose();
    _confirmPassCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() { _loading = true; _error = null; });

    try {
      // Reautentica com a senha atual
      await Supabase.instance.client.auth.signInWithPassword(
        email: Supabase.instance.client.auth.currentUser!.email!,
        password: _currentPassCtrl.text,
      );

      // Atualiza a senha
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: _newPassCtrl.text),
      );

      // Atualiza must_change_password em app_users
      await Supabase.instance.client
          .from('app_users')
          .update({'must_change_password': false})
          .eq('id', Supabase.instance.client.auth.currentUser!.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Senha alterada com sucesso!'), backgroundColor: AppColors.statusSuccess),
        );
        context.go('/');
      }
    } on AuthException {
      if (mounted) {
        setState(() { _error = 'Senha atual incorreta.'; _loading = false; });
      }
    } catch (e) {
      if (mounted) {
        setState(() { _error = 'Erro ao alterar senha. Tente novamente.'; _loading = false; });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.atrOrange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(LucideIcons.lock, color: AppColors.atrOrange, size: 32),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Alterar Senha',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Syne',
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimaryDark,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Por segurança, defina uma nova senha antes de continuar.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textSecondaryDark, fontSize: 13),
                    ),
                    const SizedBox(height: 28),

                    // Senha atual
                    const Text('Senha atual', style: TextStyle(color: AppColors.textSecondaryDark, fontSize: 12, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _currentPassCtrl,
                      obscureText: _obscureCurrent,
                      validator: (v) => v == null || v.trim().isEmpty ? 'Obrigatório' : null,
                      style: const TextStyle(color: AppColors.textPrimaryDark, fontSize: 13),
                      decoration: _inputDec('Digite sua senha atual', LucideIcons.lock, IconButton(
                        icon: Icon(_obscureCurrent ? LucideIcons.eye : LucideIcons.eyeOff, size: 16, color: AppColors.textSecondaryDark),
                        onPressed: () => setState(() => _obscureCurrent = !_obscureCurrent),
                      )),
                    ),
                    const SizedBox(height: 16),

                    // Nova senha
                    const Text('Nova senha', style: TextStyle(color: AppColors.textSecondaryDark, fontSize: 12, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _newPassCtrl,
                      obscureText: _obscureNew,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Obrigatório';
                        if (v.length < 12) return 'Mínimo 12 caracteres';
                        return null;
                      },
                      style: const TextStyle(color: AppColors.textPrimaryDark, fontSize: 13),
                      decoration: _inputDec('Mínimo 12 caracteres', LucideIcons.lock, IconButton(
                        icon: Icon(_obscureNew ? LucideIcons.eye : LucideIcons.eyeOff, size: 16, color: AppColors.textSecondaryDark),
                        onPressed: () => setState(() => _obscureNew = !_obscureNew),
                      )),
                    ),
                    const SizedBox(height: 16),

                    // Confirmar nova senha
                    const Text('Confirmar nova senha', style: TextStyle(color: AppColors.textSecondaryDark, fontSize: 12, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _confirmPassCtrl,
                      obscureText: _obscureConfirm,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Obrigatório';
                        if (v != _newPassCtrl.text) return 'Senhas não conferem';
                        return null;
                      },
                      style: const TextStyle(color: AppColors.textPrimaryDark, fontSize: 13),
                      decoration: _inputDec('Repita a nova senha', LucideIcons.lock, IconButton(
                        icon: Icon(_obscureConfirm ? LucideIcons.eye : LucideIcons.eyeOff, size: 16, color: AppColors.textSecondaryDark),
                        onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                      )),
                    ),

                    if (_error != null) ...[
                      const SizedBox(height: 16),
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
                    AtrButton.primary(
                      label: 'Alterar Senha',
                      icon: LucideIcons.check,
                      loading: _loading,
                      onPressed: _submit,
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDec(String hint, IconData icon, Widget? suffix) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: AppColors.textMutedDark, fontSize: 12),
      prefixIcon: Icon(icon, size: 16, color: AppColors.textSecondaryDark),
      suffixIcon: suffix,
      filled: true,
      fillColor: AppColors.surfaceDarkAlt,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.borderDark)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.borderDark)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.atrOrange)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.statusError)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    );
  }
}
