-- ============================================================
-- M5: Normalizar IDs TEXT → UUID
-- Tabelas afetadas: manutencoes, despesas, regras_manutencao
-- Abordagem: add new_id UUID, backfill, swap, drop old column
-- ============================================================

-- 1. manutencoes
ALTER TABLE manutencoes ADD COLUMN IF NOT EXISTS new_id UUID DEFAULT gen_random_uuid();
UPDATE manutencoes SET new_id = gen_random_uuid() WHERE new_id IS NULL;
-- Drop dependants (FKs referencing manutencoes.id) if any, before swapping
ALTER TABLE manutencoes DROP CONSTRAINT IF EXISTS manutencoes_pkey CASCADE;
ALTER TABLE manutencoes DROP COLUMN IF EXISTS id;
ALTER TABLE manutencoes RENAME COLUMN new_id TO id;
ALTER TABLE manutencoes ADD PRIMARY KEY (id);

-- 2. despesas
ALTER TABLE despesas ADD COLUMN IF NOT EXISTS new_id UUID DEFAULT gen_random_uuid();
UPDATE despesas SET new_id = gen_random_uuid() WHERE new_id IS NULL;
ALTER TABLE despesas DROP CONSTRAINT IF EXISTS despesas_pkey CASCADE;
ALTER TABLE despesas DROP COLUMN IF EXISTS id;
ALTER TABLE despesas RENAME COLUMN new_id TO id;
ALTER TABLE despesas ADD PRIMARY KEY (id);

-- 3. regras_manutencao
ALTER TABLE regras_manutencao ADD COLUMN IF NOT EXISTS new_id UUID DEFAULT gen_random_uuid();
UPDATE regras_manutencao SET new_id = gen_random_uuid() WHERE new_id IS NULL;
ALTER TABLE regras_manutencao DROP CONSTRAINT IF EXISTS regras_manutencao_pkey CASCADE;
ALTER TABLE regras_manutencao DROP COLUMN IF EXISTS id;
ALTER TABLE regras_manutencao RENAME COLUMN new_id TO id;
ALTER TABLE regras_manutencao ADD PRIMARY KEY (id);

-- 4. Verificação
DO $$
BEGIN
  RAISE NOTICE 'Migração 035 concluída: manutencoes, despesas, regras_manutencao IDs UUID';
END $$;
