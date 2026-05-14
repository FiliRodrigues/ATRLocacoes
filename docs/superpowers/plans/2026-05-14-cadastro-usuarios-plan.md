# Refatoração do Cadastro de Usuários — Plano de Implementação

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Transformar o gerenciamento de usuários em uma seção completa com re-autenticação do admin, CRUD total e integração ao Settings.

**Architecture:** Abordagem C — aprimoramento focado. Expande `UserAdminService` com 6 novos métodos, refatora `UsersScreen` com gate de re-auth, atualiza `UserFormModal` para full-edit, adiciona card no Settings, e expande a Edge Function `create-user` → `manage-users` com handlers de update/reset/delete.

**Tech Stack:** Flutter/Dart, Supabase (Auth + Edge Functions + PostgreSQL), Provider

---

## Estrutura de Arquivos

| Arquivo | Ação |
|---------|------|
| `lib/core/services/user_admin_service.dart` | Modificar |
| `lib/features/admin/users_screen.dart` | Modificar |
| `lib/features/admin/user_form_modal.dart` | Modificar |
| `lib/features/settings/settings_screen.dart` | Modificar |
| `supabase/functions/manage-users/index.ts` | Criar (renomeado de `create-user/`) |

---

### Task 1: Expandir UserAdminService

**Files:**
- Modify: `lib/core/services/user_admin_service.dart` (adicionar métodos ao final da classe, antes do `}`)

- [ ] **Step 1: Adicionar métodos `updateUser`, `resetPassword`, `deleteUser`, `reactivateUser`, `verifyAdminPassword`**

Inserir o seguinte código ANTES do `}` final da classe `UserAdminService`:

```dart
  Future<void> updateUser({
    required String id,
    String? username,
    String? nomeCompleto,
    String? role,
    List<String>? features,
  }) async {
    final res = await Supabase.instance.client.functions.invoke(
      'manage-users',
      body: {
        'action': 'update_user',
        'user_id': id,
        if (username != null) 'username': username,
        if (nomeCompleto != null) 'nome_completo': nomeCompleto,
        if (role != null) 'role': role,
        if (features != null) 'allowed_features': features,
      },
    );

    if (res.status != 200) {
      final data = res.data;
      final error = data is Map ? (data['error'] ?? 'Erro desconhecido') : 'Erro desconhecido';
      throw UserAdminException(error.toString());
    }
  }

  Future<void> resetPassword({
    required String id,
    required String newPassword,
  }) async {
    final res = await Supabase.instance.client.functions.invoke(
      'manage-users',
      body: {
        'action': 'reset_password',
        'user_id': id,
        'password': newPassword,
      },
    );

    if (res.status != 200) {
      final data = res.data;
      final error = data is Map ? (data['error'] ?? 'Erro desconhecido') : 'Erro desconhecido';
      throw UserAdminException(error.toString());
    }
  }

  Future<void> deleteUser(String id) async {
    final res = await Supabase.instance.client.functions.invoke(
      'manage-users',
      body: {
        'action': 'delete_user',
        'user_id': id,
      },
    );

    if (res.status != 200) {
      final data = res.data;
      final error = data is Map ? (data['error'] ?? 'Erro desconhecido') : 'Erro desconhecido';
      throw UserAdminException(error.toString());
    }
  }

  Future<void> reactivateUser(String userId) async {
    await Supabase.instance.client
        .from('app_users')
        .update({'ativo': true}).eq('id', userId);
  }

  Future<bool> verifyAdminPassword(String password) async {
    try {
      final currentEmail = Supabase.instance.client.auth.currentUser?.email;
      if (currentEmail == null) return false;

      final res = await Supabase.instance.client.auth.signInWithPassword(
        email: currentEmail,
        password: password,
      );
      return res.session != null;
    } catch (_) {
      return false;
    }
  }
```

- [ ] **Step 2: Atualizar `createUser` para usar `manage-users` com `action`**

Na função `createUser`, trocar `'create-user'` por `'manage-users'` e adicionar `'action': 'create_user'` ao body:

