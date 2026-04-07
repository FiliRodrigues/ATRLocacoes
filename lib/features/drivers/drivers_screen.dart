import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../core/widgets/app_sidebar.dart';
import '../../core/widgets/bento_card.dart';
import '../../core/widgets/status_badge.dart';
import '../../core/theme/app_colors.dart';
import '../../core/data/fleet_data.dart';

class DriversScreen extends StatelessWidget {
  const DriversScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppSidebar(
      child: Scaffold(
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildBreadcrumbs(context),
                const SizedBox(height: 8),
                _buildHeader(context),
                const SizedBox(height: 32),
                Wrap(
                  spacing: 24,
                  runSpacing: 24,
                  children: motoristas.map((d) => _buildDriverCard(context, d)).toList(),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBreadcrumbs(BuildContext context) {
    return Row(
      children: [
        Text('Home', style: TextStyle(color: AppColors.textSecondaryLight.withOpacity(0.6), fontSize: 12)),
        Icon(LucideIcons.chevronRight, size: 12, color: AppColors.textSecondaryLight.withOpacity(0.4)),
        const Text('Motoristas Ativos', style: TextStyle(color: AppColors.atrOrange, fontSize: 12, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Motoristas Ativos', style: Theme.of(context).textTheme.displayLarge?.copyWith(fontSize: 28)),
            Text('Gestão de operadores e regularidade de CNH.', style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
        const SizedBox(width: 16),
        Row(
          children: [
            Container(
              width: 300,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface, 
                borderRadius: BorderRadius.circular(12), 
                border: Border.all(color: Theme.of(context).dividerTheme.color!)
              ),
              child: const Row(
                children: [
                  Icon(LucideIcons.search, size: 16, color: AppColors.textSecondaryLight),
                  SizedBox(width: 12),
                  Expanded(child: TextField(decoration: InputDecoration(isDense: true, hintText: 'Buscar motorista...', border: InputBorder.none, filled: false))),
                ],
              ),
            ),
            const SizedBox(width: 16),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.atrOrange, 
                foregroundColor: Colors.white, 
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14), 
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
              ),
              onPressed: () {},
              icon: const Icon(LucideIcons.userPlus, size: 18),
              label: const Text('Novo Motorista', style: TextStyle(fontWeight: FontWeight.bold)),
            )
          ],
        )
      ],
    );
  }

  Widget _buildDriverCard(BuildContext context, DriverData d) {
    BadgeType bType = BadgeType.success;
    String statusLabel = 'CNH OK';
    if (d.statusCNH == 'vencendo') { bType = BadgeType.warning; statusLabel = 'CNH VENCENDO'; }
    else if (d.statusCNH == 'vencida') { bType = BadgeType.error; statusLabel = 'CNH VENCIDA'; }

    final initials = d.nome.split(' ').map((e) => e[0]).take(2).join('').toUpperCase();
    final hashColor = Colors.primaries[d.nome.hashCode % Colors.primaries.length];
    final vehicles = d.placasVeiculos.map((p) => getVehicleByPlate(p)).whereType<VehicleData>().toList();

    return BentoCard(
      width: 380,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(radius: 24, backgroundColor: hashColor.withOpacity(0.1), child: Text(initials, style: TextStyle(color: hashColor, fontWeight: FontWeight.bold))),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(d.nome, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 18)),
                    const SizedBox(height: 4),
                    Text(d.telefone, style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ),
              ),
              if (d.multas > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: AppColors.statusError.withOpacity(0.15), borderRadius: BorderRadius.circular(100)),
                  child: Text('${d.multas} Multas', style: TextStyle(color: AppColors.statusError, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 16),
          Text('VEÍCULOS ATRIBUÍDOS', style: TextStyle(color: AppColors.textSecondaryLight.withOpacity(0.7), fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
          const SizedBox(height: 12),
          ...vehicles.map((v) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: InkWell(
              onTap: () => context.go('/vehicles/${v.placa}'),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark ? AppColors.surfaceElevatedDark.withOpacity(0.3) : AppColors.backgroundLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.atrOrange.withOpacity(0.05)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(gradient: LinearGradient(colors: [v.cor1, v.cor2]), borderRadius: BorderRadius.circular(8)),
                      child: const Icon(LucideIcons.car, color: Colors.white, size: 14),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(v.placa, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                        Text(v.nome, style: const TextStyle(fontSize: 11, color: AppColors.textSecondaryLight)),
                      ],
                    )),
                    if (v.isFinanciado) const StatusBadge(text: 'FINANC.', type: BadgeType.info),
                    const SizedBox(width: 12),
                    Icon(LucideIcons.chevronRight, size: 14, color: AppColors.textSecondaryLight.withOpacity(0.5)),
                  ],
                ),
              ),
            ),
          )),
          const SizedBox(height: 12),
          const Divider(),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Vencimento CNH', style: TextStyle(color: AppColors.textSecondaryLight.withOpacity(0.7), fontSize: 10, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(d.vencimentoCNH, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                ],
              ),
              StatusBadge(text: statusLabel, type: bType),
            ],
          ),
        ],
      ),
    );
  }
}
