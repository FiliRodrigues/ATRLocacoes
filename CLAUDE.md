# ATR Locações — Guia para IAs

**LEIA ESTE ARQUIVO ANTES DE QUALQUER COISA.**
Este documento é a fonte de verdade para o projeto. Qualquer IA que trabalhar neste repositório deve seguir estas regras sem exceção.

---

## Regras Gerais

- Responda sempre em **português**
- Respostas curtas e diretas
- Não crie comentários em código a menos que o "porquê" seja não-óbvio
- Não adicione features além do que foi pedido
- Não altere arquivos fora do escopo da tarefa

---

## Stack Técnica

| Camada | Tecnologia |
|--------|-----------|
| Frontend | Flutter (Dart) — app Windows + Web |
| Backend | Supabase (PostgreSQL + Edge Functions) |
| Auth | Supabase Auth com JWT + `app_metadata.tenant_id` |
| Estado | Provider (`ChangeNotifier`) |
| Ícones | `lucide_icons` |
| Fontes | Google Fonts: `Syne` (títulos), `Plus Jakarta Sans` (corpo) |
| IA assistente | DeepSeek v4 Pro via Edge Function `ai-agent` — NÃO mudar para Claude/Anthropic |

---

## Supabase

- **Project ID:** `ybajzitijjtzhavgrarz`
- **URL:** `https://ybajzitijjtzhavgrarz.supabase.co`
- **Anon Key (pública):** `sb_publishable_SAX5OUy6ECnlYp_x0IuV-A_Veo9AvJA`
- **Multi-tenant:** todas as tabelas têm `tenant_id UUID NOT NULL`
- **RLS:** ativo em todas as tabelas; função `auth_tenant_id()` lê do JWT

---

## Schema Completo do Banco (fonte de verdade — verificado em 2026-05-11)

> **IMPORTANTE para qualquer IA:** NÃO invente nomes de colunas. Use EXATAMENTE os nomes abaixo.
> Se precisar de uma coluna que não existe, pergunte antes de criar uma migration.

### `abastecimentos`
| Coluna | Tipo | Nullable | Default |
|--------|------|----------|---------|
| id | text | NO | — |
| veiculo_placa | text | NO | — |
| data | timestamptz | NO | — |
| litros | numeric | NO | — |
| valor_total | numeric | NO | — |
| km_odometro | numeric | NO | — |
| tipo | tipo_combustivel (enum) | NO | 'gasolina' |
| posto | text | YES | — |
| registrado_por | text | NO | 'sistema' |
| tenant_id | uuid | NO | — |
| created_at | timestamptz | NO | now() |
| updated_at | timestamptz | NO | now() |

### `ai_action_audit`
| Coluna | Tipo | Nullable |
|--------|------|----------|
| id | uuid | NO |
| tenant_id | uuid | NO |
| user_id | uuid | NO |
| conversation_id | uuid | YES |
| tool_name | text | NO |
| input | jsonb | NO |
| output | jsonb | YES |
| status | text | NO |
| error | text | YES |
| created_at | timestamptz | NO |
| executed_at | timestamptz | YES |

### `ai_conversations`
| Coluna | Tipo | Nullable |
|--------|------|----------|
| id | uuid | NO |
| tenant_id | uuid | NO |
| user_id | uuid | NO |
| channel | text | NO |
| title | text | YES |
| created_at | timestamptz | NO |
| updated_at | timestamptz | NO |

### `ai_messages`
| Coluna | Tipo | Nullable |
|--------|------|----------|
| id | uuid | NO |
| conversation_id | uuid | NO |
| role | text | NO |
| content | jsonb | NO |
| tool_calls | jsonb | YES |
| created_at | timestamptz | NO |

### `ai_rate_limits`
| Coluna | Tipo | Default |
|--------|------|---------|
| id | uuid | gen_random_uuid() |
| phone | text | — |
| minute_count | integer | 0 |
| hour_count | integer | 0 |
| day_count | integer | 0 |
| minute_window_start | timestamptz | now() |
| hour_window_start | timestamptz | now() |
| day_window_start | timestamptz | now() |

### `app_users`
| Coluna | Tipo | Nullable | Default |
|--------|------|----------|---------|
| id | uuid | YES | — |
| username | text | NO | — |
| password_hash | text | NO | — |
| password_salt | text | NO | — |
| role | text | NO | 'admin' |
| nome_completo | text | NO | '' |
| ativo | boolean | NO | true |
| must_change_password | boolean | NO | false |
| allowed_features | text[] | NO | '{}' |
| whatsapp_phone | text | YES | — |
| whatsapp_verified | boolean | NO | false |
| ai_enabled | boolean | NO | true |
| last_login | timestamptz | YES | — |
| created_at | timestamptz | NO | now() |
| tenant_id | uuid | NO | (tenant padrão) |

