-- ============================================================================
-- Migration 014 - Consolidação RLS + Infra de tenant via app_tenant_id()
-- ============================================================================
-- Objetivo:
--   1. Garantir RLS ativa em TODAS as tabelas operacionais
--   2. Remover políticas remanescentes USING(true) da migration 001
--   3. Padronizar todas as políticas com o mesmo padrão de isolamento
--   4. Criar helper app_tenant_id() como alternativa ao jwt_tenant_id()
--      que também escuta a variável de sessão app.tenant_id (definida via
--      set_config no lado da aplicação).
--
-- Segurança: esta migration NÃO bloqueia o app atual (anon key).
--            O padrão "X IS NULL OR tenant_id = X" mantém acesso permissivo
--            quando o contexto de tenant não está disponível, e enforça
--            isolamento quando está (ex: JWT com claim tenant_id).
-- ============================================================================

-- ──────────────────────────────────────────────────────────────────────────
-- 1. Helper: app_tenant_id()
--    Tenta obter o tenant de 3 fontes, em ordem de prioridade:
--      a) Variável de sessão app.tenant_id (definida via RPC set_app_tenant)
--      b) JWT claim tenant_id (requer integração Supabase Auth)
--      c) NULL — fallback permissivo para compatibilidade com anon key
-- ──────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.app_tenant_id()
RETURNS UUID LANGUAGE sql STABLE SECURITY DEFINER AS $$
  SELECT COALESCE(
    NULLIF(current_setting('app.tenant_id', true), '')::uuid,
    public.jwt_tenant_id()
  )
$$;

-- ──────────────────────────────────────────────────────────────────────────
-- 2. RPC: set_app_tenant(p_tenant_id)
--    Chamado pelo app Flutter para definir o tenant da sessão atual.
--    Nota: com PgBouncer em transaction mode, esta variável não persiste
--          entre transações. A efetividade depende do modo de pooling.
--          Quando a app migrar para Supabase Auth + JWT claims, o
--          jwt_tenant_id() cobre o caso cross-transação automaticamente.
-- ──────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.set_app_tenant(p_tenant_id UUID)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  PERFORM set_config('app.tenant_id', p_tenant_id::text, false);
END
$$;

GRANT EXECUTE ON FUNCTION public.set_app_tenant TO anon;

-- ──────────────────────────────────────────────────────────────────────────
-- 3. Garantir RLS ativa em TODAS as tabelas operacionais
-- ──────────────────────────────────────────────────────────────────────────
ALTER TABLE IF EXISTS public.manutencoes       ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.despesas          ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.hodometros        ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.audit_log         ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.veiculos          ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.contratos         ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.checklist_eventos ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.ocorrencias       ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.financiamentos    ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.abastecimentos    ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.regras_manutencao ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.app_users         ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.tenants           ENABLE ROW LEVEL SECURITY;

-- ──────────────────────────────────────────────────────────────────────────
-- 4. POLÍTICAS PADRÃO: isolamento por tenant
--    Padrão: app_tenant_id() IS NULL OR tenant_id = app_tenant_id()
--    - Sem contexto de tenant (anon key) → permissivo (compatibilidade)
--    - Com contexto (JWT ou set_app_tenant) → isolamento estrito
-- ──────────────────────────────────────────────────────────────────────────

-- 4.1 veiculos
DROP POLICY IF EXISTS "veiculos_select"      ON public.veiculos;
DROP POLICY IF EXISTS "veiculos_update"      ON public.veiculos;
DROP POLICY IF EXISTS "veiculos_tenant"      ON public.veiculos;
DROP POLICY IF EXISTS "tenant_isolation"     ON public.veiculos;
CREATE POLICY "veiculos_tenant" ON public.veiculos FOR ALL
  USING  (app_tenant_id() IS NULL OR tenant_id = app_tenant_id())
  WITH CHECK (app_tenant_id() IS NULL OR tenant_id = app_tenant_id());

-- 4.2 manutencoes
DROP POLICY IF EXISTS "manutencoes_select"   ON public.manutencoes;
DROP POLICY IF EXISTS "manutencoes_insert"   ON public.manutencoes;
DROP POLICY IF EXISTS "manutencoes_update"   ON public.manutencoes;
DROP POLICY IF EXISTS "manutencoes_delete"   ON public.manutencoes;
DROP POLICY IF EXISTS "manutencoes_tenant"   ON public.manutencoes;
DROP POLICY IF EXISTS "tenant_isolation"     ON public.manutencoes;
DROP POLICY IF EXISTS "RLS: Isolamento Manutencoes" ON public.manutencoes;
CREATE POLICY "manutencoes_tenant" ON public.manutencoes FOR ALL
  USING  (app_tenant_id() IS NULL OR tenant_id = app_tenant_id())
  WITH CHECK (app_tenant_id() IS NULL OR tenant_id = app_tenant_id());

-- 4.3 despesas
DROP POLICY IF EXISTS "despesas_select"      ON public.despesas;
DROP POLICY IF EXISTS "despesas_insert"      ON public.despesas;
DROP POLICY IF EXISTS "despesas_update"      ON public.despesas;
DROP POLICY IF EXISTS "despesas_delete"      ON public.despesas;
DROP POLICY IF EXISTS "despesas_tenant"      ON public.despesas;
DROP POLICY IF EXISTS "tenant_isolation"     ON public.despesas;
DROP POLICY IF EXISTS "RLS: Isolamento Despesas" ON public.despesas;
CREATE POLICY "despesas_tenant" ON public.despesas FOR ALL
  USING  (app_tenant_id() IS NULL OR tenant_id = app_tenant_id())
  WITH CHECK (app_tenant_id() IS NULL OR tenant_id = app_tenant_id());

