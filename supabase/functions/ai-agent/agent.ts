import { SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2";
import { callClaude, callGpt } from "./_shared/claude.ts";
import { buildSystemPrompt } from "./system_prompt.ts";
import { TOOLS_REGISTRY, TOOL_DEFINITIONS } from "./tools/index.ts";
import { createPendingAudit, executeConfirmedAction, cancelAction } from "./confirmation.ts";
import type {
  AgentParams,
  AgentResponse,
  ClaudeMessage,
  ClaudeContentBlock,
  PendingAction,
  ToolContext,
  ToolDefinition,
  AiConversation,
  AiMessage,
} from "./types.ts";

// ================================================================
// Constantes
// ================================================================
const MAX_ITERATIONS = 15;
const HISTORY_LIMIT = 40;
const DEEPSEEK_MODEL = "deepseek-chat";
const GPT_MODEL = "gpt-4o";
const MAX_TOKENS = 4096;
const MAX_HISTORY_CHARS = 80000;

function trimHistoryToFit(msgs: ClaudeMessage[], maxChars: number): ClaudeMessage[] {
  let jsonStr = JSON.stringify(msgs);
  if (jsonStr.length <= maxChars) return msgs;

  let trimmed = [...msgs];
  while (trimmed.length > 2 && JSON.stringify(trimmed).length > maxChars) {
    let safeIndex = -1;
    for (let i = 1; i < trimmed.length - 1; i++) {
      const m = trimmed[i];
      if (m.role === "user" && Array.isArray(m.content)) {
        const hasToolResult = m.content.some((b: any) => b.type === "tool_result");
        if (!hasToolResult) {
          safeIndex = i;
          break;
        }
      } else if (m.role === "user" && typeof m.content === "string") {
        safeIndex = i;
        break;
      }
    }

    if (safeIndex !== -1) {
      trimmed = trimmed.slice(safeIndex);
    } else {
      trimmed = trimmed.slice(-2);
      break;
    }
  }
  return trimmed;
}

// ================================================================
// Helper: detecta se mensagem contem imagens
// ================================================================

function messageHasImages(content: ClaudeContentBlock[]): boolean {
  return content.some((b) => b.type === "image");
}

// ================================================================
// Helper: escolhe e chama o modelo correto
// ================================================================

type CallModelParams = {
  system: string;
  messages: ClaudeMessage[];
  tools: ToolDefinition[];
  max_tokens: number;
};

function callModel(params: CallModelParams, forceGpt: boolean) {
  const model = forceGpt ? GPT_MODEL : DEEPSEEK_MODEL;
  const call = forceGpt ? callGpt : callClaude;
  return call({ model, ...params });
}

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
// Helper: remove imagens do histórico para não inflar o payload
// (a mensagem atual do usuário NÃO é afetada)
// ================================================================

function stripImagesFromHistory(content: ClaudeContentBlock[]): ClaudeContentBlock[] {
  return content.map((block) =>
    block.type === "image"
      ? ({ type: "text", text: "[documento PDF/imagem processado anteriormente]" } as ClaudeContentBlock)
      : block
  );
}

// ================================================================
// Helper: extrai content_hashes de mensagens com marcador [content_hashes:...]
// ================================================================

function extractContentHashes(content: ClaudeContentBlock[]): string[] {
  const hashes: string[] = [];
  for (const block of content) {
    if (block.type === "text") {
      const match = block.text.match(/\[content_hashes:([^\]]+)\]/);
      if (match) {
        const hashList = match[1]
          .split(",")
          .map((h) => h.trim())
          .filter((h) => /^[a-f0-9]{64}$/i.test(h));
        hashes.push(...hashList);
        // Remove o marcador do texto visivel para o modelo
        block.text = block.text.replace(/\[content_hashes:[^\]]+\]\s*/g, "").trim();
      }
    }
  }
  return hashes;
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

function buildReplayAssistantToolCallMessage(message: AiMessage): ClaudeMessage | null {
  const toolResultBlocks = (message.content as ClaudeContentBlock[]).filter(
    (block): block is Extract<ClaudeContentBlock, { type: "tool_result" }> => block.type === "tool_result",
  );

  if (toolResultBlocks.length === 0) {
    return null;
  }

  return {
    role: "assistant",
    content: toolResultBlocks.map((block, index) => ({
      type: "tool_use" as const,
      id: block.tool_use_id,
      name: message.tool_calls?.[index] || `tool_${index + 1}`,
      input: {},
    })),
  };
}

