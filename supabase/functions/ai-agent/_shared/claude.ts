import type { ClaudeMessage, ClaudeResponse, ClaudeContentBlock, ToolDefinition } from "../types.ts";

const DEEPSEEK_API_URL = "https://api.deepseek.com/v1/chat/completions";

export type CallClaudeParams = {
  model: string;
  system: string;
  messages: ClaudeMessage[];
  tools: ToolDefinition[];
  max_tokens: number;
};

// ─── Tradução Anthropic → OpenAI ────────────────────────────────────────────

type OpenAiContentPart =
  | { type: "text"; text: string }
  | { type: "image_url"; image_url: { url: string; detail?: "low" | "high" | "auto" } };

type OpenAiMessage = {
  role: "system" | "user" | "assistant" | "tool";
  content: string | OpenAiContentPart[] | null;
  tool_calls?: OpenAiToolCall[];
  tool_call_id?: string;
  name?: string;
};

type OpenAiToolCall = {
  id: string;
  type: "function";
  function: { name: string; arguments: string };
};

type OpenAiToolDef = {
  type: "function";
  function: {
    name: string;
    description: string;
    parameters: Record<string, unknown>;
  };
};

function toOpenAiMessages(
  system: string,
  messages: ClaudeMessage[],
): OpenAiMessage[] {
  const result: OpenAiMessage[] = [];

  if (system) {
    result.push({ role: "system", content: system });
  }

  for (const msg of messages) {
    if (msg.role === "user") {
      // Concatena blocos de texto; imagens viram image_url; tool_result vira tool message
      const textParts: string[] = [];
      const imageParts: OpenAiContentPart[] = [];
      const toolMessages: OpenAiMessage[] = [];

      for (const block of msg.content) {
        if (block.type === "text") {
          textParts.push(block.text);
        } else if (block.type === "image") {
          // Envia imagem como data URL para DeepSeek Vision
          imageParts.push({
            type: "image_url" as const,
            image_url: {
              url: `data:${block.source.media_type};base64,${block.source.data}`,
            },
          });
        } else if (block.type === "tool_result") {
          toolMessages.push({
            role: "tool",
            tool_call_id: block.tool_use_id,
            content: typeof block.content === "string"
              ? block.content
              : JSON.stringify(block.content),
          });
        }
      }

      if (textParts.length > 0 || imageParts.length > 0) {
        if (imageParts.length > 0) {
          // Mensagem multimodal: content como array de partes
          const parts: OpenAiContentPart[] = [
            ...textParts.map((t) => ({ type: "text" as const, text: t })),
            ...imageParts,
          ];
          result.push({ role: "user", content: parts });
        } else {
          result.push({ role: "user", content: textParts.join("\n") || null });
        }
      }

      result.push(...toolMessages);
    } else if (msg.role === "assistant") {
      const textParts: string[] = [];
      const toolCalls: OpenAiToolCall[] = [];

      for (const block of msg.content) {
        if (block.type === "text") {
          textParts.push(block.text);
        } else if (block.type === "tool_use") {
          toolCalls.push({
            id: block.id,
            type: "function",
            function: {
              name: block.name,
              arguments: JSON.stringify(block.input),
            },
          });
        }
      }

      result.push({
        role: "assistant",
        content: textParts.length > 0 ? textParts.join("\n") : null,
        tool_calls: toolCalls.length > 0 ? toolCalls : undefined,
      });
    }
  }

  return result;
}

function toAnthropicTools(tools: ToolDefinition[]): OpenAiToolDef[] {
  return tools.map((t) => ({
    type: "function" as const,
    function: {
      name: t.name,
      description: t.description,
      parameters: t.input_schema,
    },
  }));
}

// ─── Tradução OpenAI → Anthropic ────────────────────────────────────────────