### `audit_log`
| Coluna | Tipo | Nullable | Default |
|--------|------|----------|---------|
| id | uuid | NO | gen_random_uuid() |
| username | text | NO | 'desconhecido' |
| effective_user | text | NO | 'desconhecido' |
| action | text | NO | — |
| entity | text | NO | — |
| entity_id | text | YES | — |
| payload | jsonb | YES | — |
| before_state | jsonb | YES | — |
| after_state | jsonb | YES | — |
| origin | text | NO | 'web' |
| created_at | timestamptz | NO | now() |
| tenant_id | uuid | YES | — |

### `checklist_eventos`
| Coluna | Tipo | Nullable | Default |
|--------|------|----------|---------|
| id | uuid | NO | gen_random_uuid() |
| contrato_id | uuid | NO | — |
| tipo | enum (checklist_tipo) | NO | — |
| km_odometro | integer | NO | 0 |
| km_percorridos | integer | YES | — |
| combustivel_pct | integer | NO | 100 |
| observacoes | text | NO | '' |
| fotos | text[] | NO | '{}' |
| doc_url | text | YES | — |
| assinatura_url | text | YES | — |
| realizado_por | text | NO | '' |
| created_at | timestamptz | NO | now() |
| tenant_id | uuid | NO | (tenant padrão) |

### `contratos`
| Coluna | Tipo | Nullable | Default |
|--------|------|----------|---------|
| id | uuid | NO | gen_random_uuid() |
| numero | text | NO | — |
| cliente_nome | text | NO | — |
| cliente_cnpj | text | NO | — |
| cliente_contato | text | NO | '' |
| veiculo_placa | text | NO | — |
| data_inicio | date | NO | — |
| data_fim | date | NO | — |
| sla_km_mes | integer | NO | 0 |
| valor_mensal | numeric | NO | 0 |
| status | contrato_status (enum) | NO | 'rascunho' |
| observacoes | text | NO | '' |
| criado_por | text | NO | '' |
| created_at | timestamptz | NO | now() |
| updated_at | timestamptz | NO | now() |
| tenant_id | uuid | NO | (tenant padrão) |

### `despesas`
| Coluna | Tipo | Nullable | Default |
|--------|------|----------|---------|
| id | text | NO | — |
| veiculo_placa | text | NO | — |
| motorista | text | NO | '' |
| data | timestamptz | NO | — |
| tipo | text | NO | — |
| descricao | text | NO | '' |
| odometro | integer | NO | 0 |
| litros | numeric | NO | 0 |
| valor | numeric | NO | 0 |
| pago | boolean | NO | false |
| nf | text | NO | '' |
| nome_anexo | text | NO | '' |
| created_at | timestamptz | NO | now() |
| updated_at | timestamptz | NO | now() |
| tenant_id | uuid | NO | (tenant padrão) |

### `financiamentos`
| Coluna | Tipo | Nullable | Default |
|--------|------|----------|---------|
| id | uuid | NO | gen_random_uuid() |
| veiculo_id | uuid | NO | — |
| situacao | text | YES | — |
| banco_financeira | text | YES | — |
| valor_total_veiculo | numeric | YES | — |
| valor_entrada | numeric | YES | — |
| valor_financiado | numeric | YES | — |
| valor_total_com_juros | numeric | YES | — |
| valor_ja_pago | numeric | YES | — |
| quantidade_parcelas | integer | YES | — |
| valor_parcela | numeric | YES | — |
| taxa_juros_mensal | numeric | NO | 0.0139 |
| recebimento_mensal | numeric | NO | 0 |
| previsao_quitacao | text | YES | — |
| created_at | timestamptz | YES | now() |
| updated_at | timestamptz | YES | now() |
| tenant_id | uuid | YES | — |

### `hodometros`
| Coluna | Tipo | Nullable | Default |
|--------|------|----------|---------|
| id | uuid | NO | gen_random_uuid() |
| veiculo_placa | text | NO | — |
| km | integer | NO | — |
| registrado_por | text | NO | '' |
| created_at | timestamptz | NO | now() |
| tenant_id | uuid | NO | (tenant padrão) |

### `ipva`
| Coluna | Tipo | Nullable | Default |
|--------|------|----------|---------|
| id | uuid | NO | gen_random_uuid() |
| veiculo_id | uuid | NO | — |
| ano_referencia | integer | NO | — |
| valor_total | numeric | YES | — |
| data_vencimento | date | YES | — |
| data_pagamento | date | YES | — |
| status_pagamento | text | YES | 'Pendente' |
| observacoes | text | YES | — |
| created_at | timestamptz | YES | now() |
| tenant_id | uuid | NO | (tenant padrão) |

