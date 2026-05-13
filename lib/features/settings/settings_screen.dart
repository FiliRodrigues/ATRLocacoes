import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/app_colors.dart';
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
