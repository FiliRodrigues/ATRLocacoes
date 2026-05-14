-- Tabela de pacientes/clientes da Sala ATR
CREATE TABLE IF NOT EXISTS sala_atr_clientes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  nome text NOT NULL,
  telefone text NOT NULL DEFAULT '',
  email text NOT NULL DEFAULT '',
  data_nascimento date,
  endereco text NOT NULL DEFAULT '',
  convenio text NOT NULL DEFAULT '',
  responsavel_nome text NOT NULL DEFAULT '',
  responsavel_telefone text NOT NULL DEFAULT '',
  anotacoes text NOT NULL DEFAULT '',
  ativo boolean NOT NULL DEFAULT true,
  tenant_id uuid NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE sala_atr_clientes ENABLE ROW LEVEL SECURITY;
CREATE POLICY "tenant_isolation" ON sala_atr_clientes
  USING (tenant_id = auth_tenant_id());

-- Adicionar colunas faltantes em agendamentos
ALTER TABLE sala_atr_agendamentos
  ADD COLUMN IF NOT EXISTS cliente_id uuid REFERENCES sala_atr_clientes(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS cliente_telefone text NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS tipo_pagamento text NOT NULL DEFAULT 'particular',
  ADD COLUMN IF NOT EXISTS nota_sessao text NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS lembrete_24h boolean NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS lembrete_1h boolean NOT NULL DEFAULT true;

-- Adicionar cliente_id em pacotes
ALTER TABLE sala_atr_pacotes
  ADD COLUMN IF NOT EXISTS cliente_id uuid REFERENCES sala_atr_clientes(id) ON DELETE SET NULL;

-- Realtime para sala_atr_clientes e sala_atr_pacotes
ALTER TABLE sala_atr_clientes REPLICA IDENTITY FULL;
ALTER TABLE sala_atr_pacotes REPLICA IDENTITY FULL;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
    AND tablename = 'sala_atr_clientes'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE sala_atr_clientes;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
    AND tablename = 'sala_atr_pacotes'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE sala_atr_pacotes;
  END IF;
END $$;