function toAnthropicResponse(
  json: OpenAiChatResponse,
): ClaudeResponse {
  if (!json.choices || json.choices.length === 0) {
    throw new Error("API retornou resposta sem choices. Tente novamente.");
  }
  const choice = json.choices[0];
  const msg = choice.message;

  const content: ClaudeContentBlock[] = [];

  if (msg.content) {
    content.push({ type: "text", text: msg.content });
  }

  if (msg.tool_calls) {
    for (const tc of msg.tool_calls) {
      let input: Record<string, unknown> = {};
      try {
        input = JSON.parse(tc.function.arguments);
      } catch {
        input = { _raw: tc.function.arguments };
      }

      content.push({
        type: "tool_use",
        id: tc.id,
        name: tc.function.name,
        input,
      });
    }
  }

  // Mapeia finish_reason do OpenAI para stop_reason do Anthropic
  let stop_reason: "end_turn" | "tool_use" | "max_tokens";
  if (choice.finish_reason === "tool_calls") {
    stop_reason = "tool_use";
  } else if (choice.finish_reason === "length") {
    stop_reason = "max_tokens";
  } else {
    stop_reason = "end_turn";
  }

  return {
    id: json.id,
    content,
    stop_reason,
    usage: json.usage
      ? {
          input_tokens: json.usage.prompt_tokens,
          output_tokens: json.usage.completion_tokens,
        }
      : { input_tokens: 0, output_tokens: 0 },
  };
}

type OpenAiChatResponse = {
  id: string;
  choices: Array<{
    finish_reason: "stop" | "tool_calls" | "length" | "content_filter";
    message: {
      role: "assistant";
      content: string | null;
      tool_calls?: OpenAiToolCall[];
    };
  }>;
  usage?: {
    prompt_tokens: number;
    completion_tokens: number;
    total_tokens: number;
  };
};

// ─── Chamada principal (DeepSeek) ────────────────────────────────────────────

export async function callClaude(params: CallClaudeParams): Promise<ClaudeResponse> {
  const apiKey = Deno.env.get("ANTHROPIC_API_KEY") || Deno.env.get("DEEPSEEK_API_KEY");
  if (!apiKey) {
    throw new Error("ANTHROPIC_API_KEY ou DEEPSEEK_API_KEY não configurada no ambiente");
  }

  return await _callOpenAiCompatible(DEEPSEEK_API_URL, apiKey, params, "deepseek");
}

// ─── Chamada GPT-4o (OpenAI) ─────────────────────────────────────────────────

const OPENAI_API_URL = "https://api.openai.com/v1/chat/completions";

export async function callGpt(params: CallClaudeParams): Promise<ClaudeResponse> {
  const apiKey = Deno.env.get("OPENAI_API_KEY");
  if (!apiKey) {
    throw new Error("OPENAI_API_KEY não configurada no ambiente");
  }

  return await _callOpenAiCompatible(OPENAI_API_URL, apiKey, params, "openai");
}

// ─── Implementação compartilhada ──────────────────────────────────────────────

async function _callOpenAiCompatible(
  url: string,
  apiKey: string,
  params: CallClaudeParams,
  provider: string,
): Promise<ClaudeResponse> {
  const openAiMessages = toOpenAiMessages(params.system, params.messages);

  const body: Record<string, unknown> = {
    model: params.model,
    messages: openAiMessages,
    max_tokens: params.max_tokens,
  };

  if (params.tools.length > 0) {
    body.tools = toAnthropicTools(params.tools);
  }

  const controller = new AbortController();
  const timeoutId = setTimeout(() => controller.abort(), 45_000);

  let res: Response;
  try {
    res = await fetch(url, {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${apiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(body),
      signal: controller.signal,
    });
  } catch (err: unknown) {
    clearTimeout(timeoutId);
    if (err instanceof Error && err.name === "AbortError") {
      throw new Error(`Timeout: API ${provider} não respondeu em 45 segundos. Tente novamente.`);
    }
    throw err;
  } finally {
    clearTimeout(timeoutId);
  }

  if (!res.ok) {
    const errorBody = await res.text();
    let friendlyMsg: string;
    if (res.status === 401 || res.status === 403) {
      friendlyMsg = `Erro de autenticacao com a API ${provider}. Verifique a chave.`;
    } else if (res.status === 429) {
      friendlyMsg = `Limite de taxa da API ${provider} atingido. Aguarde alguns segundos.`;
    } else if (res.status >= 500) {
      friendlyMsg = `Servico ${provider} indisponivel no momento. Tente novamente.`;
    } else if (res.status === 413) {
      friendlyMsg = "Conteudo muito grande para processamento. Reduza o tamanho da mensagem.";
    } else {
      friendlyMsg = `Erro inesperado da API ${provider} (HTTP ${res.status}).`;
    }
    console.error(`[${provider}] erro:`, res.status, errorBody);
    throw new Error(friendlyMsg);
  }

  const json: OpenAiChatResponse = await res.json();
  return toAnthropicResponse(json);
}