```dart
  Future<void> createUser({
    required String email,
    required String password,
    required String username,
    required String nomeCompleto,
    required String role,
    required List<String> allowedFeatures,
  }) async {
    final res = await Supabase.instance.client.functions.invoke(
      'manage-users',
      body: {
        'action': 'create_user',
        'email': email,
        'password': password,
        'username': username,
        'nome_completo': nomeCompleto,
        'role': role,
        'allowed_features': allowedFeatures,
      },
    );

    if (res.status != 200) {
      final data = res.data;
      final error = data is Map ? (data['error'] ?? 'Erro desconhecido') : 'Erro desconhecido';
      throw UserAdminException(error.toString());
    }
  }
```

- [ ] **Step 3: Commit**

```bash
git add lib/core/services/user_admin_service.dart
git commit -m "feat: expandir UserAdminService com update, reset, delete, verify"
```

---

### Task 2: Atualizar UsersScreen — Re-auth gate, status e ações expandidas

**Files:**
- Modify: `lib/features/admin/users_screen.dart`

- [ ] **Step 1: Adicionar estado de re-auth e método de verificação**

Adicionar ao `_UsersScreenState`:

```dart
  bool _isUnlocked = false;
  bool _verifying = false;
  String? _authError;
```

Adicionar os métodos de re-auth:

```dart
  void _showAuthGate() {
    final passCtrl = TextEditingController();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            backgroundColor: AppColors.surfaceDark,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.xl)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.atrOrange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(LucideIcons.shieldCheck, color: AppColors.atrOrange, size: 20),
                ),
                const SizedBox(width: 12),
                const Text('Verificação de segurança', style: TextStyle(color: AppColors.textPrimaryDark, fontSize: 16, fontWeight: FontWeight.w700)),
              ],
            ),
            content: SizedBox(
              width: 360,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Digite sua senha para gerenciar usuários', style: TextStyle(color: AppColors.textSecondaryDark, fontSize: 13)),
                  const SizedBox(height: 16),
                  TextField(
                    controller: passCtrl,
                    obscureText: true,
                    style: const TextStyle(color: AppColors.textPrimaryDark, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Senha do administrador',
                      hintStyle: const TextStyle(color: AppColors.textMutedDark, fontSize: 13),
                      prefixIcon: const Icon(LucideIcons.lock, size: 16, color: AppColors.textSecondaryDark),
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
                    ),
                    onSubmitted: (v) => _verifyPassword(v, ctx, passCtrl),
                  ),
                  if (_authError != null) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(LucideIcons.alertCircle, color: AppColors.statusError, size: 14),
                        const SizedBox(width: 6),
                        Text(_authError!, style: const TextStyle(color: AppColors.statusError, fontSize: 12)),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () { Navigator.pop(ctx); if (mounted) context.go('/configuracoes'); },
                child: const Text('Cancelar', style: TextStyle(color: AppColors.textSecondaryDark)),
              ),
              AtrButton.primary(
                label: 'Confirmar',
                loading: _verifying,
                onPressed: () => _verifyPassword(passCtrl.text, ctx, passCtrl),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _verifyPassword(String password, BuildContext dialogContext, TextEditingController passCtrl) async {
    setState(() { _verifying = true; _authError = null; });
    final ok = await _service.verifyAdminPassword(password);
    if (!mounted) return;
    if (ok) {
      setState(() { _isUnlocked = true; _verifying = false; });
      Navigator.pop(dialogContext);
      _load();
    } else {
      setState(() { _authError = 'Senha incorreta'; _verifying = false; });
    }
  }
```

- [ ] **Step 2: Modificar `initState` para disparar o gate**

```dart
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _showAuthGate());
    _searchCtrl.addListener(() {
      setState(() {
        _searchQuery = _searchCtrl.text.trim().toLowerCase();
        _currentPage = 0;
      });
    });
  }
```

- [ ] **Step 3: Modificar `build` para mostrar loading enquanto locked**

Substituir o início do método `build` (antes do `return Scaffold`) — adicionar o check:

