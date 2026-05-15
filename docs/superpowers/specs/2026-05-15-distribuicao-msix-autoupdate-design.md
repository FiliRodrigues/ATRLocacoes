# ATR Locações — Distribuição Windows: MSIX + GitHub Releases + Auto-update

**Data:** 2026-05-15  
**Status:** Aprovado

---

## Contexto

O app ATR Locações (Flutter/Windows) precisa ser distribuído para 5–20 máquinas internas da empresa. Atualmente não existe nenhum sistema de empacotamento, instalador ou distribuição. O objetivo é criar um fluxo completo que permita:

1. Qualquer usuário instalar o app clicando em um link
2. O app se atualizar automaticamente quando uma nova versão for publicada
3. O desenvolvedor publicar novas versões com um único comando git (`git tag`)

---

## Arquitetura Geral

```
Dev faz git tag v1.x.x
        ↓
GitHub Actions (release.yml)
  → flutter build windows --release
  → gera ATR-Setup.msix
  → atualiza releases/version.json
  → publica GitHub Release
        ↓
Usuário instala via link único:
  https://github.com/REPO/releases/latest/download/ATR-Setup.msix
        ↓
App abre → UpdateService verifica version.json
  → se versão nova: dialog "Atualizar agora?"
  → baixa .msix → abre instalador → app fecha
```

---

## Componentes

### 1. Pacote `msix` no pubspec.yaml

Adicionar dependência de dev:
```yaml
dev_dependencies:
  msix: ^3.16.7
```

Configuração em `pubspec.yaml` (seção `msix_config`):
```yaml
msix_config:
  display_name: ATR Locações
  publisher_display_name: ATR
  identity_name: com.atr.locacoes
  msix_version: 1.0.0.0        # sincronizado com version no pubspec
  logo_path: assets/images/logo.png
  capabilities: internetClient
  certificate_path:             # vazio = sem assinatura (modo dev/interno)
```

Para distribuição interna sem certificado pago, os usuários precisam ter o **Developer Mode** ativo no Windows, OU usar um certificado autoassinado (gerado uma vez, instalado nas máquinas).

---

### 2. Arquivo `releases/version.json`

Arquivo estático no repositório, atualizado automaticamente pelo CI a cada release:

```json
{
  "version": "1.0.1",
  "url": "https://github.com/REPO/releases/download/v1.0.1/ATR-Setup.msix",
  "notes": "Descrição das mudanças",
  "published_at": "2026-05-15"
}
```

URL raw do arquivo (usada pelo app para verificar versão):
`https://raw.githubusercontent.com/REPO/main/releases/version.json`

---

### 3. GitHub Actions — `.github/workflows/release.yml`

Trigger: push de tag `v*.*.*`

Passos:
1. `actions/checkout`
2. `subosito/flutter-action` (stable)
3. `flutter pub get`
4. `flutter build windows --release --dart-define=SUPABASE_URL=${{ secrets.SUPABASE_URL }} --dart-define=SUPABASE_ANON_KEY=${{ secrets.SUPABASE_ANON_KEY }}`
5. `flutter pub run msix:create`
6. Atualiza `releases/version.json` com a nova versão e URL
7. Commit + push do `version.json` atualizado
8. Cria GitHub Release com o `.msix` como asset

Secrets necessários no repositório GitHub:
- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`

---

### 4. `UpdateService` no Flutter

**Arquivo:** `lib/core/services/update_service.dart`

Responsabilidades:
- Buscar `version.json` via HTTP na inicialização
- Comparar versão remota com versão local (via `package_info_plus`)
- Mostrar `UpdateDialog` se houver versão nova
- Baixar `.msix` para `%TEMP%` via `http` package
- Abrir o instalador com `Process.run('msiexec', ['/i', caminhoMsix])`
- Fechar o app após iniciar o instalador

**Integração:** Chamado em `AppShell` (widget raiz pós-login), após a tela carregar, com delay de 3s para não bloquear a UX.

**Dependências a adicionar:**
```yaml
dependencies:
  package_info_plus: ^8.0.0   # lê versão do app
  # http já é dependência do supabase_flutter
```

---

### 5. `UpdateDialog` — Widget de notificação

Dialog simples com:
- Título: "Nova versão disponível — vX.X.X"
- Corpo: notas da versão (do `version.json`)
- Botões: "Atualizar agora" | "Depois"
- Progress indicator durante o download

---

## Fluxo de Primeiro Download

Link enviado para usuários:
```
https://github.com/REPO/releases/latest/download/ATR-Setup.msix
```

Este link sempre aponta para a versão mais recente. Quem instalar hoje terá a versão atual; o auto-update cuida das próximas versões.

---

## Tratamento de Erros

| Cenário | Comportamento |
|---------|---------------|
| Sem internet na inicialização | Skip silencioso da verificação de update |
| Download falha | Toast "Falha ao baixar atualização" — app continua normalmente |
| `version.json` malformado | Log de erro + skip silencioso |
| Usuário clica "Depois" | Não verifica novamente na mesma sessão |

---

## Fluxo de Release para o Dev

```bash
# 1. Incrementar versão no pubspec.yaml (version: 1.0.1+2)
# 2. Criar e empurrar a tag
git tag v1.0.1
git push origin v1.0.1

# GitHub Actions cuida do resto automaticamente
```

---

## Certificado para MSIX (decisão pendente de implementação)

Duas opções:
- **Opção A — Developer Mode:** Usuário ativa Developer Mode no Windows nas configurações. Sem custo, mas requer ação manual em cada máquina uma vez.
- **Opção B — Certificado autoassinado:** Gerar certificado `.pfx`, instalar nas máquinas via GPO ou script, assinar o MSIX. Mais profissional, transparente para o usuário.

Recomendação: começar com Opção A (mais rápido), migrar para Opção B quando houver mais máquinas.

---

## Arquivos Criados/Modificados

| Arquivo | Ação |
|---------|------|
| `pubspec.yaml` | Adicionar `msix`, `package_info_plus`, `msix_config` |
| `.github/workflows/release.yml` | Criar — workflow de release |
| `releases/version.json` | Criar — controlado pelo CI |
| `lib/core/services/update_service.dart` | Criar |
| `lib/core/widgets/update_dialog.dart` | Criar |
| `lib/app_shell.dart` | Modificar — chamar UpdateService na inicialização |

---

## Verificação

1. Fazer `flutter build windows --release` localmente — confirmar que gera executável sem erros
2. Rodar `flutter pub run msix:create` — confirmar geração do `.msix`
3. Instalar o `.msix` em uma máquina de teste
4. Subir um `version.json` com versão superior à instalada
5. Abrir o app — confirmar que o dialog de atualização aparece
6. Aceitar a atualização — confirmar que o instalador abre
7. Criar tag `v*` no GitHub — confirmar que o Actions roda e o Release aparece
