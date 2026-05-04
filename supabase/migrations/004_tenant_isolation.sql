-- ═══════════════════════════════════════════════════════════════════════
-- ATR Locações — Migration 004: Tenant Isolation + Audit Expansion + KM Validation
-- Executa no Supabase Dashboard → SQL Editor
-- REQUER: migrations 001, 002, 003 já executadas
-- ═══════════════════════════════════════════════════════════════════════

-- ──────────────────────────────────────────────────────────────────────
-- 1. TABELA: tenants  (organizações/empresas)
-- ──────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.tenants (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  nome       TEXT NOT NULL,
  cnpj       TEXT NOT NULL DEFAULT '',
  ativo      BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.tenants ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "tenants_select" ON public.tenants;
CREATE POLICY "tenants_select" ON public.tenants
  FOR SELECT USING (true);

-- Tenant padrão ATR (UUID fixo para backfill controlado)
INSERT INTO public.tenants (id, nome, cnpj)
VALUES ('00000000-0000-0000-0000-000000000001', 'ATR Locações', '00.000.000/0001-00')
ON CONFLICT (id) DO NOTHING;

-- ──────────────────────────────────────────────────────────────────────
-- 2. ADICIONAR tenant_id nas tabelas operacionais
-- ──────────────────────────────────────────────────────────────────────
ALTER TABLE public.app_users
  ADD COLUMN IF NOT EXISTS tenant_id UUID REFERENCES public.tenants(id);

ALTER TABLE public.manutencoes
  ADD COLUMN IF NOT EXISTS tenant_id UUID REFERENCES public.tenants(id);

ALTER TABLE public.despesas
  ADD COLUMN IF NOT EXISTS tenant_id UUID REFERENCES public.tenants(id);

ALTER TABLE public.hodometros
  ADD COLUMN IF NOT EXISTS tenant_id UUID REFERENCES public.tenants(id);

ALTER TABLE public.veiculos
  ADD COLUMN IF NOT EXISTS tenant_id UUID REFERENCES public.tenants(id);

ALTER TABLE public.contratos
  ADD COLUMN IF NOT EXISTS tenant_id UUID REFERENCES public.tenants(id);

ALTER TABLE public.checklist_eventos
  ADD COLUMN IF NOT EXISTS tenant_id UUID REFERENCES public.tenants(id);

ALTER TABLE public.ocorrencias
  ADD COLUMN IF NOT EXISTS tenant_id UUID REFERENCES public.tenants(id);

-- ──────────────────────────────────────────────────────────────────────
-- 3. BACKFILL: atribuir tenant padrão a todos os registros existentes
-- ──────────────────────────────────────────────────────────────────────
UPDATE public.app_users
  SET tenant_id = '00000000-0000-0000-0000-000000000001'
  WHERE tenant_id IS NULL;

UPDATE public.manutencoes
  SET tenant_id = '00000000-0000-0000-0000-000000000001'
  WHERE tenant_id IS NULL;

UPDATE public.despesas
  SET tenant_id = '00000000-0000-0000-0000-000000000001'
  WHERE tenant_id IS NULL;

UPDATE public.hodometros
  SET tenant_id = '00000000-0000-0000-0000-000000000001'
  WHERE tenant_id IS NULL;

UPDATE public.veiculos
  SET tenant_id = '00000000-0000-0000-0000-000000000001'
  WHERE tenant_id IS NULL;

UPDATE public.contratos
  SET tenant_id = '00000000-0000-0000-0000-000000000001'
  WHERE tenant_id IS NULL;

UPDATE public.checklist_eventos
  SET tenant_id = '00000000-0000-0000-0000-000000000001'
  WHERE tenant_id IS NULL;

UPDATE public.ocorrencias
  SET tenant_id = '00000000-0000-0000-0000-000000000001'
  WHERE tenant_id IS NULL;

-- ──────────────────────────────────────────────────────────────────────
-- 4. APLICAR NOT NULL e DEFAULT após backfill
-- ──────────────────────────────────────────────────────────────────────
ALTER TABLE public.app_users
  ALTER COLUMN tenant_id SET NOT NULL,
  ALTER COLUMN tenant_id SET DEFAULT '00000000-0000-0000-0000-000000000001';

ALTER TABLE public.manutencoes
  ALTER COLUMN tenant_id SET NOT NULL,
  ALTER COLUMN tenant_id SET DEFAULT '00000000-0000-0000-0000-000000000001';

ALTER TABLE public.despesas
  ALTER COLUMN tenant_id SET NOT NULL,
  ALTER COLUMN tenant_id SET DEFAULT '00000000-0000-0000-0000-000000000001';

ALTER TABLE public.hodometros
  ALTER COLUMN tenant_id SET NOT NULL,
  ALTER COLUMN tenant_id SET DEFAULT '00000000-0000-0000-0000-000000000001';

ALTER TABLE public.veiculos
  ALTER COLUMN tenant_id SET NOT NULL,
  ALTER COLUMN tenant_id SET DEFAULT '00000000-0000-0000-0000-000000000001';

ALTER TABLE public.contratos
  ALTER COLUMN tenant_id SET NOT NULL,
  ALTER COLUMN tenant_id SET DEFAULT '00000000-0000-0000-0000-000000000001';

ALTER TABLE public.checklist_eventos
  ALTER COLUMN tenant_id SET NOT NULL,
  ALTER COLUMN tenant_id SET DEFAULT '00000000-0000-0000-0000-000000000001';

ALTER TABLE public.ocorrencias
  ALTER COLUMN tenant_id SET NOT NULL,
  ALTER COLUMN tenant_id SET DEFAULT '00000000-0000-0000-0000-000000000001';

-- ──────────────────────────────────────────────────────────────────────
-- 5. ÍNDICES de tenant para performance
-- ──────────────────────────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_app_users_tenant
  ON public.app_users (tenant_id, username);

CREATE INDEX IF NOT EXISTS idx_manutencoes_tenant
  ON public.manutencoes (tenant_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_despesas_tenant
  ON public.despesas (tenant_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_hodometros_tenant
  ON public.hodometros (tenant_id, veiculo_placa, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_veiculos_tenant
  ON public.veiculos (tenant_id);

CREATE INDEX IF NOT EXISTS idx_contratos_tenant
  ON public.contratos (tenant_id, status);

CREATE INDEX IF NOT EXISTS idx_checklist_tenant
  ON public.checklist_eventos (tenant_id, contrato_id);

CREATE INDEX IF NOT EXISTS idx_ocorrencias_tenant
  ON public.ocorrencias (tenant_id, contrato_id, status);

-- ──────────────────────────────────────────────────────────────────────
-- 6. FUNÇÃO AUXILIAR RLS: extrai tenant_id do JWT
-- ──────────────────────────────────────────────────────────────────────
-- Quando o app envia JWT customizado com claim "tenant_id", RLS o enforça.
-- Sem claim (anon key puro): retorna NULL → app-level filter é suficiente.
CREATE OR REPLACE FUNCTION public.jwt_tenant_id()
RETURNS UUID LANGUAGE sql STABLE SECURITY DEFINER AS $$
  SELECT NULLIF(
    COALESCE(
      (current_setting('request.jwt.claims', true)::jsonb ->> 'tenant_id'),
      ''
    ),
    ''
  )::uuid
$$;

-- ──────────────────────────────────────────────────────────────────────
-- 7. RLS ATUALIZADO — isolamento por tenant
-- Estratégia dupla:
--   a) Quando JWT tem tenant_id claim: RLS enforça estritamente.
--   b) Sem claim: permite acesso (app-level filter garante isolamento).
-- ──────────────────────────────────────────────────────────────────────

-- manutencoes
DROP POLICY IF EXISTS "manutencoes_select" ON public.manutencoes;
DROP POLICY IF EXISTS "manutencoes_insert" ON public.manutencoes;
DROP POLICY IF EXISTS "manutencoes_update" ON public.manutencoes;
DROP POLICY IF EXISTS "manutencoes_delete" ON public.manutencoes;
CREATE POLICY "manutencoes_tenant" ON public.manutencoes FOR ALL
  USING  (jwt_tenant_id() IS NULL OR tenant_id = jwt_tenant_id())
  WITH CHECK (jwt_tenant_id() IS NULL OR tenant_id = jwt_tenant_id());

-- despesas
DROP POLICY IF EXISTS "despesas_select" ON public.despesas;
DROP POLICY IF EXISTS "despesas_insert" ON public.despesas;
DROP POLICY IF EXISTS "despesas_update" ON public.despesas;
DROP POLICY IF EXISTS "despesas_delete" ON public.despesas;
CREATE POLICY "despesas_tenant" ON public.despesas FOR ALL
  USING  (jwt_tenant_id() IS NULL OR tenant_id = jwt_tenant_id())
  WITH CHECK (jwt_tenant_id() IS NULL OR tenant_id = jwt_tenant_id());

-- hodometros
DROP POLICY IF EXISTS "hodometros_select" ON public.hodometros;
DROP POLICY IF EXISTS "hodometros_insert" ON public.hodometros;
CREATE POLICY "hodometros_tenant" ON public.hodometros FOR ALL
  USING  (jwt_tenant_id() IS NULL OR tenant_id = jwt_tenant_id())
  WITH CHECK (jwt_tenant_id() IS NULL OR tenant_id = jwt_tenant_id());

-- veiculos
DROP POLICY IF EXISTS "veiculos_select" ON public.veiculos;
DROP POLICY IF EXISTS "veiculos_update" ON public.veiculos;
CREATE POLICY "veiculos_tenant" ON public.veiculos FOR ALL
  USING  (jwt_tenant_id() IS NULL OR tenant_id = jwt_tenant_id())
  WITH CHECK (jwt_tenant_id() IS NULL OR tenant_id = jwt_tenant_id());

-- contratos
DROP POLICY IF EXISTS "contratos_select" ON public.contratos;
DROP POLICY IF EXISTS "contratos_insert" ON public.contratos;
DROP POLICY IF EXISTS "contratos_update" ON public.contratos;
DROP POLICY IF EXISTS "contratos_delete" ON public.contratos;
CREATE POLICY "contratos_tenant" ON public.contratos FOR ALL
  USING  (jwt_tenant_id() IS NULL OR tenant_id = jwt_tenant_id())
  WITH CHECK (jwt_tenant_id() IS NULL OR tenant_id = jwt_tenant_id());

-- checklist_eventos
DROP POLICY IF EXISTS "checklist_select" ON public.checklist_eventos;
DROP POLICY IF EXISTS "checklist_insert" ON public.checklist_eventos;
CREATE POLICY "checklist_tenant" ON public.checklist_eventos FOR ALL
  USING  (jwt_tenant_id() IS NULL OR tenant_id = jwt_tenant_id())
  WITH CHECK (jwt_tenant_id() IS NULL OR tenant_id = jwt_tenant_id());

-- ocorrencias
DROP POLICY IF EXISTS "ocorrencias_select" ON public.ocorrencias;
DROP POLICY IF EXISTS "ocorrencias_insert" ON public.ocorrencias;
DROP POLICY IF EXISTS "ocorrencias_update" ON public.ocorrencias;
CREATE POLICY "ocorrencias_tenant" ON public.ocorrencias FOR ALL
  USING  (jwt_tenant_id() IS NULL OR tenant_id = jwt_tenant_id())
  WITH CHECK (jwt_tenant_id() IS NULL OR tenant_id = jwt_tenant_id());

-- app_users: leitura restrita ao próprio tenant
DROP POLICY IF EXISTS "app_users_select" ON public.app_users;
CREATE POLICY "app_users_tenant" ON public.app_users FOR SELECT
  USING (jwt_tenant_id() IS NULL OR tenant_id = jwt_tenant_id());

-- audit_log: INSERT irrestrito (app registra); SELECT bloqueado para anon
DROP POLICY IF EXISTS "audit_log_insert" ON public.audit_log;
CREATE POLICY "audit_log_insert" ON public.audit_log FOR INSERT
  WITH CHECK (true);

-- ──────────────────────────────────────────────────────────────────────
-- 8. EXPANDIR audit_log: before/after, origin, tenant_id, effective_user
-- ──────────────────────────────────────────────────────────────────────
ALTER TABLE public.audit_log
  ADD COLUMN IF NOT EXISTS tenant_id     UUID REFERENCES public.tenants(id),
  ADD COLUMN IF NOT EXISTS effective_user TEXT NOT NULL DEFAULT 'desconhecido',
  ADD COLUMN IF NOT EXISTS before_state  JSONB,
  ADD COLUMN IF NOT EXISTS after_state   JSONB,
  ADD COLUMN IF NOT EXISTS origin        TEXT NOT NULL DEFAULT 'web';

CREATE INDEX IF NOT EXISTS idx_audit_log_tenant
  ON public.audit_log (tenant_id, entity, created_at DESC);

-- ──────────────────────────────────────────────────────────────────────
-- 9. FUNÇÃO RPC: registrar_km — validação server-side + operação atômica
-- ──────────────────────────────────────────────────────────────────────
-- Regras de negócio:
--   a) KM regressivo (novo < atual): rejeita sem alterar estado.
--   b) Salto > 1000 km por dia desde última leitura: rejeita.
--   c) Em caso de sucesso: INSERT em hodometros + UPDATE em veiculos (atômico).
-- ──────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.registrar_km(
  p_placa         TEXT,
  p_km            INTEGER,
  p_registrado_por TEXT,
  p_tenant_id     UUID
) RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_km_atual         INTEGER;
  v_ultima_leitura   RECORD;
  v_horas_decorridas FLOAT;
  v_km_maximo_dia    CONSTANT INTEGER := 1000;