```dart
    if (!_isUnlocked) {
      return Scaffold(
        backgroundColor: AppColors.backgroundDark,
        body: const Center(child: CircularProgressIndicator(color: AppColors.atrOrange)),
      );
    }
```

- [ ] **Step 4: Adicionar coluna STATUS e ações expandidas na tabela**

Trocar as colunas do `DataTable`:

```dart
  columns: const [
    DataColumn(label: Text('USUÁRIO')),
    DataColumn(label: Text('NOME')),
    DataColumn(label: Text('FUNÇÃO')),
    DataColumn(label: Text('TELAS')),
    DataColumn(label: Text('ÚLTIMO LOGIN')),
    DataColumn(label: Text('STATUS')),
    DataColumn(label: Text('')),
  ],
```

Substituir a célula de ações (última `DataCell` de cada `DataRow`) por:

```dart
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
    IconButton(
      icon: const Icon(LucideIcons.keyRound, size: 16),
      color: AppColors.textSecondaryDark,
      tooltip: 'Resetar senha',
      onPressed: () => _showResetPasswordDialog(u),
    ),
    if (u.ativo)
      IconButton(
        icon: const Icon(LucideIcons.userX, size: 16),
        color: AppColors.statusWarning,
        tooltip: 'Desativar',
        onPressed: () => _confirmDeactivate(u),
      )
    else
      IconButton(
        icon: const Icon(LucideIcons.userCheck, size: 16),
        color: AppColors.statusSuccess,
        tooltip: 'Reativar',
        onPressed: () => _reactivate(u),
      ),
    IconButton(
      icon: const Icon(LucideIcons.trash2, size: 16),
      color: AppColors.statusError,
      tooltip: 'Excluir permanentemente',
      onPressed: () => _confirmDelete(u),
    ),
  ])),
```

Adicionar célula de status entre "ÚLTIMO LOGIN" e ações:

```dart
  DataCell(_statusBadge(u.ativo)),
```

- [ ] **Step 5: Adicionar métodos `_showResetPasswordDialog`, `_reactivate`, `_confirmDelete`, `_statusBadge`**

