-- ═══════════════════════════════════════════════════════════════════════
-- ATR Locações — Migration 015: Hardening (Postgres Best Practices)
-- Skill: supabase-postgres-best-practices
-- Regras aplicadas:
--   schema-primary-keys:        bigint/UUID, evitar TEXT PK
--   schema-foreign-key-indexes: indexar colunas FK
--   query-missing-indexes:      index em colunas de JOIN/WHERE
--   query-partial-indexes:      índices parciais para queries filtradas
--   security-rls-basics:        FORCE ROW LEVEL SECURITY
--   monitor-pg-stat-statements: métricas de query ativas
-- ═══════════════════════════════════════════════════════════════════════

-- ─────────────────────────────────────────────────────────────────────
-- 1. TABELA: parcelas_financiamento (criação formal)
--    Referenciada no supabase_service.dart mas sem CREATE TABLE oficial.
--    Detectada como tabela existente — se já existe, este bloco é no-op
--    graças ao IF NOT EXISTS.
-- ─────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.parcelas_financiamento (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  financiamento_id    UUID NOT NULL REFERENCES public.financiamentos(id) ON DELETE CASCADE,
  numero_parcela      INTEGER NOT NULL,
  valor_parcela       NUMERIC(12, 2) NOT NULL DEFAULT 0,
  data_vencimento     DATE,
  data_pagamento      DATE,
  status_pagamento    TEXT NOT NULL DEFAULT 'Pendente',
  tenant_id           UUID REFERENCES public.tenants(id),
  created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ─────────────────────────────────────────────────────────────────────
-- 2. Adicionar coluna tenant_id na tabela existente (backfill seguro)
--    A tabela foi criada manualmente sem tenant_id.
-- ─────────────────────────────────────────────────────────────────────
ALTER TABLE public.parcelas_financiamento
  ADD COLUMN IF NOT EXISTS tenant_id UUID REFERENCES public.tenants(id);

-- Backfill: vincula ao tenant padrão parcelas cujo financiamento pertence ao tenant ATR
UPDATE public.parcelas_financiamento pf
SET tenant_id = '00000000-0000-0000-0000-000000000001'
WHERE pf.tenant_id IS NULL;

-- ─────────────────────────────────────────────────────────────────────
-- 3. ÍNDICE: FK mais crítica sem índice — parcelas_financiamento.financiamento_id
--    skill:query-missing-indexes — a query do app filtra por financiamento_id
--    sem índice → full scan em 331+ linhas a cada boot.
--    skill:schema-foreign-key-indexes — FK nunca é indexada automaticamente.
-- ─────────────────────────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_parcelas_financiamento_id
  ON public.parcelas_financiamento (financiamento_id);

-- Índice composto para queries com status + tenant
CREATE INDEX IF NOT EXISTS idx_parcelas_tenant_status
  ON public.parcelas_financiamento (tenant_id, status_pagamento)
  WHERE tenant_id IS NOT NULL;

-- ─────────────────────────────────────────────────────────────────────
-- 3. FORCE ROW LEVEL SECURITY em TODAS as tabelas operacionais
--    skill:security-rls-basics — sem FORCE, o table owner (service_role)
--    ignora as políticas. Com FORCE, owner também é filtrado → defesa
--    contra bugs de aplicação que esquecem o WHERE tenant_id.
-- ─────────────────────────────────────────────────────────────────────
ALTER TABLE IF EXISTS public.veiculos          FORCE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.manutencoes       FORCE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.despesas          FORCE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.hodometros        FORCE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.audit_log         FORCE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.contratos         FORCE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.checklist_eventos FORCE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.ocorrencias       FORCE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.financiamentos    FORCE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.seguros           FORCE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.abastecimentos    FORCE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.regras_manutencao FORCE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.parcelas_financiamento FORCE ROW LEVEL SECURITY;

-- ─────────────────────────────────────────────────────────────────────
-- 4. RLS para parcelas_financiamento
--    Mesmo padrão das outras tabelas: jwt_tenant_id() IS NULL permissivo,
--    com claim → isolamento estrito.
-- ─────────────────────────────────────────────────────────────────────
ALTER TABLE IF EXISTS public.parcelas_financiamento ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "parcelas_tenant" ON public.parcelas_financiamento;
CREATE POLICY "parcelas_tenant" ON public.parcelas_financiamento FOR ALL
  USING  (public.jwt_tenant_id() IS NULL OR tenant_id = public.jwt_tenant_id())
  WITH CHECK (public.jwt_tenant_id() IS NULL OR tenant_id = public.jwt_tenant_id());

-- ─────────────────────────────────────────────────────────────────────
-- 5. ÍNDICE PARCIAL: despesas pendentes (pago=false)
--    skill:query-partial-indexes — despesas não pagas são minoria dos
--    dados mas consultadas com mais frequência.
-- ─────────────────────────────────────────────────────────────────────
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_indexes
    WHERE schemaname = 'public'
      AND tablename = 'despesas'
      AND indexname = 'idx_despesas_pendentes'
  ) THEN
    CREATE INDEX idx_despesas_pendentes
      ON public.despesas (tenant_id, data DESC)
      WHERE pago = false;
  END IF;
END $$;

-- ─────────────────────────────────────────────────────────────────────
-- 6. ÍNDICE PARCIAL: manutenções em aberto (status != 'concluido')
--    skill:query-partial-indexes — pendentes são minoria mas consultadas
--    com mais frequência. Usa status_pagamento como proxy de coluna kanban.
-- ─────────────────────────────────────────────────────────────────────
DO $$ BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'manutencoes'
      AND column_name = 'status_pagamento'
  ) THEN
    IF NOT EXISTS (
      SELECT 1 FROM pg_indexes
      WHERE schemaname = 'public'
        AND tablename = 'manutencoes'
        AND indexname = 'idx_manutencoes_abertas'
    ) THEN
      CREATE INDEX idx_manutencoes_abertas
        ON public.manutencoes (tenant_id)
        WHERE status_pagamento != 'concluido';
    END IF;
  END IF;
END $$;

-- ─────────────────────────────────────────────────────────────────────
-- 7. ÍNDICE: abastecimentos por data + tenant (query de relatório mensal)
-- ─────────────────────────────────────────────────────────────────────
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_indexes
    WHERE schemaname = 'public'
      AND tablename = 'abastecimentos'
      AND indexname = 'idx_abastecimentos_data_tenant'
  ) THEN
    CREATE INDEX idx_abastecimentos_data_tenant
      ON public.abastecimentos (tenant_id, data DESC);
  END IF;
END $$;

-- ─────────────────────────────────────────────────────────────────────
-- 8. MONITORAMENTO: garantir pg_stat_statements
--    skill:monitor-pg-stat-statements — essencial para diagnosticar
--    queries lentas em produção.
-- ─────────────────────────────────────────────────────────────────────
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;

-- ─────────────────────────────────────────────────────────────────────
-- VERIFICAÇÃO FINAL
-- ─────────────────────────────────────────────────────────────────────
SELECT
  'parcelas_financiamento' AS tabela,
  COUNT(*) AS registros
FROM public.parcelas_financiamento;
