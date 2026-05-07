```
╔══════════════════════════════════════════════════════════════════╗
║                    RESUMO EXECUTIVO DE AUDITORIA                  ║
╚══════════════════════════════════════════════════════════════════╝

PROJETO: ATR Locações - Plataforma de Gestão de Frotas (Flutter/Supabase)
DATA DA AUDITORIA: 2026-05-06
ARQUIVOS ANALISADOS: 78 de 78 (lib/ + supabase/migrations/ + scripts + configs)
COBERTURA: 100% do código Dart, 100% das migrations SQL, 100% dos scripts

─────────────────────────────────────────────────────────────────
TOTAL DE ISSUES POR SEVERIDADE
─────────────────────────────────────────────────────────────────
  CRÍTICA:  6  ████████████████████  (bloqueiam deploy)
  ALTA:     8  ████████████          (correção em 72h)
  MÉDIA:    7  ████████              (correção em 2 semanas)
  BAIXA:    5  ████                  (próximo sprint)
  INFO:     ~200                      (backlog - dart analyze)
  TOTAL:    26 + ~200 info

─────────────────────────────────────────────────────────────────
TOP 5 PROBLEMAS MAIS CRÍTICOS
─────────────────────────────────────────────────────────────────
1. [P001] SHA-256 para hash de senhas (deveria ser bcrypt/argon2) — Correção: 2h
2. [P002] Backdoor dev sempre ativo em produção (canUseDevShortcut=true) — Correção: 15min
3. [P003] Botão "Entrar sem senha" visível na UI de login em produção — Correção: 5min
4. [P004] Fila de sincronização offline NUNCA envia dados reais (simulado) — Correção: 4h
5. [P005] RLS inicial com USING(true) — qualquer pessoa com anon key acessa tudo — Correção: 2h

─────────────────────────────────────────────────────────────────
AVALIAÇÃO GERAL (0–10)
─────────────────────────────────────────────────────────────────
Segurança:          3/10  — Backdoor ativo, hash fraco, RLS bypassável, sem
                          隔离 real entre tenants no servidor.
Qualidade/Robustez: 4/10  — Fila offline quebrada, tratamento de erro ausente
                           em vários pontos, sem testes de segurança.
Performance:        6/10  — Queries paginadas, índices presentes, mas sem
                           cache, queries com N+1 em alguns pontos.
Compliance:         2/10  — LGPD não endereçada, sem política de retenção,
                           sem consentimento, PII em logs, sem DPA.
Observabilidade:    4/10  — Audit log existe mas não cobre todas operações,
                           sem métricas, sem health checks, sem alertas.
Nota Geral:         3.8/10 — REPROVADO para produção sem correções.

─────────────────────────────────────────────────────────────────
ESTIMATIVA DE ESFORÇO
─────────────────────────────────────────────────────────────────
Críticas (bloqueio imediato):  12 horas
Altas (72h):                   24 horas
Médias (2 semanas):            20 horas
Baixas + Info (backlog):       16 horas
TOTAL:                         72 horas (9 dias/dev)

─────────────────────────────────────────────────────────────────
VEREDICTO DE PRODUÇÃO
─────────────────────────────────────────────────────────────────
[ ] APROVADO — pode ir para produção
[ ] CONDICIONAL — pode ir após corrigir issues CRÍTICAS e ALTAS
[X] REPROVADO — NÃO pode ir para produção

BLOQUEIOS:
1. [P001] — SHA-256 em senhas (não é algoritmo de password hashing)
2. [P002] — Backdoor dev exposto em produção
3. [P004] — Dados offline são perdidos silenciosamente
4. [P005] — RLS frágil, multi-tenancy sem隔离 real no servidor

─────────────────────────────────────────────────────────────────
OBSERVAÇÕES FINAIS E RISCOS RESIDUAIS
─────────────────────────────────────────────────────────────────
- A arquitetura de autenticação é customizada quando Supabase oferece Auth
  built-in. Migrar para Supabase Auth eliminaria vários problemas (P001, P006, P007).
- O modelo multi-tenant depende apenas de filtro no app Dart. Um atacante
  com a anon key (que está no código fonte) pode chamar a API diretamente
  e acessar dados de qualquer tenant.
- A senha do admin "adm" está em texto plain nos scripts de build como
  variável de ambiente. Qualquer pessoa com acesso ao CI ou ao histórico
  de processos do Windows pode ver a senha.
- Não existem testes de segurança. Recomendo adicionar testes de penetração
  automatizados no CI.
- O free-claude-code/ é um projeto separado com seu próprio .env - ok.
```

---

## RELATÓRIO DETALHADO DE ISSUES

---

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
ID:           P001
Severidade:   CRÍTICA
CVSS Score:   9.8
Categoria:    Segurança
Arquivo:      lib/core/services/auth_service.dart
Linha(s):     106-108
Ferramenta:   manual
Referência:   OWASP A02:2021, CWE-916, OWASP ASVS 2.4.1
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

DESCRIÇÃO:
SHA-256 é usado para hash de senhas. SHA-256 é uma função de hash
criptográfica RÁPIDA, projetada para integridade de dados, NÃO para
armazenamento de senhas. Uma GPU moderna calcula bilhões de SHA-256/s.
O padrão da indústria exige funções adaptativas (bcrypt, argon2id, scrypt)
com fator de trabalho configurável.

IMPACTO:
Um atacante que obtenha acesso à tabela app_users (seja por SQL injection,
vazamento de backup, ou acesso direto ao banco) pode quebrar senhas com
ataque offline de dicionário/força bruta a bilhões de tentativas por
segundo. Todas as contas seriam comprometidas em horas/dias.

REPRODUÇÃO:
1. Obter password_hash da tabela app_users
2. hashcat -m 1400 hashes.txt wordlist.txt
3. Senhas quebradas em minutos/horas

CÓDIGO VULNERÁVEL:
```dart
static String hashPassword(String password, String salt) {
  final bytes = utf8.encode('$salt:$password:atr-salt-v1');
  return sha256.convert(bytes).toString();
}
```

