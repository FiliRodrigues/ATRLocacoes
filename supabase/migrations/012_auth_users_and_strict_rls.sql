-- ============================================================================
-- Migration 012 - Supabase Auth user bootstrap + strict tenant RLS by auth.uid
-- ============================================================================

CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Add UUID link column in app_users if the legacy schema still does not have it.
ALTER TABLE public.app_users
  ADD COLUMN IF NOT EXISTS id UUID;

-- Backfill deterministic IDs for existing rows that still do not have one.
UPDATE public.app_users au
SET id = u.id
FROM auth.users u
WHERE au.id IS NULL
  AND lower(u.email) = lower(au.username || '@atr.com.br');

CREATE UNIQUE INDEX IF NOT EXISTS ux_app_users_id
  ON public.app_users (id)
  WHERE id IS NOT NULL;

-- Optional FK to auth.users(id) when not already present.
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'app_users_id_fkey'
      AND conrelid = 'public.app_users'::regclass
  ) THEN
    ALTER TABLE public.app_users
      ADD CONSTRAINT app_users_id_fkey
      FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE SET NULL NOT VALID;
  END IF;
END;
$$;

-- 1) Insert Filippe in Supabase Auth (GoTrue) if it does not already exist.
INSERT INTO auth.users (
  id,
  instance_id,
  role,
  aud,
  email,
  encrypted_password,
  email_confirmed_at,
  created_at,
  updated_at
)
SELECT
  gen_random_uuid(),
  '00000000-0000-0000-0000-000000000000',
  'authenticated',
  'authenticated',
  'filippe@atr.com.br',
  -- Senha removida do código (P005). Era 'extensions.crypt(\'<literal>\', ...)'
  -- até a migration 017 — o usuário foi recriado em 017 com senha aleatória.
  -- Mantida string vazia para que esta migration seja idempotente sem
  -- expor credencial trivial em git history (file content, não history).
  extensions.crypt(encode(extensions.gen_random_bytes(24), 'base64'), extensions.gen_salt('bf')),
  now(),
  now(),
  now()
WHERE NOT EXISTS (
  SELECT 1 FROM auth.users WHERE email = 'filippe@atr.com.br'
);

-- 2) Link Auth user to app profile (upsert by legacy PK username).
WITH filippe_auth AS (
  SELECT id
  FROM auth.users
  WHERE email = 'filippe@atr.com.br'
  ORDER BY created_at DESC
  LIMIT 1
)
INSERT INTO public.app_users (
  id,
  username,
  tenant_id,
  role,
  ativo,
  password_hash,
  password_salt,
  nome_completo
)
SELECT
  filippe_auth.id,
  'filippe',
  '00000000-0000-0000-0000-000000000001',
  'admin',
  true,
  encode(extensions.digest(gen_random_uuid()::text, 'sha256'), 'hex'),
  'migrated-to-auth',
  'Filippe'
FROM filippe_auth
ON CONFLICT (username) DO UPDATE
SET
  id = EXCLUDED.id,
  tenant_id = EXCLUDED.tenant_id,
  role = EXCLUDED.role,
  ativo = EXCLUDED.ativo;

-- 3) Strict tenant RLS based on auth.uid() -> app_users.id.
ALTER TABLE IF EXISTS public.manutencoes ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.despesas ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.abastecimentos ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF to_regclass('public.manutencoes') IS NOT NULL THEN
    EXECUTE 'DROP POLICY IF EXISTS "manutencoes_tenant" ON public.manutencoes';
    EXECUTE 'DROP POLICY IF EXISTS "RLS: Isolamento Manutencoes" ON public.manutencoes';
    EXECUTE '
      CREATE POLICY "RLS: Isolamento Manutencoes" ON public.manutencoes
      FOR ALL
      USING (
        tenant_id = (
          SELECT tenant_id FROM public.app_users WHERE id = auth.uid() LIMIT 1
        )
      )
      WITH CHECK (
        tenant_id = (
          SELECT tenant_id FROM public.app_users WHERE id = auth.uid() LIMIT 1
        )
      )
    ';
  END IF;

  IF to_regclass('public.despesas') IS NOT NULL THEN
    EXECUTE 'DROP POLICY IF EXISTS "despesas_tenant" ON public.despesas';
    EXECUTE 'DROP POLICY IF EXISTS "RLS: Isolamento Despesas" ON public.despesas';
    EXECUTE '
      CREATE POLICY "RLS: Isolamento Despesas" ON public.despesas
      FOR ALL
      USING (
        tenant_id = (
          SELECT tenant_id FROM public.app_users WHERE id = auth.uid() LIMIT 1
        )
      )
      WITH CHECK (
        tenant_id = (
          SELECT tenant_id FROM public.app_users WHERE id = auth.uid() LIMIT 1
        )
      )
    ';
  END IF;

  IF to_regclass('public.abastecimentos') IS NOT NULL THEN
    EXECUTE 'DROP POLICY IF EXISTS abastecimentos_tenant_isolation ON public.abastecimentos';
    EXECUTE 'DROP POLICY IF EXISTS "RLS: Isolamento Abastecimentos" ON public.abastecimentos';
    EXECUTE '
      CREATE POLICY "RLS: Isolamento Abastecimentos" ON public.abastecimentos
      FOR ALL
      USING (
        tenant_id = (
          SELECT tenant_id FROM public.app_users WHERE id = auth.uid() LIMIT 1
        )
      )
      WITH CHECK (
        tenant_id = (
          SELECT tenant_id FROM public.app_users WHERE id = auth.uid() LIMIT 1
        )
      )
    ';
  END IF;
END;
$$;
