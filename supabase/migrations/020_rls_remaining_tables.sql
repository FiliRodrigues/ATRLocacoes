-- ============================================================================
-- Migration 020 - RLS nas 5 tabelas pendentes + tenant_id
-- Objetivo: Ativar RLS em ipva, licenciamento, parcelas_seguro, multas, recebimentos
-- Segue o padrao da migration 014: app_tenant_id() IS NULL OR tenant_id = app_tenant_id()
-- ============================================================================

-- 1. Adicionar tenant_id as tabelas sem ele
ALTER TABLE public.ipva
  ADD COLUMN IF NOT EXISTS tenant_id UUID REFERENCES public.tenants(id);

ALTER TABLE public.licenciamento
  ADD COLUMN IF NOT EXISTS tenant_id UUID REFERENCES public.tenants(id);

ALTER TABLE public.parcelas_seguro
  ADD COLUMN IF NOT EXISTS tenant_id UUID REFERENCES public.tenants(id);

ALTER TABLE public.multas
  ADD COLUMN IF NOT EXISTS tenant_id UUID REFERENCES public.tenants(id);

ALTER TABLE public.recebimentos
  ADD COLUMN IF NOT EXISTS tenant_id UUID REFERENCES public.tenants(id);

-- 2. Backfill: atribuir tenant padrao a todos os registos existentes
UPDATE public.ipva
  SET tenant_id = '00000000-0000-0000-0000-000000000001'
  WHERE tenant_id IS NULL;

UPDATE public.licenciamento
  SET tenant_id = '00000000-0000-0000-0000-000000000001'
  WHERE tenant_id IS NULL;

UPDATE public.parcelas_seguro
  SET tenant_id = '00000000-0000-0000-0000-000000000001'
  WHERE tenant_id IS NULL;

UPDATE public.multas
  SET tenant_id = '00000000-0000-0000-0000-000000000001'
  WHERE tenant_id IS NULL;

UPDATE public.recebimentos
  SET tenant_id = '00000000-0000-0000-0000-000000000001'
  WHERE tenant_id IS NULL;

-- 3. NOT NULL + DEFAULT apos backfill
ALTER TABLE public.ipva
  ALTER COLUMN tenant_id SET NOT NULL,
  ALTER COLUMN tenant_id SET DEFAULT '00000000-0000-0000-0000-000000000001';

ALTER TABLE public.licenciamento
  ALTER COLUMN tenant_id SET NOT NULL,
  ALTER COLUMN tenant_id SET DEFAULT '00000000-0000-0000-0000-000000000001';

ALTER TABLE public.parcelas_seguro
  ALTER COLUMN tenant_id SET NOT NULL,
  ALTER COLUMN tenant_id SET DEFAULT '00000000-0000-0000-0000-000000000001';

ALTER TABLE public.multas
  ALTER COLUMN tenant_id SET NOT NULL,
  ALTER COLUMN tenant_id SET DEFAULT '00000000-0000-0000-0000-000000000001';

ALTER TABLE public.recebimentos
  ALTER COLUMN tenant_id SET NOT NULL,
  ALTER COLUMN tenant_id SET DEFAULT '00000000-0000-0000-0000-000000000001';

-- 4. Ativar RLS
ALTER TABLE public.ipva ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.licenciamento ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.parcelas_seguro ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.multas ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.recebimentos ENABLE ROW LEVEL SECURITY;

-- 5. Criar politicas de tenant isolation
CREATE POLICY "ipva_tenant" ON public.ipva FOR ALL
  USING  (app_tenant_id() IS NULL OR tenant_id = app_tenant_id())
  WITH CHECK (app_tenant_id() IS NULL OR tenant_id = app_tenant_id());

CREATE POLICY "licenciamento_tenant" ON public.licenciamento FOR ALL
  USING  (app_tenant_id() IS NULL OR tenant_id = app_tenant_id())
  WITH CHECK (app_tenant_id() IS NULL OR tenant_id = app_tenant_id());

CREATE POLICY "parcelas_seguro_tenant" ON public.parcelas_seguro FOR ALL
  USING  (app_tenant_id() IS NULL OR tenant_id = app_tenant_id())
  WITH CHECK (app_tenant_id() IS NULL OR tenant_id = app_tenant_id());

CREATE POLICY "multas_tenant" ON public.multas FOR ALL
  USING  (app_tenant_id() IS NULL OR tenant_id = app_tenant_id())
  WITH CHECK (app_tenant_id() IS NULL OR tenant_id = app_tenant_id());

CREATE POLICY "recebimentos_tenant" ON public.recebimentos FOR ALL
  USING  (app_tenant_id() IS NULL OR tenant_id = app_tenant_id())
  WITH CHECK (app_tenant_id() IS NULL OR tenant_id = app_tenant_id());

-- 6. Indices de tenant para performance
CREATE INDEX IF NOT EXISTS idx_ipva_tenant ON public.ipva (tenant_id, veiculo_id);
CREATE INDEX IF NOT EXISTS idx_licenciamento_tenant ON public.licenciamento (tenant_id, veiculo_id);
CREATE INDEX IF NOT EXISTS idx_parcelas_seguro_tenant ON public.parcelas_seguro (tenant_id, seguro_id);
CREATE INDEX IF NOT EXISTS idx_multas_tenant ON public.multas (tenant_id, veiculo_id);
CREATE INDEX IF NOT EXISTS idx_recebimentos_tenant ON public.recebimentos (tenant_id, veiculo_id, data_vencimento);

-- ============================================================================
-- FIM DA MIGRATION 020
-- ============================================================================