### `licenciamento`
| Coluna | Tipo | Nullable | Default |
|--------|------|----------|---------|
| id | uuid | NO | gen_random_uuid() |
| veiculo_id | uuid | NO | — |
| ano_referencia | integer | NO | — |
| mes_vencimento | text | YES | — |
| valor_total | numeric | YES | — |
| data_vencimento | date | YES | — |
| data_pagamento | date | YES | — |
| status_pagamento | text | YES | 'Pendente' |
| observacoes | text | YES | — |
| created_at | timestamptz | YES | now() |
| tenant_id | uuid | NO | (tenant padrão) |

### `manutencoes` ⚠️ ATENÇÃO — tabela com histórico de renomeações
| Coluna | Tipo | Nullable | Default |
|--------|------|----------|---------|
| id | **text** | NO | — |
| veiculo_id | uuid | NO | — |
| veiculo_placa | text | NO | '' |
| veiculo_nome | text | NO | '' |
| titulo | text | NO | '' |
| descricao | text | YES | — |
| tipo | text | YES | — |
| data | date | YES | — |
| fornecedor | text | YES | — |
| custo | numeric | YES | — |
| km_no_servico | numeric | YES | — |
| odometro | integer | NO | 0 |
| prioridade | text | NO | 'media' |
| coluna | text | NO | 'pendentes' |
| numero_os | text | NO | '' |
| nome_anexo | text | NO | '' |
| is_preventiva | boolean | NO | true |
| data_conclusao | timestamptz | YES | — |
| status_pagamento | text | YES | 'Pago' |
| observacoes | text | YES | — |
| created_at | timestamptz | YES | now() |
| tenant_id | uuid | NO | (tenant padrão) |

**Valores válidos para `coluna`:** `'pendentes'` · `'emOficina'` · `'concluidos'`
**Valores válidos para `prioridade`:** `'alta'` · `'media'` · `'baixa'` · `'ok'`

### `multas`
| Coluna | Tipo | Nullable | Default |
|--------|------|----------|---------|
| id | uuid | NO | gen_random_uuid() |
| veiculo_id | uuid | NO | — |
| ano_referencia | integer | NO | — |
| mes | text | NO | — |
| valor | numeric | YES | 0 |
| descricao | text | YES | — |
| status_pagamento | text | YES | 'Pendente' |
| data_infracao | date | YES | — |
| data_vencimento | date | YES | — |
| data_pagamento | date | YES | — |
| created_at | timestamptz | YES | now() |
| tenant_id | uuid | NO | (tenant padrão) |

### `ocorrencias`
| Coluna | Tipo | Nullable | Default |
|--------|------|----------|---------|
| id | uuid | NO | gen_random_uuid() |
| contrato_id | uuid | NO | — |
| tipo | ocorrencia_tipo (enum) | NO | — |
| status | ocorrencia_status (enum) | NO | 'aberta' |
| descricao | text | NO | — |
| data_ocorrencia | date | NO | CURRENT_DATE |
| valor_estimado | numeric | NO | 0 |
| valor_final | numeric | YES | — |
| impacto_financeiro | numeric | NO | 0 |
| responsavel_pagamento | text | NO | 'cliente' |
| fotos | text[] | NO | '{}' |
| observacoes | text | NO | '' |
| registrado_por | text | NO | '' |
| resolvido_por | text | YES | — |
| data_resolucao | date | YES | — |
| created_at | timestamptz | NO | now() |
| updated_at | timestamptz | NO | now() |
| tenant_id | uuid | NO | (tenant padrão) |

### `parcelas_financiamento`
| Coluna | Tipo | Nullable |
|--------|------|----------|
| id | uuid | NO |
| financiamento_id | uuid | NO |
| numero_parcela | integer | YES |
| valor_parcela | numeric | YES |
| data_vencimento | date | YES |
| data_pagamento | date | YES |
| status_pagamento | text | YES |
| observacoes | text | YES |
| created_at | timestamptz | YES |
| tenant_id | uuid | YES |

### `parcelas_seguro`
| Coluna | Tipo | Nullable |
|--------|------|----------|
| id | uuid | NO |
| seguro_id | uuid | NO |
| numero_parcela | integer | YES |
| valor_parcela | numeric | YES |
| data_vencimento | date | YES |
| data_pagamento | date | YES |
| status_pagamento | text | YES |
| created_at | timestamptz | YES |
| tenant_id | uuid | NO |

