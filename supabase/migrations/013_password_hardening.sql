-- ============================================================================
-- Migration 013 - Password security hardening
-- ============================================================================

-- 1. Add must_change_password flag to app_users
ALTER TABLE public.app_users
  ADD COLUMN IF NOT EXISTS must_change_password BOOLEAN NOT NULL DEFAULT FALSE;

-- 2. Invalidate the Filippe user's password ("123") by setting a random hash
--    The account must be reset manually by an admin after this migration.
UPDATE public.app_users
SET
  password_hash = encode(extensions.digest(gen_random_uuid()::text, 'sha256'), 'hex'),
  must_change_password = TRUE
WHERE username = 'filippe'
  AND password_salt = 'migrated-to-auth';

-- 3. Flag the default admin account for password change if still using the
--    well-known template password.
UPDATE public.app_users
SET must_change_password = TRUE
WHERE username = 'adm'
  AND password_salt = 'atr-salt-adm-2026';