function assistantAlreadyReplaysToolCalls(
  previousMessage: ClaudeMessage | undefined,
  replayMessage: ClaudeMessage | null,
): boolean {
  if (!previousMessage || !replayMessage || previousMessage.role !== "assistant" || !Array.isArray(previousMessage.content) || !Array.isArray(replayMessage.content)) {
    return false;
  }

  const previousToolUses = previousMessage.content.filter(
    (block): block is Extract<ClaudeContentBlock, { type: "tool_use" }> => block.type === "tool_use",
  );
  const replayToolUses = replayMessage.content.filter(
    (block): block is Extract<ClaudeContentBlock, { type: "tool_use" }> => block.type === "tool_use",
  );

  if (
    previousToolUses.length === 0 ||
    previousToolUses.length !== previousMessage.content.length ||
    previousToolUses.length !== replayToolUses.length
  ) {
    return false;
  }

  return previousToolUses.every((block, index) => {
    const replayBlock = replayToolUses[index];
    return block.id === replayBlock.id && block.name === replayBlock.name;
  });
}

function pushReplayMessage(messages: ClaudeMessage[], nextMessage: ClaudeMessage): void {
  const previousMessage = messages[messages.length - 1];
  if (
    previousMessage?.role === "user" &&
    nextMessage.role === "user" &&
    JSON.stringify(previousMessage.content) === JSON.stringify(nextMessage.content)
  ) {
    return;
  }

  messages.push(nextMessage);
}

// ================================================================
// runAgent: loop principal do agente
// ================================================================