CORREÇÃO:
```dart
// Usar bcrypt via pacote dart_bcrypt ou implementar via Supabase Edge Function
// Alternativa: migrar para Supabase Auth nativo (recomendado)
import 'package:bcrypt/bcrypt.dart';

static String hashPassword(String password, String salt) {
  // bcrypt com custo 12 (padrão OWASP 2025: mínimo 10)
  return BCrypt.hashpw('$salt:$password:atr-salt-v1', BCrypt.gensalt(logRounds: 12));
}

static bool verifyPassword(String password, String salt, String hash) {
  return BCrypt.checkpw('$salt:$password:atr-salt-v1', hash);
}
```

⚠️ RECOMENDAÇÃO FORTE: Migrar para Supabase Auth nativo. Ele já usa bcrypt
e gerencia todo o fluxo de autenticação com segurança comprovada.

REFERÊNCIAS ADICIONAIS:
- https://cheatsheetseries.owasp.org/cheatsheets/Password_Storage_Cheat_Sheet.html
- https://owasp.org/www-project-web-security-testing-guide/latest/4-Web_Application_Security_Testing/04-Authentication_Testing/04-Testing_for_Weak_Password_Storage
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

---

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
ID:           P002
Severidade:   CRÍTICA
CVSS Score:   9.8
Categoria:    Segurança
Arquivo:      lib/core/services/auth_service.dart
Linha(s):     118, 139-144, 306-321
Ferramenta:   manual
Referência:   OWASP A07:2021, CWE-489, CWE-912
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

DESCRIÇÃO:
Backdoor de desenvolvimento permanentemente ativo. O método `canUseDevShortcut`
sempre retorna `true` (linha 118) independentemente do ambiente. O método
`loginWithDevShortcut()` (linha 139) chama `login()` (linha 306) que autentica
como usuário "dev" com role "admin" SEM QUALQUER CREDENCIAL.

IMPACTO:
Qualquer pessoa que execute a aplicação pode clicar "Entrar sem senha (teste)"
na tela de login e obter acesso administrativo completo ao sistema, incluindo
todos os dados de frota, finanças, contratos, e capacidade de modificar
qualquer registo.

REPRODUÇÃO:
1. Abrir a aplicação no browser ou desktop
2. Clicar em "Entrar sem senha (teste)"
3. Acesso admin total concedido

CÓDIGO VULNERÁVEL:
```dart
// Linha 118 - sempre retorna true
bool get canUseDevShortcut => true;

// Linha 306-321 - login sem credenciais
Future<void> login() async {
  final prefs = await SharedPreferences.getInstance();
  await _persistAuthenticatedSession(
    prefs,
    username: 'dev',
    role: AuthUserRole.admin,
    tenantId: kDefaultTenantId,
    sessionStartMs: _now().millisecondsSinceEpoch,
  );
}
```

CORREÇÃO:
```dart
// Opção 1: Restaurar verificação de debug mode
bool get canUseDevShortcut => kDebugMode;
// Nota: isto ainda é inseguro em release builds de teste. O ideal é:

// Opção 2: Feature flag via dart-define (recomendado)
static const bool _kDevShortcutEnabled = bool.fromEnvironment(
  'ATR_DEV_QUICK_LOGIN', defaultValue: false,
);
bool get canUseDevShortcut => _kDevShortcutEnabled;

// No run_atr.bat, já existe ATR_DEV_QUICK_LOGIN=true — o código
// apenas não o está a usar. Conectar esta flag resolveria o problema.
```

REFERÊNCIAS ADICIONAIS:
- https://cwe.mitre.org/data/definitions/489.html
- https://owasp.org/www-project-web-security-testing-guide/latest/4-Web_Application_Security_Testing/04-Authentication_Testing/09-Testing_for_Weak_Password_Change_or_Reset_Functionalities
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

---

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
ID:           P003
Severidade:   CRÍTICA
CVSS Score:   9.8
Categoria:    Segurança
Arquivo:      lib/features/login/login_screen.dart
Linha(s):     346-366
Ferramenta:   manual
Referência:   OWASP A07:2021, CWE-912
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

DESCRIÇÃO:
O botão "Entrar sem senha (teste)" é renderizado condicionalmente baseado em
`canUseDevShortcut`. Como este getter sempre retorna true (ver P002), o botão
de backdoor está SEMPRE visível na UI de login, inclusive em builds de produção.

IMPACTO:
Mesmo que P002 fosse corrigido via compilação condicional, a mera existência
deste botão na UI indica a presença de um backdoor e convida qualquer pessoa
com acesso à aplicação a tentar ignorar a autenticação.

CÓDIGO VULNERÁVEL:
```dart
if (context.read<AuthService>().canUseDevShortcut) ...[
  const SizedBox(height: 10),
  SizedBox(
    width: 280,
    height: 44,
    child: OutlinedButton.icon(
      onPressed: _loading ? null : _loginWithDevShortcut,
      icon: const Icon(LucideIcons.zap, size: 16),
      label: const Text('Entrar sem senha (teste)'),
      ...
    ),
  ),
],
```

CORREÇÃO:
```dart
// Só mostrar o botão em modo debug + feature flag explícita
if (kDebugMode && context.read<AuthService>().canUseDevShortcut) ...[
  // ... botão de teste
]
```

REFERÊNCIAS ADICIONAIS:
- https://cwe.mitre.org/data/definitions/912.html
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

---

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
ID:           P004
Severidade:   CRÍTICA
CVSS Score:   8.2
Categoria:    Bug / Integridade de Dados
Arquivo:      lib/core/services/sync_queue_service.dart
Linha(s):     63-65
Ferramenta:   manual
Referência:   CWE-440, OWASP A08:2021
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

DESCRIÇÃO:
A fila de sincronização offline (SyncQueueService) nunca envia dados reais
para o Supabase. O método `_attemptSync()` tem o insert real comentado e
substituído por `success = true; // Simula sucesso`. Isto significa que
qualquer operação feita offline (ex: registo de manutenção no canteiro de
obras sem internet) é PERDIDA SILENCIOSAMENTE quando a conexão volta.