-- 4.4 hodometros
DROP POLICY IF EXISTS "hodometros_select"    ON public.hodometros;
DROP POLICY IF EXISTS "hodometros_insert"    ON public.hodometros;
DROP POLICY IF EXISTS "hodometros_tenant"    ON public.hodometros;
DROP POLICY IF EXISTS "tenant_isolation"     ON public.hodometros;
CREATE POLICY "hodometros_tenant" ON public.hodometros FOR ALL
  USING  (app_tenant_id() IS NULL OR tenant_id = app_tenant_id())
  WITH CHECK (app_tenant_id() IS NULL OR tenant_id = app_tenant_id());

-- 4.5 contratos
DROP POLICY IF EXISTS "contratos_select"     ON public.contratos;
DROP POLICY IF EXISTS "contratos_insert"     ON public.contratos;
DROP POLICY IF EXISTS "contratos_update"     ON public.contratos;
DROP POLICY IF EXISTS "contratos_delete"     ON public.contratos;
DROP POLICY IF EXISTS "contratos_tenant"     ON public.contratos;
DROP POLICY IF EXISTS "tenant_isolation"     ON public.contratos;
CREATE POLICY "contratos_tenant" ON public.contratos FOR ALL
  USING  (app_tenant_id() IS NULL OR tenant_id = app_tenant_id())
  WITH CHECK (app_tenant_id() IS NULL OR tenant_id = app_tenant_id());

-- 4.6 checklist_eventos
DROP POLICY IF EXISTS "checklist_select"     ON public.checklist_eventos;
DROP POLICY IF EXISTS "checklist_insert"     ON public.checklist_eventos;
DROP POLICY IF EXISTS "checklist_tenant"     ON public.checklist_eventos;
DROP POLICY IF EXISTS "tenant_isolation"     ON public.checklist_eventos;
CREATE POLICY "checklist_tenant" ON public.checklist_eventos FOR ALL
  USING  (app_tenant_id() IS NULL OR tenant_id = app_tenant_id())
  WITH CHECK (app_tenant_id() IS NULL OR tenant_id = app_tenant_id());

-- 4.7 ocorrencias
DROP POLICY IF EXISTS "ocorrencias_select"   ON public.ocorrencias;
DROP POLICY IF EXISTS "ocorrencias_insert"   ON public.ocorrencias;
DROP POLICY IF EXISTS "ocorrencias_update"   ON public.ocorrencias;
DROP POLICY IF EXISTS "ocorrencias_tenant"   ON public.ocorrencias;
DROP POLICY IF EXISTS "tenant_isolation"     ON public.ocorrencias;
CREATE POLICY "ocorrencias_tenant" ON public.ocorrencias FOR ALL
  USING  (app_tenant_id() IS NULL OR tenant_id = app_tenant_id())
  WITH CHECK (app_tenant_id() IS NULL OR tenant_id = app_tenant_id());

-- 4.8 financiamentos
DROP POLICY IF EXISTS "financiamentos_tenant" ON public.financiamentos;
DROP POLICY IF EXISTS "tenant_isolation"      ON public.financiamentos;
CREATE POLICY "financiamentos_tenant" ON public.financiamentos FOR ALL
  USING  (app_tenant_id() IS NULL OR tenant_id = app_tenant_id())
  WITH CHECK (app_tenant_id() IS NULL OR tenant_id = app_tenant_id());

-- 4.9 abastecimentos
DROP POLICY IF EXISTS "abastecimentos_tenant_isolation" ON public.abastecimentos;
DROP POLICY IF EXISTS "abastecimentos_tenant"           ON public.abastecimentos;
DROP POLICY IF EXISTS "tenant_isolation"                ON public.abastecimentos;
DROP POLICY IF EXISTS "RLS: Isolamento Abastecimentos"  ON public.abastecimentos;
CREATE POLICY "abastecimentos_tenant" ON public.abastecimentos FOR ALL
  USING  (app_tenant_id() IS NULL OR tenant_id = app_tenant_id())
  WITH CHECK (app_tenant_id() IS NULL OR tenant_id = app_tenant_id());

-- 4.10 regras_manutencao
DROP POLICY IF EXISTS "regras_manutencao_tenant" ON public.regras_manutencao;
DROP POLICY IF EXISTS "tenant_isolation"         ON public.regras_manutencao;
CREATE POLICY "regras_manutencao_tenant" ON public.regras_manutencao FOR ALL
  USING  (app_tenant_id() IS NULL OR tenant_id = app_tenant_id())
  WITH CHECK (app_tenant_id() IS NULL OR tenant_id = app_tenant_id());

-- 4.11 app_users (somente SELECT, sem escrita anônima nesta tabela)
DROP POLICY IF EXISTS "app_users_select" ON public.app_users;
DROP POLICY IF EXISTS "app_users_tenant" ON public.app_users;
CREATE POLICY "app_users_tenant" ON public.app_users FOR SELECT
  USING (app_tenant_id() IS NULL OR tenant_id = app_tenant_id());

-- 4.12 tenants (leitura pública, sem escrita anônima)
DROP POLICY IF EXISTS "tenants_select" ON public.tenants;
CREATE POLICY "tenants_select" ON public.tenants FOR SELECT
  USING (true);

-- 4.13 audit_log (append-only, sem leitura anônima)
DROP POLICY IF EXISTS "audit_log_insert" ON public.audit_log;
CREATE POLICY "audit_log_insert" ON public.audit_log FOR INSERT
  WITH CHECK (true);

-- ============================================================================
-- FIM DA MIGRATION 014
-- ============================================================================
