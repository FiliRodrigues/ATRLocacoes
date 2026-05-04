-- Migration 008: Corrige taxa_juros_mensal para refletir contratos reais
-- Argos FXP6I84 e GJF0J81: taxa real ~1.45%/mês (PMT ≈ R$1.822/mês)
-- Toros (7 unidades): taxa real ~1.425%/mês (PMT ≈ R$4.867/mês)
-- DLA0A69: corrige quantidade_parcelas de 2 para 1 (veículo quitado/próprio)
--
-- Verificação fórmula Price (taxa 1.45%, PV=50844.40, n=36):
--   PMT = 50844.40 × (0.0145 × 1.0145^36) / (1.0145^36 − 1) ≈ R$1.822
-- Verificação fórmula Price (taxa 1.425%, PV=136323.80, n=36):
--   PMT = 136323.80 × (0.01425 × 1.01425^36) / (1.01425^36 − 1) ≈ R$4.867

-- Argos financiados
UPDATE financiamentos f
SET taxa_juros_mensal = 0.0145
FROM veiculos v
WHERE f.veiculo_id = v.id
  AND v.placa IN ('FXP6I84', 'GJF0J81');

-- Toros financiadas (7 unidades)
UPDATE financiamentos f
SET taxa_juros_mensal = 0.01425,
    recebimento_mensal = 5750,
    recebimento_mensal = 5750
FROM veiculos v
WHERE f.veiculo_id = v.id
  AND v.placa IN ('SSY7I89','STE6H34','STY0J80','SVO7H22','SVR0J77','SWO0C65','SWP6H65');

-- DLA0A69: veículo próprio com qt=2 por engano — corrige para 1
UPDATE financiamentos f
SET quantidade_parcelas = 1
FROM veiculos v
WHERE f.veiculo_id = v.id
  AND v.placa = 'DLA0A69';