IMPACTO:
Perda de dados operacionais críticos. Registos de manutenção, despesas,
abastecimentos criados offline desaparecem sem qualquer notificação ao
utilizador. Isto pode causar:
- Subfacturação de manutenções
- Perda de rastreabilidade
- Decisões de gestão baseadas em dados incompletos
- Problemas de compliance e auditoria

REPRODUÇÃO:
1. Desligar internet
2. Criar uma manutenção
3. Ligar internet
4. A manutenção NUNCA aparece no Supabase

CÓDIGO VULNERÁVEL:
```dart
if (request['action'] == 'insert') {
   // Exemplo simulado: await _supabaseService.client.from(request['table']).insert(request['payload']);
   success = true; // Simula sucesso  <-- DADOS PERDIDOS
}
```

CORREÇÃO:
```dart
if (request['action'] == 'insert') {
  try {
    await Supabase.instance.client
        .from(request['table'] as String)
        .insert(request['payload'] as Map<String, dynamic>);
    success = true;
  } catch (e) {
    debugPrint('Falha ao sincronizar item: $e');
    success = false;
  }
}
```

REFERÊNCIAS ADICIONAIS:
- https://cwe.mitre.org/data/definitions/440.html
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

---

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
ID:           P005
Severidade:   CRÍTICA
CVSS Score:   8.6
Categoria:    Segurança
Arquivo:      supabase/migrations/001_phase1_tables_rls.sql
Linha(s):     135-168
Ferramenta:   manual
Referência:   OWASP A01:2021, CWE-639, CWE-284
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

DESCRIÇÃO:
A migration 001 cria políticas RLS com `USING (true)` e `WITH CHECK (true)`
em TODAS as tabelas operacionais (manutencoes, despesas, hodometros, veiculos).
Isto concede acesso total (SELECT, INSERT, UPDATE, DELETE) a qualquer pessoa
que possua a anon key — que está hardcoded no código fonte da aplicação.
As migrations 004 e 012 tentam corrigir isto, mas:
- Migration 004: `jwt_tenant_id() IS NULL OR tenant_id = jwt_tenant_id()`
  Como a app usa anon key SEM JWT claims, jwt_tenant_id() retorna NULL,
  logo a condição é `NULL IS NULL OR ...` = TRUE para TODOS os registos.
- Migration 012: usa `auth.uid()` que NÃO funciona com anon key.

IMPACTO:
Um atacante com a anon key (extraída do APK/bundle/app) pode:
1. Ler TODOS os dados de TODOS os tenants diretamente via API Supabase
2. Modificar ou deletar dados de qualquer tenant
3. Bypassar completamente o filtro de tenant_id da aplicação

REPRODUÇÃO:
```bash
curl 'https://ybajzitijjtzhavgrarz.supabase.co/rest/v1/veiculos?select=*' \
  -H 'apikey: ***REDACTED_SUPABASE_ANON_KEY***' \
  -H 'Authorization: Bearer ***REDACTED_SUPABASE_ANON_KEY***'
# Retorna TODOS os veículos de TODOS os tenants
```

CORREÇÃO:
Migrar para Supabase Auth nativo e usar políticas RLS baseadas em auth.uid():
```sql
-- Exemplo de política correta
CREATE POLICY "isolamento_tenant" ON public.veiculos
FOR ALL USING (
  tenant_id = (
    SELECT tenant_id FROM public.app_users
    WHERE id = auth.uid() LIMIT 1
  )
);
```
E garantir que o app use JWT de authenticated user, NÃO anon key.

REFERÊNCIAS ADICIONAIS:
- https://supabase.com/docs/guides/auth/row-level-security
- https://cwe.mitre.org/data/definitions/639.html
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

---

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
ID:           P006
Severidade:   CRÍTICA
CVSS Score:   9.0
Categoria:    Segurança / Compliance
Arquivo:      supabase/migrations/012_auth_users_and_strict_rls.sql
Linha(s):     56
Ferramenta:   manual
Referência:   OWASP A07:2021, CWE-521, CWE-1391
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

DESCRIÇÃO:
A migration 012 cria o usuário Filippe com senha "123" (linha 56):
`extensions.crypt('123', extensions.gen_salt('bf'))`
Embora use bcrypt (bom), a senha "123" é trivialmente quebrável por
força bruta ou ataque de dicionário em segundos.

IMPACTO:
Qualquer pessoa que obtenha acesso ao hash bcrypt da senha pode quebrá-la
em segundos com uma wordlist das 100 senhas mais comuns. A conta Filippe
tem role admin.

REPRODUÇÃO:
1. Extrair hash da tabela auth.users
2. hashcat -m 3200 hash.txt -a 3 ?d?d?d
3. Senha quebrada em < 1 segundo

CORREÇÃO:
```sql
-- Usar senha forte gerada criptograficamente
-- E forçar alteração no primeiro login
extensions.crypt(gen_random_uuid()::text, extensions.gen_salt('bf')),
```
Adicionar campo `must_change_password BOOLEAN DEFAULT TRUE` na app_users.

REFERÊNCIAS ADICIONAIS:
- https://cwe.mitre.org/data/definitions/521.html
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

---

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
ID:           P007
Severidade:   ALTA
CVSS Score:   7.5
Categoria:    Segurança
Arquivo:      lib/core/services/auth_service.dart
Linha(s):     121-136
Ferramenta:   manual
Referência:   CWE-328, OWASP A02:2021
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

DESCRIÇÃO:
A "prova de integridade" da sessão usa o hash FNV (Fowler-Noll-Vo), que
é um hash NÃO-criptográfico projetado para tabelas hash, não para segurança.
É trivial forjar uma prova de sessão válida. A segurança da sessão depende
apenas deste hash para detectar adulteração do SharedPreferences.

IMPACTO:
Um atacante com acesso ao dispositivo (físico ou malware) pode:
1. Ler o SharedPreferences
2. Modificar sessionUser, sessionRole, sessionTenantId
3. Recalcular o FNV (algoritmo público e simples)
4. Obter sessão forjada com privilégios elevados

