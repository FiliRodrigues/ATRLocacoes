# ATR Locações

Plataforma Flutter para gestão de frota com foco em operação, manutenção,
financeiro e compliance de veículos.

## Stack

- Flutter (Material 3)
- Provider (estado)
- GoRouter (navegação)
- SharedPreferences (sessão)
- intl (formatação)

## Arquitetura

Estrutura principal por domínio, com componentes compartilhados em core:

- `lib/core/`
	- `data/`: modelos e mocks de dados
	- `enums/`: enums de domínio (status, alertas, prioridades)
	- `navigation/`: roteamento central da aplicação
	- `services/`: serviços de infraestrutura (ex.: autenticação)
	- `theme/`: tema global e estado de tema
	- `widgets/`: componentes reutilizáveis
- `lib/features/`
	- módulos funcionais (dashboard, veículos, manutenção, despesas, etc.)

Fluxo de bootstrap:

1. `main.dart` inicializa locale e providers.
2. `AuthService` carrega sessão persistida.
3. `AppRouter` aplica guard de autenticação e resolve rotas.
4. `AppSidebar` funciona como shell visual das telas principais.

## Requisitos

- Flutter SDK compatível com `>=3.3.0 <4.0.0`
- Windows, Chrome ou Edge para execução local

## Como rodar

No diretório do projeto:

```bash
flutter pub get
flutter run -d windows
```

Com Supabase explicitamente configurado no run:

```bash
flutter run -d windows --dart-define=SUPABASE_URL=https://SEU-PROJETO.supabase.co --dart-define=SUPABASE_ANON_KEY=sb_publishable_xxx
```

Opções web:

```bash
flutter run -d chrome --web-port 5000
flutter run -d edge --web-port 5000
```

Desktop Local (recomendado neste projeto):

1. Ajuste credenciais e Supabase em `run_atr.local.bat`.
2. Abra o app nativo com:

```powershell
powershell -ExecutionPolicy Bypass -File .\run_atr_windows.ps1
```

3. Para abrir sem terminal (atalho desktop), execute uma vez:

```powershell
powershell -ExecutionPolicy Bypass -File .\create_desktop_shortcut.ps1
```

Isso cria os atalhos `ATR Local` (web) e `ATR Desktop` (Windows nativo).

## Autenticação (configuração)

O login usa credenciais fornecidas por variáveis de build (`--dart-define`).

Desktop:

```bash
flutter run -d windows --dart-define=ATR_LOGIN_USER=seu_usuario --dart-define=ATR_LOGIN_PASS=sua_senha_forte
```

Web:

```bash
flutter run -d chrome --web-port 5000 --dart-define=ATR_LOGIN_USER=seu_usuario --dart-define=ATR_LOGIN_PASS=sua_senha_forte
```

Sem essas variáveis, o login é bloqueado por segurança.
O launcher Desktop (`run_atr_windows.ps1`) também consome `SUPABASE_URL` e
`SUPABASE_ANON_KEY` do `run_atr.local.bat`.

## Qualidade

Análise estática:

```bash
flutter analyze
```

Testes:

```bash
flutter test
```

## Testes adicionados na Fase 2

- Unit: regras de financiamento
- Unit: métricas e sugestão de venda de veículos
- Unit: movimentação de cards no provider de manutenção
- Widget: renderização e interação do `BentoCard`
- Widget: renderização base do `StatusBadge`

## Observações

- O projeto utiliza dados mockados em `core/data` para desenvolvimento local.
- Tema é centralizado em um único estado global para evitar divergência entre telas.
