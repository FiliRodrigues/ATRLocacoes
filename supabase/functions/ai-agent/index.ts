import { serve } from "https://deno.land/std@0.208.0/http/server.ts";
import { corsHeaders } from "./_shared/cors.ts";
import { authenticate } from "./_shared/auth.ts";
import { getUserClient, getServiceClient } from "./_shared/supabase.ts";
import { runAgent } from "./agent.ts";
import { checkRateLimit, incrementRateLimit, RateLimitExceeded } from "./_shared/rate_limit.ts";
import type { ClaudeContentBlock } from "./types.ts";

serve(async (req: Request) => {
  // Preflight CORS
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const contentLength = parseInt(req.headers.get("content-length") || "0", 10);
  if (contentLength > 20 * 1024 * 1024) {
    return new Response(
      JSON.stringify({ error: "Payload muito grande. Limite: 20MB." }),
      { status: 413, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }

  try {
    // Parse do body primeiro para poder usar na autenticacao webhook (WhatsApp suporta body.phone)
    const body = await req.json().catch(() => ({}));

    // Autentica o request (JWT Bearer ou x-webhook-secret)
    const auth = await authenticate(req, { phone: body.phone });

    if (!auth.ok) {
      return new Response(
        JSON.stringify({ error: auth.error }),
        {
          status: auth.status,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    // Converte body.message (string) para o formato ClaudeMessage esperado
    let messageContent: ClaudeContentBlock[];

    if (typeof body.message === "string") {
      messageContent = [{ type: "text", text: body.message }];
    } else if (Array.isArray(body.message)) {
      // Se ja for array de content blocks (ex: com imagens), usa direto
      messageContent = body.message as ClaudeContentBlock[];
    } else if (body.message && typeof body.message === "object" && Array.isArray(body.message.content)) {
      // Formato { role: "user", content: [...] }
      messageContent = body.message.content as ClaudeContentBlock[];
    } else {
      return new Response(
        JSON.stringify({ error: "Campo 'message' obrigatorio (string ou content blocks)." }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    // Clientes Supabase
    const userClient = getUserClient(auth.jwt);
    const serviceClient = getServiceClient();

    // Rate limiting antes de executar o agente
    try {
      await checkRateLimit(auth.tenant_id, auth.user_id, serviceClient);
    } catch (err: unknown) {
      if (err instanceof RateLimitExceeded) {
        return new Response(
          JSON.stringify({ error: err.message, retryAfter: err.retryAfter }),
          {
            status: 429,
            headers: { ...corsHeaders, "Content-Type": "application/json", "Retry-After": String(err.retryAfter) },
          },
        );
      }
      throw err;
    }

    try {
      // Executa o agente
      const result = await runAgent({
        tenant_id: auth.tenant_id,
        user_id: auth.user_id,
        channel: body.channel || "web",
        conversation_id: body.conversation_id,
        message: {
          role: "user",
          content: messageContent,
        },
        confirm_action_id: body.confirm_action_id,
        cancel_action_id: body.cancel_action_id,
        content_hashes: body.content_hashes,
        userClient,
        serviceClient,
      });

      return new Response(JSON.stringify(result), {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    } finally {
      // Incrementa rate limit sempre que possível
      incrementRateLimit(auth.tenant_id, auth.user_id, serviceClient).catch(e => console.error("Erro incrementRateLimit", e));
    }
  } catch (err: unknown) {
    const msg = err instanceof Error ? err.message : String(err);
    console.error("[ai-agent] fatal:", msg);
    return new Response(
      JSON.stringify({ error: "internal_error" }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      },
    );
  }
});
