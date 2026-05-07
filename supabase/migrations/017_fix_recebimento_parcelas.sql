-- ═══════════════════════════════════════════════════════════════════════
-- ATR Locações — Migration 017: Corrigir recebimento_mensal e parcelas órfãs
--
-- Problema detectado (2026-05-07):
--   1. recebimento_mensal = 0 em TODOS os financiamentos ativos
--      → Migration 007 pode não ter sido executada ou dados foram recriados.
--   2. 331 parcelas em parcelas_financiamento com financiamento_id
--      que não referencia nenhum financiamentos.id existente.
--      → Tabela existia antes da migration 015, FK nunca foi criada.
--
-- Ação:
--   A. Re-aplica recebimento_mensal (idempotente, sem impacto colateral)
--   B. Remove parcelas órfãs e adiciona FK constraint
-- ═══════════════════════════════════════════════════════════════════════

-- ─────────────────────────────────────────────────────────────────────
-- PARTE A: Corrigir recebimento_mensal (re-aplica migration 007)
-- ─────────────────────────────────────────────────────────────────────

UPDATE public.financiamentos f SET recebimento_mensal = 2950.00
FROM public.veiculos v WHERE f.veiculo_id = v.id AND v.placa = 'FXP6I84';

UPDATE public.financiamentos f SET recebimento_mensal = 2950.00
FROM public.veiculos v WHERE f.veiculo_id = v.id AND v.placa = 'FYG7B86';

UPDATE public.financiamentos f SET recebimento_mensal = 3000.00
FROM public.veiculos v WHERE f.veiculo_id = v.id AND v.placa = 'GEJ1H24';

UPDATE public.financiamentos f SET recebimento_mensal = 2950.00
FROM public.veiculos v WHERE f.veiculo_id = v.id AND v.placa = 'GJF0J81';

UPDATE public.financiamentos f SET recebimento_mensal = 5500.00
FROM public.veiculos v WHERE f.veiculo_id = v.id AND v.placa = 'RGC8F39';

UPDATE public.financiamentos f SET recebimento_mensal = 5700.00
FROM public.veiculos v WHERE f.veiculo_id = v.id AND v.placa IN (
  'SSY7I89','STE6H34','STY0J80','SVO7H22','SVR0J77','SWO0C65','SWP6H65'
);

-- ─────────────────────────────────────────────────────────────────────
-- PARTE B: Corrigir parcelas_financiamento órfãs
-- Remove parcelas cujo financiamento_id não referencia nenhum
-- financiamentos.id existente. Depois adiciona a FK que deveria
-- ter sido criada na migration 015.
-- ─────────────────────────────────────────────────────────────────────

-- 1. Conta órfãos antes de remover (para auditoria)
DO $$
DECLARE
  v_orfas INTEGER;
BEGIN
  SELECT COUNT(*) INTO v_orfas
  FROM public.parcelas_financiamento pf
  WHERE pf.financiamento_id IS NOT NULL
    AND NOT EXISTS (
      SELECT 1 FROM public.financiamentos f WHERE f.id = pf.financiamento_id
    );
  RAISE NOTICE 'parcelas órfãs encontradas: %', v_orfas;
END $$;

-- 2. Remove órfãos
DELETE FROM public.parcelas_financiamento
WHERE financiamento_id IS NOT NULL
  AND NOT EXISTS (
    SELECT 1 FROM public.financiamentos f WHERE f.id = financiamento_id
  );

-- 3. Adiciona FK constraint (só funciona se não houver mais órfãos)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.table_constraints
    WHERE table_name = 'parcelas_financiamento'
      AND constraint_name = 'parcelas_financiamento_financiamento_id_fkey'
  ) THEN
    ALTER TABLE public.parcelas_financiamento
      ADD CONSTRAINT parcelas_financiamento_financiamento_id_fkey
      FOREIGN KEY (financiamento_id) REFERENCES public.financiamentos(id)
      ON DELETE CASCADE;
  END IF;
END $$;

-- ─────────────────────────────────────────────────────────────────────
-- VERIFICAÇÃO FINAL
-- ─────────────────────────────────────────────────────────────────────
SELECT v.placa, f.recebimento_mensal
FROM public.financiamentos f
JOIN public.veiculos v ON v.id = f.veiculo_id
WHERE f.recebimento_mensal > 0
ORDER BY v.placa;

SELECT
  'parcelas_financiamento' AS tabela,
  COUNT(*) AS registros
FROM public.parcelas_financiamento;
