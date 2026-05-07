-- ============================================================
-- 009: Habilita RLS nas 5 tabelas vulneráveis seguindo o padrão
-- multi-tenant existente (app_tenant_id()).
--
-- Tabelas: ipva, licenciamento, multas, recebimentos, parcelas_seguro
-- Estratégia: ADD tenant_id -> backfill via FK pai -> SET NOT NULL
--             -> FK + index -> ENABLE RLS + policy padrão
-- ============================================================

-- ============== IPVA ==============
ALTER TABLE public.ipva ADD COLUMN IF NOT EXISTS tenant_id uuid;

UPDATE public.ipva i
SET tenant_id = v.tenant_id
FROM public.veiculos v
WHERE i.veiculo_id = v.id AND i.tenant_id IS NULL;

ALTER TABLE public.ipva ALTER COLUMN tenant_id SET NOT NULL;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.table_constraints
                 WHERE constraint_name = 'ipva_tenant_id_fkey' AND table_name='ipva') THEN
    ALTER TABLE public.ipva
      ADD CONSTRAINT ipva_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id);
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_ipva_tenant ON public.ipva(tenant_id);

ALTER TABLE public.ipva ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS ipva_tenant ON public.ipva;
CREATE POLICY ipva_tenant ON public.ipva FOR ALL
  USING ((app_tenant_id() IS NULL) OR (tenant_id = app_tenant_id()))
  WITH CHECK ((app_tenant_id() IS NULL) OR (tenant_id = app_tenant_id()));

-- ============== LICENCIAMENTO ==============
ALTER TABLE public.licenciamento ADD COLUMN IF NOT EXISTS tenant_id uuid;

UPDATE public.licenciamento l
SET tenant_id = v.tenant_id
FROM public.veiculos v
WHERE l.veiculo_id = v.id AND l.tenant_id IS NULL;

ALTER TABLE public.licenciamento ALTER COLUMN tenant_id SET NOT NULL;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.table_constraints
                 WHERE constraint_name = 'licenciamento_tenant_id_fkey' AND table_name='licenciamento') THEN
    ALTER TABLE public.licenciamento
      ADD CONSTRAINT licenciamento_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id);
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_licenciamento_tenant ON public.licenciamento(tenant_id);

ALTER TABLE public.licenciamento ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS licenciamento_tenant ON public.licenciamento;
CREATE POLICY licenciamento_tenant ON public.licenciamento FOR ALL
  USING ((app_tenant_id() IS NULL) OR (tenant_id = app_tenant_id()))
  WITH CHECK ((app_tenant_id() IS NULL) OR (tenant_id = app_tenant_id()));

-- ============== MULTAS ==============
ALTER TABLE public.multas ADD COLUMN IF NOT EXISTS tenant_id uuid;

UPDATE public.multas m
SET tenant_id = v.tenant_id
FROM public.veiculos v
WHERE m.veiculo_id = v.id AND m.tenant_id IS NULL;

ALTER TABLE public.multas ALTER COLUMN tenant_id SET NOT NULL;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.table_constraints
                 WHERE constraint_name = 'multas_tenant_id_fkey' AND table_name='multas') THEN
    ALTER TABLE public.multas
      ADD CONSTRAINT multas_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id);
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_multas_tenant ON public.multas(tenant_id);

ALTER TABLE public.multas ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS multas_tenant ON public.multas;
CREATE POLICY multas_tenant ON public.multas FOR ALL
  USING ((app_tenant_id() IS NULL) OR (tenant_id = app_tenant_id()))
  WITH CHECK ((app_tenant_id() IS NULL) OR (tenant_id = app_tenant_id()));

-- ============== RECEBIMENTOS ==============
ALTER TABLE public.recebimentos ADD COLUMN IF NOT EXISTS tenant_id uuid;

UPDATE public.recebimentos r
SET tenant_id = v.tenant_id
FROM public.veiculos v
WHERE r.veiculo_id = v.id AND r.tenant_id IS NULL;

ALTER TABLE public.recebimentos ALTER COLUMN tenant_id SET NOT NULL;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.table_constraints
                 WHERE constraint_name = 'recebimentos_tenant_id_fkey' AND table_name='recebimentos') THEN
    ALTER TABLE public.recebimentos
      ADD CONSTRAINT recebimentos_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id);
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_recebimentos_tenant ON public.recebimentos(tenant_id);

ALTER TABLE public.recebimentos ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS recebimentos_tenant ON public.recebimentos;
CREATE POLICY recebimentos_tenant ON public.recebimentos FOR ALL
  USING ((app_tenant_id() IS NULL) OR (tenant_id = app_tenant_id()))
  WITH CHECK ((app_tenant_id() IS NULL) OR (tenant_id = app_tenant_id()));

-- ============== PARCELAS_SEGURO (vincula via seguros) ==============
ALTER TABLE public.parcelas_seguro ADD COLUMN IF NOT EXISTS tenant_id uuid;

UPDATE public.parcelas_seguro p
SET tenant_id = s.tenant_id
FROM public.seguros s
WHERE p.seguro_id = s.id AND p.tenant_id IS NULL;

ALTER TABLE public.parcelas_seguro ALTER COLUMN tenant_id SET NOT NULL;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.table_constraints
                 WHERE constraint_name = 'parcelas_seguro_tenant_id_fkey' AND table_name='parcelas_seguro') THEN
    ALTER TABLE public.parcelas_seguro
      ADD CONSTRAINT parcelas_seguro_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id);
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_parcelas_seguro_tenant ON public.parcelas_seguro(tenant_id);

ALTER TABLE public.parcelas_seguro ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS parcelas_seguro_tenant ON public.parcelas_seguro;
CREATE POLICY parcelas_seguro_tenant ON public.parcelas_seguro FOR ALL
  USING ((app_tenant_id() IS NULL) OR (tenant_id = app_tenant_id()))
  WITH CHECK ((app_tenant_id() IS NULL) OR (tenant_id = app_tenant_id()));
