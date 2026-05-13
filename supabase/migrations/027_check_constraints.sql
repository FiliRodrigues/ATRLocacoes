-- Migration 027: Check constraints de integridade
-- Garante que valores financeiros não sejam negativos e datas sejam coerentes

DO $$
BEGIN
  -- manutencoes: custo não pode ser negativo
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'chk_manutencoes_custo'
  ) THEN
    ALTER TABLE manutencoes ADD CONSTRAINT chk_manutencoes_custo CHECK (custo >= 0);
  END IF;

  -- despesas: valor não pode ser negativo
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'chk_despesas_valor'
  ) THEN
    ALTER TABLE despesas ADD CONSTRAINT chk_despesas_valor CHECK (valor >= 0);
  END IF;

  -- contratos: data_fim deve ser >= data_inicio
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'chk_contratos_datas'
  ) THEN
    ALTER TABLE contratos ADD CONSTRAINT chk_contratos_datas CHECK (data_fim >= data_inicio);
  END IF;
END $$;
