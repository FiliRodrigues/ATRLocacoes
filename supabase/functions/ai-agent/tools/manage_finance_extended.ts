import { AtrTool } from "../types.ts";

// ================================================================
// Deletar financiamento (corrigir registro errado)
// ================================================================
export const deleteFinanciamento: AtrTool = {
  name: "delete_financiamento",
  category: "write",
  description:
    "Deleta um financiamento incorreto ou nulo. " +
    "Use para: 'remove o financiamento registrado errado', 'apaga o débito inválido'.",
  input_schema: {
    type: "object",
    properties: {
      financiamento_id: { type: "string", description: "ID do financiamento a deletar." },
    },
    required: ["financiamento_id"],
  },

  preview: async (input, _ctx) => `Deletar financiamento: ${input.financiamento_id}`,

  handler: async (input, ctx) => {
    const supabase = ctx.supabase as Record<string, unknown>;
    const tenantId = ctx.tenant_id as string;
    const id = String(input.financiamento_id).trim();

    const { data } = await (supabase as any)
      .from("financiamentos")
      .select("id, veiculo_id")
      .eq("tenant_id", tenantId)
      .eq("id", id)
      .single();

    if (!data) return { ok: false, error: "Financiamento não encontrado." };
    const display = (await deleteFinanciamento.preview!(input, ctx)) ?? "";
    return { ok: true, data: { financiamento_id: id }, display };
  },
};

// ================================================================
// Atualizar parcela de seguro
// ================================================================
export const updateParcelaSeguro: AtrTool = {
  name: "update_parcela_seguro",
  category: "write",
  description:
    "Atualiza o status de pagamento de uma parcela de seguro. " +
    "Use para: 'marca parcela de seguro como paga', 'atualiza data de pagamento'.",
  input_schema: {
    type: "object",
    properties: {
      parcela_id: { type: "string", description: "ID da parcela de seguro." },
      status_pagamento: { type: "string", description: "Novo status: 'Pendente', 'Pago', 'Atrasado'." },
      data_pagamento: { type: "string", description: "Data de pagamento YYYY-MM-DD (opcional)." },
    },
    required: ["parcela_id"],
  },

  preview: async (input, _ctx) => {
    const statusText = input.status_pagamento ? ` → ${input.status_pagamento}` : "";
    return `Atualizar parcela seguro: ${input.parcela_id}${statusText}`;
  },

  handler: async (input, ctx) => {
    const supabase = ctx.supabase as Record<string, unknown>;
    const tenantId = ctx.tenant_id as string;
    const id = String(input.parcela_id).trim();

    const { data } = await (supabase as any)
      .from("parcelas_seguro")
      .select("id")
      .eq("tenant_id", tenantId)
      .eq("id", id)
      .single();

    if (!data) return { ok: false, error: "Parcela de seguro não encontrada." };

    const updates: Record<string, unknown> = {};
    if (input.status_pagamento !== undefined) {
      updates.status_pagamento = String(input.status_pagamento).trim();
    }
    if (input.data_pagamento !== undefined) {
      updates.data_pagamento = String(input.data_pagamento);
    }

    if (Object.keys(updates).length === 0) {
      return { ok: false, error: "Nenhum campo para atualizar." };
    }

    const display = (await updateParcelaSeguro.preview!(input, ctx)) ?? "";
    return { ok: true, data: { parcela_id: id, updates }, display };
  },
};

// ================================================================
// Criar hodômetro (registro de km)
// ================================================================
export const createHodometro: AtrTool = {
  name: "create_hodometro",
  category: "write",
  description:
    "Registra uma leitura de hodômetro (quilometragem atual do veículo). " +
    "Use para: 'registra 45.000 km para o carro', 'atualiza odômetro do veículo'.",
  input_schema: {
    type: "object",
    properties: {
      veiculo_placa: { type: "string", description: "Placa do veículo (ex: ABC-1234)." },
      km: { type: "integer", description: "Quilometragem atual." },
      registrado_por: { type: "string", description: "Quem registrou (ex: 'João Silva'). Default: 'sistema'." },
    },
    required: ["veiculo_placa", "km"],
  },

  preview: async (input, _ctx) => `Registrar hodômetro: ${input.veiculo_placa} → ${input.km} km`,

  handler: async (input, ctx) => {
    const supabase = ctx.supabase as Record<string, unknown>;
    const tenantId = ctx.tenant_id as string;

    const placa = String(input.veiculo_placa).toUpperCase().trim();
    const km = Number(input.km);

    // Verifica se veículo existe
    const { data: veiculo } = await (supabase as any)
      .from("veiculos")
      .select("id, km_atual")
      .eq("tenant_id", tenantId)
      .eq("placa", placa)
      .single();

    if (!veiculo) return { ok: false, error: `Veículo com placa ${placa} não encontrado.` };

    // Valida se km é maior que o atual
    if (veiculo.km_atual !== null && km < veiculo.km_atual) {
      return {
        ok: false,
        error: `Km ${km} é menor que o km atual (${veiculo.km_atual}). Km não pode retroagir.`,
      };
    }

    const validatedData: Record<string, unknown> = {
      veiculo_placa: placa,
      km,
      registrado_por: input.registrado_por ? String(input.registrado_por).trim() : "sistema",
    };

    const display = (await createHodometro.preview!(input, ctx)) ?? "";
    return { ok: true, data: validatedData, display };
  },
};

