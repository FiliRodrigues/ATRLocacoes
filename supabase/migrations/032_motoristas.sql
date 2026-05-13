-- 032_motoristas: tabela motoristas e migração de dados de despesas

-- Tabela motoristas
CREATE TABLE IF NOT EXISTS motoristas (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  nome text NOT NULL,
  telefone text,
  cnh text,
  vencimento_cnh date,
  status_cnh text NOT NULL DEFAULT 'ok',
  multas integer NOT NULL DEFAULT 0,
  tenant_id uuid NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- RLS
ALTER TABLE motoristas ENABLE ROW LEVEL SECURITY;

CREATE POLICY "motoristas_select_tenant" ON motoristas
  FOR SELECT USING (tenant_id = auth_tenant_id());

CREATE POLICY "motoristas_insert_tenant" ON motoristas
  FOR INSERT WITH CHECK (tenant_id = auth_tenant_id());

CREATE POLICY "motoristas_update_tenant" ON motoristas
  FOR UPDATE USING (tenant_id = auth_tenant_id());

CREATE POLICY "motoristas_delete_tenant" ON motoristas
  FOR DELETE USING (tenant_id = auth_tenant_id());

-- Migrar motoristas únicos de despesas.motorista (usa tenant_id da despesa)
INSERT INTO motoristas (nome, telefone, cnh, vencimento_cnh, status_cnh, multas, tenant_id)
SELECT
  d.motorista,
  NULL,
  NULL,
  NULL,
  'ok',
  0,
  d.tenant_id
FROM despesas d
WHERE d.motorista IS NOT NULL AND d.motorista <> ''
  AND NOT EXISTS (
    SELECT 1 FROM motoristas m
    WHERE m.nome = d.motorista AND m.tenant_id = d.tenant_id
  )
GROUP BY d.motorista, d.tenant_id;
