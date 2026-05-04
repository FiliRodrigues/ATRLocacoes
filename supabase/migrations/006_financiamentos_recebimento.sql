-- Adiciona coluna recebimento_mensal à tabela financiamentos
-- Representa o valor mensal recebido do locatário para cobrir a parcela do financiamento.
ALTER TABLE public.financiamentos
  ADD COLUMN IF NOT EXISTS recebimento_mensal NUMERIC(12, 2) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS valor_parcela       NUMERIC(12, 2),
  ADD COLUMN IF NOT EXISTS taxa_juros_mensal   NUMERIC(8, 6)  NOT NULL DEFAULT 0.0139,
  ADD COLUMN IF NOT EXISTS previsao_quitacao   TEXT;

COMMENT ON COLUMN public.financiamentos.recebimento_mensal IS
  'Valor mensal recebido do locatário (aluguel). Usado para calcular receita vs custo da parcela.';
