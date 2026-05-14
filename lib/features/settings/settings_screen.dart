import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/services/auth_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/atr_theme_state.dart';
import '../../core/widgets/bento_card.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = Supabase.instance.client.auth.currentUser;
    final tenantId = (user?.appMetadata ?? {})['tenant_id'] as String?;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Configurações'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          BentoCard(
            animationDelay: 100,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Perfil do Usuário',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 16),
                _InfoRow(
                  icon: LucideIcons.user,
                  label: 'Email',
                  value: user?.email ?? '--',
                ),
                const Divider(height: 24),
                _InfoRow(
                  icon: LucideIcons.building2,
                  label: 'Tenant',
                  value: tenantId?.substring(0, 8) ?? '--',
                ),
                const Divider(height: 24),
                _InfoRow(
                  icon: LucideIcons.shieldCheck,
                  label: 'Provedor',
                  value: (user?.appMetadata ?? {})['provider'] as String? ?? 'email',
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          BentoCard(
            animationDelay: 200,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Aparência', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 16),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Modo escuro'),
                  subtitle: const Text('Usar tema escuro'),
                  secondary: Icon(
                    isDark ? LucideIcons.moon : LucideIcons.sun,
                    color: isDark ? AppColors.statusInfo : AppColors.statusWarning,
                  ),
                  value: isDark,
                  onChanged: (_) => AtrThemeState.toggleTheme(),
                ),
              ],
            ),
          ),
          if (context.read<AuthService>().currentRole == AuthUserRole.admin)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: GestureDetector(
                onTap: () => context.push('/admin/users'),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceDark,
                    borderRadius: BorderRadius.circular(AppRadii.xl),
                    border: Border.all(color: AppColors.borderDark),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.atrOrange.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(LucideIcons.shield, color: AppColors.atrOrange, size: 20),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Gerenciar Usuários', style: TextStyle(fontFamily: 'Syne', color: AppColors.textPrimaryDark, fontSize: 16, fontWeight: FontWeight.w700)),
                            SizedBox(height: 4),
                            Text('Cadastrar, editar permissões e gerenciar logins do sistema', style: TextStyle(color: AppColors.textSecondaryDark, fontSize: 12)),
                          ],
                        ),
                      ),
                      const Icon(LucideIcons.chevronRight, color: AppColors.textSecondaryDark, size: 18),
                    ],
                  ),
                ),
              ),
            ),
          const SizedBox(height: 16),
          BentoCard(
            animationDelay: 300,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Sobre', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 16),
                _InfoRow(
                  icon: LucideIcons.info,
                  label: 'Versão',
                  value: '1.0.0',
                ),
                const Divider(height: 24),
                _InfoRow(
                  icon: LucideIcons.database,
                  label: 'Backend',
                  value: 'Supabase',
                ),
                const Divider(height: 24),
                _InfoRow(
                  icon: LucideIcons.bot,
                  label: 'IA Assistant',
                  value: 'DeepSeek v4 Pro',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.textSecondaryLight),
        const SizedBox(width: 12),
        Text(label, style: const TextStyle(color: AppColors.textSecondaryLight)),
        const Spacer(),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    );
  }
}
