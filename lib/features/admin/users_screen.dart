import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/user_admin_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/atr_button.dart';
import '../../core/widgets/atr_top_bar.dart';
import 'user_form_modal.dart';

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  final UserAdminService _service = UserAdminService();
  final _searchCtrl = TextEditingController();
  List<AppUser>? _users;
  String? _error;
  String _searchQuery = '';
  int _currentPage = 0;
  static const int _pageSize = 10;

  @override
  void initState() {
    super.initState();
    _load();
    _searchCtrl.addListener(() {
      setState(() {
        _searchQuery = _searchCtrl.text.trim().toLowerCase();
        _currentPage = 0;
      });
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final users = await _service.listUsers();
      if (mounted) setState(() { _users = users; _error = null; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); });
    }
  }

  List<AppUser> get _filteredUsers {
    if (_users == null) return [];
    if (_searchQuery.isEmpty) return _users!;
    return _users!.where((u) =>
      u.username.toLowerCase().contains(_searchQuery) ||
      u.nomeCompleto.toLowerCase().contains(_searchQuery)
    ).toList();
  }

  List<AppUser> get _pagedUsers {
    final filtered = _filteredUsers;
    final start = _currentPage * _pageSize;
    if (start >= filtered.length) return [];
    final end = (start + _pageSize).clamp(0, filtered.length);
    return filtered.sublist(start, end);
  }

  int get _totalPages => (_filteredUsers.length / _pageSize).ceil();

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthService>();
    if (auth.currentRole != AuthUserRole.admin) {
      WidgetsBinding.instance.addPostFrameCallback((_) => context.go('/'));
      return const SizedBox.shrink();
    }

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                GestureDetector(
                  onTap: () => context.go('/'),
                  child: Container(
                    width: 36,
                    height: 36,
                    margin: const EdgeInsets.only(right: 12, bottom: 24),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceDarkAlt.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.borderDark),
                    ),
                    child: const Icon(LucideIcons.arrowLeft, color: AppColors.textSecondaryDark, size: 18),
                  ),
                ),
                Expanded(
                  child: AtrTopBar(
                    title: 'Gerenciar Usuários',
                    subtitle: 'Controle de acesso e permissões',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                AtrButton.primary(
                  label: '+ Novo Usuário',
                  icon: LucideIcons.userPlus,
                  onPressed: () async {
                    final created = await showDialog<bool>(
                      context: context,
                      barrierDismissible: false,
                      builder: (_) => const UserFormModal(),
                    );
                    if (created == true) _load();
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    style: const TextStyle(
                      fontFamily: 'Plus Jakarta Sans',
                      color: AppColors.textPrimaryDark,
                      fontSize: 13,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Buscar por nome ou usuário...',
                      hintStyle: const TextStyle(color: AppColors.textMutedDark, fontSize: 13),
                      prefixIcon: const Icon(LucideIcons.search, color: AppColors.textSecondaryDark, size: 16),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(LucideIcons.x, size: 14),
                              color: AppColors.textSecondaryDark,
                              onPressed: () {
                                _searchCtrl.clear();
                                setState(() { _currentPage = 0; });
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: AppColors.surfaceDarkAlt.withValues(alpha: 0.4),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadii.lg),
                        borderSide: BorderSide(color: AppColors.borderDark),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadii.lg),
                        borderSide: BorderSide(color: AppColors.borderDark),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadii.lg),
                        borderSide: BorderSide(color: AppColors.atrOrange.withValues(alpha: 0.5)),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                  ),
                ),
                if (_users != null) ...[
                  const SizedBox(width: 12),
                  Text(
                    '${_filteredUsers.length} usuário(s)',
                    style: const TextStyle(color: AppColors.textSecondaryDark, fontSize: 12),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),
            Expanded(child: _buildContent()),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(LucideIcons.alertCircle, color: AppColors.statusError, size: 32),
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: AppColors.textSecondaryDark)),
            const SizedBox(height: 12),
            AtrButton.secondary(label: 'Tentar novamente', onPressed: _load),
          ],
        ),
      );
    }

    if (_users == null) {
      return const Center(child: CircularProgressIndicator(color: AppColors.atrOrange));
    }

    if (_users!.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.users, color: AppColors.textMutedDark, size: 40),
            SizedBox(height: 12),
            Text(
              'Nenhum usuário encontrado.',
              style: TextStyle(color: AppColors.textSecondaryDark, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surfaceDark,
                borderRadius: BorderRadius.circular(AppRadii.xl),
                border: Border.all(color: AppColors.borderDark),
              ),
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(AppColors.surfaceDarkAlt.withValues(alpha: 0.5)),
                headingTextStyle: const TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  color: AppColors.textSecondaryDark,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
                dataTextStyle: const TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  color: AppColors.textPrimaryDark,
                  fontSize: 13,
                ),
                dividerThickness: 0.5,
                columnSpacing: 24,
                columns: const [
                  DataColumn(label: Text('USUÁRIO')),
                  DataColumn(label: Text('NOME')),
                  DataColumn(label: Text('FUNÇÃO')),
                  DataColumn(label: Text('TELAS')),
                  DataColumn(label: Text('ÚLTIMO LOGIN')),
                  DataColumn(label: Text('')),
                ],
                rows: _pagedUsers.map((u) {
                  final initials = u.nomeCompleto.isNotEmpty
                      ? u.nomeCompleto.split(' ').take(2).map((s) => s.isNotEmpty ? s[0].toUpperCase() : '').join()
                      : u.username.isNotEmpty
                          ? u.username[0].toUpperCase()
                          : '?';
                  return DataRow(cells: [
                    DataCell(Row(children: [
                      Container(
                        width: 32, height: 32,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: AppColors.warmGradient),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(child: Text(initials, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800))),
                      ),
                      const SizedBox(width: 10),
                      Text(u.username, style: const TextStyle(fontWeight: FontWeight.w600)),
                    ])),
                    DataCell(Text(u.nomeCompleto)),
                    DataCell(_roleBadge(u.role, u.isAdmin)),
                    DataCell(Text('${u.allowedFeatures.length} telas', style: const TextStyle(color: AppColors.textSecondaryDark, fontSize: 12))),
                    DataCell(Text(u.lastLogin != null ? '${u.lastLogin!.day}/${u.lastLogin!.month}/${u.lastLogin!.year}' : '—', style: const TextStyle(color: AppColors.textSecondaryDark, fontSize: 12))),
                    DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                      IconButton(
                        icon: const Icon(LucideIcons.pencil, size: 16),
                        color: AppColors.textSecondaryDark,
                        tooltip: 'Editar',
                        onPressed: () async {
                          final edited = await showDialog<bool>(
                            context: context,
                            barrierDismissible: false,
                            builder: (_) => UserFormModal(existing: u),
                          );
                          if (edited == true) _load();
                        },
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        icon: const Icon(LucideIcons.trash2, size: 16),
                        color: AppColors.statusError,
                        tooltip: 'Desativar',
                        onPressed: () => _confirmDeactivate(u),
                      ),
                    ])),
                  ]);
                }).toList(),
              ),
            ),
          ),
        ),
        if (_totalPages > 1) ...[
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(LucideIcons.chevronLeft, size: 18),
                color: _currentPage > 0 ? AppColors.atrOrange : AppColors.textMutedDark,
                onPressed: _currentPage > 0 ? () => setState(() => _currentPage--) : null,
              ),
              const SizedBox(width: 4),
              Text(
                'Pág. ${_currentPage + 1} de $_totalPages',
                style: const TextStyle(color: AppColors.textSecondaryDark, fontSize: 12),
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(LucideIcons.chevronRight, size: 18),
                color: _currentPage < _totalPages - 1 ? AppColors.atrOrange : AppColors.textMutedDark,
                onPressed: _currentPage < _totalPages - 1 ? () => setState(() => _currentPage++) : null,
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _roleBadge(String role, bool isAdmin) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isAdmin ? AppColors.atrOrange.withValues(alpha: 0.15) : AppColors.statusInfo.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadii.pill),
        border: Border.all(color: isAdmin ? AppColors.atrOrange.withValues(alpha: 0.3) : AppColors.statusInfo.withValues(alpha: 0.25)),
      ),
      child: Text(
        isAdmin ? 'Admin' : 'Membro',
        style: TextStyle(
          color: isAdmin ? AppColors.atrOrange : AppColors.statusInfo,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  void _confirmDeactivate(AppUser user) {
    final currentUser = context.read<AuthService>().currentUser;
    if (user.username == currentUser?.username) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Você não pode desativar seu próprio usuário.')),
      );
      return;
    }
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.xl)),
        title: const Text('Desativar usuário', style: TextStyle(color: AppColors.textPrimaryDark)),
        content: Text('Tem certeza que deseja desativar "${user.nomeCompleto}" (${user.username})? O usuário não poderá mais fazer login.', style: const TextStyle(color: AppColors.textSecondaryDark)),
        actions: [
          AtrButton.ghost(label: 'Cancelar', onPressed: () => Navigator.pop(ctx)),
          const SizedBox(width: 8),
          AtrButton.primary(
            label: 'Desativar',
            onPressed: () async {
              await _service.setActive(user.id!, false);
              Navigator.pop(ctx);
              _load();
            },
          ),
        ],
      ),
    );
  }
}
