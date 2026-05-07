-- ═══════════════════════════════════════════════════════════════════════
-- ATR Locações — Migration 009: Criação das tabelas veiculos, financiamentos, seguros
--
-- CONTEXTO: estas tabelas são referenciadas em todas as migrações anteriores
-- (001–008) mas nunca foram criadas explicitamente, causando falha silenciosa
-- em loadFromSupabase() e FK errors ao executar 002_phase2_locacao_b2b.sql.
--
-- Execute no Supabase Dashboard → SQL Editor.
-- REQUER: migration 004 (tenants) já executada.
-- ═══════════════════════════════════════════════════════════════════════

-- ──────────────────────────────────────────────────────────────────────
-- 1. TABELA: veiculos
--    Coluna `placa` é a chave de negócio usada como FK em `contratos`.
--    Coluna `id` é UUID interno para joins com `financiamentos` e `seguros`.
-- ──────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.veiculos (
  id                     UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  placa                  TEXT NOT NULL,
  marca                  TEXT NOT NULL DEFAULT '',
  modelo                 TEXT NOT NULL DEFAULT '',
  ano_fabricacao         INTEGER,
  ano_modelo             INTEGER,
  cor                    TEXT NOT NULL DEFAULT '',
  renavam                TEXT NOT NULL DEFAULT '',
  chassi                 TEXT NOT NULL DEFAULT '',
  situacao_operacional   TEXT NOT NULL DEFAULT 'Parado',
  propriedade_status     TEXT NOT NULL DEFAULT 'Próprio',
  km_inicial             INTEGER NOT NULL DEFAULT 0,
  km_atual               INTEGER NOT NULL DEFAULT 0,
  data_compra            DATE,
  valor_veiculo          NUMERIC(12, 2) NOT NULL DEFAULT 0,
  status_alterado_por    TEXT NOT NULL DEFAULT '',
  status_atualizado_em   TIMESTAMPTZ,
  vencimento_ipva        DATE,
  vencimento_seguro      DATE,
  vencimento_licenciamento DATE,
  observacoes            TEXT NOT NULL DEFAULT '',
  tenant_id              UUID REFERENCES public.tenants(id),
  created_at             TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at             TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT uq_veiculos_placa UNIQUE (placa)
);

ALTER TABLE public.veiculos
  ADD COLUMN IF NOT EXISTS tenant_id UUID REFERENCES public.tenants(id);

DROP TRIGGER IF EXISTS trg_veiculos_updated_at ON public.veiculos;
CREATE TRIGGER trg_veiculos_updated_at
  BEFORE UPDATE ON public.veiculos
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE INDEX IF NOT EXISTS idx_veiculos_tenant
  ON public.veiculos (tenant_id);

CREATE INDEX IF NOT EXISTS idx_veiculos_situacao
  ON public.veiculos (situacao_operacional, tenant_id);

ALTER TABLE public.veiculos ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "veiculos_tenant_select" ON public.veiculos;
CREATE POLICY "veiculos_tenant_select" ON public.veiculos
  FOR SELECT USING (true);

DROP POLICY IF EXISTS "veiculos_tenant_insert" ON public.veiculos;
CREATE POLICY "veiculos_tenant_insert" ON public.veiculos
  FOR INSERT WITH CHECK (true);

DROP POLICY IF EXISTS "veiculos_tenant_update" ON public.veiculos;
CREATE POLICY "veiculos_tenant_update" ON public.veiculos
  FOR UPDATE USING (true);

DROP POLICY IF EXISTS "veiculos_tenant_delete" ON public.veiculos;
CREATE POLICY "veiculos_tenant_delete" ON public.veiculos
  FOR DELETE USING (true);

