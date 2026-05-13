-- 025_fix_manutencoes_columns
-- Corrige schema mismatch entre SupabaseCustosRepository (Dart) e tabela manutencoes.
-- Renomeia colunas para match com ManutencaoItem, adiciona colunas ausentes, backfill de dados.

-- Drop trigger quebrado que referencia updated_at (coluna inexistente)
DROP TRIGGER IF EXISTS trg_manutencoes_updated_at ON manutencoes;

-- 1. Mudar id de UUID para TEXT (Dart gera IDs numéricos, não UUIDs)
ALTER TABLE manutencoes ALTER COLUMN id TYPE TEXT USING id::TEXT;
ALTER TABLE manutencoes ALTER COLUMN id DROP DEFAULT;

-- 2. Renomear colunas para match com o modelo Dart
ALTER TABLE manutencoes RENAME COLUMN data_servico TO data;
ALTER TABLE manutencoes RENAME COLUMN tipo_servico TO tipo;
ALTER TABLE manutencoes RENAME COLUMN oficina TO fornecedor;
ALTER TABLE manutencoes RENAME COLUMN valor_servico TO custo;
ALTER TABLE manutencoes RENAME COLUMN km_registro TO km_no_servico;

-- 3. Adicionar colunas ausentes
ALTER TABLE manutencoes ADD COLUMN IF NOT EXISTS veiculo_placa  TEXT NOT NULL DEFAULT '';
ALTER TABLE manutencoes ADD COLUMN IF NOT EXISTS veiculo_nome   TEXT NOT NULL DEFAULT '';
ALTER TABLE manutencoes ADD COLUMN IF NOT EXISTS titulo         TEXT NOT NULL DEFAULT '';
ALTER TABLE manutencoes ADD COLUMN IF NOT EXISTS odometro       INTEGER NOT NULL DEFAULT 0;
ALTER TABLE manutencoes ADD COLUMN IF NOT EXISTS prioridade     TEXT NOT NULL DEFAULT 'media';
ALTER TABLE manutencoes ADD COLUMN IF NOT EXISTS coluna         TEXT NOT NULL DEFAULT 'pendentes';
ALTER TABLE manutencoes ADD COLUMN IF NOT EXISTS numero_os      TEXT NOT NULL DEFAULT '';
ALTER TABLE manutencoes ADD COLUMN IF NOT EXISTS nome_anexo     TEXT NOT NULL DEFAULT '';
ALTER TABLE manutencoes ADD COLUMN IF NOT EXISTS is_preventiva  BOOLEAN NOT NULL DEFAULT TRUE;
ALTER TABLE manutencoes ADD COLUMN IF NOT EXISTS data_conclusao TIMESTAMPTZ;

-- 4. Backfill: popular veiculo_placa, veiculo_nome e titulo usando JOIN com veiculos
UPDATE manutencoes m
SET
  veiculo_placa = COALESCE(v.placa, ''),
  veiculo_nome  = COALESCE(v.marca || ' ' || v.modelo, ''),
  titulo        = COALESCE(m.descricao, 'Manutenção')
FROM veiculos v
WHERE v.id::TEXT = m.veiculo_id::TEXT;

-- 5. Manutenções pagas → coluna 'concluidos'
UPDATE manutencoes
SET coluna = 'concluidos'
WHERE status_pagamento ILIKE '%pag%';

-- 6. Inferir is_preventiva do tipo
UPDATE manutencoes
SET is_preventiva = (tipo ILIKE '%prev%' OR tipo ILIKE '%revis%');
