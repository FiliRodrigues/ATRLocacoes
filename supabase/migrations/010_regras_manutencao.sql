-- ═══════════════════════════════════════════════════════════════════════
-- ATR Locações — Migration 010: Tabela de Regras de Manutenção Preventiva
--
-- Permite configurar regras por KM e/ou dias que disparam automaticamente
-- OS (Ordens de Serviço) no Kanban de manutenção.
--
-- REQUER: migrations 001–009 já executadas.
-- ═══════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS public.regras_manutencao (
  id                    TEXT PRIMARY KEY,
  titulo                TEXT NOT NULL,
  tipo                  TEXT NOT NULL,
  veiculo_placa         TEXT,                           -- NULL = aplica a todos
  intervalo_km          INTEGER,                        -- ex: 10000 (a cada 10k km)
  intervalo_dias        INTEGER,                        -- ex: 180 (a cada 6 meses)
  custo_estimado        NUMERIC(12, 2) NOT NULL DEFAULT 0,
  prioridade            TEXT NOT NULL DEFAULT 'media',
  is_ativa              BOOLEAN NOT NULL DEFAULT true,
  km_ultima_execucao    INTEGER,
  data_ultima_execucao  TIMESTAMPTZ,
  tenant_id             UUID REFERENCES public.tenants(id),
  created_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT chk_regras_criterio CHECK (
    intervalo_km IS NOT NULL OR intervalo_dias IS NOT NULL
  )
);

DROP TRIGGER IF EXISTS trg_regras_manutencao_updated_at ON public.regras_manutencao;
CREATE TRIGGER trg_regras_manutencao_updated_at
  BEFORE UPDATE ON public.regras_manutencao
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE INDEX IF NOT EXISTS idx_regras_manutencao_tenant
  ON public.regras_manutencao (tenant_id, is_ativa);

CREATE INDEX IF NOT EXISTS idx_regras_manutencao_placa
  ON public.regras_manutencao (veiculo_placa)
  WHERE veiculo_placa IS NOT NULL;

ALTER TABLE public.regras_manutencao ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "regras_select" ON public.regras_manutencao;
CREATE POLICY "regras_select" ON public.regras_manutencao
  FOR SELECT USING (true);

DROP POLICY IF EXISTS "regras_insert" ON public.regras_manutencao;
CREATE POLICY "regras_insert" ON public.regras_manutencao
  FOR INSERT WITH CHECK (true);

DROP POLICY IF EXISTS "regras_update" ON public.regras_manutencao;
CREATE POLICY "regras_update" ON public.regras_manutencao
  FOR UPDATE USING (true);

DROP POLICY IF EXISTS "regras_delete" ON public.regras_manutencao;
CREATE POLICY "regras_delete" ON public.regras_manutencao
  FOR DELETE USING (true);

-- ──────────────────────────────────────────────────────────────────────
-- Regras padrão (seeds) — equivalentes às boas práticas do mercado
-- ──────────────────────────────────────────────────────────────────────
INSERT INTO public.regras_manutencao
  (id, titulo, tipo, intervalo_km, intervalo_dias, custo_estimado, prioridade, tenant_id)
VALUES
  ('regra-oleo-10k',    'Troca de Óleo e Filtro',         'Troca de Óleo',          10000, 180,  450.00, 'alta',  '00000000-0000-0000-0000-000000000001'),
  ('regra-revisao-40k', 'Revisão Periódica 40k',          'Revisão Periódica',      40000, 365, 1800.00, 'alta',  '00000000-0000-0000-0000-000000000001'),
  ('regra-pneus-60k',   'Inspeção de Pneus 60k',          'Pneus',                  60000, NULL,  300.00, 'media', '00000000-0000-0000-0000-000000000001'),
  ('regra-pastilhas',   'Troca de Pastilhas de Freio',    'Freios',                 40000, NULL,  600.00, 'alta',  '00000000-0000-0000-0000-000000000001'),
  ('regra-correia',     'Inspeção de Correia Dentada',    'Correia Dentada',         NULL, 730, 1200.00, 'alta',  '00000000-0000-0000-0000-000000000001'),
  ('regra-ar-cond',     'Manutenção Ar-Condicionado',     'Ar-Condicionado',         NULL, 365,  350.00, 'baixa', '00000000-0000-0000-0000-000000000001')
ON CONFLICT (id) DO NOTHING;
