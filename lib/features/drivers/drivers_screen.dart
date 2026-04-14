import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../../core/widgets/app_sidebar.dart';
import '../../core/widgets/bento_card.dart';
import '../../core/widgets/status_badge.dart';
import '../../core/theme/app_colors.dart';
import '../../core/data/fleet_data.dart';

class DriversScreen extends StatefulWidget {
  const DriversScreen({super.key});

  @override
  State<DriversScreen> createState() => _DriversScreenState();
}

class _DriversScreenState extends State<DriversScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';
  List<DriverData>? _cachedFilteredDrivers;
  int _cachedRepoVersion = -1;
  String _cachedQuery = '';

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    final nextQuery = _searchCtrl.text.trim().toLowerCase();
    if (nextQuery == _query) return;
    setState(() {
      _query = nextQuery;
    });
  }

  @override
  void dispose() {
    _searchCtrl.removeListener(_onSearchChanged);
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<FleetRepository>();
    final filteredDrivers = _getFilteredDrivers(repo);

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
                  children: filteredDrivers
                      .map((d) => _buildDriverCard(context, d, repo))
                      .toList(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<DriverData> _getFilteredDrivers(FleetRepository repo) {
    if (_cachedFilteredDrivers != null &&
        _cachedRepoVersion == repo.version &&
        _cachedQuery == _query) {
      return _cachedFilteredDrivers!;
    }

    final filtered = repo.motoristas.where((d) {
      if (_query.isEmpty) return true;
      return d.nome.toLowerCase().contains(_query) ||
          d.telefone.toLowerCase().contains(_query);
    }).toList();

    _cachedRepoVersion = repo.version;
    _cachedQuery = _query;
    _cachedFilteredDrivers = filtered;
    return filtered;
  }

  Widget _buildBreadcrumbs(BuildContext context) {
    return Row(
      children: [
        Text('Home',
            style: TextStyle(
                color: AppColors.textSecondaryLight.withValues(alpha: 0.6),
                fontSize: 12,),),
        Icon(LucideIcons.chevronRight,
            size: 12,
            color: AppColors.textSecondaryLight.withValues(alpha: 0.4),),
        const Text('Motoristas Ativos',
            style: TextStyle(
                color: AppColors.atrOrange,
                fontSize: 12,
                fontWeight: FontWeight.bold,),),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Motoristas Ativos',
                style: Theme.of(context)
                    .textTheme
                    .displayLarge
                    ?.copyWith(fontSize: 28),),
            Text('Gestão de operadores e regularidade de CNH.',
                style: Theme.of(context).textTheme.bodyMedium,),
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 300),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: Theme.of(context).dividerTheme.color!,),),
                child: Row(
                  children: [
                    const Icon(LucideIcons.search,
                        size: 16, color: AppColors.textSecondaryLight,),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _searchCtrl,
                        decoration: const InputDecoration(
                          isDense: true,
                          hintText: 'Buscar motorista...',
                          border: InputBorder.none,
                          filled: false,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.atrOrange,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),),),
              onPressed: () => _showNewDriverDialog(context),
              icon: const Icon(LucideIcons.userPlus, size: 18),
              label: const Text('Novo Motorista',
                  style: TextStyle(fontWeight: FontWeight.bold),),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDriverCard(
      BuildContext context, DriverData d, FleetRepository repo,) {
    BadgeType bType = BadgeType.success;
    String statusLabel = 'CNH OK';
    if (d.statusCNH == CnhStatus.vencendo) {
      bType = BadgeType.warning;
      statusLabel = 'CNH VENCENDO';
    } else if (d.statusCNH == CnhStatus.vencida) {
      bType = BadgeType.error;
      statusLabel = 'CNH VENCIDA';
    }

    final initials =
        d.nome.split(' ').map((e) => e[0]).take(2).join().toUpperCase();
    final hashColor =
        Colors.primaries[d.nome.hashCode % Colors.primaries.length];
    final vehicles = d.placasVeiculos
      .map((p) => repo.getVehicleByPlate(p))
        .whereType<VehicleData>()
        .toList();

    return BentoCard(
      width: 380,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                  radius: 24,
                  backgroundColor: hashColor.withValues(alpha: 0.1),
                  child: Text(initials,
                      style: TextStyle(
                          color: hashColor, fontWeight: FontWeight.bold,),),),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(d.nome,
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontSize: 18),),
                    const SizedBox(height: 4),
                    Text(d.telefone,
                        style: Theme.of(context).textTheme.bodyMedium,),
                  ],
                ),
              ),
              if (d.multas > 0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                      color: AppColors.statusError.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(100),),
                  child: Text('${d.multas} Multas',
                      style: const TextStyle(
                          color: AppColors.statusError,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,),),
                ),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 16),
          Text('VEÍCULOS ATRIBUÍDOS',
              style: TextStyle(
                  color: AppColors.textSecondaryLight.withValues(alpha: 0.7),
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,),),
          const SizedBox(height: 12),
          ...vehicles.map((v) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: InkWell(
                  onTap: () => context.go('/vehicles/${v.placa}'),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10,),
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? AppColors.surfaceElevatedDark.withValues(alpha: 0.3)
                          : AppColors.backgroundLight,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: AppColors.atrOrange.withValues(alpha: 0.05),),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                              gradient:
                                  LinearGradient(colors: [v.cor1, v.cor2]),
                              borderRadius: BorderRadius.circular(8),),
                          child: const Icon(LucideIcons.car,
                              color: Colors.white, size: 14,),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                            child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(v.placa,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800, fontSize: 13,),),
                            Text(v.nome,
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondaryLight,),),
                          ],
                        ),),
                        if (v.isFinanciado)
                          const StatusBadge(
                              text: 'FINANC.', type: BadgeType.info,),
                        const SizedBox(width: 12),
                        Icon(LucideIcons.chevronRight,
                            size: 14,
                            color: AppColors.textSecondaryLight
                                .withValues(alpha: 0.5),),
                      ],
                    ),
                  ),
                ),
              ),),
          const SizedBox(height: 12),
          const Divider(),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Vencimento CNH',
                      style: TextStyle(
                          color: AppColors.textSecondaryLight
                              .withValues(alpha: 0.7),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,),),
                  const SizedBox(height: 4),
                  Text(formatDate(d.vencimentoCNH),
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 13,),),
                ],
              ),
              StatusBadge(text: statusLabel, type: bType),
            ],
          ),
        ],
      ),
    );
  }

  void _showNewDriverDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final cnhExpiryCtrl = TextEditingController();
    String? modalError;

    DateTime? parseDate(String raw) {
      final parts = raw.trim().split('/');
      if (parts.length != 3) return null;
      final day = int.tryParse(parts[0]);
      final month = int.tryParse(parts[1]);
      final year = int.tryParse(parts[2]);
      if (day == null || month == null || year == null) return null;
      if (month < 1 || month > 12 || day < 1 || day > 31) return null;
      // Validate day is valid for the given month
      final candidate = DateTime(year, month, day);
      // DateTime auto-adjusts invalid dates (e.g., Feb 30 → Mar 2)
      // So verify the month didn't change
      if (candidate.month != month || candidate.day != day) return null;
      return candidate;
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
          builder: (ctx, setModalState) => AlertDialog(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),),
                title: const Text('Cadastrar Motorista',
                    style: TextStyle(fontWeight: FontWeight.w800),),
                content: SizedBox(
                  width: 460,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Nome Completo',
                          prefixIcon: Icon(LucideIcons.user),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: phoneCtrl,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Telefone',
                          prefixIcon: Icon(LucideIcons.phone),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        decoration: const InputDecoration(
                          labelText: 'Número CNH',
                          prefixIcon: Icon(LucideIcons.creditCard),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: cnhExpiryCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Vencimento CNH (DD/MM/AAAA)',
                          prefixIcon: Icon(LucideIcons.calendar),
                        ),
                      ),
                      if (modalError != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          modalError!,
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancelar'),),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.atrOrange,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),),),
                    onPressed: () {
                      final name = nameCtrl.text.trim();
                      final phone = phoneCtrl.text.trim();
                      final expiry = parseDate(cnhExpiryCtrl.text);
                      if (name.length < 3 ||
                          phone.length < 8 ||
                          expiry == null) {
                        setModalState(() {
                          modalError =
                              'Preencha nome, telefone e data válida (DD/MM/AAAA).';
                        });
                        return;
                      }

                      final created = context.read<FleetRepository>().addDriver(
                            nome: name,
                            telefone: phone,
                            vencimentoCNH: expiry,
                          );
                      if (!created) {
                        setModalState(() {
                          modalError =
                              'Telefone já cadastrado ou dados inválidos.';
                        });
                        return;
                      }

                      Navigator.pop(ctx);
                    },
                    child: const Text('Cadastrar'),
                  ),
                ],
              ),),
    ).whenComplete(() {
      nameCtrl.dispose();
      phoneCtrl.dispose();
      cnhExpiryCtrl.dispose();
    });
  }
}