BEGIN
  -- Bloqueia a linha do veículo para garantir atomicidade
  SELECT km_atual INTO v_km_atual
  FROM public.veiculos
  WHERE placa = p_placa
    AND (p_tenant_id IS NULL OR tenant_id = p_tenant_id)
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'ok', false,
      'error', 'Veículo não encontrado ou sem permissão de acesso'
    );
  END IF;

  -- Validação: KM regressivo
  IF v_km_atual IS NOT NULL AND p_km < v_km_atual THEN
    RETURN jsonb_build_object(
      'ok', false,
      'error', format(
        'KM regressivo detectado: KM informado (%s) é menor que KM atual (%s)',
        p_km, v_km_atual
      )
    );
  END IF;

  -- Validação: salto suspeito de KM por janela de tempo
  SELECT * INTO v_ultima_leitura
  FROM public.hodometros
  WHERE veiculo_placa = p_placa
    AND (p_tenant_id IS NULL OR tenant_id = p_tenant_id)
  ORDER BY created_at DESC
  LIMIT 1;

  IF FOUND AND v_ultima_leitura.km IS NOT NULL THEN
    v_horas_decorridas := EXTRACT(
      EPOCH FROM (NOW() - v_ultima_leitura.created_at)
    ) / 3600.0;

    -- Normaliza para no mínimo 1 dia (evita rejeitar leituras no mesmo dia)
    IF v_horas_decorridas >= 0.1 THEN
      DECLARE
        v_dias     FLOAT := GREATEST(v_horas_decorridas / 24.0, 1.0);
        v_km_delta INTEGER := p_km - v_ultima_leitura.km;
      BEGIN
        IF v_km_delta > (v_km_maximo_dia * v_dias) THEN
          RETURN jsonb_build_object(
            'ok', false,
            'error', format(
              'Salto de KM suspeito: +%s km em %.1f horas (limite: %s km/dia)',
              v_km_delta, v_horas_decorridas, v_km_maximo_dia
            )
          );
        END IF;
      END;
    END IF;
  END IF;

  -- Operação atômica: INSERT hodometro + UPDATE veículo
  INSERT INTO public.hodometros (veiculo_placa, km, registrado_por, tenant_id)
  VALUES (p_placa, p_km, p_registrado_por, p_tenant_id);

  UPDATE public.veiculos
  SET
    km_atual             = p_km,
    status_alterado_por  = p_registrado_por,
    status_atualizado_em = NOW()
  WHERE placa = p_placa
    AND (p_tenant_id IS NULL OR tenant_id = p_tenant_id);

  RETURN jsonb_build_object('ok', true, 'km', p_km);
END;
$$;

-- Permite que anon key chame a função (RLS interno à função via SECURITY DEFINER)
GRANT EXECUTE ON FUNCTION public.registrar_km TO anon;

-- ──────────────────────────────────────────────────────────────────────
-- 10. SEGUNDO TENANT DE TESTE — para validação de bloqueio cross-tenant
-- Executar manualmente no Supabase para testes A/B:
--
-- INSERT INTO public.tenants (id, nome, cnpj)
-- VALUES ('00000000-0000-0000-0000-000000000002', 'Empresa B (Teste)', '')
-- ON CONFLICT DO NOTHING;
--
-- Para criar usuário do tenant B:
-- INSERT INTO public.app_users (username, password_hash, password_salt, role, tenant_id)
-- VALUES (
--   'operador_b',
--   encode(digest('SALT_B:SENHA_B:atr-salt-v1', 'sha256'), 'hex'),
--   'SALT_B', 'fleet',
--   '00000000-0000-0000-0000-000000000002'
-- );
-- ──────────────────────────────────────────────────────────────────────

-- ════════════════════════════════════════════════════════════════════════
-- FIM DA MIGRATION 004
-- ════════════════════════════════════════════════════════════════════════
