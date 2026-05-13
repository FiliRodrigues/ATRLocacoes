-- Migration 034: Validação de allowed_features
-- Garante que apenas features conhecidas podem ser atribuídas a usuários

CREATE OR REPLACE FUNCTION validate_allowed_features(features text[])
RETURNS boolean
LANGUAGE plpgsql
IMMUTABLE
AS $$
DECLARE
  valid_features text[] := ARRAY[
    'dashboard', 'frota', 'vehicles', 'drivers',
    'custos', 'contratos', 'vencimentos', 'relatorios',
    'financial_admin', 'obras', 'sala_atr', 'lazer',
    'ai_assistant', 'users_admin', 'configuracoes', 'settings'
  ];
  f text;
BEGIN
  IF features IS NULL THEN RETURN true; END IF;
  FOREACH f IN ARRAY features LOOP
    IF NOT (f = ANY(valid_features)) THEN
      RETURN false;
    END IF;
  END LOOP;
  RETURN true;
END;
$$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'chk_app_users_features'
  ) THEN
    ALTER TABLE app_users
      ADD CONSTRAINT chk_app_users_features
      CHECK (allowed_features IS NULL OR validate_allowed_features(allowed_features));
  END IF;
END $$;
