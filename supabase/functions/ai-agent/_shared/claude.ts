import type { ClaudeMessage, ClaudeResponse, ToolDefinition } from "../types.ts";

const ANTHROPIC_API_URL = "https://api.anthropic.com/v1/messages";
const ANTHROPIC_VERSION = "2023-06-01";

export type CallClaudeParams = {
  model: string;
  system: string;
  messages: ClaudeMessage[];
  tools: ToolDefinition[];
  max_tokens: number;
};

/**
 * Chama a API Anthropic (Claude) com o prompt e ferramentas fornecidos.
 * Retorna a resposta parseada ou lança um erro com status e corpo.
 */
export async function callClaude(params: CallClaudeParams): Promise<ClaudeResponse> {
  const apiKey = Deno.env.get("ANTHROPIC_API_KEY");
  if (!apiKey) {
    throw new Error("ANTHROPIC_API_KEY não configurada no ambiente");
  }

  const body: Record<string, unknown> = {
    model: params.model,
    system: params.system,
    messages: params.messages,
    max_tokens: params.max_tokens,
  };

  // Só inclui tools se houver ferramentas definidas
  if (params.tools.length > 0) {
    body.tools = params.tools;
  }

  const res = await fetch(ANTHROPIC_API_URL, {
    method: "POST",
    headers: {
      "x-api-key": apiKey,
      "anthropic-version": ANTHROPIC_VERSION,
      "content-type": "application/json",
    },
    body: JSON.stringify(body),
  });

  if (!res.ok) {
    const errorBody = await res.text();
    throw new Error(
      `Anthropic API erro ${res.status}: ${errorBody}`
    );
  }

  const json: ClaudeResponse = await res.json();
  return json;
}
