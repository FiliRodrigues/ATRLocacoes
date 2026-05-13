import type { SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2";

const RATE_LIMITS = {
  minute: 10,
  hour: 50,
  day: 200,
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
  serviceClient: SupabaseClient,
): Promise<void> {
  const now = new Date();

  const { data, error } = await serviceClient
    .from("ai_rate_limits")
    .select("minute_count, hour_count, day_count, minute_window_start, hour_window_start, day_window_start")
    .eq("phone", userId)
    .maybeSingle();

  if (error) {
    console.warn("[rate_limit] Erro ao consultar limites, permitindo:", error.message);
    return;
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
    const retryAfter = Math.ceil((minuteWindow.getTime() + 60_000 - now.getTime()) / 1000);
    throw new RateLimitExceeded("Limite de requisições por minuto excedido (10/min).", retryAfter);
  }
  if (effectiveHour >= RATE_LIMITS.hour) {
    const retryAfter = Math.ceil((hourWindow.getTime() + 3_600_000 - now.getTime()) / 1000);
    throw new RateLimitExceeded("Limite de requisições por hora excedido (50/hora).", retryAfter);
  }
  if (effectiveDay >= RATE_LIMITS.day) {
    const retryAfter = Math.ceil((dayWindow.getTime() + 86_400_000 - now.getTime()) / 1000);
    throw new RateLimitExceeded("Limite de requisições por dia excedido (200/dia).", retryAfter);
  }
}

export async function incrementRateLimit(
  tenantId: string,
  userId: string,
  serviceClient: SupabaseClient,
): Promise<void> {
  try {
    await serviceClient.rpc("increment_rate_limit", {
      p_phone: userId,
    });
  } catch (err: unknown) {
    console.warn("[rate_limit] Erro ao incrementar contador:", err instanceof Error ? err.message : String(err));
  }
}
