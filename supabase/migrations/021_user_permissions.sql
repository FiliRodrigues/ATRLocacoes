-- 021_user_permissions: allowed_features, role constraint, helper + backfill

-- 1. Coluna nova em app_users
ALTER TABLE public.app_users
  ADD COLUMN IF NOT EXISTS allowed_features text[] NOT NULL DEFAULT '{}';

-- 2. Backfill: fleet → member com allowed_features
UPDATE public.app_users
   SET role = 'member',
       allowed_features = ARRAY['frota','vehicles']
 WHERE role = 'fleet';

-- 3. Constraint de role (substituir existente)
ALTER TABLE public.app_users
  DROP CONSTRAINT IF EXISTS app_users_role_check;
ALTER TABLE public.app_users
  ADD CONSTRAINT app_users_role_check
  CHECK (role IN ('admin','member'));

-- 4. Helper para JWT: ler allowed_features da claim
CREATE OR REPLACE FUNCTION public.auth_allowed_features()
RETURNS text[]
LANGUAGE sql STABLE SECURITY DEFINER
AS $$
  SELECT ARRAY(
    SELECT jsonb_array_elements_text(
      auth.jwt() -> 'app_metadata' -> 'allowed_features'
    )
  );
$$;

-- 5. Backfill: copiar allowed_features para auth.users app_metadata (admin = array vazio)
UPDATE auth.users u
   SET raw_app_meta_data = raw_app_meta_data
       || jsonb_build_object('allowed_features', to_jsonb(COALESCE(au.allowed_features, '{}'::text[])))
  FROM public.app_users au
 WHERE au.id = u.id;

-- 6. Garantir que admins existentes tenham role=admin no app_users
UPDATE public.app_users
   SET role = 'admin'
 WHERE role NOT IN ('admin','member');

-- 7. Rebuild RLS: permitir UPDATE para o próprio usuário (troca de senha, must_change_password)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE policyname = 'app_users_self_update'
    AND tablename = 'app_users'
  ) THEN
    CREATE POLICY app_users_self_update ON public.app_users
      FOR UPDATE TO authenticated
      USING (id = auth.uid())
      WITH CHECK (id = auth.uid());
  END IF;
END $$;

-- 8. Otimizações: índices e estatísticas
CREATE INDEX IF NOT EXISTS idx_app_users_role ON public.app_users(role);
CREATE INDEX IF NOT EXISTS idx_app_users_id ON public.app_users(id);
ANALYZE public.app_users;
