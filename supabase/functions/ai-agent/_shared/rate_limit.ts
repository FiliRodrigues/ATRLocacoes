import type { SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2";

const RATE_LIMITS = {
  minute: 30,
  hour: 300,
  day: 1500,
};

export class RateLimitExceeded extends Error {
  retryAfter: number; // segundos
  constructor(message: string, retryAfter: number) {
    super(message);
    this.name = "RateLimitExceeded";
    this.retryAfter = retryAfter;
  }
}

export async function checkRateLimit(
  tenantId: string,
  userId: string,
  channel: string,
  serviceClient: SupabaseClient,
): Promise<void> {
  const now = new Date();

  let query = serviceClient
    .from("ai_rate_limits")
    .select("minute_count, hour_count, day_count, minute_window_start, hour_window_start, day_window_start");

  if (channel === 'whatsapp') {
    query = query.eq("phone", userId);
  } else {
    query = query.eq("user_id", userId);
  }

  const { data, error } = await query.maybeSingle();

  if (error) {
    console.error("[rate_limit] Falha CRÍTICA ao consultar limites:", error.message);
    throw new Error(`Rate limit check falhou: ${error.message}`);
  }

  const row = data as Record<string, unknown> | null;
  const minuteCount = (row?.minute_count as number) ?? 0;
  const hourCount = (row?.hour_count as number) ?? 0;
  const dayCount = (row?.day_count as number) ?? 0;
  const minuteWindow = row?.minute_window_start ? new Date(row.minute_window_start as string) : new Date(0);
  const hourWindow = row?.hour_window_start ? new Date(row.hour_window_start as string) : new Date(0);
  const dayWindow = row?.day_window_start ? new Date(row.day_window_start as string) : new Date(0);

  const minuteAgo = new Date(now.getTime() - 60_000);
  const hourAgo = new Date(now.getTime() - 3_600_000);
  const dayAgo = new Date(now.getTime() - 86_400_000);

  const effectiveMinute = minuteWindow < minuteAgo ? 0 : minuteCount;
  const effectiveHour = hourWindow < hourAgo ? 0 : hourCount;
  const effectiveDay = dayWindow < dayAgo ? 0 : dayCount;

  if (effectiveMinute >= RATE_LIMITS.minute) {
    const retryAfter = Math.max(1, Math.ceil((minuteWindow.getTime() + 60_000 - now.getTime()) / 1000));
    throw new RateLimitExceeded(`Limite de requisições por minuto excedido (${RATE_LIMITS.minute}/min).`, retryAfter);
  }
  if (effectiveHour >= RATE_LIMITS.hour) {
    const retryAfter = Math.max(1, Math.ceil((hourWindow.getTime() + 3_600_000 - now.getTime()) / 1000));
    throw new RateLimitExceeded(`Limite de requisições por hora excedido (${RATE_LIMITS.hour}/hora).`, retryAfter);
  }
  if (effectiveDay >= RATE_LIMITS.day) {
    const retryAfter = Math.max(1, Math.ceil((dayWindow.getTime() + 86_400_000 - now.getTime()) / 1000));
    throw new RateLimitExceeded(`Limite de requisições por dia excedido (${RATE_LIMITS.day}/dia).`, retryAfter);
  }
}

export async function incrementRateLimit(
  tenantId: string,
  userId: string,
  channel: string,
  serviceClient: SupabaseClient,
): Promise<void> {
  try {
    await serviceClient.rpc("increment_rate_limit", {
      p_phone: channel === 'whatsapp' ? userId : null,
      p_user_id: channel === 'web' ? userId : null,
      p_channel: channel,
    });
  } catch (err: unknown) {
    console.warn("[rate_limit] Erro ao incrementar contador:", err instanceof Error ? err.message : String(err));
  }
}
