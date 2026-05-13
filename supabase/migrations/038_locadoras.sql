CREATE TABLE IF NOT EXISTS locadoras (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  nome text NOT NULL,
  tenant_id uuid NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(nome, tenant_id)
);

ALTER TABLE locadoras ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Tenant isolation for locadoras"
  ON locadoras
  FOR ALL
  USING (tenant_id = auth_tenant_id())
  WITH CHECK (tenant_id = auth_tenant_id());

GRANT ALL ON locadoras TO authenticated;
