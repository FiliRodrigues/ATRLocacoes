import { AtrTool } from "../types.ts";

export const deleteContract: AtrTool = {
  name: "delete_contract",
  category: "write",
  description: "Remove um contrato. IRREVERSÍVEL. O contrato deve estar encerrado.",
  input_schema: {
    type: "object",
    properties: {
      contract_id: { type: "string", description: "ID do contrato." },
      confirm: { type: "boolean", description: "Deve ser true." },
    },
    required: ["contract_id", "confirm"],
  },
  preview: async (input, ctx) => {
    const supabase = ctx.supabase as Record<string, unknown>;
    const tenantId = ctx.tenant_id as string;
    const { data } = await (supabase as any).from("contratos")
      .select("id, numero, cliente_nome, status").eq("tenant_id", tenantId).eq("id", String(input.contract_id)).single();
    if (!data) return `Excluir contrato: ID ${input.contract_id} não encontrado.`;
    if (input.confirm !== true) return `⚠️ Excluir contrato ${data.numero} (${data.cliente_nome}) — confirme com "confirm: true".`;
    return `🗑️ EXCLUIR contrato ${data.numero} (${data.cliente_nome}) — IRREVERSÍVEL`;
  },
  handler: async (input, ctx) => {
    const supabase = ctx.supabase as Record<string, unknown>;
    const tenantId = ctx.tenant_id as string;
    if (input.confirm !== true) return { ok: false, error: "Confirme com 'confirm: true'." };
    const id = String(input.contract_id).trim();
    const { data } = await (supabase as any).from("contratos")
      .select("id, numero, cliente_nome, status").eq("tenant_id", tenantId).eq("id", id).single();
    if (!data) return { ok: false, error: `Contrato ${id} não encontrado.` };
    if (data.status === "ativo") return { ok: false, error: "Encerre o contrato antes de excluir." };
    const display = `🗑️ Excluir contrato ${data.numero} (${data.cliente_nome})`;
    return { ok: true, data: { contract_id: id }, display };
  },
};