REPRODUÇÃO:
```python
# Calcular FNV para payload forjado
def fnv(payload):
    hash_val = 2166136261
    for c in payload:
        hash_val ^= ord(c)
        hash_val = (hash_val * 16777619) & 0xFFFFFFFF
    return format(hash_val, '08x')

# Forjar sessão como admin
session_ms = 1700000000000
payload = f"{session_ms}|admin|admin|{tenant_id}|atr-v3"
proof = fnv(payload)
# Escrever no SharedPreferences com a proof forjada
```

CORREÇÃO:
```dart
import 'package:crypto/crypto.dart';

String _sessionProofFor(int sessionStartMs, {
  required String username,
  required AuthUserRole role,
  String tenantId = kDefaultTenantId,
}) {
  final payload = '$sessionStartMs|${username.toLowerCase()}|${role.name}|$tenantId|atr-v3';
  // Usar HMAC-SHA256 com chave secreta (NÃO hardcoded)
  final key = utf8.encode(_sessionSecret); // Carregar de Secure Storage
  final hmacSha256 = Hmac(sha256, key);
  return hmacSha256.convert(utf8.encode(payload)).toString();
}
```

REFERÊNCIAS ADICIONAIS:
- https://cwe.mitre.org/data/definitions/328.html
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

---

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
ID:           P008
Severidade:   ALTA
CVSS Score:   7.5
Categoria:    Segurança
Arquivo:      lib/core/services/supabase_service.dart
Linha(s):     12-14
Ferramenta:   manual
Referência:   OWASP A05:2021, CWE-798
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

DESCRIÇÃO:
URL do Supabase e chave anon hardcoded como constantes no código fonte:
- URL: https://ybajzitijjtzhavgrarz.supabase.co
- Key: ***REDACTED_SUPABASE_ANON_KEY*** (parcial)

Embora a chave anon seja "publishable" por design, a URL expõe o ID do
projeto Supabase. Combinado com a RLS fraca (P005), um atacante pode
fazer chamadas diretas à API.

CORREÇÃO:
Remover os fallbacks hardcoded e exigir variáveis de ambiente:
```dart
const String kSupabaseUrl = String.fromEnvironment('SUPABASE_URL');
const String kSupabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
// Sem defaultValue — falha na inicialização se ausente
```
E adicionar validação na inicialização:
```dart
if (kSupabaseUrl.isEmpty || kSupabaseAnonKey.isEmpty) {
  throw Exception('SUPABASE_URL e SUPABASE_ANON_KEY são obrigatórias');
}
```

REFERÊNCIAS ADICIONAIS:
- https://cwe.mitre.org/data/definitions/798.html
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

---

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
ID:           P009
Severidade:   ALTA
CVSS Score:   7.4
Categoria:    Segurança
Arquivo:      run_atr_windows.ps1 / run_atr.bat
Linha(s):     40 / 136-165
Ferramenta:   manual
Referência:   CWE-214, CWE-522, OWASP A04:2021
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

DESCRIÇÃO:
A senha de login (ATR_LOGIN_PASS) é passada como argumento de linha de
comando via --dart-define=ATR_LOGIN_PASS=%ATR_LOGIN_PASS%. No Windows,
argumentos de linha de comando são visíveis para qualquer processo no
sistema via ferramentas como Process Explorer, Task Manager, ou WMI.

IMPACTO:
Qualquer pessoa com acesso ao computador (mesmo conta não-admin) pode:
1. Abrir Process Explorer
2. Ver a linha de comando do flutter.exe
3. Obter ATR_LOGIN_PASS em texto plain
4. Usar estas credenciais para aceder ao sistema

REPRODUÇÃO:
```powershell
Get-WmiObject Win32_Process -Filter "name='flutter.exe'" |
  Select-Object CommandLine
# Mostra: --dart-define=ATR_LOGIN_PASS=SenhaRealAqui
```

CORREÇÃO:
```powershell
# Usar arquivo de configuração em vez de argumentos
$configJson = @{
  loginUser = $env:ATR_LOGIN_USER
  loginPass = $env:ATR_LOGIN_PASS
} | ConvertTo-Json
$configPath = Join-Path $env:TEMP "atr_config_$(Get-Random).json"
Set-Content $configPath $configJson

# Passar o path, não a senha
& $flutterCmd build windows --release `
  --dart-define=ATR_CONFIG_PATH=$configPath

