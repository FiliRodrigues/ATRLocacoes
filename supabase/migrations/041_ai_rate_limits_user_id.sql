-- Migration 041: Adicionar user_id e channel à tabela ai_rate_limits
ALTER TABLE public.ai_rate_limits ADD COLUMN IF NOT EXISTS user_id UUID;
ALTER TABLE public.ai_rate_limits ADD COLUMN IF NOT EXISTS channel TEXT NOT NULL DEFAULT 'whatsapp';

-- Criar constraint UNIQUE
CREATE UNIQUE INDEX IF NOT EXISTS ai_rate_limits_user_id_idx ON public.ai_rate_limits(user_id) WHERE user_id IS NOT NULL;

-- Atualizar ou criar a função RPC para incluir channel e user_id
CREATE OR REPLACE FUNCTION public.increment_rate_limit(
  p_phone text DEFAULT NULL,
  p_user_id uuid DEFAULT NULL,
  p_channel text DEFAULT 'whatsapp'
)
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
  IF p_user_id IS NOT NULL AND p_channel = 'web' THEN
    INSERT INTO public.ai_rate_limits 
      (user_id, channel, minute_count, hour_count, day_count, minute_window_start, hour_window_start, day_window_start)
    VALUES (p_user_id, p_channel, 1, 1, 1, v_now, v_now, v_now)
    ON CONFLICT (user_id) WHERE user_id IS NOT NULL DO UPDATE SET
      minute_count = CASE
        WHEN ai_rate_limits.minute_window_start < v_minute_ago THEN 1
        ELSE ai_rate_limits.minute_count + 1
      END,
      minute_window_start = CASE
        WHEN ai_rate_limits.minute_window_start < v_minute_ago THEN v_now
        ELSE ai_rate_limits.minute_window_start
      END,
      hour_count = CASE
        WHEN ai_rate_limits.hour_window_start < v_hour_ago THEN 1
        ELSE ai_rate_limits.hour_count + 1
      END,
      hour_window_start = CASE
        WHEN ai_rate_limits.hour_window_start < v_hour_ago THEN v_now
        ELSE ai_rate_limits.hour_window_start
      END,
      day_count = CASE
        WHEN ai_rate_limits.day_window_start < v_day_ago THEN 1
        ELSE ai_rate_limits.day_count + 1
      END,
      day_window_start = CASE
        WHEN ai_rate_limits.day_window_start < v_day_ago THEN v_now
        ELSE ai_rate_limits.day_window_start
      END;
  ELSE
    -- whatsapp fallback logic with phone
    INSERT INTO public.ai_rate_limits 
      (phone, channel, minute_count, hour_count, day_count, minute_window_start, hour_window_start, day_window_start)
    VALUES (p_phone, 'whatsapp', 1, 1, 1, v_now, v_now, v_now)
    ON CONFLICT (phone) DO UPDATE SET
      minute_count = CASE
        WHEN ai_rate_limits.minute_window_start < v_minute_ago THEN 1
        ELSE ai_rate_limits.minute_count + 1
      END,
      minute_window_start = CASE
        WHEN ai_rate_limits.minute_window_start < v_minute_ago THEN v_now
        ELSE ai_rate_limits.minute_window_start
      END,
      hour_count = CASE
        WHEN ai_rate_limits.hour_window_start < v_hour_ago THEN 1
        ELSE ai_rate_limits.hour_count + 1
      END,
      hour_window_start = CASE
        WHEN ai_rate_limits.hour_window_start < v_hour_ago THEN v_now
        ELSE ai_rate_limits.hour_window_start
      END,
      day_count = CASE
        WHEN ai_rate_limits.day_window_start < v_day_ago THEN 1
        ELSE ai_rate_limits.day_count + 1
      END,
      day_window_start = CASE
        WHEN ai_rate_limits.day_window_start < v_day_ago THEN v_now
        ELSE ai_rate_limits.day_window_start
      END;
  END IF;
END;
$$;
