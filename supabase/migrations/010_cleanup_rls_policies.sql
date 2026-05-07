-- ============================================================
-- 010: Limpeza de policies redundantes "USING (true)" / "WITH CHECK (true)"
-- que anulavam a proteção tenant nas tabelas que JÁ tinham a policy ALL
-- correta. Adiciona policy ALL em `seguros` (que só tinha as 4 furadas).
-- Também fixa search_path mutável das funções públicas.
-- ============================================================

-- =========================================================
-- PARTE 1: REMOVER policies redundantes USING/CHECK (true)
-- =========================================================

-- veiculos: já tem `veiculos_tenant` ALL com tenant check
DROP POLICY IF EXISTS veiculos_tenant_select ON public.veiculos;
DROP POLICY IF EXISTS veiculos_tenant_insert ON public.veiculos;
DROP POLICY IF EXISTS veiculos_tenant_update ON public.veiculos;
DROP POLICY IF EXISTS veiculos_tenant_delete ON public.veiculos;

-- financiamentos: já tem `financiamentos_tenant` ALL com tenant check
DROP POLICY IF EXISTS financiamentos_tenant_select ON public.financiamentos;
DROP POLICY IF EXISTS financiamentos_tenant_insert ON public.financiamentos;
DROP POLICY IF EXISTS financiamentos_tenant_update ON public.financiamentos;
DROP POLICY IF EXISTS financiamentos_tenant_delete ON public.financiamentos;

-- regras_manutencao: já tem `regras_manutencao_tenant` ALL
DROP POLICY IF EXISTS regras_select ON public.regras_manutencao;
DROP POLICY IF EXISTS regras_insert ON public.regras_manutencao;
DROP POLICY IF EXISTS regras_update ON public.regras_manutencao;
DROP POLICY IF EXISTS regras_delete ON public.regras_manutencao;

-- =========================================================
-- PARTE 2: seguros não tem policy ALL — criar antes de remover
-- =========================================================
CREATE POLICY seguros_tenant ON public.seguros FOR ALL
  USING ((app_tenant_id() IS NULL) OR (tenant_id = app_tenant_id()))
  WITH CHECK ((app_tenant_id() IS NULL) OR (tenant_id = app_tenant_id()));

DROP POLICY IF EXISTS seguros_tenant_select ON public.seguros;
DROP POLICY IF EXISTS seguros_tenant_insert ON public.seguros;
DROP POLICY IF EXISTS seguros_tenant_update ON public.seguros;
DROP POLICY IF EXISTS seguros_tenant_delete ON public.seguros;

-- =========================================================
-- PARTE 3: Fixar search_path mutável (proteção contra SQL injection
-- via shadowing de objetos no search_path do caller)
-- =========================================================
ALTER FUNCTION public.app_tenant_id() SET search_path = public, pg_catalog;
ALTER FUNCTION public.jwt_tenant_id() SET search_path = public, pg_catalog;
ALTER FUNCTION public.current_tenant_id() SET search_path = public, pg_catalog;
ALTER FUNCTION public.set_app_tenant(uuid) SET search_path = public, pg_catalog;
ALTER FUNCTION public.set_updated_at() SET search_path = public, pg_catalog;
ALTER FUNCTION public.registrar_km(text, integer, text, uuid) SET search_path = public, pg_catalog;
ALTER FUNCTION public.trg_abastecimentos_updated_at() SET search_path = public, pg_catalog;