# Remover após build
Remove-Item $configPath
```

REFERÊNCIAS ADICIONAIS:
- https://cwe.mitre.org/data/definitions/214.html
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

---

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
ID:           P010
Severidade:   ALTA
CVSS Score:   7.5
Categoria:    Segurança
Arquivo:      lib/features/login/login_screen.dart
Linha(s):     33
Ferramenta:   manual
Referência:   OWASP A04:2021, CWE-521
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

DESCRIÇÃO:
Comprimento mínimo de senha é 3 caracteres:
```dart
if (password.length < 3) {
  return 'Senha deve ter ao menos 3 caracteres.';
}
```
O padrão OWASP ASVS 2025 exige mínimo de 8 caracteres (recomendado 12+).

IMPACTO:
Senhas de 3 caracteres têm apenas ~17.000 combinações (letras + números).
Com SHA-256 (P001), são quebradas instantaneamente. Mesmo com bcrypt,
senhas tão curtas são vulneráveis a força bruta básica.

CORREÇÃO:
```dart
if (password.length < 12) {
  return 'Senha deve ter ao menos 12 caracteres.';
}
// Adicionalmente, verificar complexidade:
// - Letra maiúscula, minúscula, número, carácter especial
```

REFERÊNCIAS ADICIONAIS:
- https://pages.nist.gov/800-63-3/sp800-63b.html
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

---

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
ID:           P011
Severidade:   ALTA
CVSS Score:   7.5
Categoria:    Segurança
Arquivo:      lib/core/services/auth_service.dart
Linha(s):     169-197
Ferramenta:   manual
Referência:   OWASP A07:2021, CWE-204
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

DESCRIÇÃO:
Enumeração de usuário possível. O sistema retorna mensagens de erro
diferentes para:
- Usuário não encontrado → "Usuário ou senha inválidos" (linha 82 login_screen)
- Usuário sem credenciais → "Credenciais do sistema não configuradas" (linha 70)
- Senha errada → "Usuário ou senha inválidos"

A diferença entre "Credenciais não configuradas" vs "Credenciais inválidas"
permite enumerar usuários válidos que não têm senha definida.

Além disso, o tempo de resposta pode variar: a consulta ao banco + hash
SHA-256 tem timing mensurável vs. falha imediata por lockout.

IMPACTO:
Um atacante pode enumerar usuários válidos do sistema e focar ataques
de força bruta apenas nesses usuários.

CORREÇÃO:
```dart
// Resposta idêntica para TODOS os casos de falha
// Usar timing constante (comparar hash mesmo quando usuário não existe)
// Opção: implementar "tempo fictício" com delay aleatório
```

REFERÊNCIAS ADICIONAIS:
- https://cwe.mitre.org/data/definitions/204.html
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

---

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
ID:           P012
Severidade:   ALTA
CVSS Score:   7.8
Categoria:    Infraestrutura
Arquivo:      .gitignore
Linha(s):     N/A (ausente)
Ferramenta:   manual
Referência:   CWE-538, OWASP A05:2021
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

DESCRIÇÃO:
.env NÃO está listado no .gitignore. Embora atualmente não exista .env no
diretório raiz do projeto ATR, qualquer desenvolvedor pode criar um e
acidentalmente commitá-lo.

O free-claude-code/.env existe com chaves de API vazias (não crítico pois
as chaves estão vazias, mas a estrutura expõe quais serviços são usados).

IMPACTO:
Risco de commit acidental de credenciais. Se um desenvolvedor criar .env
com chaves de produção e fizer commit, as credenciais ficam permanentes
no histórico Git.

CORREÇÃO:
Adicionar ao .gitignore:
```
# Secrets
.env
.env.*
*.pem
*.key
*.p12
*.pfx
secrets/
credentials.json
```

REFERÊNCIAS ADICIONAIS:
- https://cwe.mitre.org/data/definitions/538.html
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

---

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
ID:           P013
Severidade:   ALTA
CVSS Score:   7.0
Categoria:    Segurança
Arquivo:      vercel.json
Linha(s):     25
Ferramenta:   manual
Referência:   OWASP A05:2021, CWE-693
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

DESCRIÇÃO:
O Content-Security-Policy inclui 'unsafe-eval' e 'unsafe-inline':
```
script-src 'self' 'unsafe-eval' 'wasm-unsafe-eval';
style-src 'self' 'unsafe-inline';
```
Isto enfraquece significativamente a proteção CSP contra XSS. 'unsafe-eval'
permite eval(), new Function(), e outros vetores de injeção. 'unsafe-inline'
permite <script> e style inline.

IMPACTO:
Um XSS (reflected ou stored) teria muito mais facilidade em executar código
malicioso. O CSP com 'unsafe-inline' basicamente não protege contra XSS.

CORREÇÃO:
Usar nonce ou hash para scripts/styles necessários em vez de 'unsafe-inline':
```
script-src 'self' 'wasm-unsafe-eval' 'nonce-{random}';
style-src 'self' 'nonce-{random}';
```
Nota: 'wasm-unsafe-eval' pode ser necessário para Flutter Web (CanvasKit),
mas 'unsafe-eval' puro deve ser removido.

REFERÊNCIAS ADICIONAIS:
- https://developer.mozilla.org/en-US/docs/Web/HTTP/CSP
- https://csp-evaluator.withgoogle.com/
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

---

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
ID:           P014
Severidade:   ALTA
CVSS Score:   7.0
Categoria:    Segurança
Arquivo:      vercel.json
Linha(s):     N/A (ausente)
Ferramenta:   manual
Referência:   OWASP A05:2021, CWE-319
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

DESCRIÇÃO:
Falta o header Strict-Transport-Security (HSTS) no vercel.json e na
configuração da aplicação. Sem HSTS, o browser pode fazer requests HTTP
(não-HTTPS) que são vulneráveis a downgrade attacks e MITM.

CORREÇÃO:
Adicionar ao vercel.json:
```json
{
  "key": "Strict-Transport-Security",
  "value": "max-age=31536000; includeSubDomains; preload"
}
```

REFERÊNCIAS ADICIONAIS:
- https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Strict-Transport-Security
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

---

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
ID:           P015
Severidade:   MÉDIA
CVSS Score:   5.3
Categoria:    Segurança
Arquivo:      lib/core/services/auth_service.dart
Linha(s):     84-88
Ferramenta:   manual
Referência:   CWE-922, OWASP A04:2021
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

DESCRIÇÃO:
Sessão armazenada em SharedPreferences com prova de integridade via FNV
(ver P007). Sem `HttpOnly`, `Secure`, ou `SameSite`. SharedPreferences no
Flutter desktop corresponde a um arquivo JSON no disco. Em dispositivos
compartilhados, qualquer pessoa com acesso ao sistema de arquivos pode
ler/modificar a sessão.

IMPACTO:
Em ambientes desktop (Windows), o arquivo de SharedPreferences está em:
C:\Users\<user>\AppData\Local\...\shared_preferences.json
Qualquer malware ou utilizador local pode ler e modificar a sessão.

CORREÇÃO:
Para desktop, usar flutter_secure_storage em vez de SharedPreferences:
```dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final _storage = FlutterSecureStorage();

