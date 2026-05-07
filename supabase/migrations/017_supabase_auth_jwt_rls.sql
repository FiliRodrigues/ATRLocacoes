-- ============================================================
-- 017: Migração de autenticação custom (app_users + RPC) para
--      Supabase Auth + RLS baseado em JWT claim (tenant_id, role).
--
-- Motivação (P002 — CVSS 9.8): as políticas atuais usavam o padrão
--   (app_tenant_id() IS NULL) OR (tenant_id = app_tenant_id())
-- com `set_app_tenant` GRANT a `anon`. Como PostgREST usa pool de
-- conexões, `set_config('app.tenant_id', ..., false)` não persiste
-- entre requests, e o fallback IS NULL agia como porta dos fundos
-- permanente para anon ler todos os tenants. Migração para JWT
-- elimina o problema: o claim viaja em cada request e não depende
-- do estado da conexão.
--
-- ESTRUTURA:
--   PARTE 1: Bootstrap auth.users a partir de app_users (senha temp)
--   PARTE 2: Helper auth_tenant_id()/auth_role() lendo do JWT
--   PARTE 3: Reescrever todas as policies (sem fallback IS NULL,
--            restritas a role `authenticated`)
--   PARTE 4: Tighten audit_log (anon não pode mais inserir)
--   PARTE 5: Tighten tenants (cada user vê só o próprio tenant)
--   PARTE 6: Revogar set_app_tenant de anon/authenticated
--   PARTE 7: Garantir extensão pgcrypto disponível em `extensions`
-- ============================================================

CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA extensions;

-- =========================================================
-- PARTE 1: Bootstrap auth.users a partir de app_users
--   - Para cada usuário existente em app_users, cria entrada
--     correspondente em auth.users com email = <username>@atr.local
--     e senha temporária aleatória (16 chars base64).
--   - O claim `tenant_id`, `role` e `username` são gravados em
--     raw_app_meta_data (vão para o JWT como `app_metadata`).
--   - Se o email já existe em auth.users, apenas atualiza metadados
--     (idempotente — pode rodar múltiplas vezes).
-- =========================================================

DO $$
DECLARE
  v_user RECORD;
  v_email TEXT;
  v_temp_password TEXT;
  v_uid UUID;
BEGIN
  FOR v_user IN
    SELECT username, role, tenant_id, nome_completo
    FROM public.app_users
    WHERE COALESCE(ativo, true) = true
  LOOP
    v_email := lower(v_user.username) || '@atr.local';

    -- Já existe?
    SELECT id INTO v_uid FROM auth.users WHERE email = v_email;

    IF v_uid IS NULL THEN
      -- Senha temporária aleatória — usuário deve trocar imediatamente
      v_temp_password := encode(extensions.gen_random_bytes(12), 'base64');
      v_uid := gen_random_uuid();

      INSERT INTO auth.users (
        instance_id, id, aud, role,
        email, encrypted_password, email_confirmed_at,
        raw_app_meta_data, raw_user_meta_data,
        created_at, updated_at,
        confirmation_token, recovery_token, email_change_token_new, email_change
      ) VALUES (
        '00000000-0000-0000-0000-000000000000',
        v_uid,
        'authenticated',
        'authenticated',
        v_email,
        extensions.crypt(v_temp_password, extensions.gen_salt('bf', 10)),
        now(),
        jsonb_build_object(
          'provider', 'email',
          'providers', ARRAY['email'],
          'tenant_id', v_user.tenant_id,
          'role', v_user.role,
          'username', v_user.username
        ),
        jsonb_build_object('full_name', COALESCE(v_user.nome_completo, v_user.username)),
        now(), now(),
        '', '', '', ''
      );

      INSERT INTO auth.identities (
        provider_id, user_id, identity_data,
        provider, last_sign_in_at, created_at, updated_at
      ) VALUES (
        v_uid::text,
        v_uid,
        jsonb_build_object('sub', v_uid::text, 'email', v_email, 'email_verified', true),
        'email',
        now(), now(), now()
      );

      RAISE NOTICE 'AUTH BOOTSTRAP — % => email=% temp_password=%',
        v_user.username, v_email, v_temp_password;
    ELSE
      -- Já existe: apenas reforça os claims em app_metadata
      UPDATE auth.users
      SET raw_app_meta_data = COALESCE(raw_app_meta_data, '{}'::jsonb) || jsonb_build_object(
        'tenant_id', v_user.tenant_id,
        'role', v_user.role,
        'username', v_user.username
      )
      WHERE id = v_uid;
      RAISE NOTICE 'AUTH BOOTSTRAP — % já existe (id=%); claims atualizados', v_user.username, v_uid;
    END IF;
  END LOOP;
END $$;

-- =========================================================
-- PARTE 2: Helpers JWT-based
--   `auth_tenant_id()` retorna o claim `tenant_id` do JWT do request
--   atual. Sem JWT (anon) ou sem claim, retorna NULL e as policies
--   negam acesso (não há fallback permissivo).
-- =========================================================

CREATE OR REPLACE FUNCTION public.auth_tenant_id()
RETURNS uuid
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
  SELECT NULLIF(
    COALESCE(
      (auth.jwt() -> 'app_metadata' ->> 'tenant_id'),
      ''
    ),
    ''
  )::uuid
$$;

