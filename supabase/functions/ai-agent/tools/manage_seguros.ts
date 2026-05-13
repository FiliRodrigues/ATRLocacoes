import { AtrTool } from "../types.ts";

// ================================================================
// Criar apólice de seguro
// ================================================================
export const createSeguro: AtrTool = {
  name: "create_seguro",
  category: "write",
  description:
    "Registra nova apólice de seguro para um veículo. " +
    "Use para: 'registra seguro do ABC-1234 na Porto Seguro por R$3.200', " +
    "'adiciona apólice anual da frota na Bradesco Seguros'.",
  input_schema: {
    type: "object",
    properties: {
      veiculo_placa: { type: "string", description: "Placa do veículo (ex: ABC-1234)." },
      ano_referencia: { type: "integer", description: "Ano de referência do seguro (ex: 2025)." },
      empresa: { type: "string", description: "Seguradora (ex: 'Porto Seguro', 'Bradesco Seguros')." },
      numero_apolice: { type: "string", description: "Número da apólice (opcional)." },
      valor_apolice: { type: "number", description: "Valor total da apólice em R$ (opcional)." },
      num_parcelas: { type: "integer", description: "Número de parcelas (opcional)." },
      data_inicio: { type: "string", description: "Data de início da cobertura YYYY-MM-DD (opcional)." },
      data_renovacao: { type: "string", description: "Data de renovação YYYY-MM-DD (opcional)." },
      observacoes: { type: "string", description: "Observações adicionais (opcional)." },
    },
    required: ["veiculo_placa", "ano_referencia", "empresa"],
  },

  preview: async (input, ctx) => {
    const placa = String(input.veiculo_placa).toUpperCase().trim();
    const valor = input.valor_apolice ? ` — R$ ${Number(input.valor_apolice).toFixed(2)}` : "";
    return `Registrar seguro ${input.ano_referencia} — ${placa} — ${input.empresa}${valor}`;
  },

  handler: async (input, ctx) => {
    const supabase = ctx.supabase as Record<string, unknown>;
    const tenantId = ctx.tenant_id as string;

    const placa = String(input.veiculo_placa).toUpperCase().trim();
    const { data: veiculo } = await (supabase as any)
      .from("veiculos")
      .select("id, placa")
      .eq("tenant_id", tenantId)
      .eq("placa", placa)
      .single();
    if (!veiculo) return { ok: false, error: `Veículo com placa ${placa} não encontrado.` };

    const anoRef = Number(input.ano_referencia);
    if (!Number.isInteger(anoRef) || anoRef < 2000 || anoRef > 2100) {
      return { ok: false, error: "ano_referencia inválido." };
    }

    const validatedData: Record<string, unknown> = {
      veiculo_id: veiculo.id,
      ano_referencia: anoRef,
      empresa: String(input.empresa).trim(),
      status_pagamento: "Pendente",
    };

    if (input.numero_apolice) validatedData.numero_apolice = String(input.numero_apolice).trim();
    if (input.valor_apolice != null) validatedData.valor_apolice = Number(input.valor_apolice);
    if (input.num_parcelas != null) validatedData.num_parcelas = Number(input.num_parcelas);
    if (input.data_inicio) {
      if (!/^\d{4}-\d{2}-\d{2}$/.test(String(input.data_inicio))) {
        return { ok: false, error: "data_inicio inválida. Use YYYY-MM-DD." };
      }
      validatedData.data_inicio = String(input.data_inicio);
    }
    if (input.data_renovacao) {
      if (!/^\d{4}-\d{2}-\d{2}$/.test(String(input.data_renovacao))) {
        return { ok: false, error: "data_renovacao inválida. Use YYYY-MM-DD." };
      }
      validatedData.data_renovacao = String(input.data_renovacao);
    }
    if (input.observacoes) validatedData.observacoes = String(input.observacoes).trim();

    const display = (await createSeguro.preview!(input, ctx)) ?? "";
    return { ok: true, data: validatedData, display };
  },
};

// ================================================================
// Atualizar apólice de seguro
// ================================================================
export const updateSeguro: AtrTool = {
  name: "update_seguro",
  category: "write",
  description:
    "Atualiza dados de uma apólice de seguro existente. " +
    "Use para: 'atualiza número da apólice', 'corrige valor do seguro', 'registra data de renovação'.",
  input_schema: {
    type: "object",
    properties: {
      seguro_id: { type: "string", description: "ID (UUID) da apólice de seguro." },
      empresa: { type: "string", description: "Nova seguradora." },
      numero_apolice: { type: "string", description: "Novo número da apólice." },
      valor_apolice: { type: "number", description: "Novo valor da apólice em R$." },
      num_parcelas: { type: "integer", description: "Novo número de parcelas." },
      data_inicio: { type: "string", description: "Nova data de início YYYY-MM-DD." },
      data_renovacao: { type: "string", description: "Nova data de renovação YYYY-MM-DD." },
      status_pagamento: { type: "string", description: "Novo status: 'Pendente', 'Pago', 'Cancelado'." },
      observacoes: { type: "string", description: "Novas observações." },
    },
    required: ["seguro_id"],
  },

  preview: async (input, ctx) => {
    const supabase = ctx.supabase as Record<string, unknown>;
    const tenantId = ctx.tenant_id as string;
    const { data } = await (supabase as any)
      .from("seguros")
      .select("id, empresa, ano_referencia")
      .eq("tenant_id", tenantId)
      .eq("id", String(input.seguro_id))
      .single();
    if (!data) return `Atualizar seguro: ID ${input.seguro_id} não encontrado.`;
    return `Atualizar seguro ${data.empresa} ${data.ano_referencia} (ID ${input.seguro_id})`;
  },

  handler: async (input, ctx) => {
    const supabase = ctx.supabase as Record<string, unknown>;
    const tenantId = ctx.tenant_id as string;
    const id = String(input.seguro_id).trim();

    const { data } = await (supabase as any)
      .from("seguros")
      .select("id")
      .eq("tenant_id", tenantId)
      .eq("id", id)
      .single();
    if (!data) return { ok: false, error: "Seguro não encontrado." };

    const updates: Record<string, unknown> = {};
    if (input.empresa !== undefined) updates.empresa = String(input.empresa).trim();
    if (input.numero_apolice !== undefined) updates.numero_apolice = String(input.numero_apolice).trim();
    if (input.valor_apolice !== undefined) updates.valor_apolice = Number(input.valor_apolice);
    if (input.num_parcelas !== undefined) updates.num_parcelas = Number(input.num_parcelas);
    if (input.status_pagamento !== undefined) updates.status_pagamento = String(input.status_pagamento).trim();
    if (input.observacoes !== undefined) updates.observacoes = String(input.observacoes).trim();
    if (input.data_inicio !== undefined) {
      if (!/^\d{4}-\d{2}-\d{2}$/.test(String(input.data_inicio))) {
        return { ok: false, error: "data_inicio inválida. Use YYYY-MM-DD." };
      }
      updates.data_inicio = String(input.data_inicio);
    }
    if (input.data_renovacao !== undefined) {
      if (!/^\d{4}-\d{2}-\d{2}$/.test(String(input.data_renovacao))) {
        return { ok: false, error: "data_renovacao inválida. Use YYYY-MM-DD." };
      }
      updates.data_renovacao = String(input.data_renovacao);
    }

    if (Object.keys(updates).length === 0) return { ok: false, error: "Nenhum campo para atualizar." };

    const display = (await updateSeguro.preview!(input, ctx)) ?? "";
    return { ok: true, data: { seguro_id: id, updates }, display };
  },
};