export async function runAgent(params: AgentParams): Promise<AgentResponse> {
  const {
    tenant_id,
    user_id,
    channel,
    screen_context,
    conversation_id,
    message,
    confirm_action_id,
    cancel_action_id,
    content_hashes: paramContentHashes,
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
  // Passo 2: Se for cancelamento de acao pendente
  // ----------------------------------------------------------
  if (cancel_action_id) {
    const ok = await cancelAction(cancel_action_id, user_id, tenant_id, serviceClient);

    const responseText = ok
      ? "Acao cancelada."
      : "Nao foi possivel cancelar a acao (ja processada ou nao encontrada).";

    const responseContent: ClaudeContentBlock[] = [
      { type: "text", text: responseText },
    ];

    const assistantMsg: ClaudeMessage = {
      role: "assistant",
      content: responseContent,
    };

    await saveMessage(convId, "user", message.content, null, serviceClient);
    await saveMessage(convId, "assistant", responseContent, null, serviceClient);

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
  // Passo 3: Se for confirmacao de acao pendente
  // ----------------------------------------------------------
  if (confirm_action_id) {
    // 1. Executa a acao confirmada
    const result = await executeConfirmedAction(confirm_action_id, {
      tenant_id,
      user_id,
      userClient,
      serviceClient,
    });

    const responseText = result.ok
      ? `✅ ${result.display || "Registrado com sucesso!"}`
      : `❌ Falha ao executar: ${result.error}`;

    const responseContent: ClaudeContentBlock[] = [{ type: "text", text: responseText }];

    // 2. Salva a intencao e o resultado no historico
    await saveMessage(convId, "user", [{ type: "text", text: "confirmar" }], ["__confirm__"], serviceClient);
    await saveMessage(convId, "assistant", responseContent, null, serviceClient);

    await serviceClient
      .from("ai_conversations")
      .update({ updated_at: new Date().toISOString() })
      .eq("id", convId);

    return {
      conversation_id: convId,
      message: { role: "assistant", content: responseContent },
      pending_actions: [],
      confirmed_action: {
        action_id: confirm_action_id,
        ok: result.ok,
        error: result.error,
      },
    };
  }

  // ----------------------------------------------------------
  // Passo 3: Carrega historico
  // ----------------------------------------------------------
  const history = await loadMessageHistory(convId, serviceClient);

  // ----------------------------------------------------------
  // Passo 3.5: Extrai content_hashes e verifica PDFs ja processados
  // ----------------------------------------------------------
  const contentHashes = [
    ...(paramContentHashes || []),
    ...extractContentHashes(message.content),
  ];

  if (contentHashes.length > 0) {
    const checkedIds = new Set<string>();
    const matches: Array<{ tool_name: string; created_at: string; status: string }> = [];
    for (const hash of contentHashes) {
      const { data } = await serviceClient
        .from("ai_action_audit")
        .select("id, tool_name, created_at, status")
        .eq("tenant_id", tenant_id)
        .eq("user_id", user_id)
        .contains("content_hashes", [hash])
        .limit(10);
      if (data) {
        for (const row of data) {
          if (!checkedIds.has(row.id)) {
            checkedIds.add(row.id);
            matches.push(row);
          }
        }
      }
    }

    if (matches.length > 0) {
      const executed = matches.filter((m) => m.status === "executed");
      const pending = matches.filter((m) => m.status === "pending_confirmation");

      let warningText = "";
      if (executed.length > 0) {
        const dates = executed
          .map((e) => new Date(e.created_at).toLocaleDateString("pt-BR"))
          .join(", ");
        warningText =
          `⚠️ Detectei que este PDF ja foi processado com sucesso (${dates}). ` +
          `Deseja reprocessar mesmo assim? Responda "sim, reprocessar" para continuar.`;
      } else if (pending.length > 0) {
        const dates = pending
          .map((e) => new Date(e.created_at).toLocaleDateString("pt-BR"))
          .join(", ");
        warningText =
          `⚠️ Este PDF tem acoes pendentes de confirmacao desde ${dates}. ` +
          `Confirme ou cancele antes de reenviar.`;
      }

      if (warningText) {
        const warningContent: ClaudeContentBlock[] = [{ type: "text", text: warningText }];
        await saveMessage(convId, "assistant", warningContent, null, serviceClient);

        await serviceClient
          .from("ai_conversations")
          .update({ updated_at: new Date().toISOString() })
          .eq("id", convId);

        return {
          conversation_id: convId,
          message: { role: "assistant", content: warningContent },
          pending_actions: [],
        };
      }
    }
  }

  // ----------------------------------------------------------
  // Passo 4: Salva mensagem do usuario
  // ----------------------------------------------------------
  await saveMessage(convId, "user", message.content, null, serviceClient);

  // ----------------------------------------------------------
  // Passo 5: Constroi array de mensagens para Claude
  // ----------------------------------------------------------
  // tool_result messages sao mapeadas para role "user" com blocos tool_result,
  // pois toOpenAiMessages converte esses blocos para role "tool" do OpenAI.
  // A nova mensagem do usuario e anexada ao ultimo bloco "user" se ele ja
  // contiver apenas tool_results, evitando dois "user" consecutivos que
  // causam erro 400 no DeepSeek.
  let messages: ClaudeMessage[] = [];
  for (const m of history) {
    if (m.role === "tool_result") {
      const replayAssistantMessage = buildReplayAssistantToolCallMessage(m);
      if (!assistantAlreadyReplaysToolCalls(messages[messages.length - 1], replayAssistantMessage)) {
        if (replayAssistantMessage) {
          messages.push(replayAssistantMessage);
        }
      }

      const content = stripImagesFromHistory(m.content as ClaudeContentBlock[]);
      pushReplayMessage(messages, { role: "user", content });
      continue;
    }

    const role = m.role as "user" | "assistant";
    const content = stripImagesFromHistory(m.content as ClaudeContentBlock[]);
    pushReplayMessage(messages, { role, content });
  }

  const historyCountBeforeTrim = messages.length;
  messages = trimHistoryToFit(messages, MAX_HISTORY_CHARS);
  const wasHistoryTrimmed = messages.length < historyCountBeforeTrim;

  if (wasHistoryTrimmed) {
    messages = [
      {
        role: "user",
        content: [{
          type: "text",
          text: "[Nota interna: parte do histórico desta conversa foi omitida por limite de contexto. Baseie-se apenas nas mensagens abaixo e nas ferramentas disponíveis para consultar dados atuais.]",
        }],
      },
      {
        role: "assistant",
        content: [{ type: "text", text: "Entendido." }],
      },
      ...messages,
    ];
  }

  // Verifica se o ultimo bloco é tool_result (seria role "user" com tool_result blocks).
  // Nesse caso, anexa a nova mensagem do usuario junto ao mesmo bloco "user"
  // para evitar dois "user" consecutivos.
  const lastMsg = messages[messages.length - 1];
  const lastIsToolResult = lastMsg?.role === "user" &&
    Array.isArray(lastMsg.content) &&
    (lastMsg.content as ClaudeContentBlock[]).every((b) => b.type === "tool_result");

  if (lastIsToolResult) {
    const merged = [...(lastMsg.content as ClaudeContentBlock[]), ...message.content];
    messages[messages.length - 1] = { ...lastMsg, content: merged };
  } else {
    messages.push({ role: "user" as const, content: message.content });
  }

  // ----------------------------------------------------------
  // Passo 6: System prompt
  // ----------------------------------------------------------
  const systemPrompt = buildSystemPrompt(screen_context);

  // ----------------------------------------------------------
  // Passo 7: Loop de tool use (max 10 iteracoes)
  // ----------------------------------------------------------
  let finalAssistantMessage: ClaudeMessage | null = null;
  const allPendingActions: PendingAction[] = [];
  const forceGpt = messageHasImages(message.content);
  const consecutiveToolErrors = new Map<string, number>();

  for (let iteration = 0; iteration < MAX_ITERATIONS; iteration++) {
    // a. Chama modelo (GPT-4o se tiver imagens, DeepSeek se texto puro)
    const response = await callModel({
      system: systemPrompt,
      messages,
      tools: TOOL_DEFINITIONS,
      max_tokens: MAX_TOKENS,
    }, forceGpt);

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

    // d. Processa tool_use blocks (reads em paralelo, writes em sequencia)
    const toolUseBlocks = response.content.filter(
      (block): block is Extract<ClaudeContentBlock, { type: "tool_use" }> => block.type === "tool_use",
    );
    const toolResultById = new Map<string, Extract<ClaudeContentBlock, { type: "tool_result" }>>();
    const toolCallNames: string[] = [];
    const readToolBlocks: Array<Extract<ClaudeContentBlock, { type: "tool_use" }>> = [];
    const writeToolBlocks: Array<Extract<ClaudeContentBlock, { type: "tool_use" }>> = [];
    let hasWriteTool = false;

    for (const block of toolUseBlocks) {
      toolCallNames.push(block.name);
      const tool = TOOLS_REGISTRY[block.name];

      if (!tool) {
        const count = (consecutiveToolErrors.get(block.name) ?? 0) + 1;
        consecutiveToolErrors.set(block.name, count);
        if (count >= 3) {
          finalAssistantMessage = {
            role: "assistant",
            content: [{ type: "text", text: `⚠️ Ação cancelada automaticamente. A ferramenta solicitada ("${block.name}") não existe no sistema.` }],
          };
          await saveMessage(convId, "assistant", finalAssistantMessage.content, null, serviceClient);
          return { conversation_id: convId, message: finalAssistantMessage, pending_actions: [] };
        }
        toolResultById.set(block.id, {
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

      consecutiveToolErrors.delete(block.name);

      if (tool.category === "write") {
        hasWriteTool = true;
        writeToolBlocks.push(block);
      } else {
        readToolBlocks.push(block);
      }
    }

    const readResults = await Promise.all(readToolBlocks.map(async (block) => {
      const tool = TOOLS_REGISTRY[block.name];
      const ctx = createToolContext(tenant_id, user_id, convId, channel, userClient, serviceClient);
      if (!tool) {
        return {
          block,
          result: { ok: false, error: `Tool "${block.name}" nao encontrada no registro.` },
        };
      }

      try {
        const result = await tool.handler(block.input, ctx);
        return { block, result };
      } catch (err: unknown) {
        const msg = err instanceof Error ? err.message : String(err);
        return { block, result: { ok: false, error: msg } };
      }
    }));

    for (const { block, result } of readResults) {
      toolResultById.set(block.id, {
        type: "tool_result",
        tool_use_id: block.id,
        content: JSON.stringify(result),
        is_error: !result.ok,
      });
    }

    for (const block of writeToolBlocks) {
      const tool = TOOLS_REGISTRY[block.name];

      if (!tool) {
        toolResultById.set(block.id, {
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

      try {
        const ctxPreview = createToolContext(tenant_id, user_id, convId, channel, userClient, serviceClient);
        const validationResult = await tool.handler(block.input, ctxPreview);
        if (!validationResult.ok) {
          toolResultById.set(block.id, {
            type: "tool_result",
            tool_use_id: block.id,
            content: JSON.stringify({
              ok: false,
              error: validationResult.error || "Dados inválidos para a ação solicitada.",
            }),
            is_error: true,
          });
          continue;
        }

        const auditInput = validationResult.data &&
            typeof validationResult.data === "object" &&
            !Array.isArray(validationResult.data)
          ? validationResult.data as Record<string, unknown>
          : block.input;

        let preview = validationResult.display?.trim() || "";
        if (!preview) {
          if (tool.preview) {
            preview = await tool.preview(auditInput, ctxPreview);
          } else {
            preview = `Acao: ${tool.name}\nDados: ${JSON.stringify(auditInput, null, 2)}`;
          }
        }

        const auditId = await createPendingAudit({
          tenant_id,
          user_id,
          conversation_id: convId,
          tool_name: block.name,
          input: auditInput,
          content_hashes: contentHashes.length > 0 ? contentHashes : undefined,
          serviceClient,
        });

        allPendingActions.push({
          action_id: auditId,
          tool_name: block.name,
          preview,
        });

        toolResultById.set(block.id, {
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
        toolResultById.set(block.id, {
          type: "tool_result",
          tool_use_id: block.id,
          content: JSON.stringify({
            ok: false,
            error: `Erro ao preparar acao: ${msg}`,
          }),
          is_error: true,
        });
      }
    }

    const toolResultBlocks: ClaudeContentBlock[] = toolUseBlocks
      .map((block) => toolResultById.get(block.id))
      .filter((block): block is Extract<ClaudeContentBlock, { type: "tool_result" }> => Boolean(block));

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
      const finalResponse = await callModel({
        system: systemPrompt,
        messages,
        tools: TOOL_DEFINITIONS,
        max_tokens: MAX_TOKENS,
      }, forceGpt);

      // Se o modelo ainda retornar tool_use (improvável mas possível), filtra para só texto
      const hasToolUse = finalResponse.content.some(b => b.type === "tool_use");
      const safeContent: ClaudeContentBlock[] = hasToolUse
        ? finalResponse.content.filter(b => b.type !== "tool_use")
        : finalResponse.content;

      if (hasToolUse) {
        console.warn("[agent] Resposta final continha tool_use — descartado.");
        safeContent.push({ type: "text", text: "\n\n*(Aviso: Algumas ações solicitadas não puderam ser processadas nesta mensagem.)*" });
      }

      // Detecta duplicatas nos tool_results e injeta aviso visivel na resposta
      let duplicateWarning = "";
      for (const block of toolResultBlocks) {
        if (block.type === "tool_result" && !block.is_error) {
          try {
            const parsed = JSON.parse(block.content);
            if (
              parsed.preview &&
              (parsed.preview.includes("DUPLICATA") ||
               parsed.preview.includes("duplicidade") ||
               parsed.preview.includes("similar(es)"))
            ) {
              if (!duplicateWarning) {
                duplicateWarning =
                  "\\n\\n⚠️ **ATENCAO: Possiveis duplicidades detectadas.** " +
                  "Verifique os cards de confirmacao acima. " +
                  "Confirme apenas se realmente deseja registrar novamente.";
              }
              // Marca o pending action correspondente como duplicado
              const matchingAction = allPendingActions.find(
                (a) => a.action_id === parsed.action_id
              );
              if (matchingAction) {
                (matchingAction as Record<string, unknown>).has_duplicates = true;
              }
            }
          } catch { /* ignora erros de parse */ }
        }
      }

      if (duplicateWarning) {
        safeContent.push({ type: "text", text: duplicateWarning });
      }

      finalAssistantMessage = {
        role: "assistant",
        content: safeContent,
      };

      await saveMessage(convId, "assistant", safeContent, null, serviceClient);

      // Atualiza titulo e timestamp
      const textPreview = extractTextBlocks(safeContent);
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
