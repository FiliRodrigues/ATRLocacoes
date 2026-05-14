# Spec: Refatoração do Cadastro de Usuários

**Data:** 2026-05-14
**Status:** Aprovado
**Abordagem:** C — Aprimoramento focado

---

## 1. Objetivo

Transformar o gerenciamento de usuários em uma seção completa com re-autenticação
do admin, CRUD total (criar, editar, resetar senha, desativar, excluir), integrada
ao fluxo de Configurações.

---

## 2. Arquitetura e Fluxo de Dados

### 2.1 Camadas

```
SettingsScreen
  └─ card "Gerenciar Usuários"
       └─ Navigator → UsersScreen (com gate de re-auth)
            ├─ ReAuthGate (modal de senha)
            ├─ UserFormModal (criar / editar completo)
            ├─ ResetPasswordDialog
            ├─ DeleteConfirmDialog (dupla confirmação)
            └─ DeactivateConfirmDialog
```

### 2.2 Arquivos alterados

| Arquivo | Mudança |
|---------|---------|
| `lib/core/services/user_admin_service.dart` | +6 métodos: `updateUser`, `updateRole`, `resetPassword`, `deleteUser`, `reactivateUser`, `verifyAdminPassword` |
| `lib/features/admin/users_screen.dart` | Re-auth gate, ações expandidas, status na tabela |
| `lib/features/admin/user_form_modal.dart` | Modo full-edit (username, nome, função, features), distinção create/edit |
| `lib/features/settings/settings_screen.dart` | Card "Gerenciar Usuários" (admin-only) apontando para `/admin/users` |
| `supabase/functions/manage-users/index.ts` | Renomeado de `create-user/`. +3 handlers: `update_user`, `reset_password`, `delete_user` |

### 2.3 O que **não** muda

- `AuthService` — sem novos métodos
- `app_users` — zero alterações no schema
- Sidebar — já mostra "Gerenciar Usuários" para admins
- RLS — policies existentes continuam

---

## 3. Edge Function `manage-users/`

### 3.1 Handlers (campo `action` no body)

| Action | Descrição | Validações |
|--------|-----------|------------|
| `create_user` | `auth.admin.createUser` + INSERT `app_users` | Caller admin, senha ≥12 chars |
| `update_user` | UPDATE `app_users` + `auth.admin.updateUserById` | Caller admin, não a si mesmo |
| `reset_password` | `auth.admin.updateUserById(id, { password })` | Caller admin, senha ≥12 chars |
| `delete_user` | DELETE `app_users` + `auth.admin.deleteUser` | Caller admin, não a si mesmo |

### 3.2 Segurança

- JWT do caller validado via `supabase.auth.getUser()`
- Caller deve ter `app_metadata.role === 'admin'`
- Operações de update/delete usam `service_role key`
- Bloqueio: admin não pode gerenciar o próprio usuário

---

## 4. UI

### 4.1 Tela principal `UsersScreen`

```
┌─────────────────────────────────────────────────┐
│ ← Voltar   Gerenciar Usuários                    │
│            Controle de acesso e permissões        │
├─────────────────────────────────────────────────┤
│ [+ Novo Usuário]                                  │
│ 🔍 Buscar por nome ou usuário...  [X]  42 usuário(s) │
├─────────────────────────────────────────────────┤
│ USUÁRIO   NOME      FUNÇÃO   TELAS   ÚLTIMO   STATUS   AÇÕES │
│ JD  admin Admin S.  Admin   Todas   10/05    ◆ Ativo   ✎ ↻ 🗑 ✕ │
│ MB  maria Maria B.  Membro  3 telas 09/05    ◆ Ativo   ✎ ↻ 🗑 ✕ │
│ CS  carlo Carlos S. Membro  5 telas —        ◇ Inativo  ✎ ↻ 🗑 ✕ │
├─────────────────────────────────────────────────────────────────┤
│                         ← Pág. 1 de 5 →                        │
└─────────────────────────────────────────────────────────────────┘
```

### 4.2 Ações por linha

| Ícone | Ação | Modal/Diálogo |
|-------|------|--------------|
| ✎ | Editar | `UserFormModal` em modo full-edit |
| ↻ | Resetar senha | Diálogo: nova senha + confirmar |
| 🗑 | Desativar | Confirmação → `ativo = false` |
| ✕ | Excluir | Dupla confirmação (irreversível) |

### 4.3 Re-auth Gate

- Ao abrir `UsersScreen`, se não autenticado → modal com campo de senha
- `UserAdminService.verifyAdminPassword()` faz `signInWithPassword` com o email do admin logado
- Sucesso → estado `_isUnlocked = true`, persiste na instância da tela
- Fechou a tela → volta ao estado locked

### 4.4 UserFormModal — diferença create vs edit

| Campo | Create | Edit |
|-------|--------|------|
| Email | Visível, obrigatório | Oculto |
| Username | Visível, editável | Visível, editável |
| Nome completo | Visível | Visível, editável |
| Senha / Confirmar | Visível, obrigatório | Oculto |
| Função (admin/membro) | Visível, editável | Visível, editável |
| Telas permitidas | Visível se "Membro" | Visível se "Membro" |

### 4.5 Exclusão permanente — dupla confirmação

- **Modal 1:** "Tem certeza que deseja excluir permanentemente 'Maria B.' (maria)?"
- **Modal 2:** "Esta ação é irreversível. Digite o username 'maria' para confirmar." (text field + botão)

---

## 5. Estados e Erros

### 5.1 Estados da tela principal

| Estado | Gatilho | UI |
|--------|---------|-----|
| `locked` | Tela aberta sem re-auth | Modal de senha |
| `loading` | Buscando usuários | Spinner |
| `loaded` | Dados recebidos | Tabela |
| `empty` | Zero resultados | "Nenhum usuário encontrado" |
| `error` | Falha na requisição | Ícone + mensagem + retry |

### 5.2 Tratamento de erros

| Erro | Mensagem |
|------|----------|
| Email duplicado | "Este email já está cadastrado" |
| Senha < 12 chars | Validação client + Edge Function |
| Tentou gerenciar a si mesmo | "Você não pode gerenciar seu próprio usuário" |
| Rede | "Erro de conexão. Tente novamente." |
| Senha re-auth incorreta | "Senha incorreta" (modal não fecha) |

---

## 6. Escopo e Limites

### Dentro do escopo
- Re-autenticação do admin ao abrir a tela
- CRUD completo: criar, editar (permissões, função, nome, username), resetar senha, desativar, excluir
- Card "Gerenciar Usuários" no Settings (admin-only)
- Dupla confirmação para exclusão permanente

### Fora do escopo
- Registro público (sign-up) — continua inexistente
- "Esqueci minha senha" — fora do escopo
- Notificações de criação de usuário — fora do escopo
- Histórico de ações do admin — já coberto pelo `audit_log`
- Bulk operations (selecionar múltiplos e agir)