// ================================================================
// Atualizar IPVA
// ================================================================
export const updateIpva: AtrTool = {
  name: "update_ipva",
  category: "write",
  description:
    "Atualiza status de pagamento do IPVA. " +
    "Use para: 'marca IPVA 2025 como pago', 'registra data de pagamento do IPVA'.",
  input_schema: {
    type: "object",
    properties: {
      ipva_id: { type: "string", description: "ID do IPVA." },
      status_pagamento: { type: "string", description: "Status: 'Pendente', 'Pago', 'Cancelado'." },
      data_pagamento: { type: "string", description: "Data de pagamento YYYY-MM-DD (opcional)." },
      observacoes: { type: "string", description: "Observações (opcional)." },
    },
    required: ["ipva_id"],
  },

  preview: async (input, _ctx) => {
    const statusText = input.status_pagamento ? ` → ${input.status_pagamento}` : "";
    return `Atualizar IPVA: ${input.ipva_id}${statusText}`;
  },

  handler: async (input, ctx) => {
    const supabase = ctx.supabase as Record<string, unknown>;
    const tenantId = ctx.tenant_id as string;
    const id = String(input.ipva_id).trim();

    const { data } = await (supabase as any)
      .from("ipva")
      .select("id")
      .eq("tenant_id", tenantId)
      .eq("id", id)
      .single();

    if (!data) return { ok: false, error: "IPVA não encontrado." };

    const updates: Record<string, unknown> = {};
    if (input.status_pagamento !== undefined) {
      updates.status_pagamento = String(input.status_pagamento).trim();
    }
    if (input.data_pagamento !== undefined) {
      updates.data_pagamento = String(input.data_pagamento);
    }
    if (input.observacoes !== undefined) {
      updates.observacoes = String(input.observacoes).trim();
    }

    if (Object.keys(updates).length === 0) {
      return { ok: false, error: "Nenhum campo para atualizar." };
    }

    const display = (await updateIpva.preview!(input, ctx)) ?? "";
    return { ok: true, data: { ipva_id: id, updates }, display };
  },
};

// ================================================================
// Atualizar Licenciamento
// ================================================================
export const updateLicenciamento: AtrTool = {
  name: "update_licenciamento",
  category: "write",
  description:
    "Atualiza status de pagamento do licenciamento. " +
    "Use para: 'marca licenciamento como pago', 'registra data de pagamento'.",
  input_schema: {
    type: "object",
    properties: {
      licenciamento_id: { type: "string", description: "ID do licenciamento." },
      status_pagamento: { type: "string", description: "Status: 'Pendente', 'Pago', 'Cancelado'." },
      data_pagamento: { type: "string", description: "Data de pagamento YYYY-MM-DD (opcional)." },
      observacoes: { type: "string", description: "Observações (opcional)." },
    },
    required: ["licenciamento_id"],
  },

  preview: async (input, _ctx) => {
    const statusText = input.status_pagamento ? ` → ${input.status_pagamento}` : "";
    return `Atualizar licenciamento: ${input.licenciamento_id}${statusText}`;
  },

  handler: async (input, ctx) => {
    const supabase = ctx.supabase as Record<string, unknown>;
    const tenantId = ctx.tenant_id as string;
    const id = String(input.licenciamento_id).trim();

    const { data } = await (supabase as any)
      .from("licenciamento")
      .select("id")
      .eq("tenant_id", tenantId)
      .eq("id", id)
      .single();

    if (!data) return { ok: false, error: "Licenciamento não encontrado." };

    const updates: Record<string, unknown> = {};
    if (input.status_pagamento !== undefined) {
      updates.status_pagamento = String(input.status_pagamento).trim();
    }
    if (input.data_pagamento !== undefined) {
      updates.data_pagamento = String(input.data_pagamento);
    }
    if (input.observacoes !== undefined) {
      updates.observacoes = String(input.observacoes).trim();
    }

    if (Object.keys(updates).length === 0) {
      return { ok: false, error: "Nenhum campo para atualizar." };
    }

    const display = (await updateLicenciamento.preview!(input, ctx)) ?? "";
    return { ok: true, data: { licenciamento_id: id, updates }, display };
  },
};

