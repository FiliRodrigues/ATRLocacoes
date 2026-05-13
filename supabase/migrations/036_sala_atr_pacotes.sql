-- ============================================================
-- M6: Pacotes Sala ATR persistentes
-- ============================================================

CREATE TABLE IF NOT EXISTS sala_atr_pacotes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  cliente_nome TEXT NOT NULL,
  total_sessoes INTEGER NOT NULL DEFAULT 10,
  sessoes_usadas INTEGER NOT NULL DEFAULT 0,
  valor_pago NUMERIC NOT NULL DEFAULT 0,
  valor_por_sessao NUMERIC NOT NULL DEFAULT 0,
  ativo BOOLEAN NOT NULL DEFAULT true,
  tenant_id UUID NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- RLS: tenant isolation
ALTER TABLE sala_atr_pacotes ENABLE ROW LEVEL SECURITY;

-- Política: usuários autenticados do mesmo tenant podem ler
CREATE POLICY "Tenant isolation select" ON sala_atr_pacotes
  FOR SELECT
  TO authenticated
  USING (tenant_id = auth_tenant_id());

-- Política: usuários autenticados do mesmo tenant podem inserir
CREATE POLICY "Tenant isolation insert" ON sala_atr_pacotes
  FOR INSERT
  TO authenticated
  WITH CHECK (tenant_id = auth_tenant_id());

-- Política: usuários autenticados do mesmo tenant podem atualizar
CREATE POLICY "Tenant isolation update" ON sala_atr_pacotes
  FOR UPDATE
  TO authenticated
  USING (tenant_id = auth_tenant_id())
  WITH CHECK (tenant_id = auth_tenant_id());

-- Política: usuários autenticados do mesmo tenant podem deletar
CREATE POLICY "Tenant isolation delete" ON sala_atr_pacotes
  FOR DELETE
  TO authenticated
  USING (tenant_id = auth_tenant_id());

-- Índice para busca por tenant
CREATE INDEX IF NOT EXISTS idx_sala_atr_pacotes_tenant ON sala_atr_pacotes(tenant_id);
CREATE INDEX IF NOT EXISTS idx_sala_atr_pacotes_cliente ON sala_atr_pacotes(tenant_id, cliente_nome);

-- Trigger para updated_at automático
CREATE OR REPLACE FUNCTION update_sala_atr_pacotes_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_sala_atr_pacotes_updated_at ON sala_atr_pacotes;
CREATE TRIGGER trg_sala_atr_pacotes_updated_at
  BEFORE UPDATE ON sala_atr_pacotes
  FOR EACH ROW EXECUTE FUNCTION update_sala_atr_pacotes_updated_at();

DO $$
BEGIN
  RAISE NOTICE 'Migração 036 concluída: sala_atr_pacotes criada com RLS';
END $$;