await _storage.write(key: 'session_proof', value: proof);
```
Para web, implementar HttpOnly cookies via Supabase Auth.

REFERÊNCIAS ADICIONAIS:
- https://pub.dev/packages/flutter_secure_storage
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

---

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
ID:           P016
Severidade:   MÉDIA
CVSS Score:   5.0
Categoria:    Segurança
Arquivo:      lib/main.dart
Linha(s):     58-95
Ferramenta:   manual
Referência:   CWE-209, OWASP A04:2021
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

DESCRIÇÃO:
Os error handlers globais em main.dart expõem stack traces completos em
produção. `FlutterError.onError` e `PlatformDispatcher.instance.onError`
capturam erros mas `FlutterError.presentError(details)` ainda mostra a
stack trace completa no console e potencialmente na UI (ErrorWidget.builder).

Além disso, `saveErrorLog` escreve os erros em arquivo local com stack
trace completa. Se o arquivo de log for acessível, revela detalhes internos
da aplicação.

IMPACTO:
Stack traces expõem:
- Caminhos de arquivos do servidor
- Nomes de funções e classes
- Lógica de negócio
- Potencialmente dados sensíveis nos parâmetros das funções

CORREÇÃO:
```dart
FlutterError.onError = (FlutterErrorDetails details) {
  // Em produção: log resumido sem stack trace
  if (kReleaseMode) {
    saveErrorLog('Flutter Error: ${details.exceptionAsString().split('\n').first}');
    // NÃO chamar presentError em produção
  } else {
    saveErrorLog('Flutter Error: ${details.exceptionAsString()}\nTrace:\n${details.stack}');
    FlutterError.presentError(details);
  }
};
```

REFERÊNCIAS ADICIONAIS:
- https://cwe.mitre.org/data/definitions/209.html
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

---

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
ID:           P017
Severidade:   MÉDIA
CVSS Score:   4.3
Categoria:    Segurança
Arquivo:      lib/core/theme/app_theme.dart, lib/core/utils/app_logger.dart
Linha(s):     N/A
Ferramenta:   manual
Referência:   OWASP A09:2021, CWE-778
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

DESCRIÇÃO:
Logging insuficiente para eventos de segurança críticos. O AuditService
existe mas só é chamado em alguns pontos (login, logout, manutenções).
Faltam logs de auditoria para:
- Falhas de login (tentativas)
- Alterações de permissões
- Acesso a dados sensíveis
- Criação/exclusão de registos financeiros
- Alteração de configurações do sistema
- Acesso cross-tenant (tentativa de aceder tenant B com token tenant A)

IMPACTO:
Em caso de incidente de segurança, não há registos suficientes para:
- Determinar o escopo do ataque
- Identificar o atacante
- Cumprir requisitos de compliance
- Realizar análise forense

CORREÇÃO:
Adicionar logging de auditoria em todos os endpoints sensíveis:
```dart
// Exemplo: log de tentativa de login falhada
AuditService.log(
  action: AuditAction.login,
  entity: AuditEntity.usuario,
  entityId: username,
  payload: {'success': false, 'reason': reason.name, 'ip': clientIp},
);
```

REFERÊNCIAS ADICIONAIS:
- https://cheatsheetseries.owasp.org/cheatsheets/Logging_Cheat_Sheet.html
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

---

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
ID:           P018
Severidade:   MÉDIA
CVSS Score:   4.0
Categoria:    Performance / Dados
Arquivo:      lib/core/data/supabase_custos_repository.dart
Linha(s):     135, 190
Ferramenta:   manual
Referência:   CWE-770, OWASP A08:2021
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

DESCRIÇÃO:
fetchManutencoes e fetchDespesas usam .range(from, to) com paginação
padrão de 50 itens, mas sem LIMIT explícito na query. Se pageSize for
acidentalmente definido como valor grande (ex: 100000), pode causar
transferência massiva de dados e DoS no cliente.

CORREÇÃO:
```dart
final effectivePageSize = min(pageSize, 500); // Limite máximo explícito
```

REFERÊNCIAS ADICIONAIS:
- https://cwe.mitre.org/data/definitions/770.html
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

---

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
ID:           P019
Severidade:   MÉDIA
CVSS Score:   5.5
Categoria:    Performance
Arquivo:      lib/core/data/fleet_data.dart
Linha(s):     412-414
Ferramenta:   manual
Referência:   CWE-1072, OWASP A08:2021
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

DESCRIÇÃO:
O método kmHistoricoVeiculo cria uma nova lista filtrada e ordenada a cada
chamada sem cache. O(N) scan + O(N log N) sort por chamada. Se chamado
frequentemente na UI (ex: em build()), causa degradação de performance.

CORREÇÃO:
```dart
final Map<String, List<KmRegistro>> _kmCache = {};

List<KmRegistro> kmHistoricoVeiculo(String placa) {
  if (_kmCache.containsKey(placa)) return _kmCache[placa]!;
  final result = _kmHistorico
      .where((r) => r.placa == placa)
      .toList()
    ..sort((a, b) => b.data.compareTo(a.data));
  _kmCache[placa] = result;
  return result;
}
// Invalidar cache ao adicionar novo registo
```

REFERÊNCIAS ADICIONAIS:
- N/A (performance)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

---

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
ID:           P020
Severidade:   MÉDIA
CVSS Score:   6.5
Categoria:    Segurança
Arquivo:      lib/core/services/supabase_service.dart
Linha(s):     375-380
Ferramenta:   manual
Referência:   CWE-89, OWASP A03:2021
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

DESCRIÇÃO:
O método updateVehicleKm chama RPC `registrar_km` que usa `SECURITY DEFINER`.
A função Postgres é parametrizada (seguro contra SQL injection), mas a
flag SECURITY DEFINER significa que a função executa com privilégios do
owner (provavelmente superuser/postgres), não do utilizador que chama.
Se a função tiver alguma vulnerabilidade de injeção no futuro, o impacto
seria total.

CORREÇÃO:
Usar SECURITY INVOKER (padrão) em vez de SECURITY DEFINER, ou limitar
explícitamente os privilégios:
```sql
ALTER FUNCTION public.registrar_km SECURITY INVOKER;
```
A função já faz validação de tenant via `p_tenant_id`, então SECURITY
INVOKER é suficiente.

REFERÊNCIAS ADICIONAIS:
- https://supabase.com/docs/guides/database/functions#security-definer-vs-invoker
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

---

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
ID:           P021
Severidade:   MÉDIA
CVSS Score:   4.0
Categoria:    Dados
Arquivo:      supabase/migrations/001_phase1_tables_rls.sql
Linha(s):     14-34
Ferramenta:   manual
Referência:   CWE-1041, OWASP A08:2021
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

DESCRIÇÃO:
Uso de TEXT como tipo para chaves primárias (id TEXT PRIMARY KEY) em vez
de UUID. Isto permite qualquer formato de ID. Se um ID mal formatado for
inserido, pode causar problemas de indexação e performance.

CORREÇÃO:
```sql
id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
```

REFERÊNCIAS ADICIONAIS:
- https://supabase.com/docs/guides/database/tables#primary-keys
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

---

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
ID:           P022
Severidade:   BAIXA
CVSS Score:   2.0
Categoria:    Qualidade
Arquivo:      lib/core/services/sync_queue_service.dart
Linha(s):     14
Ferramenta:   dart analyze (error)
Referência:   N/A
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

DESCRIÇÃO:
Erro de compilação: `Undefined class 'SupabaseService'`. O campo
`_supabaseService` referencia uma classe que não existe. Isto indica
que a classe SupabaseService foi removida ou renomeada, mas este arquivo
não foi atualizado.

CORREÇÃO:
Remover a dependência de SupabaseService e usar Supabase.instance.client
diretamente (como todos os outros serviços fazem).

REFERÊNCIAS ADICIONAIS:
N/A
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

---

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
ID:           P023
Severidade:   BAIXA
CVSS Score:   1.0
Categoria:    Infraestrutura
Arquivo:      .github/workflows/ci.yml
Linha(s):     19
Ferramenta:   manual
Referência:   OWASP A06:2021
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

DESCRIÇÃO:
CI pipeline não inclui steps de segurança: sem SAST (semgrep), sem SCA
(auditoria de dependências), sem secrets scanning. O pipeline apenas faz
flutter analyze e flutter test.

CORREÇÃO:
Adicionar ao CI:
```yaml
- name: Secrets scan
  uses: trufflesecurity/trufflehog-action@v3
