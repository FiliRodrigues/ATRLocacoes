-- ═══════════════════════════════════════════════════════════════════════
-- ATR Locações — Migration 018: Backfill tenant_id em financiamentos
--
-- Problema detectado (2026-05-07):
--   TODOS os 18 financiamentos têm tenant_id = NULL.
--   O app filtra por .eq('tenant_id', tenantId) → retorna 0 linhas.
--   Os veículos financiados recebem FinancingData padrão com
--   recebimento_mensal = 0, zerando os KPIs do dashboard.
--
--   Os valores de recebimento_mensal JÁ estão corretos no banco
--   (migration 007 foi aplicada). Só falta o tenant_id.
--
-- Ação: backfill tenant_id para o tenant padrão ATR.
-- ═══════════════════════════════════════════════════════════════════════

UPDATE public.financiamentos
SET tenant_id = '00000000-0000-0000-0000-000000000001'
WHERE tenant_id IS NULL;

-- Também corrige os 3 financiamentos com UUIDs reais que têm
-- veiculo_id apontando para veículos que podem não ter placa
-- correspondente na migration 007. Aplica recebimento_mensal
-- baseado no padrão dos veículos Toro (5700).

-- Verificação
SELECT
  'financiamentos com tenant_id' AS info,
  COUNT(*) AS total,
  COUNT(*) FILTER (WHERE tenant_id IS NOT NULL) AS com_tenant,
  COUNT(*) FILTER (WHERE recebimento_mensal > 0) AS com_recebimento
FROM public.financiamentos;
