import { AtrTool } from "../types.ts";

export const updateAbastecimento: AtrTool = {
  name: "update_abastecimento",
  category: "write",
  description: "Atualiza um registro de abastecimento. Use para corrigir litros, valor, km ou posto.",
  input_schema: {
    type: "object",
    properties: {
      abastecimento_id: { type: "string", description: "ID do abastecimento." },
      litros: { type: "number", description: "Novos litros." },
      valor_total: { type: "number", description: "Novo valor total." },
      km_odometro: { type: "number", description: "Novo km." },
      tipo: { type: "string", description: "Novo tipo: gasolina, etanol, diesel, gnv." },
      posto: { type: "string", description: "Novo posto." },
      data: { type: "string", description: "Nova data YYYY-MM-DD." },
    },
    required: ["abastecimento_id"],
  },

  preview: async (input, ctx) => {
    const supabase = ctx.supabase as Record<string, unknown>;
    const tenantId = ctx.tenant_id as string;
    const { data } = await (supabase as any).from("abastecimentos")
      .select("id, veiculo_placa, litros, valor_total")
      .eq("tenant_id", tenantId).eq("id", String(input.abastecimento_id)).single();
    if (!data) return `Atualizar abastecimento: ID ${input.abastecimento_id} não encontrado.`;
    const mudancas: string[] = [];
    for (const [k, v] of Object.entries(input)) {
      if (k !== "abastecimento_id" && v !== undefined && v !== null) mudancas.push(`${k}=${v}`);
    }
    return `Atualizar abastecimento ${data.veiculo_placa} (${data.litros}L): ${mudancas.join(", ") || "sem alterações"}`;
  },

  handler: async (input, ctx) => {
    const supabase = ctx.supabase as Record<string, unknown>;
    const tenantId = ctx.tenant_id as string;
    const id = String(input.abastecimento_id).trim();
    if (!id) return { ok: false, error: "ID é obrigatório." };

    const { data } = await (supabase as any).from("abastecimentos")
      .select("id, veiculo_placa").eq("tenant_id", tenantId).eq("id", id).single();
    if (!data) return { ok: false, error: `Abastecimento ${id} não encontrado.` };

    const updates: Record<string, unknown> = {};
    if (input.litros !== undefined && input.litros !== null) updates.litros = Number(input.litros);
    if (input.valor_total !== undefined && input.valor_total !== null) updates.valor_total = Number(input.valor_total);
    if (input.km_odometro !== undefined && input.km_odometro !== null) updates.km_odometro = Number(input.km_odometro);
    if (input.tipo !== undefined) updates.tipo = String(input.tipo).trim();
    if (input.posto !== undefined) updates.posto = String(input.posto).trim();
    if (input.data !== undefined) updates.data = String(input.data).trim();

    if (Object.keys(updates).length === 0) return { ok: false, error: "Nenhum campo para atualizar." };
    if (updates.data && !/^\d{4}-\d{2}-\d{2}$/.test(String(updates.data))) {
      return { ok: false, error: "Data inválida. Use YYYY-MM-DD." };
    }

    const display = (await updateAbastecimento.preview!(input, ctx)) ?? "";
    return { ok: true, data: { abastecimento_id: id, updates }, display };
  },
};

export const deleteAbastecimento: AtrTool = {
  name: "delete_abastecimento",
  category: "write",
  description: "Remove um abastecimento. IRREVERSÍVEL.",
  input_schema: {
    type: "object",
    properties: {
      abastecimento_id: { type: "string", description: "ID do abastecimento." },
      confirm: { type: "boolean", description: "Deve ser true." },
    },
    required: ["abastecimento_id", "confirm"],
  },

  preview: async (input, ctx) => {
    const supabase = ctx.supabase as Record<string, unknown>;
    const tenantId = ctx.tenant_id as string;
    const { data } = await (supabase as any).from("abastecimentos")
      .select("id, veiculo_placa, litros, valor_total")
      .eq("tenant_id", tenantId).eq("id", String(input.abastecimento_id)).single();
    if (!data) return `Excluir abastecimento: ID ${input.abastecimento_id} não encontrado.`;
    if (input.confirm !== true) return `⚠️ Excluir abastecimento ${data.veiculo_placa} ${data.litros}L R$ ${data.valor_total} — confirme com "confirm: true".`;
    return `🗑️ EXCLUIR abastecimento ${data.veiculo_placa} ${data.litros}L R$ ${data.valor_total} — IRREVERSÍVEL`;
  },

  handler: async (input, ctx) => {
    const supabase = ctx.supabase as Record<string, unknown>;
    const tenantId = ctx.tenant_id as string;
    if (input.confirm !== true) return { ok: false, error: "Confirme com 'confirm: true'." };
    const id = String(input.abastecimento_id).trim();
    const { data } = await (supabase as any).from("abastecimentos")
      .select("id, veiculo_placa, litros, valor_total").eq("tenant_id", tenantId).eq("id", id).single();
    if (!data) return { ok: false, error: `Abastecimento ${id} não encontrado.` };
    const display = `🗑️ Excluir abastecimento ${data.veiculo_placa} ${data.litros}L R$ ${data.valor_total}`;
    return { ok: true, data: { abastecimento_id: id }, display };
  },
};
