import { createClient, SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2";

/**
 * Cria um Supabase client autenticado com o JWT do usuário.
 * Todas as queries passam por RLS (Row Level Security).
 * Usado para operações normais de leitura/escrita do usuário.
 */
export function getUserClient(jwt: string): SupabaseClient {
  return createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_ANON_KEY")!,
    {
      global: {
        headers: { Authorization: `Bearer ${jwt}` },
      },
    }
  );
}

/**
 * Cria um Supabase client com service_role (bypass RLS).
 * Usado exclusivamente para operações privilegiadas:
 * - Criar registros de auditoria (ai_action_audit)
 * - Ler/atualizar rate limits (ai_rate_limits)
 * - Buscar usuários por telefone (app_users)
 * - Operações administrativas
 *
 * NUNCA use este client para operações que deveriam ser do usuário.
 */
let _serviceClient: SupabaseClient | null = null;

export function getServiceClient(): SupabaseClient {
  if (!_serviceClient) {
    _serviceClient = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
      {
        auth: { autoRefreshToken: false },
      }
    );
  }
  return _serviceClient;
}

/**
 * Força a recriação do client service_role (uso em testes).
 */
export function resetServiceClient(): void {
  _serviceClient = null;
}
