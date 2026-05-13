-- Migration 039: RPC increment_rate_limit para o sistema de rate limiting da IA
-- Chamada por ai-agent/_shared/rate_limit.ts → incrementRateLimit()

CREATE OR REPLACE FUNCTION public.increment_rate_limit(p_phone text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_now timestamptz := now();
  v_minute_ago timestamptz := v_now - interval '1 minute';
  v_hour_ago   timestamptz := v_now - interval '1 hour';
  v_day_ago    timestamptz := v_now - interval '1 day';
BEGIN
  INSERT INTO public.ai_rate_limits (phone, minute_count, hour_count, day_count,
    minute_window_start, hour_window_start, day_window_start)
  VALUES (p_phone, 1, 1, 1, v_now, v_now, v_now)
  ON CONFLICT (phone) DO UPDATE SET
    -- Minuto: reseta janela se expirou
    minute_count = CASE
      WHEN ai_rate_limits.minute_window_start < v_minute_ago THEN 1
      ELSE ai_rate_limits.minute_count + 1
    END,
    minute_window_start = CASE
      WHEN ai_rate_limits.minute_window_start < v_minute_ago THEN v_now
      ELSE ai_rate_limits.minute_window_start
    END,
    -- Hora: reseta janela se expirou
    hour_count = CASE
      WHEN ai_rate_limits.hour_window_start < v_hour_ago THEN 1
      ELSE ai_rate_limits.hour_count + 1
    END,
    hour_window_start = CASE
      WHEN ai_rate_limits.hour_window_start < v_hour_ago THEN v_now
      ELSE ai_rate_limits.hour_window_start
    END,
    -- Dia: reseta janela se expirou
    day_count = CASE
      WHEN ai_rate_limits.day_window_start < v_day_ago THEN 1
      ELSE ai_rate_limits.day_count + 1
    END,
    day_window_start = CASE
      WHEN ai_rate_limits.day_window_start < v_day_ago THEN v_now
      ELSE ai_rate_limits.day_window_start
    END;
END;
$$;

-- Garante que só o service_role pode chamar (a edge function usa serviceClient)
REVOKE ALL ON FUNCTION public.increment_rate_limit(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.increment_rate_limit(text) TO service_role;

-- Índice único em phone se ainda não existir
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_indexes
    WHERE tablename = 'ai_rate_limits' AND indexname = 'ai_rate_limits_phone_key'
  ) THEN
    ALTER TABLE public.ai_rate_limits ADD CONSTRAINT ai_rate_limits_phone_key UNIQUE (phone);
  END IF;
END $$;
