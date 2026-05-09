import { SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2";
import { callClaude } from "./_shared/claude.ts";
import { buildSystemPrompt } from "./system_prompt.ts";
import { TOOLS_REGISTRY, TOOL_DEFINITIONS } from "./tools/index.ts";
import { createPendingAudit, executeConfirmedAction } from "./confirmation.ts";
import type {
  AgentParams,
  AgentResponse,
  ClaudeMessage,
  ClaudeContentBlock,
  PendingAction,
  ToolContext,
  AiConversation,
  AiMessage,
} from "./types.ts";

// ================================================================
// Constantes
// ================================================================
const MAX_ITERATIONS = 10;
const HISTORY_LIMIT = 20;
const CLAUDE_MODEL = "claude-sonnet-4-20250514";
const MAX_TOKENS = 4096;

// ================================================================
// Helper: constroi ToolContext com compatibilidade (supabase)
// ================================================================

function createToolContext(
  tenant_id: string,
  user_id: string,
  conversation_id: string,
  channel: "web" | "whatsapp",
  userClient: SupabaseClient,
  serviceClient: SupabaseClient,
): ToolContext {
  return {
    tenant_id,
    user_id,
    conversation_id,
    channel,
    userClient,
    serviceClient,
    // @ts-ignore compatibilidade com tools existentes que usam ctx.supabase
    supabase: userClient,
  };
}

// ================================================================
// Helper: persiste mensagem no banco (ai_messages)
// ================================================================

async function saveMessage(
  conversation_id: string,
  role: "user" | "assistant" | "tool_result",
  content: ClaudeContentBlock[],
  tool_calls: string[] | null,
  serviceClient: SupabaseClient,
): Promise<void> {
  const { error } = await serviceClient
    .from("ai_messages")
    .insert({
      conversation_id,
      role,
      content,
      tool_calls,
    });

  if (error) {
    console.error("[agent] Erro ao salvar mensagem:", error.message);
    throw new Error(`Falha ao salvar mensagem: ${error.message}`);
  }
}

// ================================================================
// Helper: carrega historico da conversa
// ================================================================

async function loadMessageHistory(
  conversation_id: string,
  serviceClient: SupabaseClient,
): Promise<AiMessage[]> {
  const { data, error } = await serviceClient
    .from("ai_messages")
    .select("id, conversation_id, role, content, tool_calls, created_at")
    .eq("conversation_id", conversation_id)
    .order("created_at", { ascending: true })
    .limit(HISTORY_LIMIT);

  if (error) {
    console.error("[agent] Erro ao carregar historico:", error.message);
    throw new Error(`Falha ao carregar historico: ${error.message}`);
  }

  return (data || []) as AiMessage[];
}

// ================================================================
// Helper: carrega ou cria conversa
// ================================================================

async function loadOrCreateConversation(
  tenant_id: string,
  user_id: string,
  channel: "web" | "whatsapp",
  conversation_id: string | undefined,
  serviceClient: SupabaseClient,
): Promise<string> {
  // Se ja tem ID, verifica se existe e pertence ao usuario
  if (conversation_id) {
    const { data: existing, error } = await serviceClient
      .from("ai_conversations")
      .select("id, user_id, tenant_id")
      .eq("id", conversation_id)
      .single();

    if (!error && existing) {
      if (existing.user_id !== user_id || existing.tenant_id !== tenant_id) {
        throw new Error("Conversa nao pertence a este usuario/tenant.");
      }
      // Atualiza updated_at
      await serviceClient
        .from("ai_conversations")
        .update({ updated_at: new Date().toISOString() })
        .eq("id", conversation_id);
      return conversation_id;
    }
  }

  // Cria nova conversa
  const { data: created, error: createErr } = await serviceClient
    .from("ai_conversations")
    .insert({
      tenant_id,
      user_id,
      channel,
      title: null,
    })
    .select("id")
    .single();

  if (createErr || !created) {
    throw new Error(`Falha ao criar conversa: ${createErr?.message}`);
  }

  return created.id;
}

// ================================================================
// Helper: extrai blocos de texto da resposta do Claude
// ================================================================

function extractTextBlocks(content: ClaudeContentBlock[]): string {
  return content
    .filter((b) => b.type === "text")
    .map((b) => b.type === "text" ? b.text : "")
    .join("\n")
    .trim();
}

// ================================================================
// runAgent: loop principal do agente
// ================================================================

export async function runAgent(params: AgentParams): Promise<AgentResponse> {
  const {
    tenant_id,
    user_id,
    channel,
    conversation_id,
    message,
    confirm_action_id,
    userClient,
    serviceClient,
  } = params;

  // ----------------------------------------------------------
  // Passo 1: Carrega ou cria conversa
  // ----------------------------------------------------------
  const convId = await loadOrCreateConversation(
    tenant_id,
    user_id,
    channel,
    conversation_id,
    serviceClient,
  );

  // ----------------------------------------------------------
  // Passo 2: Se for confirmacao de acao pendente
  // ----------------------------------------------------------
  if (confirm_action_id) {
    const result = await executeConfirmedAction(confirm_action_id, {
      tenant_id,
      user_id,
      serviceClient,
    });

    const responseText = result.ok
      ? `Acao executada com sucesso!\n\n${result.display || ""}`
      : `Falha ao executar acao: ${result.error}`;

    const responseContent: ClaudeContentBlock[] = [
      { type: "text", text: responseText },
    ];

    const assistantMsg: ClaudeMessage = {
      role: "assistant",
      content: responseContent,
    };

    // Salva a mensagem de confirmacao
    // Primeiro salva a mensagem do usuario (pedido de confirmacao)
    await saveMessage(convId, "user", message.content, null, serviceClient);
    await saveMessage(convId, "assistant", responseContent, null, serviceClient);

    // Atualiza updated_at da conversa
    await serviceClient
      .from("ai_conversations")
      .update({ updated_at: new Date().toISOString() })
      .eq("id", convId);

    return {
      conversation_id: convId,
      message: assistantMsg,
      pending_actions: [],
    };
  }

  // ----------------------------------------------------------
  // Passo 3: Carrega historico
  // ----------------------------------------------------------
  const history = await loadMessageHistory(convId, serviceClient);

  // ----------------------------------------------------------
  // Passo 4: Salva mensagem do usuario
  // ----------------------------------------------------------
  await saveMessage(convId, "user", message.content, null, serviceClient);

  // ----------------------------------------------------------
  // Passo 5: Constroi array de mensagens para Claude
  // ----------------------------------------------------------
  const messages: ClaudeMessage[] = [
    ...history
      .filter((m) => m.role !== "tool_result")
      .map((m) => ({
        role: m.role as "user" | "assistant",
        content: m.content as ClaudeContentBlock[],
      })),
    { role: "user" as const, content: message.content },
  ];

  // ----------------------------------------------------------
  // Passo 6: System prompt
  // ----------------------------------------------------------
  const systemPrompt = buildSystemPrompt(tenant_id);

  // ----------------------------------------------------------
  // Passo 7: Loop de tool use (max 10 iteracoes)
  // ----------------------------------------------------------
  let finalAssistantMessage: ClaudeMessage | null = null;
  const allPendingActions: PendingAction[] = [];

  for (let iteration = 0; iteration < MAX_ITERATIONS; iteration++) {
    // a. Chama Claude
    const response = await callClaude({
      model: CLAUDE_MODEL,
      system: systemPrompt,
      messages,
      tools: TOOL_DEFINITIONS,
      max_tokens: MAX_TOKENS,
    });

    // b. Se stop_reason != 'tool_use': salva resposta, retorna
    if (response.stop_reason !== "tool_use") {
      finalAssistantMessage = {
        role: "assistant",
        content: response.content,
      };

      await saveMessage(convId, "assistant", response.content, null, serviceClient);

      // Atualiza titulo da conversa na primeira resposta do assistant
      const textPreview = extractTextBlocks(response.content);
      if (textPreview) {
        const title = textPreview.length > 80 ? textPreview.substring(0, 77) + "..." : textPreview;
        await serviceClient
          .from("ai_conversations")
          .update({ title, updated_at: new Date().toISOString() })
          .eq("id", convId)
          .eq("title", null); // so atualiza se ainda nao tem titulo
      } else {
        await serviceClient
          .from("ai_conversations")
          .update({ updated_at: new Date().toISOString() })
          .eq("id", convId);
      }
      break;
    }

    // c. Adiciona resposta do assistant ao array de mensagens
    messages.push({
      role: "assistant",
      content: response.content,
    });

    // d. Processa cada tool_use block
    const toolResultBlocks: ClaudeContentBlock[] = [];
    const toolCallNames: string[] = [];
    let hasWriteTool = false;

    for (const block of response.content) {
      if (block.type !== "tool_use") continue;

      const tool = TOOLS_REGISTRY[block.name];
      toolCallNames.push(block.name);

      if (!tool) {
        // Tool nao encontrada
        toolResultBlocks.push({
          type: "tool_result",
          tool_use_id: block.id,
          content: JSON.stringify({
            ok: false,
            error: `Tool "${block.name}" nao encontrada no registro.`,
          }),
          is_error: true,
        });
        continue;
      }

      if (tool.category === "write") {
        hasWriteTool = true;

        try {
          // Gera preview (consulta veiculo, formata valores, etc.)
          let preview = "";
          const ctxPreview = createToolContext(tenant_id, user_id, convId, channel, userClient, serviceClient);
          if (tool.preview) {
            preview = await tool.preview(block.input, ctxPreview);
          } else {
            preview = `Acao: ${tool.name}\nDados: ${JSON.stringify(block.input, null, 2)}`;
          }

          // Cria registro de auditoria (pending_confirmation)
          const auditId = await createPendingAudit({
            tenant_id,
            user_id,
            conversation_id: convId,
            tool_name: block.name,
            input: block.input,
            serviceClient,
          });

          allPendingActions.push({
            action_id: auditId,
            tool_name: block.name,
            preview,
          });

          // Retorna tool_result com metadados de confirmacao
          toolResultBlocks.push({
            type: "tool_result",
            tool_use_id: block.id,
            content: JSON.stringify({
              requires_confirmation: true,
              action_id: auditId,
              tool_name: block.name,
              preview,
            }),
          });
        } catch (err: unknown) {
          const msg = err instanceof Error ? err.message : String(err);
          toolResultBlocks.push({
            type: "tool_result",
            tool_use_id: block.id,
            content: JSON.stringify({
              ok: false,
              error: `Erro ao preparar acao: ${msg}`,
            }),
            is_error: true,
          });
        }
      } else {
        // Tool de leitura: executa imediatamente
        const ctx = createToolContext(tenant_id, user_id, convId, channel, userClient, serviceClient);
        let toolResult;
        try {
          toolResult = await tool.handler(block.input, ctx);
        } catch (err: unknown) {
          const msg = err instanceof Error ? err.message : String(err);
          toolResult = { ok: false, error: msg };
        }

        toolResultBlocks.push({
          type: "tool_result",
          tool_use_id: block.id,
          content: JSON.stringify(toolResult),
          is_error: !toolResult.ok,
        });
      }
    }

    // e. Salva mensagem de tool_result
    if (toolCallNames.length > 0) {
      await saveMessage(convId, "tool_result", toolResultBlocks, toolCallNames, serviceClient);
    }

    // f. Adiciona tool results como user message para continuar o loop
    messages.push({
      role: "user",
      content: toolResultBlocks,
    });

    // g. Se houve tool de escrita, NAO continua o loop.
    //    O Claude recebeu os resultados de leitura + pedidos de confirmacao.
    //    Chamamos Claude mais UMA vez para ele gerar a resposta final ao usuario.
    //    Depois retornamos com pending_actions para o frontend.
    if (hasWriteTool) {
      // Chama Claude uma ultima vez para responder ao usuario sobre as confirmacoes
      const finalResponse = await callClaude({
        model: CLAUDE_MODEL,
        system: systemPrompt,
        messages,
        tools: TOOL_DEFINITIONS,
        max_tokens: MAX_TOKENS,
      });

      finalAssistantMessage = {
        role: "assistant",
        content: finalResponse.content,
      };

      await saveMessage(convId, "assistant", finalResponse.content, null, serviceClient);

      // Atualiza titulo e timestamp
      const textPreview = extractTextBlocks(finalResponse.content);
      if (textPreview) {
        const title = textPreview.length > 80 ? textPreview.substring(0, 77) + "..." : textPreview;
        await serviceClient
          .from("ai_conversations")
          .update({ title, updated_at: new Date().toISOString() })
          .eq("id", convId)
          .eq("title", null);
      } else {
        await serviceClient
          .from("ai_conversations")
          .update({ updated_at: new Date().toISOString() })
          .eq("id", convId);
      }
      break;
    }
  }

  // Se chegou ao maximo de iteracoes sem resposta final
  if (!finalAssistantMessage) {
    finalAssistantMessage = {
      role: "assistant",
      content: [
        {
          type: "text",
          text: "Atingi o limite de processamento. Por favor, simplifique sua pergunta ou tente novamente.",
        },
      ],
    };
    await saveMessage(convId, "assistant", finalAssistantMessage.content, null, serviceClient);

    await serviceClient
      .from("ai_conversations")
      .update({ updated_at: new Date().toISOString() })
      .eq("id", convId);
  }

  // ----------------------------------------------------------
  // Passo 8: Retorna resposta final
  // ----------------------------------------------------------
  return {
    conversation_id: convId,
    message: finalAssistantMessage,
    pending_actions: allPendingActions,
  };
}