```dart
  void _showResetPasswordDialog(AppUser user) {
    final passCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.xl)),
        title: Text('Resetar senha de "${user.nomeCompleto}"', style: const TextStyle(color: AppColors.textPrimaryDark)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: passCtrl,
              obscureText: true,
              style: const TextStyle(color: AppColors.textPrimaryDark, fontSize: 13),
              decoration: InputDecoration(
                labelText: 'Nova senha',
                hintText: 'Mínimo 12 caracteres',
                labelStyle: const TextStyle(color: AppColors.textSecondaryDark, fontSize: 11),
                filled: true,
                fillColor: AppColors.surfaceDarkAlt,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.borderDark)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.borderDark)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.atrOrange)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: confirmCtrl,
              obscureText: true,
              style: const TextStyle(color: AppColors.textPrimaryDark, fontSize: 13),
              decoration: InputDecoration(
                labelText: 'Confirmar senha',
                labelStyle: const TextStyle(color: AppColors.textSecondaryDark, fontSize: 11),
                filled: true,
                fillColor: AppColors.surfaceDarkAlt,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.borderDark)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.borderDark)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.atrOrange)),
              ),
            ),
          ],
        ),
        actions: [
          AtrButton.ghost(label: 'Cancelar', onPressed: () => Navigator.pop(ctx)),
          AtrButton.primary(
            label: 'Resetar',
            onPressed: () async {
              if (passCtrl.text.length < 12) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('A senha deve ter no mínimo 12 caracteres.')));
                return;
              }
              if (passCtrl.text != confirmCtrl.text) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Senhas não conferem.')));
                return;
              }
              try {
                await _service.resetPassword(id: user.id!, newPassword: passCtrl.text);
                Navigator.pop(ctx);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Senha resetada com sucesso.'), backgroundColor: AppColors.statusSuccess));
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e')));
                }
              }
            },
          ),
        ],
      ),
    );
  }

  void _reactivate(AppUser user) async {
    await _service.reactivateUser(user.id!);
    _load();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${user.nomeCompleto} reativado.'), backgroundColor: AppColors.statusSuccess),
      );
    }
  }

  void _confirmDelete(AppUser user) {
    final currentUser = context.read<AuthService>().currentUser;
    if (user.username == currentUser?.username) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Você não pode excluir seu próprio usuário.')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.xl)),
        title: const Text('Excluir permanentemente', style: TextStyle(color: AppColors.textPrimaryDark)),
        content: Text('Tem certeza que deseja excluir permanentemente "${user.nomeCompleto}" (${user.username})?', style: const TextStyle(color: AppColors.textSecondaryDark)),
        actions: [
          AtrButton.ghost(label: 'Cancelar', onPressed: () => Navigator.pop(ctx)),
          AtrButton.primary(
            label: 'Excluir',
            onPressed: () {
              Navigator.pop(ctx);
              _showDeleteConfirmFinal(user);
            },
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmFinal(AppUser user) {
    final confirmCtrl = TextEditingController();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.xl)),
        title: const Row(
          children: [
            Icon(LucideIcons.alertTriangle, color: AppColors.statusError, size: 20),
            SizedBox(width: 8),
            Text('Confirmação final', style: TextStyle(color: AppColors.statusError, fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Esta ação é irreversível.', style: TextStyle(color: AppColors.textSecondaryDark, fontSize: 13)),
            const SizedBox(height: 8),
            Text('Digite "${user.username}" para confirmar:', style: const TextStyle(color: AppColors.textPrimaryDark, fontSize: 13)),
            const SizedBox(height: 10),
            TextField(
              controller: confirmCtrl,
              style: const TextStyle(color: AppColors.textPrimaryDark, fontSize: 13),
              decoration: InputDecoration(
                hintText: user.username,
                filled: true,
                fillColor: AppColors.surfaceDarkAlt,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        actions: [
          AtrButton.ghost(label: 'Cancelar', onPressed: () => Navigator.pop(ctx)),
          AtrButton.primary(
            label: 'Confirmar exclusão',
            onPressed: () async {
              if (confirmCtrl.text.trim() != user.username) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Username não confere.')));
                return;
              }
              try {
                await _service.deleteUser(user.id!);
                Navigator.pop(ctx);
                _load();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${user.nomeCompleto} excluído permanentemente.'), backgroundColor: AppColors.statusError),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e')));
                }
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _statusBadge(bool ativo) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: ativo ? AppColors.statusSuccess.withValues(alpha: 0.12) : AppColors.textMutedDark.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadii.pill),
        border: Border.all(color: ativo ? AppColors.statusSuccess.withValues(alpha: 0.25) : AppColors.textMutedDark.withValues(alpha: 0.25)),
      ),
      child: Text(
        ativo ? 'Ativo' : 'Inativo',
        style: TextStyle(color: ativo ? AppColors.statusSuccess : AppColors.textMutedDark, fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );
  }
```

- [ ] **Step 6: Commit**

```bash
git add lib/features/admin/users_screen.dart
git commit -m "feat: re-auth gate, status, reset senha, delete com dupla confirmação"
```

---

### Task 3: Atualizar UserFormModal para full-edit

**Files:**
- Modify: `lib/features/admin/user_form_modal.dart`

- [ ] **Step 1: Remover `readOnly` do campo username no modo edit**

```dart
  // Trocar a chamada:
  //   _buildField('Username', _userCtrl, LucideIcons.user, (v) { ... }, readOnly: _isEditing),
  // por:
  _buildField('Username', _userCtrl, LucideIcons.user, (v) {
    if (v == null || v.trim().isEmpty) return 'Obrigatório';
    if (v.trim().length < 3) return 'Mínimo 3 caracteres';
    return null;
  }),
```

- [ ] **Step 2: Permitir edição da função no modo edit**

Trocar:

```dart
  onTap: _isEditing ? null : () => setState(() => _role = value),
```

Por:

```dart
  onTap: () => setState(() => _role = value),
```

- [ ] **Step 3: Substituir `_submit` para incluir update completo**

```dart
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
```

- [ ] **Step 4: Commit**

```bash
git add lib/features/admin/user_form_modal.dart
git commit -m "feat: UserFormModal full-edit com username, nome, função e features"
```

---

### Task 4: Adicionar card "Gerenciar Usuários" no Settings

**Files:**
- Modify: `lib/features/settings/settings_screen.dart`

- [ ] **Step 1: Ler o arquivo atual para encontrar o ponto de inserção**

- [ ] **Step 2: Adicionar o card antes da seção "Sobre"**

Adicionar dentro do `Column` no `SingleChildScrollView`:

```dart
  if (context.read<AuthService>().currentRole == AuthUserRole.admin)
    Padding(
      padding: const EdgeInsets.only(bottom: 24),
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
```

- [ ] **Step 3: Garantir imports necessários**

```dart
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../../core/services/auth_service.dart';
```

- [ ] **Step 4: Commit**

```bash
git add lib/features/settings/settings_screen.dart
git commit -m "feat: card Gerenciar Usuários no Settings (admin-only)"
```

---

### Task 5: Expandir Edge Function (create-user → manage-users)

**Files:**
- Create: `supabase/functions/manage-users/index.ts`

- [ ] **Step 1: Criar diretório**

```bash
New-Item -ItemType Directory -Path "supabase\functions\manage-users" -Force
```

- [ ] **Step 2: Escrever a Edge Function completa**

