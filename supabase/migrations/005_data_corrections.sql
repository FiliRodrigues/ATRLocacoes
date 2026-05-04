-- ================================================================
-- ATR Locações — Correções de dados identificadas na comparação Excel vs DB
-- Data: 2026-05-04
-- ================================================================

-- ----------------------------------------------------------------
-- 1. MANUTENÇÕES — 3 registros faltando no banco (existem no Excel)
-- ----------------------------------------------------------------

-- FDI4E96: JULHO/2023 = R$1.920,00
INSERT INTO public.manutencoes (
  veiculo_id, data_servico, descricao, tipo_servico,
  valor_servico, km_registro, status_pagamento, observacoes, tenant_id
)
SELECT
  v.id,
  '2023-07-01'::date,
  'Manutenção/Revisão – Julho 2023',
  'Revisão',
  1920.00,
  NULL,
  'Pago',
  'Lançamento importado do Controle Veículos ATR.xlsx',
  v.tenant_id
FROM public.veiculos v
WHERE v.placa = 'FDI4E96';

-- FSW7F45: JUNHO/2023 = R$9.576,24
INSERT INTO public.manutencoes (
  veiculo_id, data_servico, descricao, tipo_servico,
  valor_servico, km_registro, status_pagamento, observacoes, tenant_id
)
SELECT
  v.id,
  '2023-06-01'::date,
  'Manutenção/Revisão – Junho 2023',
  'Revisão',
  9576.24,
  NULL,
  'Pago',
  'Lançamento importado do Controle Veículos ATR.xlsx',
  v.tenant_id
FROM public.veiculos v
WHERE v.placa = 'FSW7F45';

-- FYG7B86: SETEMBRO/2023 = R$795,00
INSERT INTO public.manutencoes (
  veiculo_id, data_servico, descricao, tipo_servico,
  valor_servico, km_registro, status_pagamento, observacoes, tenant_id
)
SELECT
  v.id,
  '2023-09-01'::date,
  'Manutenção/Revisão – Setembro 2023',
  'Revisão',
  795.00,
  NULL,
  'Pago',
  'Lançamento importado do Controle Veículos ATR.xlsx',
  v.tenant_id
FROM public.veiculos v
WHERE v.placa = 'FYG7B86';

-- ----------------------------------------------------------------
-- 2. SEGURO — Correção de typo na empresa FSW7F45
-- ----------------------------------------------------------------
UPDATE public.seguros s
SET empresa = 'Liberty Seguros'
FROM public.veiculos v
WHERE s.veiculo_id = v.id
  AND v.placa = 'FSW7F45'
  AND s.empresa = 'Lyberti Seguros';

-- ----------------------------------------------------------------
-- 3. FINANCIAMENTOS faltando — veículos quitados sem registro
-- ----------------------------------------------------------------

-- RNZ1B74: Quitado (sem valores preenchidos no Excel)
INSERT INTO public.financiamentos (
  veiculo_id, situacao, valor_total_veiculo, valor_entrada,
  valor_financiado, valor_ja_pago
)
SELECT
  v.id,
  'Quitada',
  NULL, NULL, 0.00, NULL
FROM public.veiculos v
WHERE v.placa = 'RNZ1B74'
  AND NOT EXISTS (
    SELECT 1 FROM public.financiamentos f WHERE f.veiculo_id = v.id
  );

-- RNC2E57: Quitado (sem valores preenchidos no Excel)
INSERT INTO public.financiamentos (
  veiculo_id, situacao, valor_total_veiculo, valor_entrada,
  valor_financiado, valor_ja_pago
)
SELECT
  v.id,
  'Quitada',
  NULL, NULL, 0.00, NULL
FROM public.veiculos v
WHERE v.placa = 'RNC2E57'
  AND NOT EXISTS (
    SELECT 1 FROM public.financiamentos f WHERE f.veiculo_id = v.id
  );

-- UES1J20: Financiado (valores não preenchidos no Excel — aguarda preenchimento)
INSERT INTO public.financiamentos (
  veiculo_id, situacao, valor_total_veiculo, valor_entrada,
  valor_financiado, valor_ja_pago
)
SELECT
  v.id,
  'Financiado',
  NULL, NULL, NULL, NULL
FROM public.veiculos v
WHERE v.placa = 'UES1J20'
  AND NOT EXISTS (
    SELECT 1 FROM public.financiamentos f WHERE f.veiculo_id = v.id
  );

-- ----------------------------------------------------------------
-- 4. VERIFICAÇÃO FINAL
-- ----------------------------------------------------------------
SELECT 'manutencoes' as tabela, COUNT(*) as total FROM public.manutencoes
UNION ALL
SELECT 'financiamentos', COUNT(*) FROM public.financiamentos;