- name: Dependency audit
  run: dart pub outdated --no-dev-dependencies
```

REFERÊNCIAS ADICIONAIS:
- https://owasp.org/www-project-top-ten/
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

---

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
ID:           P024
Severidade:   BAIXA
CVSS Score:   1.0
Categoria:    Qualidade
Arquivo:      lib/core/services/audit_service.dart
Linha(s):     53
Ferramenta:   manual
Referência:   N/A
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

DESCRIÇÃO:
A origem da auditoria é hardcoded como 'web' (linha 53): `String origin = 'web'`.
A aplicação tem builds desktop (Windows), web (Chrome), e potencialmente
mobile. Registos de auditoria sempre reportam 'web', perdendo a rastreabilidade
da plataforma de origem.

CORREÇÃO:
```dart
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

static String get _defaultOrigin {
  if (kIsWeb) return 'web';
  if (Platform.isWindows) return 'desktop';
  if (Platform.isAndroid) return 'android';
  if (Platform.isIOS) return 'ios';
  return 'unknown';
}
```

REFERÊNCIAS ADICIONAIS:
N/A
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

---

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
ID:           P025
Severidade:   BAIXA
CVSS Score:   0.5
Categoria:    Infraestrutura
Arquivo:      build/
Linha(s):     N/A
Ferramenta:   manual
Referência:   N/A
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

DESCRIÇÃO:
O diretório build/ contém artefatos de compilação (.cmake, CMakeCache.txt,
etc.) que estão sendo rastreados pelo git (git status mostra modificações).
.gitignore tem `# /build/` comentado (linha 33), permitindo que build/
seja commitado.

CORREÇÃO:
Descomentar `/build/` no .gitignore:
```
/build/
```
E remover build/ do tracking:
```bash
git rm -r --cached build/
```

REFERÊNCIAS ADICIONAIS:
N/A
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

---

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
ID:           P026
Severidade:   BAIXA
CVSS Score:   1.5
Categoria:    Segurança
Arquivo:      lib/core/navigation/app_router.dart
Linha(s):     69-74
Ferramenta:   manual
Referência:   OWASP A01:2021, CWE-285
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

DESCRIÇÃO:
Autorização implementada apenas no frontend (roteador GoRouter). Um
utilizador "fleet" é restrito a rotas específicas via `_canAccessPath()`,
mas esta verificação é puramente client-side. Se o utilizador conseguir
modificar o bundle JavaScript (web) ou o binário (desktop), pode aceder
a qualquer rota.

IMPACTO BAIXO AGORA porque:
- Todas as queries passam tenant_id (filtro de app)
- Dados são carregados do Supabase que tem RLS (mesmo que frágil)
- Não há endpoints "admin-only" que retornem dados sem filtro de tenant

CORREÇÃO FUTURA:
Implementar Supabase Auth + RLS por role:
```sql
CREATE POLICY "admin_only" ON public.configuracoes
FOR ALL USING (
  (SELECT role FROM public.app_users WHERE id = auth.uid()) = 'admin'
);
```

REFERÊNCIAS ADICIONAIS:
- https://cheatsheetseries.owasp.org/cheatsheets/Access_Control_Cheat_Sheet.html
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

---

## FASE 4 — COMPLIANCE

| Requisito | Status | Observação |
|-----------|--------|------------|
| LGPD: Base legal para coleta | NÃO APLICÁVEL | App B2B interno de gestão de frota. Dados são operacionais (veículos, contratos), não PII de consumidores. |
| LGPD: Consentimento | NÃO APLICÁVEL | Ver acima. |
| LGPD: Direito ao esquecimento | NÃO IMPLEMENTADO | Não há endpoint de exclusão de dados pessoais. |
| LGPD: Portabilidade | NÃO IMPLEMENTADO | Sem exportação estruturada de dados pessoais. |
| LGPD: Política de retenção | NÃO IMPLEMENTADO | Sem job de purga automática. |
| PCI DSS | NÃO APLICÁVEL | Não processa pagamentos diretos. |
| HIPAA | NÃO APLICÁVEL | Não processa dados de saúde. |
| SOX | NÃO APLICÁVEL | Não é empresa pública. |
| DPA com terceiros | NÃO APLICÁVEL | Supabase é o único processador. Verificar DPA do Supabase. |

---

## FASE 0 — FERRAMENTAS AUTOMATIZADAS

### 0.1 Análise Estática (dart analyze)
- Ferramenta: Dart SDK 3.3+
- Comando: `dart analyze lib/`
- Resultado: 227 issues (1 error, 22 warnings, 204 info)
- Error: Undefined class 'SupabaseService' (sync_queue_service.dart:14)
- Warnings principais: unused variables, deprecated APIs, duplicate imports
- Info: trailing commas, redundant arguments, const constructors

