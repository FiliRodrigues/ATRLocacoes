import { AtrTool } from "../types.ts";

// ================================================================
// Ferramenta unificada: marcar qualquer entidade financeira como paga/pendente
// ================================================================
export const updatePaymentStatus: AtrTool = {
  name: "update_payment_status",
  category: "write",
  description:
    "Atualiza o status de pagamento de qualquer entidade financeira. " +
    "Use para: 'marca IPVA como pago', 'marca multa como pendente', " +
    "'registra pagamento do seguro', 'marca parcela do financiamento como paga', " +
    "'registra recebimento de aluguel como recebido'.\n" +
    "Entidades suportadas: 'ipva', 'licenciamento', 'seguro', 'multa', 'parcela_financiamento', 'parcela_seguro', 'recebimento'.",
  input_schema: {
    type: "object",
    properties: {
      entity: {
        type: "string",
        description: "Tipo da entidade: 'ipva', 'licenciamento', 'seguro', 'multa', 'parcela_financiamento', 'parcela_seguro', 'recebimento'.",
        enum: ["ipva", "licenciamento", "seguro", "multa", "parcela_financiamento", "parcela_seguro", "recebimento"],
      },
      entity_id: { type: "string", description: "ID (UUID) do registro a atualizar." },
      status_pagamento: {
        type: "string",
        description: "Status: 'Pago', 'Pendente', 'Atrasado', 'Cancelado'.",
      },
      data_pagamento: { type: "string", description: "Data do pagamento YYYY-MM-DD (opcional, default hoje)." },
      valor_recebido: { type: "number", description: "Valor recebido (para recebimentos). Opcional — se omitido, não atualiza." },
      observacoes: { type: "string", description: "Observações (opcional)." },
    },
    required: ["entity", "entity_id", "status_pagamento"],
  },

  preview: async (input, ctx) => {
    const supabase = ctx.supabase as Record<string, unknown>;
    const tenantId = ctx.tenant_id as string;
    const entity = String(input.entity);
    const tableMap: Record<string, string> = {
      ipva: "ipva", licenciamento: "licenciamento", seguro: "seguros",
      multa: "multas", parcela_financiamento: "parcelas_financiamento",
      parcela_seguro: "parcelas_seguro", recebimento: "recebimentos",
    };
    const table = tableMap[entity];
    if (!table) return `Atualizar pagamento: entidade "${entity}" inválida.`;

    const { data } = await (supabase as any).from(table)
      .select("*").eq("tenant_id", tenantId).eq("id", String(input.entity_id)).single();

    if (!data) return `Atualizar ${entity}: ID ${input.entity_id} não encontrado.`;
    return `Marcar ${entity} como ${input.status_pagamento}: ID ${input.entity_id}${input.data_pagamento ? ` em ${input.data_pagamento}` : ""}`;
  },

  handler: async (input, ctx) => {
    const supabase = ctx.supabase as Record<string, unknown>;
    const tenantId = ctx.tenant_id as string;
    const entity = String(input.entity);
    const tableMap: Record<string, string> = {
      ipva: "ipva", licenciamento: "licenciamento", seguro: "seguros",
      multa: "multas", parcela_financiamento: "parcelas_financiamento",
      parcela_seguro: "parcelas_seguro", recebimento: "recebimentos",
    };
    const table = tableMap[entity];
    if (!table) return { ok: false, error: `Entidade "${entity}" não suportada.` };

    const id = String(input.entity_id).trim();
    const { data } = await (supabase as any).from(table)
      .select("id, status_pagamento").eq("tenant_id", tenantId).eq("id", id).single();
    if (!data) return { ok: false, error: `Registro ${id} não encontrado na tabela ${table}.` };

    const status = String(input.status_pagamento).trim();
    const updates: Record<string, unknown> = { status_pagamento: status };

    if (input.data_pagamento) {
      if (!/^\d{4}-\d{2}-\d{2}$/.test(String(input.data_pagamento))) {
        return { ok: false, error: "Data inválida. Use YYYY-MM-DD." };
      }
      updates.data_pagamento = String(input.data_pagamento);
    }
    if (status === "Pago" && !input.data_pagamento) {
      updates.data_pagamento = new Date().toISOString().split("T")[0];
    }
    if (input.valor_recebido !== undefined && entity === "recebimento") {
      const valor = Number(input.valor_recebido);
      if (valor <= 0) return { ok: false, error: "valor_recebido deve ser > 0." };
      updates.valor_recebido = valor;
    }
    if (input.observacoes) {
      updates.observacoes = String(input.observacoes).trim();
    }

    const display = `Marcar ${entity} como ${status}: ID ${id}`;
    return { ok: true, data: { table, entity_id: id, updates, entity }, display };
  },
};

