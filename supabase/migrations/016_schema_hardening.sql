-- ═══════════════════════════════════════════════════════════════════════
-- ATR Locações — Migration 016: Schema Hardening
-- Correções pós-auditoria de 28 regras Postgres/Supabase:
--   1. FORCE RLS em app_users (ausente na 015)
--   2. FK constraints: manutencoes/despesas/hodometros.veiculo_placa → veiculos(placa)
--   3. Remover índices duplicados da skill 20260505
--   4. Padronizar RLS de seguros com jwt_tenant_id()
-- ═══════════════════════════════════════════════════════════════════════

-- ─────────────────────────────────────────────────────────────────────
-- 1. FORCE ROW LEVEL SECURITY em app_users
--    Migration 015 aplicou FORCE RLS em 13 tabelas mas esqueceu app_users.
--    Sem FORCE, o service_role bypassa a política de SELECT → risco de
--    leitura cross-tenant em caso de bug na aplicação.
-- ─────────────────────────────────────────────────────────────────────
ALTER TABLE IF EXISTS public.app_users FORCE ROW LEVEL SECURITY;

-- ─────────────────────────────────────────────────────────────────────
-- 2. FOREIGN KEY CONSTRAINTS
--    As tabelas manutencoes, despesas e hodometros referenciam veiculos
--    por placa (TEXT) sem FK constraint. Isso permite:
--      a) Registros órfãos quando um veículo é deletado
--      b) Erros de digitação em placas sem validação no banco
--    veiculos.placa tem UNIQUE constraint (009) → FK é seguro.
-- ─────────────────────────────────────────────────────────────────────

-- 2.1 manutencoes.veiculo_placa → veiculos(placa)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.table_constraints
    WHERE table_name = 'manutencoes'
      AND constraint_name = 'manutencoes_veiculo_placa_fkey'
  ) THEN
    -- Primeiro limpa órfãos (se houver) para evitar erro na criação da FK
    DELETE FROM public.manutencoes
    WHERE veiculo_placa IS NOT NULL
      AND veiculo_placa NOT IN (SELECT placa FROM public.veiculos);

    ALTER TABLE public.manutencoes
      ADD CONSTRAINT manutencoes_veiculo_placa_fkey
      FOREIGN KEY (veiculo_placa) REFERENCES public.veiculos(placa)
      ON UPDATE CASCADE ON DELETE SET NULL;
  END IF;
END $$;

-- 2.2 despesas.veiculo_placa → veiculos(placa)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.table_constraints
    WHERE table_name = 'despesas'
      AND constraint_name = 'despesas_veiculo_placa_fkey'
  ) THEN
    DELETE FROM public.despesas
    WHERE veiculo_placa IS NOT NULL
      AND veiculo_placa NOT IN (SELECT placa FROM public.veiculos);

    ALTER TABLE public.despesas
      ADD CONSTRAINT despesas_veiculo_placa_fkey
      FOREIGN KEY (veiculo_placa) REFERENCES public.veiculos(placa)
      ON UPDATE CASCADE ON DELETE SET NULL;
  END IF;
END $$;

-- 2.3 hodometros.veiculo_placa → veiculos(placa)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.table_constraints
    WHERE table_name = 'hodometros'
      AND constraint_name = 'hodometros_veiculo_placa_fkey'
  ) THEN
    DELETE FROM public.hodometros
    WHERE veiculo_placa IS NOT NULL
      AND veiculo_placa NOT IN (SELECT placa FROM public.veiculos);

    ALTER TABLE public.hodometros
      ADD CONSTRAINT hodometros_veiculo_placa_fkey
      FOREIGN KEY (veiculo_placa) REFERENCES public.veiculos(placa)
      ON UPDATE CASCADE ON DELETE SET NULL;
  END IF;
END $$;

-- ─────────────────────────────────────────────────────────────────────
-- 3. REMOVER ÍNDICES DUPLICADOS
--    A skill 20260505 criou índices redundantes com nomes diferentes.
--    Cada índice extra consome write performance (todo INSERT/UPDATE/DELETE
--    precisa manter o índice) sem benefício de leitura.
-- ─────────────────────────────────────────────────────────────────────

-- 3.1 idx_contratos_tenant_status = idx_contratos_tenant (mesmas colunas: tenant_id, status)
--    004 criou idx_contratos_tenant, 20260505 criou idx_contratos_tenant_status
DROP INDEX IF EXISTS public.idx_contratos_tenant_status;

-- 3.2 idx_despesas_nao_pagas = idx_despesas_pendentes (mesmo filtro: pago=false)
--    015 criou idx_despesas_pendentes, 20260505 criou idx_despesas_nao_pagas
DROP INDEX IF EXISTS public.idx_despesas_nao_pagas;

-- ─────────────────────────────────────────────────────────────────────
-- 4. PADRONIZAR RLS DE seguros
--    Migration 009 criou seguros com políticas permissivas USING(true).
--    Migration 014 não atualizou seguros. Esta migration padroniza com
--    o mesmo padrão jwt_tenant_id() das demais tabelas.
-- ─────────────────────────────────────────────────────────────────────
ALTER TABLE IF EXISTS public.seguros FORCE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "seguros_tenant_select" ON public.seguros;
DROP POLICY IF EXISTS "seguros_tenant_insert" ON public.seguros;
DROP POLICY IF EXISTS "seguros_tenant_update" ON public.seguros;
DROP POLICY IF EXISTS "seguros_tenant_delete" ON public.seguros;
DROP POLICY IF EXISTS "seguros_tenant" ON public.seguros;

CREATE POLICY "seguros_tenant" ON public.seguros FOR ALL
  USING  (public.jwt_tenant_id() IS NULL OR tenant_id = public.jwt_tenant_id())
  WITH CHECK (public.jwt_tenant_id() IS NULL OR tenant_id = public.jwt_tenant_id());

-- ─────────────────────────────────────────────────────────────────────
-- 5. VERIFICAÇÃO
-- ─────────────────────────────────────────────────────────────────────
DO $$
DECLARE
  v_count INTEGER;
BEGIN
  -- 5.1 Confirmar FORCE RLS em app_users
  SELECT COUNT(*) INTO v_count
  FROM pg_tables
  WHERE schemaname = 'public'
    AND tablename = 'app_users'
    AND rowsecurity = true;

  IF v_count = 0 THEN
    RAISE WARNING 'app_users RLS não está ativo!';
  END IF;

  -- 5.2 Contar FK constraints criadas
  v_count := 0;
  SELECT COUNT(*) INTO v_count
  FROM information_schema.table_constraints
  WHERE table_schema = 'public'
    AND constraint_type = 'FOREIGN KEY'
    AND constraint_name IN (
      'manutencoes_veiculo_placa_fkey',
      'despesas_veiculo_placa_fkey',
      'hodometros_veiculo_placa_fkey'
    );

  RAISE NOTICE 'FK constraints verificadas: % (esperado: 3)', v_count;

  -- 5.3 Listar políticas ativas
  RAISE NOTICE 'Políticas ativas após migration:';
END $$;

-- Lista todas as políticas ativas para conferência manual
SELECT tablename, policyname, cmd, qual
FROM pg_policies
WHERE schemaname = 'public'
ORDER BY tablename, policyname;
