import type { SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2";

// ================================================================
// Tipos base do agente ATR
// ================================================================

/** Categoria da ferramenta: leitura ou escrita */
export type ToolCategory = "read" | "write";

/** Contexto injetado em toda execução de ferramenta */
export type ToolContext = {
  tenant_id: string;
  user_id: string;
  conversation_id: string;
  channel: "web" | "whatsapp";
  /** Client autenticado com o JWT do usuário (respeita RLS) */
  userClient: SupabaseClient;
  /** Client service_role (para auditoria, rate limits, etc.) */
  serviceClient: SupabaseClient;
};

/** Resultado padronizado de execução de ferramenta */
export type ToolResult = {
  ok: boolean;
  data?: unknown;
  error?: string;
  /** Texto formatado para exibição ao usuário na interface */
  display?: string;
};

/** Definição de uma ferramenta registrada no agente ATR */
export type AtrTool = {
  name: string;
  description: string;
  category: ToolCategory;
  input_schema: Record<string, unknown>;
  /** Handler principal: executa a ação da ferramenta */
  handler: (input: Record<string, unknown>, ctx: ToolContext) => Promise<ToolResult>;
  /** Preview opcional: gera texto de confirmação antes da execução (writes) */
  preview?: (input: Record<string, unknown>, ctx: ToolContext) => Promise<string>;
};

// ================================================================
// Tipos da API Anthropic (Claude)
// ================================================================

/** Mensagem no formato Anthropic */
export type ClaudeMessage = {
  role: "user" | "assistant";
  content: ClaudeContentBlock[];
};

/** Bloco de conteúdo (texto, imagem, tool_use, tool_result) */
export type ClaudeContentBlock =
  | { type: "text"; text: string }
  | { type: "image"; source: { type: "base64"; media_type: string; data: string } }
  | {
      type: "tool_use";
      id: string;
      name: string;
      input: Record<string, unknown>;
    }
  | {
      type: "tool_result";
      tool_use_id: string;
      content: string;
      is_error?: boolean;
    };

/** Definição de tool no formato Anthropic */
export type ToolDefinition = {
  name: string;
  description: string;
  input_schema: Record<string, unknown>;
};

/** Resposta da API Anthropic */
export type ClaudeResponse = {
  id: string;
  content: ClaudeContentBlock[];
  stop_reason: "end_turn" | "tool_use" | "max_tokens";
  usage: { input_tokens: number; output_tokens: number };
};

// ================================================================
// Tipos internos do agente
// ================================================================

/** Parâmetros recebidos pela Edge Function */
export type AgentParams = {
  tenant_id: string;
  user_id: string;
  channel: "web" | "whatsapp";
  conversation_id?: string;
  message: { role: "user"; content: ClaudeContentBlock[] };
  /** ID de uma ação pendente a confirmar/rejeitar */
  confirm_action_id?: string;
  /** Client Supabase autenticado com JWT do usuário (respeita RLS) */
  userClient: SupabaseClient;
  /** Client Supabase service_role (bypass RLS, para auditoria e rate limits) */
  serviceClient: SupabaseClient;
};

/** Resposta da Edge Function para o cliente */
export type AgentResponse = {
  conversation_id: string;
  /** Mensagem do assistant para exibir, ou null se não houver texto novo */
  message: ClaudeMessage | null;
  /** Ações de escrita que precisam de confirmação do usuário */
  pending_actions: PendingAction[];
};

/** Ação pendente de confirmação */
export type PendingAction = {
  action_id: string;
  tool_name: string;
  preview: string;
};

// ================================================================
// Tipos do banco (matching exato das colunas)
// ================================================================

/** Tabela: ai_conversations */
export type AiConversation = {
  id: string;
  tenant_id: string;
  user_id: string;
  channel: "web" | "whatsapp";
  title: string | null;
  created_at: string;
  updated_at: string;
};

/** Tabela: ai_messages */
export type AiMessage = {
  id: string;
  conversation_id: string;
  role: "user" | "assistant" | "tool_result";
  content: ClaudeContentBlock[];
  tool_calls: string[] | null;
  created_at: string;
};

/** Tabela: ai_action_audit */
export type AiActionAudit = {
  id: string;
  tenant_id: string;
  user_id: string;
  conversation_id: string | null;
  tool_name: string;
  input: Record<string, unknown>;
  output: Record<string, unknown> | null;
  status: "pending_confirmation" | "confirmed" | "executed" | "failed" | "cancelled";
  error: string | null;
  created_at: string;
  executed_at: string | null;
};

/** Tabela: ai_rate_limits */
export type AiRateLimit = {
  id: string;
  phone: string;
  minute_count: number;
  hour_count: number;
  day_count: number;
  minute_window_start: string;
  hour_window_start: string;
  day_window_start: string;
};

// ================================================================
// Schemas do banco (veiculos, manutencoes, despesas, etc.)
// ================================================================

/** Tabela: veiculos */
export type Veiculo = {
  id: string;
  placa: string;
  tipo: string | null;
  marca: string | null;
  modelo: string | null;
  ano_fabricacao_modelo: string | null;
  situacao_operacional: string | null;
  km_atual: number | null;
  valor_veiculo: number | null;
  tenant_id: string;
};

/** Tabela: manutencoes */
export type Manutencao = {
  id: string;
  veiculo_id: string;
  data_servico: string;
  descricao: string | null;
  tipo_servico: string | null;
  oficina: string | null;
  valor_servico: number | null;
  km_registro: number | null;
  status_pagamento: string;
  tenant_id: string;
};

/** Tabela: despesas */
export type Despesa = {
  id: string;
  veiculo_placa: string | null;
  motorista: string | null;
  data: string;
  tipo: string | null;
  descricao: string | null;
  odometro: number | null;
  litros: number | null;
  valor: number | null;
  pago: boolean | null;
  nf: string | null;
  tenant_id: string;
};

/** Tabela: contratos */
export type Contrato = {
  id: string;
  numero: string;
  cliente_nome: string | null;
  cliente_cnpj: string | null;
  veiculo_placa: string | null;
  data_inicio: string | null;
  data_fim: string | null;
  valor_mensal: number | null;
  status: "ativo" | "encerrado" | "suspenso" | "rascunho";
  tenant_id: string;
};

/** Tabela: financiamentos */
export type Financiamento = {
  id: string;
  veiculo_id: string;
  situacao: string | null;
  banco_financeira: string | null;
  valor_financiado: number | null;
  valor_ja_pago: number | null;
  quantidade_parcelas: number | null;
  recebimento_mensal: number | null;
  valor_parcela: number | null;
  taxa_juros_mensal: number | null;
  tenant_id: string;
};

/** Tabela: parcelas_financiamento */
export type ParcelaFinanciamento = {
  id: string;
  financiamento_id: string;
  numero_parcela: number;
  valor_parcela: number | null;
  data_vencimento: string | null;
  data_pagamento: string | null;
  status_pagamento: string;
  tenant_id: string;
};

/** Tabela: hodometros */
export type Hodometro = {
  id: string;
  veiculo_placa: string | null;
  km: number | null;
  registrado_por: string | null;
  tenant_id: string;
};