// ================================================================
// Deletar recebimento
// ================================================================
export const deleteRecebimento: AtrTool = {
  name: "delete_recebimento",
  category: "write",
  description:
    "Remove um recebimento registrado incorretamente. " +
    "Use para: 'apaga recebimento duplicado', 'remove parcela registrada errada'.",
  input_schema: {
    type: "object",
    properties: {
      recebimento_id: { type: "string", description: "ID (UUID) do recebimento a remover." },
    },
    required: ["recebimento_id"],
  },

  preview: async (input, ctx) => {
    const supabase = ctx.supabase as Record<string, unknown>;
    const tenantId = ctx.tenant_id as string;
    const { data } = await (supabase as any)
      .from("recebimentos")
      .select("id, locatario, valor_previsto, numero_parcela")
      .eq("tenant_id", tenantId)
      .eq("id", String(input.recebimento_id))
      .single();
    if (!data) return `Deletar recebimento: ID ${input.recebimento_id} não encontrado.`;
    const parcela = data.numero_parcela ? ` parcela ${data.numero_parcela}` : "";
    return `Deletar recebimento${parcela} de R$ ${Number(data.valor_previsto).toFixed(2)}${data.locatario ? ` (${data.locatario})` : ""}`;
  },

  handler: async (input, ctx) => {
    const supabase = ctx.supabase as Record<string, unknown>;
    const tenantId = ctx.tenant_id as string;
    const id = String(input.recebimento_id).trim();

    const { data } = await (supabase as any)
      .from("recebimentos")
      .select("id, valor_previsto")
      .eq("tenant_id", tenantId)
      .eq("id", id)
      .single();
    if (!data) return { ok: false, error: "Recebimento não encontrado." };

    const display = (await deleteRecebimento.preview!(input, ctx)) ?? "";
    return { ok: true, data: { recebimento_id: id }, display };
  },
};

// ================================================================
// Ferramenta: criar novo recebimento de aluguel
// ================================================================
export const createRecebimento: AtrTool = {
  name: "create_recebimento",
  category: "write",
  description:
    "Registra um novo recebimento de aluguel vinculado a um veículo. " +
    "Use para: 'registra recebimento de R$5.000 para ABC1234 em janeiro', " +
    "'adiciona parcela de aluguel da cliente XPTO'.",
  input_schema: {
    type: "object",
    properties: {
      veiculo_id: { type: "string", description: "ID (UUID) do veículo." },
      locatario: { type: "string", description: "Nome do locatário (opcional)." },
      numero_parcela: { type: "integer", description: "Número da parcela (opcional)." },
      valor_previsto: { type: "number", description: "Valor previsto do recebimento em R$." },
      valor_recebido: { type: "number", description: "Valor efetivamente recebido (opcional, default = valor_previsto)." },
      data_vencimento: { type: "string", description: "Data de vencimento YYYY-MM-DD (opcional)." },
      data_recebimento: { type: "string", description: "Data do recebimento YYYY-MM-DD (opcional, default hoje se status='Pago')." },
      status_pagamento: { type: "string", description: "Status: 'Pago', 'Pendente', 'Atrasado'. Default 'Pendente'." },
      observacoes: { type: "string", description: "Observações (opcional)." },
    },
    required: ["veiculo_id", "valor_previsto"],
  },

  preview: async (input, ctx) => {
    const supabase = ctx.supabase as Record<string, unknown>;
    const tenantId = ctx.tenant_id as string;
    const { data } = await (supabase as any).from("veiculos")
      .select("id, placa").eq("tenant_id", tenantId).eq("id", String(input.veiculo_id)).single();
    if (!data) return `Criar recebimento: veículo ${input.veiculo_id} não encontrado.`;
    const valor = Number(input.valor_recebido || input.valor_previsto);
    return `Registrar recebimento de R$ ${valor.toFixed(2)} para ${data.placa}${input.locatario ? ` (${input.locatario})` : ""}`;
  },

  handler: async (input, ctx) => {
    const supabase = ctx.supabase as Record<string, unknown>;
    const tenantId = ctx.tenant_id as string;
    const { data: veiculo } = await (supabase as any).from("veiculos")
      .select("id, placa").eq("tenant_id", tenantId).eq("id", String(input.veiculo_id)).single();
    if (!veiculo) return { ok: false, error: "Veículo não encontrado." };

    const valorPrevisto = Number(input.valor_previsto);
    if (valorPrevisto <= 0) return { ok: false, error: "valor_previsto deve ser > 0." };

    const validatedData: Record<string, unknown> = {
      veiculo_id: String(input.veiculo_id),
      locatario: input.locatario ? String(input.locatario).trim() : null,
      numero_parcela: input.numero_parcela != null ? Number(input.numero_parcela) : null,
      valor_previsto: valorPrevisto,
      valor_recebido: input.valor_recebido != null ? Number(input.valor_recebido) : valorPrevisto,
      data_vencimento: input.data_vencimento ? String(input.data_vencimento) : null,
      data_recebimento: null,
      status_pagamento: input.status_pagamento ? String(input.status_pagamento).trim() : "Pendente",
      observacoes: input.observacoes ? String(input.observacoes).trim() : null,
    };

    // Validar datas
    if (validatedData.data_vencimento && !/^\d{4}-\d{2}-\d{2}$/.test(String(validatedData.data_vencimento))) {
      return { ok: false, error: "data_vencimento inválida. Use YYYY-MM-DD." };
    }

    // Se status é Pago, definir data_recebimento
    if (validatedData.status_pagamento === "Pago") {
      validatedData.data_recebimento = input.data_recebimento || new Date().toISOString().split("T")[0];
    }

    const display = (await createRecebimento.preview!(input, ctx)) ?? "";
    return { ok: true, data: validatedData, display };
  },
};
