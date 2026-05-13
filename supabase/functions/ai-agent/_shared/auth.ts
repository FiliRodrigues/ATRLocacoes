import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { create, getNumericDate } from "https://deno.land/x/djwt@v3.0.1/mod.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const SUPABASE_JWT_SECRET = Deno.env.get("SUPABASE_JWT_SECRET")!;
const AI_AGENT_WEBHOOK_SECRET = Deno.env.get("AI_AGENT_WEBHOOK_SECRET")!;

export type AuthResult =
  | { ok: true; tenant_id: string; user_id: string; jwt: string }
  | { ok: false; error: string; status: number };

/**
 * Autentica requests de 2 formas:
 * - Web/Flutter: valida JWT do Supabase Auth (header Authorization: Bearer <jwt>)
 * - WhatsApp webhook: valida AI_AGENT_WEBHOOK_SECRET no header x-webhook-secret
 *
 * Extrai tenant_id do app_metadata do JWT.
 * Extrai user_id da claim sub do JWT.
 *
 * Para WhatsApp: gera um JWT assinado com SUPABASE_JWT_SECRET
 * contendo as mesmas claims (sub, app_metadata.tenant_id) para que o
 * Supabase client aceite o token em queries RLS.
 */
export async function authenticate(
  req: Request,
  body?: { phone?: string }
): Promise<AuthResult> {
  // --- Via Web/Flutter: JWT no header Authorization ---
  const authHeader = req.headers.get("Authorization");
  if (authHeader?.startsWith("Bearer ")) {
    const jwt = authHeader.slice(7);

    // Valida o JWT criando um client autenticado e chamando getUser()
    const userClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
      global: { headers: { Authorization: `Bearer ${jwt}` } },
    });

    const {
      data: { user },
      error: userErr,
    } = await userClient.auth.getUser();

    if (userErr || !user) {
      return {
        ok: false,
        error: "JWT inválido ou expirado",
        status: 401,
      };
    }

    const tenant_id = user.app_metadata?.tenant_id as string | undefined;
    const user_id = user.id;

    if (typeof tenant_id !== "string") {
      return {
        ok: false,
        error: "JWT não contém tenant_id no app_metadata",
        status: 403,
      };
    }

    return { ok: true, tenant_id, user_id, jwt };
  }

  // --- Via WhatsApp webhook: valida x-webhook-secret ---
  const webhookSecret = req.headers.get("x-webhook-secret");

  if (webhookSecret) {
    if (webhookSecret !== AI_AGENT_WEBHOOK_SECRET) {
      return {
        ok: false,
        error: "Webhook secret inválido",
        status: 401,
      };
    }

    // Procura o usuário pelo telefone no corpo da requisição
    if (!body?.phone) {
      return {
        ok: false,
        error:
          "Telefone (phone) obrigatório no corpo para autenticação WhatsApp",
        status: 400,
      };
    }

    // Usa service_role para buscar o usuário vinculado ao telefone
    const serviceClient = createClient(
      SUPABASE_URL,
      SUPABASE_SERVICE_ROLE_KEY,
      { auth: { autoRefreshToken: false } }
    );

    const { data: appUser, error: lookupErr } = await serviceClient
      .from("app_users")
      .select("id, tenant_id, ai_enabled, whatsapp_verified")
      .eq("whatsapp_phone", body.phone)
      .single();

    if (lookupErr || !appUser) {
      return {
        ok: false,
        error: "Nenhum usuário encontrado com este número WhatsApp",
        status: 404,
      };
    }

    if (!appUser.ai_enabled) {
      return {
        ok: false,
        error: "Assistente IA não está habilitado para este usuário",
        status: 403,
      };
    }

    if (!appUser.whatsapp_verified) {
      return {
        ok: false,
        error:
          "Número WhatsApp não verificado. Use o código enviado por SMS.",
        status: 403,
      };
    }

    // Gera um JWT real assinado com SUPABASE_JWT_SECRET,
    // com as mesmas claims que o Supabase Auth usaria.
    // Isso permite que o Supabase client aceite este token e RLS funcione.
    const secretBytes = new TextEncoder().encode(SUPABASE_JWT_SECRET);
    const cryptoKey = await crypto.subtle.importKey(
      "raw",
      secretBytes,
      { name: "HMAC", hash: "SHA-256" },
      false,
      ["sign"]
    );

    const now = Math.floor(Date.now() / 1000);
    const serviceJwt = await create(
      { alg: "HS256", typ: "JWT" },
      {
        sub: appUser.id,
        aud: "authenticated",
        role: "authenticated",
        app_metadata: {
          tenant_id: appUser.tenant_id,
        },
        iat: now,
        exp: now + 3600, // 1 hora
      },
      cryptoKey
    );

    return {
      ok: true,
      tenant_id: appUser.tenant_id,
      user_id: appUser.id,
      jwt: serviceJwt,
    };
  }

  // --- Nenhuma autenticação fornecida ---
  return {
    ok: false,
    error:
      "Autenticação obrigatória. Forneça Authorization: Bearer <jwt> ou x-webhook-secret",
    status: 401,
  };
}