```typescript
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const { action, email, password, username, nome_completo, role, allowed_features, user_id } = await req.json();

    const userClient = createClient(SUPABASE_URL, Deno.env.get('SUPABASE_ANON_KEY')!, {
      global: { headers: { Authorization: req.headers.get('Authorization')! } },
    });
    const { data: { user: caller } } = await userClient.auth.getUser();
    if (!caller || caller.app_metadata?.role !== 'admin') {
      return new Response(JSON.stringify({ error: 'Apenas administradores podem gerenciar usuários.' }), {
        status: 403, headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }
    const callerTenant = caller.app_metadata?.tenant_id;
    const admin = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

    switch (action) {

      case 'create_user': {
        if (!email || !password || !username) {
          return new Response(JSON.stringify({ error: 'Campos obrigatórios: email, password, username' }), {
            status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          });
        }
        if (password.length < 12) {
          return new Response(JSON.stringify({ error: 'A senha deve ter no mínimo 12 caracteres.' }), {
            status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          });
        }
        if (!['admin', 'member'].includes(role)) {
          return new Response(JSON.stringify({ error: 'Role inválida. Use admin ou member.' }), {
            status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          });
        }

        const { data: created, error: createError } = await admin.auth.admin.createUser({
          email,
          password,
          email_confirm: true,
          app_metadata: {
            role,
            username,
            tenant_id: callerTenant,
            allowed_features: role === 'admin' ? [] : (allowed_features ?? []),
          },
          user_metadata: { full_name: nome_completo },
        });

        if (createError) {
          const msg = createError.message.includes('duplicate')
            ? 'Email já cadastrado no sistema.'
            : createError.message;
          return new Response(JSON.stringify({ error: msg }), {
            status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          });
        }

        const { error: insertError } = await admin.from('app_users').insert({
          username,
          password_hash: '',
          password_salt: '',
          role,
          nome_completo: nome_completo ?? '',
          tenant_id: callerTenant,
          id: created.user.id,
          allowed_features: role === 'admin' ? [] : (allowed_features ?? []),
          must_change_password: true,
        });

        if (insertError) {
          await admin.auth.admin.deleteUser(created.user.id);
          return new Response(JSON.stringify({ error: insertError.message }), {
            status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          });
        }

        return new Response(JSON.stringify({ ok: true, user_id: created.user.id }), {
          status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        });
      }

      case 'update_user': {
        if (!user_id) {
          return new Response(JSON.stringify({ error: 'user_id é obrigatório' }), {
            status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          });
        }
        if (user_id === caller.id) {
          return new Response(JSON.stringify({ error: 'Você não pode gerenciar seu próprio usuário.' }), {
            status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          });
        }

        const { data: targetUser } = await admin.from('app_users').select('tenant_id').eq('id', user_id).maybeSingle();
        if (!targetUser || targetUser.tenant_id !== callerTenant) {
          return new Response(JSON.stringify({ error: 'Usuário não encontrado.' }), {
            status: 404, headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          });
        }

        const updates: Record<string, any> = {};
        if (username !== undefined) updates.username = username;
        if (nome_completo !== undefined) updates.nome_completo = nome_completo;
        if (role !== undefined) updates.role = role;
        if (allowed_features !== undefined) updates.allowed_features = allowed_features;

        const { error: updateError } = await admin.from('app_users').update(updates).eq('id', user_id);
        if (updateError) {
          return new Response(JSON.stringify({ error: updateError.message }), {
            status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          });
        }

        const authMeta: Record<string, any> = {};
        if (role !== undefined) authMeta.role = role;
        if (username !== undefined) authMeta.username = username;
        if (allowed_features !== undefined) authMeta.allowed_features = allowed_features;

        await admin.auth.admin.updateUserById(user_id, { app_metadata: authMeta });

        return new Response(JSON.stringify({ ok: true }), {
          status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        });
      }

      case 'reset_password': {
        if (!user_id || !password) {
          return new Response(JSON.stringify({ error: 'user_id e password são obrigatórios' }), {
            status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          });
        }
        if (password.length < 12) {
          return new Response(JSON.stringify({ error: 'A senha deve ter no mínimo 12 caracteres.' }), {
            status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          });
        }

        await admin.auth.admin.updateUserById(user_id, { password });
        await admin.from('app_users').update({ must_change_password: true }).eq('id', user_id);

        return new Response(JSON.stringify({ ok: true }), {
          status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        });
      }

      case 'delete_user': {
        if (!user_id) {
          return new Response(JSON.stringify({ error: 'user_id é obrigatório' }), {
            status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          });
        }
        if (user_id === caller.id) {
          return new Response(JSON.stringify({ error: 'Você não pode excluir seu próprio usuário.' }), {
            status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          });
        }

        const { data: target } = await admin.from('app_users').select('tenant_id').eq('id', user_id).maybeSingle();
        if (!target || target.tenant_id !== callerTenant) {
          return new Response(JSON.stringify({ error: 'Usuário não encontrado.' }), {
            status: 404, headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          });
        }

        await admin.from('app_users').delete().eq('id', user_id);
        await admin.auth.admin.deleteUser(user_id);

        return new Response(JSON.stringify({ ok: true }), {
          status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        });
      }

      default:
        return new Response(JSON.stringify({ error: `Ação desconhecida: ${action}` }), {
          status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        });
    }
  } catch (err) {
    return new Response(JSON.stringify({ error: err instanceof Error ? err.message : 'Erro interno' }), {
      status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }
});
```

- [ ] **Step 3: Escrever deno.json**

```json
{
  "imports": {
    "@supabase/supabase-js": "https://esm.sh/@supabase/supabase-js@2"
  }
}
```

- [ ] **Step 4: Deploy da Edge Function**

```bash
supabase functions deploy manage-users --project-ref ybajzitijjtzhavgrarz
```

- [ ] **Step 5: Commit**

```bash
git add supabase/functions/manage-users/
git commit -m "feat: Edge Function manage-users com create, update, reset_password, delete_user"
```

---

### Task 6: Verificação final

- [ ] **Step 1: Rodar `flutter analyze`**

```bash
cd C:\Users\filip\Desktop\ATR; flutter analyze
```

Corrigir quaisquer warnings/erros.

- [ ] **Step 2: Rodar testes existentes**

```bash
cd C:\Users\filip\Desktop\ATR; flutter test
```

- [ ] **Step 3: Commit final**

```bash
git add -A
git commit -m "chore: ajustes finais e verificação"
```
