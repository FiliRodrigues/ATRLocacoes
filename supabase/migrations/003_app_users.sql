-- ═══════════════════════════════════════════════════════════════════════
-- ATR Locações — Migration 003: Multi-user Authentication
-- Executa no Supabase Dashboard → SQL Editor
-- ═══════════════════════════════════════════════════════════════════════

-- ── Tabela de usuários do sistema ───────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.app_users (
  username        TEXT PRIMARY KEY,
  password_hash   TEXT NOT NULL,
  password_salt   TEXT NOT NULL,
  role            TEXT NOT NULL DEFAULT 'admin' CHECK (role IN ('admin', 'fleet')),
  nome_completo   TEXT NOT NULL DEFAULT '',
  ativo           BOOLEAN NOT NULL DEFAULT TRUE,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  last_login      TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_app_users_ativo
  ON public.app_users (username, ativo);

-- ── RLS ─────────────────────────────────────────────────────────────────
ALTER TABLE public.app_users ENABLE ROW LEVEL SECURITY;

-- SELECT: app pode buscar o usuário para validar login
-- (password_hash não revela a senha — SHA-256 é one-way)
DROP POLICY IF EXISTS "app_users_select" ON public.app_users;
CREATE POLICY "app_users_select" ON public.app_users
  FOR SELECT USING (true);

-- INSERT/UPDATE/DELETE: bloqueados para anon key
-- Gerencie usuários pelo Supabase Dashboard → Table Editor

-- ── Usuário administrador padrão ────────────────────────────────────────
-- Hash: SHA-256('atr-salt-adm-2026:TroquePorUmaSenhaForte:atr-salt-v1')
-- Para trocar a senha, use a função abaixo com a nova senha:
--   SELECT encode(digest('SEU_SALT:NOVA_SENHA:atr-salt-v1', 'sha256'), 'hex');
-- Depois UPDATE public.app_users SET password_hash = '...hash...' WHERE username = 'adm';
INSERT INTO public.app_users (username, password_hash, password_salt, role, nome_completo)
SELECT
  'adm',
  encode(digest('atr-salt-adm-2026' || ':' || 'TroquePorUmaSenhaForte' || ':atr-salt-v1', 'sha256'), 'hex'),
  'atr-salt-adm-2026',
  'admin',
  'Administrador'
WHERE NOT EXISTS (SELECT 1 FROM public.app_users WHERE username = 'adm');

-- ── Como adicionar mais usuários ────────────────────────────────────────
-- Gere um salt único por usuário (ex: gen_random_uuid()::text)
-- Exemplo de inserção:
--
-- INSERT INTO public.app_users (username, password_hash, password_salt, role, nome_completo)
-- VALUES (
--   'frota',
--   encode(digest('SEU_SALT_UNICO:SENHA_DO_FROTA:atr-salt-v1', 'sha256'), 'hex'),
--   'SEU_SALT_UNICO',
--   'fleet',
--   'Operador de Frota'
-- );
-- ════════════════════════════════════════════════════════════════════════
