-- ═══════════════════════════════════════════════════════════════════════
-- Migration 011 — Módulo Combustível: tabela abastecimentos
-- ═══════════════════════════════════════════════════════════════════════

-- Tipo ENUM de combustível (evita strings livres)
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'tipo_combustivel') THEN
    CREATE TYPE tipo_combustivel AS ENUM (
      'gasolina', 'etanol', 'diesel', 'gnv', 'eletrico'
    );
  END IF;
END$$;

-- Tabela de abastecimentos
CREATE TABLE IF NOT EXISTS abastecimentos (
  id               TEXT        PRIMARY KEY,
  veiculo_placa    TEXT        NOT NULL REFERENCES veiculos(placa) ON UPDATE CASCADE,
  data             TIMESTAMPTZ NOT NULL,
  litros           NUMERIC(10, 3) NOT NULL CHECK (litros > 0),
  valor_total      NUMERIC(12, 2) NOT NULL CHECK (valor_total >= 0),
  km_odometro      NUMERIC(12, 1) NOT NULL CHECK (km_odometro >= 0),
  tipo             tipo_combustivel NOT NULL DEFAULT 'gasolina',
  posto            TEXT,
  registrado_por   TEXT        NOT NULL DEFAULT 'sistema',
  tenant_id        UUID        NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Índices para queries comuns
CREATE INDEX IF NOT EXISTS idx_abastecimentos_tenant
  ON abastecimentos (tenant_id);

CREATE INDEX IF NOT EXISTS idx_abastecimentos_veiculo
  ON abastecimentos (veiculo_placa, tenant_id);

CREATE INDEX IF NOT EXISTS idx_abastecimentos_data
  ON abastecimentos (data DESC, tenant_id);

-- Trigger updated_at
CREATE OR REPLACE FUNCTION trg_abastecimentos_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS set_abastecimentos_updated_at ON abastecimentos;
CREATE TRIGGER set_abastecimentos_updated_at
  BEFORE UPDATE ON abastecimentos
  FOR EACH ROW EXECUTE FUNCTION trg_abastecimentos_updated_at();

-- ═══════════════════════════════════════════════════════════════════════
-- Row Level Security
-- ═══════════════════════════════════════════════════════════════════════

ALTER TABLE abastecimentos ENABLE ROW LEVEL SECURITY;

-- Política permissiva: acesso somente ao próprio tenant (via JWT claim)
DROP POLICY IF EXISTS abastecimentos_tenant_isolation ON abastecimentos;
CREATE POLICY abastecimentos_tenant_isolation ON abastecimentos
  USING (
    tenant_id = COALESCE(
      (current_setting('request.jwt.claims', true)::jsonb ->> 'tenant_id')::uuid,
      '00000000-0000-0000-0000-000000000001'::uuid
    )
  )
  WITH CHECK (
    tenant_id = COALESCE(
      (current_setting('request.jwt.claims', true)::jsonb ->> 'tenant_id')::uuid,
      '00000000-0000-0000-0000-000000000001'::uuid
    )
  );
