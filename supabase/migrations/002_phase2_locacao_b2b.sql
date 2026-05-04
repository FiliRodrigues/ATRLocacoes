-- ═══════════════════════════════════════════════════════════════════════
-- ATR Locações — Phase 2 Migration: B2B/B2G Locação
-- Executa no Supabase SQL Editor após a migration 001
-- ═══════════════════════════════════════════════════════════════════════

-- ──────────────────────────────────────────────────────────────────────
-- 1. ENUM: tipo de ocorrência
-- ──────────────────────────────────────────────────────────────────────
DO $$ BEGIN
  CREATE TYPE ocorrencia_tipo AS ENUM ('multa', 'sinistro', 'avaria', 'outro');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE ocorrencia_status AS ENUM ('aberta', 'em_analise', 'resolvida', 'cancelada');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE checklist_tipo AS ENUM ('check_in', 'check_out');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE contrato_status AS ENUM ('ativo', 'encerrado', 'suspenso', 'rascunho');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- ──────────────────────────────────────────────────────────────────────
-- 2. TABELA: contratos
-- ──────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.contratos (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  numero              TEXT NOT NULL UNIQUE,           -- ex: "CTR-2026-001"
  cliente_nome        TEXT NOT NULL,
  cliente_cnpj        TEXT NOT NULL,
  cliente_contato     TEXT NOT NULL DEFAULT '',
  veiculo_placa       TEXT NOT NULL REFERENCES public.veiculos(placa),
  data_inicio         DATE NOT NULL,
  data_fim            DATE NOT NULL,
  sla_km_mes          INTEGER NOT NULL DEFAULT 0,     -- KM contratado/mês
  valor_mensal        NUMERIC(12,2) NOT NULL DEFAULT 0,
  status              contrato_status NOT NULL DEFAULT 'rascunho',
  observacoes         TEXT NOT NULL DEFAULT '',
  criado_por          TEXT NOT NULL DEFAULT '',
  created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

DROP TRIGGER IF EXISTS trg_contratos_updated_at ON public.contratos;
CREATE TRIGGER trg_contratos_updated_at
  BEFORE UPDATE ON public.contratos
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE INDEX IF NOT EXISTS idx_contratos_placa
  ON public.contratos (veiculo_placa, status);

CREATE INDEX IF NOT EXISTS idx_contratos_cnpj
  ON public.contratos (cliente_cnpj);

-- ──────────────────────────────────────────────────────────────────────
-- 3. TABELA: checklist_eventos  (check-in / check-out)
-- ──────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.checklist_eventos (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  contrato_id     UUID NOT NULL REFERENCES public.contratos(id) ON DELETE CASCADE,
  tipo            checklist_tipo NOT NULL,
  km_odometro     INTEGER NOT NULL DEFAULT 0,
  km_percorridos  INTEGER,                            -- preenchido no check-out
  combustivel_pct INTEGER NOT NULL DEFAULT 100,       -- 0–100
  observacoes     TEXT NOT NULL DEFAULT '',
  fotos           TEXT[] NOT NULL DEFAULT '{}',       -- URLs Supabase Storage
  doc_url         TEXT,                               -- URL documento PDF
  assinatura_url  TEXT,                               -- URL imagem assinatura
  realizado_por   TEXT NOT NULL DEFAULT '',
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_checklist_contrato
  ON public.checklist_eventos (contrato_id, tipo, created_at DESC);

-- ──────────────────────────────────────────────────────────────────────
-- 4. TABELA: ocorrencias
-- ──────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.ocorrencias (
  id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  contrato_id           UUID NOT NULL REFERENCES public.contratos(id) ON DELETE CASCADE,
  tipo                  ocorrencia_tipo NOT NULL,
  status                ocorrencia_status NOT NULL DEFAULT 'aberta',
  descricao             TEXT NOT NULL,
  data_ocorrencia       DATE NOT NULL DEFAULT CURRENT_DATE,
  valor_estimado        NUMERIC(12,2) NOT NULL DEFAULT 0,
  valor_final           NUMERIC(12,2),               -- preenchido ao resolver
  impacto_financeiro    NUMERIC(12,2) NOT NULL DEFAULT 0, -- deduzido do contrato
  responsavel_pagamento TEXT NOT NULL DEFAULT 'cliente', -- 'cliente' | 'seguro' | 'atr'
  fotos                 TEXT[] NOT NULL DEFAULT '{}',
  observacoes           TEXT NOT NULL DEFAULT '',
  registrado_por        TEXT NOT NULL DEFAULT '',
  resolvido_por         TEXT,
  data_resolucao        DATE,
  created_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at            TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

DROP TRIGGER IF EXISTS trg_ocorrencias_updated_at ON public.ocorrencias;
CREATE TRIGGER trg_ocorrencias_updated_at
  BEFORE UPDATE ON public.ocorrencias
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE INDEX IF NOT EXISTS idx_ocorrencias_contrato
  ON public.ocorrencias (contrato_id, status);

-- ──────────────────────────────────────────────────────────────────────
-- 5. VIEW: resumo financeiro por contrato
-- ──────────────────────────────────────────────────────────────────────
CREATE OR REPLACE VIEW public.vw_contrato_financeiro AS
SELECT
  c.id                                             AS contrato_id,
  c.numero,
  c.cliente_nome,
  c.veiculo_placa,
  c.valor_mensal,
  c.data_inicio,
  c.data_fim,
  c.status,
  COALESCE(SUM(o.impacto_financeiro), 0)           AS total_ocorrencias,
  c.valor_mensal - COALESCE(SUM(o.impacto_financeiro), 0) AS saldo_liquido,
  COUNT(o.id) FILTER (WHERE o.status = 'aberta')   AS ocorrencias_abertas
FROM public.contratos c
LEFT JOIN public.ocorrencias o ON o.contrato_id = c.id
GROUP BY c.id;

-- ──────────────────────────────────────────────────────────────────────
-- 6. RLS
-- ──────────────────────────────────────────────────────────────────────
ALTER TABLE public.contratos         ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.checklist_eventos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ocorrencias       ENABLE ROW LEVEL SECURITY;

-- contratos
DROP POLICY IF EXISTS "contratos_select" ON public.contratos;
DROP POLICY IF EXISTS "contratos_insert" ON public.contratos;
DROP POLICY IF EXISTS "contratos_update" ON public.contratos;
DROP POLICY IF EXISTS "contratos_delete" ON public.contratos;
CREATE POLICY "contratos_select" ON public.contratos FOR SELECT USING (true);
CREATE POLICY "contratos_insert" ON public.contratos FOR INSERT WITH CHECK (true);
CREATE POLICY "contratos_update" ON public.contratos FOR UPDATE USING (true);
CREATE POLICY "contratos_delete" ON public.contratos FOR DELETE USING (true);

-- checklist_eventos
DROP POLICY IF EXISTS "checklist_select" ON public.checklist_eventos;
DROP POLICY IF EXISTS "checklist_insert" ON public.checklist_eventos;
CREATE POLICY "checklist_select" ON public.checklist_eventos FOR SELECT USING (true);
CREATE POLICY "checklist_insert" ON public.checklist_eventos FOR INSERT WITH CHECK (true);

-- ocorrencias
DROP POLICY IF EXISTS "ocorrencias_select" ON public.ocorrencias;
DROP POLICY IF EXISTS "ocorrencias_insert" ON public.ocorrencias;
DROP POLICY IF EXISTS "ocorrencias_update" ON public.ocorrencias;
CREATE POLICY "ocorrencias_select" ON public.ocorrencias FOR SELECT USING (true);
CREATE POLICY "ocorrencias_insert" ON public.ocorrencias FOR INSERT WITH CHECK (true);
CREATE POLICY "ocorrencias_update" ON public.ocorrencias FOR UPDATE USING (true);

-- ──────────────────────────────────────────────────────────────────────
-- FIM DA MIGRATION
-- ──────────────────────────────────────────────────────────────────────
