-- ═══════════════════════════════════════════════════════════════════════
-- ATR Locações — Phase 1 Migration
-- Executa no Supabase SQL Editor (Dashboard > SQL Editor > New Query)
-- ═══════════════════════════════════════════════════════════════════════

-- ──────────────────────────────────────────────────────────────────────
-- 1. EXTENSÕES
-- ──────────────────────────────────────────────────────────────────────
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ──────────────────────────────────────────────────────────────────────
-- 2. TABELA: manutencoes
-- ──────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.manutencoes (
  id              TEXT PRIMARY KEY,
  veiculo_placa   TEXT NOT NULL,
  veiculo_nome    TEXT NOT NULL DEFAULT '',
  titulo          TEXT NOT NULL,
  descricao       TEXT NOT NULL DEFAULT '',
  tipo            TEXT NOT NULL,
  data            TIMESTAMPTZ NOT NULL,
  km_no_servico   INTEGER NOT NULL DEFAULT 0,
  odometro        INTEGER NOT NULL DEFAULT 0,
  custo           NUMERIC(12, 2) NOT NULL DEFAULT 0,
  prioridade      TEXT NOT NULL DEFAULT 'media',
  coluna          TEXT NOT NULL DEFAULT 'pendentes',
  fornecedor      TEXT NOT NULL DEFAULT '',
  numero_os       TEXT NOT NULL DEFAULT '',
  nome_anexo      TEXT NOT NULL DEFAULT '',
  is_preventiva   BOOLEAN NOT NULL DEFAULT TRUE,
  data_conclusao  TIMESTAMPTZ,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_manutencoes_updated_at ON public.manutencoes;
CREATE TRIGGER trg_manutencoes_updated_at
  BEFORE UPDATE ON public.manutencoes
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ──────────────────────────────────────────────────────────────────────
-- 3. TABELA: despesas
-- ──────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.despesas (
  id            TEXT PRIMARY KEY,
  veiculo_placa TEXT NOT NULL,
  motorista     TEXT NOT NULL DEFAULT '',
  data          TIMESTAMPTZ NOT NULL,
  tipo          TEXT NOT NULL,
  descricao     TEXT NOT NULL DEFAULT '',
  odometro      INTEGER NOT NULL DEFAULT 0,
  litros        NUMERIC(8, 2) NOT NULL DEFAULT 0,
  valor         NUMERIC(12, 2) NOT NULL DEFAULT 0,
  pago          BOOLEAN NOT NULL DEFAULT FALSE,
  nf            TEXT NOT NULL DEFAULT '',
  nome_anexo    TEXT NOT NULL DEFAULT '',
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

DROP TRIGGER IF EXISTS trg_despesas_updated_at ON public.despesas;
CREATE TRIGGER trg_despesas_updated_at
  BEFORE UPDATE ON public.despesas
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ──────────────────────────────────────────────────────────────────────
-- 4. TABELA: hodometros  (histórico de leituras KM)
-- ──────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.hodometros (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  veiculo_placa   TEXT NOT NULL,
  km              INTEGER NOT NULL,
  registrado_por  TEXT NOT NULL DEFAULT '',
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_hodometros_placa_data
  ON public.hodometros (veiculo_placa, created_at DESC);

-- ──────────────────────────────────────────────────────────────────────
-- 5. ATUALIZAR tabela veiculos (colunas de status persistido)
-- ──────────────────────────────────────────────────────────────────────
ALTER TABLE public.veiculos
  ADD COLUMN IF NOT EXISTS km_atual               INTEGER,
  ADD COLUMN IF NOT EXISTS status_alterado_por    TEXT,
  ADD COLUMN IF NOT EXISTS status_atualizado_em   TIMESTAMPTZ;

-- ──────────────────────────────────────────────────────────────────────
-- 6. TABELA: audit_log  (append-only — sem UPDATE/DELETE)
-- ──────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.audit_log (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  username    TEXT NOT NULL DEFAULT 'desconhecido',
  action      TEXT NOT NULL,
  entity      TEXT NOT NULL,
  entity_id   TEXT,
  payload     JSONB,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_audit_log_entity
  ON public.audit_log (entity, entity_id, created_at DESC);

-- ──────────────────────────────────────────────────────────────────────
-- 7. RLS — Habilitar em todas as tabelas operacionais
-- ──────────────────────────────────────────────────────────────────────
ALTER TABLE public.manutencoes  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.despesas     ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hodometros   ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.audit_log    ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.veiculos     ENABLE ROW LEVEL SECURITY;

-- ──────────────────────────────────────────────────────────────────────
-- 8. RLS POLICIES
-- Estratégia atual: anon key autenticado pelo app (sem Supabase Auth real).
-- Policies permitem acesso total via service_role (backend) e leitura
-- via anon (app). Quando Supabase Auth for implantado, substituir
-- "true" por "auth.role() = 'authenticated'".
-- ──────────────────────────────────────────────────────────────────────

-- manutencoes
DROP POLICY IF EXISTS "manutencoes_select" ON public.manutencoes;
DROP POLICY IF EXISTS "manutencoes_insert" ON public.manutencoes;
DROP POLICY IF EXISTS "manutencoes_update" ON public.manutencoes;
DROP POLICY IF EXISTS "manutencoes_delete" ON public.manutencoes;

CREATE POLICY "manutencoes_select" ON public.manutencoes FOR SELECT USING (true);
CREATE POLICY "manutencoes_insert" ON public.manutencoes FOR INSERT WITH CHECK (true);
CREATE POLICY "manutencoes_update" ON public.manutencoes FOR UPDATE USING (true);
CREATE POLICY "manutencoes_delete" ON public.manutencoes FOR DELETE USING (true);

-- despesas
DROP POLICY IF EXISTS "despesas_select" ON public.despesas;
DROP POLICY IF EXISTS "despesas_insert" ON public.despesas;
DROP POLICY IF EXISTS "despesas_update" ON public.despesas;
DROP POLICY IF EXISTS "despesas_delete" ON public.despesas;

CREATE POLICY "despesas_select" ON public.despesas FOR SELECT USING (true);
CREATE POLICY "despesas_insert" ON public.despesas FOR INSERT WITH CHECK (true);
CREATE POLICY "despesas_update" ON public.despesas FOR UPDATE USING (true);
CREATE POLICY "despesas_delete" ON public.despesas FOR DELETE USING (true);

-- hodometros
DROP POLICY IF EXISTS "hodometros_select" ON public.hodometros;
DROP POLICY IF EXISTS "hodometros_insert" ON public.hodometros;

CREATE POLICY "hodometros_select" ON public.hodometros FOR SELECT USING (true);
CREATE POLICY "hodometros_insert" ON public.hodometros FOR INSERT WITH CHECK (true);

-- veiculos
DROP POLICY IF EXISTS "veiculos_select" ON public.veiculos;
DROP POLICY IF EXISTS "veiculos_update" ON public.veiculos;

CREATE POLICY "veiculos_select" ON public.veiculos FOR SELECT USING (true);
CREATE POLICY "veiculos_update" ON public.veiculos FOR UPDATE USING (true);

-- audit_log  (insert-only: nenhum cliente pode ler ou deletar)
DROP POLICY IF EXISTS "audit_log_insert" ON public.audit_log;

CREATE POLICY "audit_log_insert" ON public.audit_log FOR INSERT WITH CHECK (true);

-- ──────────────────────────────────────────────────────────────────────
-- FIM DA MIGRATION
-- ──────────────────────────────────────────────────────────────────────
