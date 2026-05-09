import { serve } from "https://deno.land/std@0.208.0/http/server.ts";
import { corsHeaders } from "./_shared/cors.ts";
import { authenticate } from "./_shared/auth.ts";
import { getUserClient, getServiceClient } from "./_shared/supabase.ts";
import { runAgent } from "./agent.ts";
import type { ClaudeContentBlock } from "./types.ts";

serve(async (req: Request) => {
  // Preflight CORS
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    // Autentica o request (JWT Bearer ou x-webhook-secret)
    const auth = await authenticate(req);

    if (!auth.ok) {
      return new Response(
        JSON.stringify({ error: auth.error }),
        {
          status: auth.status,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    // Parse do body
    const body = await req.json().catch(() => ({}));

    // Clientes Supabase
    const userClient = getUserClient(auth.jwt);
    const serviceClient = getServiceClient();

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
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

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
      userClient,
      serviceClient,
    });

    return new Response(JSON.stringify(result), {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (err: unknown) {
    const msg = err instanceof Error ? err.message : String(err);
    console.error("[ai-agent] fatal:", msg);
    return new Response(
      JSON.stringify({ error: "internal_error", detail: msg }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      },
    );
  }
});