// ================================================================
// Atualizar Multa
// ================================================================
export const updateMulta: AtrTool = {
  name: "update_multa",
  category: "write",
  description: "Atualiza status de pagamento de uma multa de trânsito.",
  input_schema: {
    type: "object",
    properties: {
      multa_id: { type: "string", description: "ID da multa." },
      status_pagamento: { type: "string", description: "Status: 'Pendente', 'Pago', 'Cancelado'." },
      data_pagamento: { type: "string", description: "Data de pagamento YYYY-MM-DD (opcional)." },
      observacoes: { type: "string", description: "Observações (opcional)." },
    },
    required: ["multa_id"],
  },

  preview: async (input, _ctx) => {
    const statusText = input.status_pagamento ? ` → ${input.status_pagamento}` : "";
    return `Atualizar multa: ${input.multa_id}${statusText}`;
  },

  handler: async (input, ctx) => {
    const supabase = ctx.supabase as Record<string, unknown>;
    const tenantId = ctx.tenant_id as string;
    const id = String(input.multa_id).trim();

    const { data } = await (supabase as any)
      .from("multas")
      .select("id")
      .eq("tenant_id", tenantId)
      .eq("id", id)
      .single();

    if (!data) return { ok: false, error: "Multa não encontrada." };

    const updates: Record<string, unknown> = {};
    if (input.status_pagamento !== undefined) {
      updates.status_pagamento = String(input.status_pagamento).trim();
    }
    if (input.data_pagamento !== undefined) {
      updates.data_pagamento = String(input.data_pagamento);
    }
    if (input.observacoes !== undefined) {
      updates.observacoes = String(input.observacoes).trim();
    }

    if (Object.keys(updates).length === 0) {
      return { ok: false, error: "Nenhum campo para atualizar." };
    }

    const display = (await updateMulta.preview!(input, ctx)) ?? "";
    return { ok: true, data: { multa_id: id, updates }, display };
  },
};

// ================================================================
// Validar km para regra de manutenção (helper para criar manutenção)
// ================================================================
export const validateKmIntervalo: AtrTool = {
  name: "validate_km_intervalo",
  category: "read",
  description:
    "Verifica se o km informado é válido para uma regra de manutenção " +
    "(km > km_atual do veículo). Use antes de registrar manutenção preventiva.",
  input_schema: {
    type: "object",
    properties: {
      veiculo_placa: { type: "string", description: "Placa do veículo." },
      km_servico: { type: "integer", description: "Km em que o serviço foi realizado." },
    },
    required: ["veiculo_placa", "km_servico"],
  },

  preview: async (input, _ctx) => `Validar km: ${input.veiculo_placa} @ ${input.km_servico} km`,

  handler: async (input, ctx) => {
    const supabase = ctx.supabase as Record<string, unknown>;
    const tenantId = ctx.tenant_id as string;

    const placa = String(input.veiculo_placa).toUpperCase().trim();
    const km = Number(input.km_servico);

    const { data: veiculo } = await (supabase as any)
      .from("veiculos")
      .select("placa, km_atual")
      .eq("tenant_id", tenantId)
      .eq("placa", placa)
      .single();

    if (!veiculo) return { ok: false, error: `Veículo ${placa} não encontrado.` };

    const kmAtual = veiculo.km_atual || 0;
    const isValid = km > kmAtual;

    return {
      ok: true,
      data: {
        veiculo_placa: placa,
        km_servico: km,
        km_atual: kmAtual,
        is_valid: isValid,
        mensagem: isValid
          ? `✓ Km ${km} é válido (maior que km atual ${kmAtual})`
          : `✗ Km ${km} é inválido (não pode ser menor/igual ao km atual ${kmAtual})`,
      },
    };
  },
};