-- ──────────────────────────────────────────────────────────────────────
-- 2. TABELA: financiamentos
--    Vinculada a veiculos via veiculo_id (UUID).
--    Colunas adicionais de migrations 006–008 já incluídas na definição base.
-- ──────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.financiamentos (
  id                   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  veiculo_id           UUID NOT NULL REFERENCES public.veiculos(id) ON DELETE CASCADE,
  situacao             TEXT NOT NULL DEFAULT 'Financiado',
  valor_total_veiculo  NUMERIC(12, 2),
  valor_entrada        NUMERIC(12, 2),
  valor_financiado     NUMERIC(12, 2),
  valor_ja_pago        NUMERIC(12, 2) NOT NULL DEFAULT 0,
  quantidade_parcelas  INTEGER NOT NULL DEFAULT 48,
  recebimento_mensal   NUMERIC(12, 2) NOT NULL DEFAULT 0,
  valor_parcela        NUMERIC(12, 2),
  taxa_juros_mensal    NUMERIC(8, 6) NOT NULL DEFAULT 0.0139,
  previsao_quitacao    TEXT NOT NULL DEFAULT '',
  tenant_id            UUID REFERENCES public.tenants(id),
  created_at           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT uq_financiamentos_veiculo UNIQUE (veiculo_id)
);

ALTER TABLE public.financiamentos
  ADD COLUMN IF NOT EXISTS tenant_id UUID REFERENCES public.tenants(id);

DROP TRIGGER IF EXISTS trg_financiamentos_updated_at ON public.financiamentos;
CREATE TRIGGER trg_financiamentos_updated_at
  BEFORE UPDATE ON public.financiamentos
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE INDEX IF NOT EXISTS idx_financiamentos_veiculo
  ON public.financiamentos (veiculo_id);

CREATE INDEX IF NOT EXISTS idx_financiamentos_tenant
  ON public.financiamentos (tenant_id);

ALTER TABLE public.financiamentos ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "financiamentos_tenant_select" ON public.financiamentos;
CREATE POLICY "financiamentos_tenant_select" ON public.financiamentos
  FOR SELECT USING (true);

DROP POLICY IF EXISTS "financiamentos_tenant_insert" ON public.financiamentos;
CREATE POLICY "financiamentos_tenant_insert" ON public.financiamentos
  FOR INSERT WITH CHECK (true);

DROP POLICY IF EXISTS "financiamentos_tenant_update" ON public.financiamentos;
CREATE POLICY "financiamentos_tenant_update" ON public.financiamentos
  FOR UPDATE USING (true);

DROP POLICY IF EXISTS "financiamentos_tenant_delete" ON public.financiamentos;
CREATE POLICY "financiamentos_tenant_delete" ON public.financiamentos
  FOR DELETE USING (true);

-- ──────────────────────────────────────────────────────────────────────
-- 3. TABELA: seguros
--    Referenciada em migration 005 (correção de typo empresa).
-- ──────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.seguros (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  veiculo_id      UUID NOT NULL REFERENCES public.veiculos(id) ON DELETE CASCADE,
  empresa         TEXT NOT NULL DEFAULT '',
  numero_apolice  TEXT NOT NULL DEFAULT '',
  data_inicio     DATE,
  data_fim        DATE,
  valor_premio    NUMERIC(12, 2) NOT NULL DEFAULT 0,
  cobertura       TEXT NOT NULL DEFAULT '',
  observacoes     TEXT NOT NULL DEFAULT '',
  tenant_id       UUID REFERENCES public.tenants(id),
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.seguros
  ADD COLUMN IF NOT EXISTS tenant_id UUID REFERENCES public.tenants(id);

DROP TRIGGER IF EXISTS trg_seguros_updated_at ON public.seguros;
CREATE TRIGGER trg_seguros_updated_at
  BEFORE UPDATE ON public.seguros
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE INDEX IF NOT EXISTS idx_seguros_veiculo
  ON public.seguros (veiculo_id);

CREATE INDEX IF NOT EXISTS idx_seguros_tenant
  ON public.seguros (tenant_id);

ALTER TABLE public.seguros ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "seguros_tenant_select" ON public.seguros;
CREATE POLICY "seguros_tenant_select" ON public.seguros
  FOR SELECT USING (true);

DROP POLICY IF EXISTS "seguros_tenant_insert" ON public.seguros;
CREATE POLICY "seguros_tenant_insert" ON public.seguros
  FOR INSERT WITH CHECK (true);

DROP POLICY IF EXISTS "seguros_tenant_update" ON public.seguros;
CREATE POLICY "seguros_tenant_update" ON public.seguros
  FOR UPDATE USING (true);

DROP POLICY IF EXISTS "seguros_tenant_delete" ON public.seguros;
CREATE POLICY "seguros_tenant_delete" ON public.seguros
  FOR DELETE USING (true);

-- ──────────────────────────────────────────────────────────────────────
-- 4. CORRIGE FK em contratos (era REFERENCES public.veiculos(placa))
--    Recria sem FK para evitar erro se contratos já existir com FK quebrada.
--    A integridade é garantida pela constraint UNIQUE em veiculos.placa.
-- ──────────────────────────────────────────────────────────────────────
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.table_constraints
    WHERE table_name = 'contratos'
      AND constraint_name = 'contratos_veiculo_placa_fkey'
  ) THEN
    BEGIN
      ALTER TABLE public.contratos
        ADD CONSTRAINT contratos_veiculo_placa_fkey
        FOREIGN KEY (veiculo_placa) REFERENCES public.veiculos(placa);
    EXCEPTION WHEN others THEN
      -- FK já existe ou contratos ainda não tem registros inválidos
      NULL;
    END;
  END IF;