CREATE OR REPLACE FUNCTION public.auth_role()
RETURNS text
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
  SELECT COALESCE(auth.jwt() -> 'app_metadata' ->> 'role', '')
$$;

REVOKE ALL ON FUNCTION public.auth_tenant_id() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.auth_role() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.auth_tenant_id() TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.auth_role() TO authenticated, service_role;

-- =========================================================
-- PARTE 3: Reescrever todas as policies de tabelas tenant-isolated.
--   Padrão novo:
--     FOR ALL TO authenticated
--     USING      (tenant_id = public.auth_tenant_id())
--     WITH CHECK (tenant_id = public.auth_tenant_id())
--   - `TO authenticated` impede anon de ver QUALQUER linha
--   - Sem fallback IS NULL — claim ausente => zero linhas
--   - service_role continua bypassando (usado por jobs/migrations)
-- =========================================================

-- Lista de tabelas com coluna tenant_id e policy "*_tenant" atual
DO $$
DECLARE
  v_tbl TEXT;
  v_policies TEXT[] := ARRAY[
    'abastecimentos:abastecimentos_tenant',
    'checklist_eventos:checklist_tenant',
    'contratos:contratos_tenant',
    'despesas:despesas_tenant',
    'financiamentos:financiamentos_tenant',
    'hodometros:hodometros_tenant',
    'ipva:ipva_tenant',
    'licenciamento:licenciamento_tenant',
    'manutencoes:manutencoes_tenant',
    'multas:multas_tenant',
    'ocorrencias:ocorrencias_tenant',
    'parcelas_financiamento:parcelas_tenant',
    'parcelas_seguro:parcelas_seguro_tenant',
    'recebimentos:recebimentos_tenant',
    'regras_manutencao:regras_manutencao_tenant',
    'seguros:seguros_tenant',
    'veiculos:veiculos_tenant'
  ];
  v_split TEXT[];
BEGIN
  FOREACH v_tbl IN ARRAY v_policies LOOP
    v_split := string_to_array(v_tbl, ':');
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.%I', v_split[2], v_split[1]);
    EXECUTE format(
      'CREATE POLICY %I ON public.%I FOR ALL TO authenticated USING (tenant_id = public.auth_tenant_id()) WITH CHECK (tenant_id = public.auth_tenant_id())',
      v_split[2], v_split[1]
    );
  END LOOP;
END $$;

-- =========================================================
-- PARTE 4: Tighten app_users — antes: SELECT TO public; agora:
--   somente authenticated, restrito ao próprio tenant.
-- =========================================================

DROP POLICY IF EXISTS app_users_tenant ON public.app_users;
CREATE POLICY app_users_tenant ON public.app_users
  FOR SELECT TO authenticated
  USING (tenant_id = public.auth_tenant_id());

-- =========================================================
-- PARTE 5: Tighten audit_log — INSERT só authenticated/service_role,
--   SELECT só authenticated do mesmo tenant.
-- =========================================================

ALTER TABLE public.audit_log ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS audit_log_insert ON public.audit_log;
DROP POLICY IF EXISTS audit_log_select ON public.audit_log;

CREATE POLICY audit_log_insert ON public.audit_log
  FOR INSERT TO authenticated
  WITH CHECK (tenant_id IS NULL OR tenant_id = public.auth_tenant_id());

CREATE POLICY audit_log_select ON public.audit_log
  FOR SELECT TO authenticated
  USING (tenant_id = public.auth_tenant_id());

-- =========================================================
-- PARTE 6: Tighten tenants — cada user só vê o próprio tenant
-- =========================================================

ALTER TABLE public.tenants ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS tenants_select ON public.tenants;
CREATE POLICY tenants_select ON public.tenants
  FOR SELECT TO authenticated
  USING (id = public.auth_tenant_id());

-- =========================================================
-- PARTE 7: Revogar set_app_tenant de anon/authenticated.
--   Mantém disponível só para service_role (scripts internos).
--   `app_tenant_id()` e `jwt_tenant_id()` antigos continuam, mas
--   sem uso em policies — ficam apenas pra compat até remoção.
-- =========================================================

REVOKE EXECUTE ON FUNCTION public.set_app_tenant(uuid) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.set_app_tenant(uuid) FROM anon;
REVOKE EXECUTE ON FUNCTION public.set_app_tenant(uuid) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.set_app_tenant(uuid) TO service_role;

-- Também tranca app_tenant_id (não deve mais ser chamado por anon)
REVOKE EXECUTE ON FUNCTION public.app_tenant_id() FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.app_tenant_id() FROM anon;
GRANT EXECUTE ON FUNCTION public.app_tenant_id() TO authenticated, service_role;

-- =========================================================
-- PARTE 8: Verificação — nenhuma policy deve mais usar
--   `app_tenant_id() IS NULL` como fallback.
-- =========================================================
DO $$
DECLARE
  v_count INT;
BEGIN
  SELECT count(*) INTO v_count
  FROM pg_policies
  WHERE schemaname = 'public'
    AND qual ILIKE '%app_tenant_id() IS NULL%';
  IF v_count > 0 THEN
    RAISE EXCEPTION 'Policies com fallback IS NULL ainda existem (% policies). Aborting.', v_count;
  END IF;
  RAISE NOTICE 'OK — zero policies com fallback permissivo';
END $$;