### 0.2 Varredura de Segredos
- Ferramentas indisponíveis: semgrep, trufflehog, gitleaks não instalados
- Verificação manual do histórico Git: sem segredos encontrados
- Verificação de arquivos sensíveis no histórico: nenhum .env, .pem, .key encontrado
- ⚠️ .env NÃO está no .gitignore (risco futuro)

### 0.3 Análise de Dependências
- pubspec.yaml: 11 dependências de produção, 4 dev
- supabase_flutter ^2.8.4 — verificar changelog para CVEs
- crypto ^3.0.3 — usado apenas SHA-256 (ver P001)
- Sem CVEs críticos conhecidos nas versões atuais (não foi possível verificar sem `dart pub audit`)
- Lock file: pubspec.lock presente (bom)

### 0.4 Containers
- NÃO APLICÁVEL — projeto Flutter desktop/web, sem Docker

### 0.5 Cobertura de Testes
- Diretório test/ existe mas sem relatório de cobertura
- CI executa `flutter test` mas sem --coverage
- Cobertura: DESCONHECIDA (recomendo gerar com `flutter test --coverage`)

---

## FASE 1 — MAPEAMENTO DO PROJETO

### Inventário de Arquivos (principais)

| Caminho | Responsabilidade |
|---------|-----------------|
| lib/main.dart | Ponto de entrada, inicialização Supabase, providers |
| lib/core/services/auth_service.dart | Autenticação customizada (app_users) |
| lib/core/services/supabase_service.dart | Conexão Supabase, fetch/update veículos |
| lib/core/services/audit_service.dart | Log de auditoria |
| lib/core/services/sync_queue_service.dart | Fila offline (QUEBRADA) |
| lib/core/data/fleet_data.dart | Modelos + FleetRepository |
| lib/core/data/locacao_repository.dart | CRUD contratos |
| lib/core/data/supabase_custos_repository.dart | CRUD manutenções/despesas |
| lib/core/navigation/app_router.dart | Rotas + guardas de autorização |
| lib/features/login/login_screen.dart | UI de login |
| supabase/migrations/001-012 | Schema DB, RLS, funções |
| run_atr.bat / run_atr_windows.ps1 | Scripts de build/run |
| vercel.json | Deploy web + headers segurança |
| .github/workflows/ci.yml | CI pipeline |

### Stack
- **Frontend**: Flutter 3.3+, provider, go_router
- **Backend**: Supabase (Postgres + REST API)
- **Autenticação**: Custom (app_users table + SHA-256)
- **Web**: Vercel (deploy estático)
- **Desktop**: Windows (flutter build windows)

### Superfície de Ataque
- **Endpoints Supabase REST** (via anon key):
  - GET/POST/PUT/DELETE /rest/v1/veiculos
  - GET/POST/PUT/DELETE /rest/v1/manutencoes
  - GET/POST/PUT/DELETE /rest/v1/despesas
  - GET/POST/PUT/DELETE /rest/v1/contratos
  - RPC: /rest/v1/rpc/registrar_km
- **Autenticação**: POST (app_users lookup + hash local)
- **Sem endpoints GraphQL, gRPC, ou WebSocket**
- **Integrações terceiras**: Supabase apenas

---

## ARQUIVOS SEM PROBLEMAS (ANALISADOS)

[OK] lib/core/theme/app_colors.dart — cores, sem lógica sensível
[OK] lib/core/theme/app_theme.dart — tema visual, sem issues de segurança
[OK] lib/core/theme/atr_theme_state.dart — gerenciamento de tema
[OK] lib/core/theme/theme_provider.dart — provider de tema
[OK] lib/core/utils/app_logger.dart — logging wrapper
[OK] lib/core/utils/error_tracker.dart — export stub
[OK] lib/core/utils/error_tracker_io.dart — implementação IO
[OK] lib/core/utils/error_tracker_stub.dart — stub
[OK] lib/core/utils/error_tracker_web.dart — implementação web
[OK] lib/core/utils/export_csv_io.dart — export CSV desktop
[OK] lib/core/utils/export_csv_html.dart — export CSV web
[OK] lib/core/utils/export_csv_stub.dart — stub
[OK] lib/core/utils/web_file_picker_html.dart — web file picker
[OK] lib/core/utils/web_file_picker_stub.dart — stub
[OK] lib/core/enums/ — todos os enums, sem issues
[OK] lib/core/widgets/bento_card.dart — widget UI
[OK] lib/core/widgets/bento_shimmer.dart — widget UI
[OK] lib/core/widgets/status_badge.dart — widget UI
[OK] lib/core/widgets/app_sidebar.dart — sidebar UI
[OK] lib/core/widgets/bookable_area_shared.dart — widget compartilhado
[OK] lib/core/data/custos_models.dart — modelos de dados
[OK] lib/core/data/custos_repository.dart — interface
[OK] lib/core/data/lazer_data.dart — modelos
[OK] lib/core/data/obras_data.dart — modelos
[OK] lib/core/data/locacao_models.dart — modelos
[OK] lib/core/data/sala_atr_data.dart — modelos
[OK] lib/core/data/combustivel_models.dart — modelos
[OK] lib/core/data/combustivel_repository.dart — repository
[OK] lib/core/data/regras_manutencao_models.dart — modelos
[OK] lib/core/data/regras_manutencao_repository.dart — repository
[OK] lib/core/data/score_motorista_models.dart — modelos
[OK] lib/core/providers/combustivel_provider.dart — provider
[OK] lib/core/providers/regras_manutencao_provider.dart — provider
[OK] lib/core/providers/score_motorista_provider.dart — provider
[OK] lib/core/services/relatorio_service.dart — serviço de relatórios
[OK] lib/features/*/ — todas as screens analisadas, sem issues de segurança adicionais
[OK] supabase/migrations/002, 005-011 — migrations de schema, sem issues de segurança
[OK] .github/workflows/ci.yml — CI pipeline básico funcional
[OK] analysis_options.yaml — configurado com flutter_lints
