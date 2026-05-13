import { AtrTool } from "../types.ts";

export const deleteExpense: AtrTool = {
  name: "delete_expense",
  category: "write",
  description: "Remove uma despesa. IRREVERSÍVEL. Forneça o ID exato.",
  input_schema: {
    type: "object",
    properties: {
      expense_id: { type: "string", description: "ID da despesa." },
      confirm: { type: "boolean", description: "Deve ser true." },
    },
    required: ["expense_id", "confirm"],
  },

  preview: async (input, ctx) => {
    const supabase = ctx.supabase as Record<string, unknown>;
    const tenantId = ctx.tenant_id as string;
    const { data } = await (supabase as any).from("despesas")
      .select("id, tipo, valor, veiculo_placa")
      .eq("tenant_id", tenantId).eq("id", String(input.expense_id)).single();
    if (!data) return `Excluir despesa: ID ${input.expense_id} não encontrado.`;
    if (input.confirm !== true) return `⚠️ Excluir despesa ${data.tipo} R$ ${data.valor} — confirme com "confirm: true".`;
    return `🗑️ EXCLUIR despesa ${data.tipo} R$ ${data.valor} (${data.veiculo_placa || "geral"}) — IRREVERSÍVEL`;
  },

  handler: async (input, ctx) => {
    const supabase = ctx.supabase as Record<string, unknown>;
    const tenantId = ctx.tenant_id as string;
    if (input.confirm !== true) return { ok: false, error: "Confirme com 'confirm: true'." };

    const id = String(input.expense_id).trim();
    const { data } = await (supabase as any).from("despesas")
      .select("id, tipo, valor, veiculo_placa")
      .eq("tenant_id", tenantId).eq("id", id).single();
    if (!data) return { ok: false, error: `Despesa ${id} não encontrada.` };

    const display = `🗑️ Excluir despesa ${data.tipo} R$ ${data.valor} (${data.veiculo_placa || "geral"})`;
    return { ok: true, data: { expense_id: id }, display };
  },
};