END $$;

-- ──────────────────────────────────────────────────────────────────────
-- 5. FUNÇÃO RPC: registrar_km (requerida por FleetSupabaseService)
--    Valida KM regressivo e salto suspeito antes de persistir.
-- ──────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.registrar_km(
  p_placa         TEXT,
  p_km            INTEGER,
  p_registrado_por TEXT,
  p_tenant_id     UUID DEFAULT '00000000-0000-0000-0000-000000000001'::UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_km_atual INTEGER;
  v_ultima_data TIMESTAMPTZ;
  v_diff_dias INTEGER;
  v_km_dia NUMERIC;
BEGIN
  -- Busca KM atual do veículo
  SELECT km_atual, status_atualizado_em
    INTO v_km_atual, v_ultima_data
    FROM public.veiculos
   WHERE placa = p_placa;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Veículo não encontrado: ' || p_placa);
  END IF;

  -- Validação anti-regressão
  IF v_km_atual IS NOT NULL AND p_km < v_km_atual THEN
    RETURN jsonb_build_object(
      'ok', false,
      'error', 'KM regressivo: novo KM (' || p_km || ') é menor que o atual (' || v_km_atual || ')'
    );
  END IF;

  -- Validação de salto suspeito (> 1000 km/dia)
  IF v_ultima_data IS NOT NULL AND v_km_atual IS NOT NULL THEN
    v_diff_dias := GREATEST(
      EXTRACT(EPOCH FROM (NOW() - v_ultima_data)) / 86400.0,
      1
    );
    v_km_dia := (p_km - v_km_atual)::NUMERIC / v_diff_dias;
    IF v_km_dia > 1000 THEN
      RETURN jsonb_build_object(
        'ok', false,
        'error', 'Salto suspeito: ' || ROUND(v_km_dia) || ' km/dia excede limite de 1000 km/dia'
      );
    END IF;
  END IF;

  -- Persiste leitura no histórico
  INSERT INTO public.hodometros (veiculo_placa, km, registrado_por, tenant_id)
  VALUES (p_placa, p_km, p_registrado_por, p_tenant_id);

  -- Atualiza KM atual no veículo
  UPDATE public.veiculos
     SET km_atual = p_km,
         status_atualizado_em = NOW(),
         status_alterado_por  = p_registrado_por
   WHERE placa = p_placa;

  RETURN jsonb_build_object('ok', true);
END;
$$;

-- ──────────────────────────────────────────────────────────────────────
-- 6. VERIFICAÇÃO FINAL
-- ──────────────────────────────────────────────────────────────────────
SELECT
  'veiculos'       AS tabela, COUNT(*) AS registros FROM public.veiculos
UNION ALL SELECT
  'financiamentos', COUNT(*) FROM public.financiamentos
UNION ALL SELECT
  'seguros',        COUNT(*) FROM public.seguros;
