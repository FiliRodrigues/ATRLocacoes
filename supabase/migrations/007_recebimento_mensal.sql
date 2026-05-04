-- Migration 007: atualizar recebimento_mensal dos financiamentos com valores reais da planilha
-- Fonte: "Entrada de valores de Locação" de cada aba do Excel

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

-- 7 Toros: SSY7I89, STE6H34, STY0J80, SVO7H22, SVR0J77, SWO0C65, SWP6H65
UPDATE public.financiamentos f SET recebimento_mensal = 5700.00
FROM public.veiculos v WHERE f.veiculo_id = v.id AND v.placa IN (
  'SSY7I89','STE6H34','STY0J80','SVO7H22','SVR0J77','SWO0C65','SWP6H65'
);

-- Verificação
SELECT v.placa, f.situacao, f.recebimento_mensal
FROM public.financiamentos f
JOIN public.veiculos v ON v.id = f.veiculo_id
ORDER BY v.placa;
