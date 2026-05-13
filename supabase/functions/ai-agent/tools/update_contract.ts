import { AtrTool } from "../types.ts";

export const updateContract: AtrTool = {
  name: "update_contract",
  category: "write",
  description:
    "Atualiza um contrato de locação. Use para encerrar contrato, mudar valores, status, etc. " +
    "Para encerrar: 'encerra contrato CTR-2026-001' → status='encerrado'. " +
    "Status válidos: 'ativo', 'encerrado', 'suspenso', 'rascunho'.",
  input_schema: {
    type: "object",
    properties: {
      contract_id: { type: "string", description: "ID (UUID) do contrato." },
      status: { type: "string", description: "Status: 'ativo', 'encerrado', 'suspenso', 'rascunho'." },
      data_fim: { type: "string", description: "Nova data de fim YYYY-MM-DD." },
      valor_mensal: { type: "number", description: "Novo valor mensal." },
      sla_km_mes: { type: "integer", description: "Novo SLA de km." },
      observacoes: { type: "string", description: "Novas observações." },
      cliente_nome: { type: "string", description: "Novo nome do cliente." },
      cliente_contato: { type: "string", description: "Novo contato." },
    },
    required: ["contract_id"],
  },

  preview: async (input, ctx) => {
    const supabase = ctx.supabase as Record<string, unknown>;
    const tenantId = ctx.tenant_id as string;
    const { data } = await (supabase as any).from("contratos")
      .select("id, numero, cliente_nome, status")
      .eq("tenant_id", tenantId).eq("id", String(input.contract_id)).single();
    if (!data) return `Atualizar contrato: ID ${input.contract_id} não encontrado.`;
    const mudancas: string[] = [];
    for (const [k, v] of Object.entries(input)) {
      if (k !== "contract_id" && v !== undefined && v !== null) mudancas.push(`${k}=${v}`);
    }
    return `Atualizar contrato ${data.numero} (${data.cliente_nome}): ${mudancas.join(", ") || "sem alterações"}`;
  },

  handler: async (input, ctx) => {
    const supabase = ctx.supabase as Record<string, unknown>;
    const tenantId = ctx.tenant_id as string;
    const id = String(input.contract_id).trim();
    if (!id) return { ok: false, error: "ID é obrigatório." };

    const { data } = await (supabase as any).from("contratos")
      .select("id, numero, cliente_nome, status")
      .eq("tenant_id", tenantId).eq("id", id).single();
    if (!data) return { ok: false, error: `Contrato ${id} não encontrado.` };

    const updates: Record<string, unknown> = {};
    if (input.status !== undefined) {
      const s = String(input.status).trim();
      if (!["ativo", "encerrado", "suspenso", "rascunho"].includes(s)) {
        return { ok: false, error: "Status inválido. Use: 'ativo', 'encerrado', 'suspenso' ou 'rascunho'." };
      }
      updates.status = s;
    }
    if (input.data_fim !== undefined) {
      if (!/^\d{4}-\d{2}-\d{2}$/.test(String(input.data_fim))) return { ok: false, error: "Data inválida. Use YYYY-MM-DD." };
      updates.data_fim = String(input.data_fim);
    }
    if (input.valor_mensal !== undefined) updates.valor_mensal = Number(input.valor_mensal);
    if (input.sla_km_mes !== undefined) updates.sla_km_mes = Number(input.sla_km_mes);
    if (input.observacoes !== undefined) updates.observacoes = String(input.observacoes).trim();
    if (input.cliente_nome !== undefined) updates.cliente_nome = String(input.cliente_nome).trim();
    if (input.cliente_contato !== undefined) updates.cliente_contato = String(input.cliente_contato).trim();

    if (Object.keys(updates).length === 0) return { ok: false, error: "Nenhum campo para atualizar." };

    const display = (await updateContract.preview!(input, ctx)) ?? "";
    return { ok: true, data: { contract_id: id, updates }, display };
  },
};
