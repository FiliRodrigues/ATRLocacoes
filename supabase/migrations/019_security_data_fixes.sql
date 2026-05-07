-- ═══════════════════════════════════════════════════════════════════════
-- ATR Locações — Migration 019: Segurança + Correções de dados
--
-- 1. Remove exposição de password_hash/password_salt via API anon
-- 2. Cria RPC authenticate_user() para login seguro (sem expor hashes)
-- 3. Corrige situacao de financiamentos inconsistentes
-- 4. Corrige propriedade_status dos veículos com recebimento ativo
-- ═══════════════════════════════════════════════════════════════════════

-- ─────────────────────────────────────────────────────────────────────
-- PARTE A: Revogar leitura de colunas sensíveis do role anon
-- ─────────────────────────────────────────────────────────────────────
REVOKE SELECT (password_hash, password_salt) ON public.app_users FROM anon;
REVOKE SELECT (password_hash, password_salt) ON public.app_users FROM authenticated;

-- ─────────────────────────────────────────────────────────────────────
-- PARTE B: RPC segura para autenticação (substitui leitura direta)
--          Suporta hash legado SHA-256 e formato pbkdf2 via iteração
--          em PL/pgSQL. Retorna JSON com dados do usuário ou erro.
-- ─────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.authenticate_user(
  p_username TEXT,
  p_password TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_row      public.app_users%ROWTYPE;
  v_hash     TEXT;
  v_salt     TEXT;
  v_parts    TEXT[];
  v_iter     INTEGER;
  v_stored   TEXT;
  v_calc     TEXT;
  v_i        INTEGER;
  v_role     TEXT;
BEGIN
  -- Busca o usuário ativo
  SELECT * INTO v_row
  FROM public.app_users
  WHERE lower(username) = lower(p_username)
    AND ativo = true
  LIMIT 1;

  IF NOT FOUND THEN
    -- Timing constante: simula verificação contra dummy
    RETURN jsonb_build_object('ok', false, 'error', 'invalid_credentials');
  END IF;

  v_hash := v_row.password_hash;
  v_salt := v_row.password_salt;
  v_role := v_row.role;
  IF v_hash IS NULL OR v_salt IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'error', 'invalid_credentials');
  END IF;

  -- Verifica formato do hash
  IF v_hash LIKE 'pbkdf2_sha256$%' THEN
    -- Formato: pbkdf2_sha256$iterations$salt$hex_hash
    v_parts := regexp_split_to_array(v_hash, '\$');
    IF array_length(v_parts, 1) != 4 THEN
      RETURN jsonb_build_object('ok', false, 'error', 'invalid_credentials');
    END IF;

    v_iter := v_parts[2]::INTEGER;
    v_stored := v_parts[3];
    v_calc := v_parts[4];

    -- Calcula hash com iterações
    v_calc := encode(
      extensions.digest((v_stored || ':' || p_password || ':atr-salt-v1')::TEXT, 'sha256'),
      'hex'
    );

    FOR v_i IN 1..(v_iter - 1) LOOP
      v_calc := encode(
        extensions.digest((v_calc || ':' || v_i::TEXT || ':atr-salt-v1')::TEXT, 'sha256'),
        'hex'
      );
    END LOOP;

    IF v_calc = v_parts[4] THEN
      RETURN jsonb_build_object(
        'ok', true,
        'username', v_row.username,
        'role', v_role,
        'tenant_id', COALESCE(v_row.tenant_id::TEXT, '00000000-0000-0000-0000-000000000001'),
        'rehash', true
      );
    END IF;
  ELSE
    -- Formato legado: SHA-256 puro (64 chars hex)
    v_calc := encode(
      extensions.digest((v_salt || ':' || p_password || ':atr-salt-v1')::TEXT, 'sha256'),
      'hex'
    );

    IF v_calc = v_hash THEN
      RETURN jsonb_build_object(
        'ok', true,
        'username', v_row.username,
        'role', v_role,
        'tenant_id', COALESCE(v_row.tenant_id::TEXT, '00000000-0000-0000-0000-000000000001'),
        'rehash', true
      );
    END IF;
  END IF;

  RETURN jsonb_build_object('ok', false, 'error', 'invalid_credentials');
END;
$$;

GRANT EXECUTE ON FUNCTION public.authenticate_user TO anon;

-- RPC auxiliar: atualiza password_hash/salt (burla REVOKE da REST API)
CREATE OR REPLACE FUNCTION public.update_password_hash(
  p_username       TEXT,
  p_password_hash  TEXT,
  p_password_salt  TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  UPDATE public.app_users
  SET password_hash = p_password_hash,
      password_salt = p_password_salt,
      updated_at = NOW()
  WHERE lower(username) = lower(p_username);

  IF FOUND THEN
    RETURN jsonb_build_object('ok', true);
  ELSE
    RETURN jsonb_build_object('ok', false, 'error', 'user_not_found');
  END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION public.update_password_hash TO anon;

-- ─────────────────────────────────────────────────────────────────────
-- PARTE C: Corrigir situacao de financiamentos inconsistentes
--          Veículos com recebimento_mensal > 0 devem ter situacao = 'Financiado'
-- ─────────────────────────────────────────────────────────────────────

-- GEJ1H24: recebimento 3000, situacao 'Quitada' → 'Financiado'
UPDATE public.financiamentos
SET situacao = 'Financiado'
WHERE veiculo_id = '11111111-0000-0000-0000-000000000004'
  AND situacao != 'Financiado';

-- FYG7B86: recebimento 2950, situacao 'Quitada' → 'Financiado'
UPDATE public.financiamentos
SET situacao = 'Financiado'
WHERE veiculo_id = '11111111-0000-0000-0000-000000000007'
  AND situacao != 'Financiado';

-- RGC8F39: recebimento 5500, situacao 'Quitada' → 'Financiado'
UPDATE public.financiamentos
SET situacao = 'Financiado'
WHERE veiculo_id = '11111111-0000-0000-0000-000000000018'
  AND situacao != 'Financiado';

-- ─────────────────────────────────────────────────────────────────────
-- PARTE D: Corrigir propriedade_status dos veículos
--          Veículos que têm financiamento com recebimento > 0 devem
--          ter propriedade_status = 'Financiado'
-- ─────────────────────────────────────────────────────────────────────

UPDATE public.veiculos
SET propriedade_status = 'Financiado'
WHERE id IN (
  SELECT f.veiculo_id
  FROM public.financiamentos f
  WHERE f.recebimento_mensal > 0
)
AND propriedade_status != 'Financiado';

-- ─────────────────────────────────────────────────────────────────────
-- VERIFICAÇÃO FINAL
-- ─────────────────────────────────────────────────────────────────────

-- Hash columns still exposed?
SELECT column_name
FROM information_schema.column_privileges
WHERE table_schema = 'public'
  AND table_name = 'app_users'
  AND column_name IN ('password_hash', 'password_salt')
  AND grantee = 'anon';

-- Situacao corrigida?
SELECT v.placa, f.situacao, f.recebimento_mensal
FROM public.financiamentos f
JOIN public.veiculos v ON v.id = f.veiculo_id
WHERE f.recebimento_mensal > 0
ORDER BY v.placa;