### `recebimentos`
| Coluna | Tipo | Nullable | Default |
|--------|------|----------|---------|
| id | uuid | NO | gen_random_uuid() |
| veiculo_id | uuid | NO | — |
| locatario | text | YES | — |
| numero_parcela | integer | YES | — |
| valor_previsto | numeric | YES | — |
| valor_recebido | numeric | YES | — |
| data_vencimento | date | YES | — |
| data_recebimento | date | YES | — |
| status_pagamento | text | YES | 'Pendente' |
| observacoes | text | YES | — |
| created_at | timestamptz | YES | now() |
| tenant_id | uuid | NO | (tenant padrão) |

### `regras_manutencao`
| Coluna | Tipo | Nullable | Default |
|--------|------|----------|---------|
| id | **text** | NO | — |
| titulo | text | NO | — |
| tipo | text | NO | — |
| veiculo_placa | text | YES | — |
| intervalo_km | integer | YES | — |
| intervalo_dias | integer | YES | — |
| custo_estimado | numeric | NO | 0 |
| prioridade | text | NO | 'media' |
| is_ativa | boolean | NO | true |
| km_ultima_execucao | integer | YES | — |
| data_ultima_execucao | timestamptz | YES | — |
| created_at | timestamptz | NO | now() |
| updated_at | timestamptz | NO | now() |
| tenant_id | uuid | YES | — |

### `seguros`
| Coluna | Tipo | Nullable |
|--------|------|----------|
| id | uuid | NO |
| veiculo_id | uuid | NO |
| ano_referencia | integer | NO |
| empresa | text | YES |
| numero_apolice | text | YES |
| valor_apolice | numeric | YES |
| num_parcelas | integer | YES |
| data_inicio | date | YES |
| data_renovacao | date | YES |
| valor_total_pago | numeric | YES |
| status_pagamento | text | YES |
| observacoes | text | YES |
| created_at | timestamptz | YES |
| updated_at | timestamptz | YES |
| tenant_id | uuid | YES |

### `tenants`
| Coluna | Tipo | Nullable |
|--------|------|----------|
| id | uuid | NO |
| nome | text | NO |
| cnpj | text | NO |
| ativo | boolean | NO |
| created_at | timestamptz | NO |

### `veiculos`
| Coluna | Tipo | Nullable |
|--------|------|----------|
| id | uuid | NO |
| placa | text | NO |
| tipo | text | YES |
| marca | text | YES |
| modelo | text | YES |
| ano_fabricacao_modelo | text | YES |
| renavam | text | YES |
| chassi | text | YES |
| km_inicial | numeric | YES |
| km_atual | integer | YES |
| situacao_operacional | text | YES |
| propriedade_status | text | YES |
| valor_veiculo | numeric | YES |
| numero_nota_fiscal | text | YES |
| data_nota_fiscal | date | YES |
| numero_contrato | text | YES |
| data_compra | date | YES |
| observacoes | text | YES |
| status_alterado_por | text | YES |
| status_atualizado_em | timestamptz | YES |
| created_at | timestamptz | YES |
| updated_at | timestamptz | YES |
| tenant_id | uuid | NO |

---

## Regras para Migrations

1. **NUNCA** invente nomes de colunas — consulte este documento ou use `mcp__supabase__execute_sql` para verificar
2. Toda migration recebe número sequencial: `026_`, `027_`, etc.
3. Use `ALTER TABLE ... ADD COLUMN IF NOT EXISTS` para segurança
4. Migrations de renomeação: use `RENAME COLUMN` — não recriar a coluna
5. Sempre testar com `SELECT` após aplicar para confirmar

## Regras para Edge Functions (Supabase)

- Funções ficam em `supabase/functions/ai-agent/`
- O agente IA usa **DeepSeek v4 Pro** — não mudar para outro modelo
- INSERT em `manutencoes` via Edge Function deve usar as colunas exatas acima
- Autenticação: validar JWT via `supabase.auth.getUser()` — não confiar no body

## Cores do Design System

```dart
AppColors.backgroundDark   = #0B0F19   // fundo geral
AppColors.surfaceDark       = #131825   // cards, modais
AppColors.surfaceElevatedDark = #1A2035 // elementos elevados
AppColors.atrNavyBlue       = #1A2332   // sidebar
AppColors.atrOrange         = #FF8C42   // ação primária
AppColors.statusSuccess     = #34D399   // verde (concluído, custo positivo)
AppColors.statusWarning     = #FBBF24   // amarelo (corretiva, atenção)
AppColors.statusError       = #F87171   // vermelho (urgente, erro)
AppColors.statusInfo        = #60A5FA   // azul (preventiva, info)
AppColors.textPrimaryDark   = #F1F5F9
AppColors.textSecondaryDark = #8B9CC0
AppColors.textMutedDark     = #64748B
```
