-- Migration 033: CREATE TABLE IF NOT EXISTS para tabelas fiscais
-- ipva, licenciamento e multas (schemas exatos do banco remoto)

-- ═══════════════════════════════════════════════════════════════════════
-- IPVA
-- ═══════════════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS ipva (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  veiculo_id uuid NOT NULL,
  ano_referencia integer NOT NULL,
  valor_total numeric,
  data_vencimento date,
  data_pagamento date,
  status_pagamento text DEFAULT 'Pendente',
  observacoes text,
  created_at timestamptz DEFAULT now(),
  tenant_id uuid NOT NULL
);

ALTER TABLE ipva ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  CREATE POLICY "ipva_select" ON ipva FOR SELECT USING (tenant_id = auth_tenant_id());
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE POLICY "ipva_insert" ON ipva FOR INSERT WITH CHECK (tenant_id = auth_tenant_id());
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE POLICY "ipva_update" ON ipva FOR UPDATE USING (tenant_id = auth_tenant_id());
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE POLICY "ipva_delete" ON ipva FOR DELETE USING (tenant_id = auth_tenant_id());
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

CREATE INDEX IF NOT EXISTS idx_ipva_veiculo ON ipva(veiculo_id);
CREATE INDEX IF NOT EXISTS idx_ipva_tenant ON ipva(tenant_id);

-- ═══════════════════════════════════════════════════════════════════════
-- Licenciamento
-- ═══════════════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS licenciamento (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  veiculo_id uuid NOT NULL,
  ano_referencia integer NOT NULL,
  mes_vencimento text,
  valor_total numeric,
  data_vencimento date,
  data_pagamento date,
  status_pagamento text DEFAULT 'Pendente',
  observacoes text,
  created_at timestamptz DEFAULT now(),
  tenant_id uuid NOT NULL
);

ALTER TABLE licenciamento ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  CREATE POLICY "licenciamento_select" ON licenciamento FOR SELECT USING (tenant_id = auth_tenant_id());
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE POLICY "licenciamento_insert" ON licenciamento FOR INSERT WITH CHECK (tenant_id = auth_tenant_id());
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE POLICY "licenciamento_update" ON licenciamento FOR UPDATE USING (tenant_id = auth_tenant_id());
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE POLICY "licenciamento_delete" ON licenciamento FOR DELETE USING (tenant_id = auth_tenant_id());
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

CREATE INDEX IF NOT EXISTS idx_licenciamento_veiculo ON licenciamento(veiculo_id);
CREATE INDEX IF NOT EXISTS idx_licenciamento_tenant ON licenciamento(tenant_id);

-- ═══════════════════════════════════════════════════════════════════════
-- Multas
-- ═══════════════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS multas (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  veiculo_id uuid NOT NULL,
  ano_referencia integer NOT NULL,
  mes text NOT NULL,
  valor numeric DEFAULT 0,
  descricao text,
  status_pagamento text DEFAULT 'Pendente',
  data_infracao date,
  data_vencimento date,
  data_pagamento date,
  created_at timestamptz DEFAULT now(),
  tenant_id uuid NOT NULL
);

ALTER TABLE multas ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  CREATE POLICY "multas_select" ON multas FOR SELECT USING (tenant_id = auth_tenant_id());
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE POLICY "multas_insert" ON multas FOR INSERT WITH CHECK (tenant_id = auth_tenant_id());
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE POLICY "multas_update" ON multas FOR UPDATE USING (tenant_id = auth_tenant_id());
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE POLICY "multas_delete" ON multas FOR DELETE USING (tenant_id = auth_tenant_id());
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

CREATE INDEX IF NOT EXISTS idx_multas_veiculo ON multas(veiculo_id);
CREATE INDEX IF NOT EXISTS idx_multas_tenant ON multas(tenant_id);
