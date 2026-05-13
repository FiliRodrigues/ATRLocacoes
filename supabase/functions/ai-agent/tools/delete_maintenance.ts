import { AtrTool } from "../types.ts";

export const deleteMaintenance: AtrTool = {
  name: "delete_maintenance",
  category: "write",
  description:
    "Remove uma manutenção da frota ATR Locações. " +
    "ATENÇÃO: Ação irreversível. Use apenas com certeza absoluta. " +
    "Forneça o ID exato da manutenção.",
  input_schema: {
    type: "object",
    properties: {
      maintenance_id: {
        type: "string", description: "ID (UUID) da manutenção a ser removida.",
      },
      confirm: {
        type: "boolean", description: "Deve ser true para confirmar.",
      },
    },
    required: ["maintenance_id", "confirm"],
  },

  preview: async (input, ctx) => {
    const supabase = ctx.supabase as Record<string, unknown>;
    const tenantId = ctx.tenant_id as string;
    const { data } = await (supabase as any).from("manutencoes")
      .select("id, titulo, veiculo_placa, custo")
      .eq("tenant_id", tenantId).eq("id", String(input.maintenance_id)).single();
    if (!data) return `Excluir manutenção: ID ${input.maintenance_id} não encontrado.`;
    if (input.confirm !== true) return `⚠️ Excluir manutenção "${data.titulo}" (${data.veiculo_placa}) R$ ${data.custo} — confirme com "confirm: true".`;
    return `🗑️ EXCLUIR manutenção "${data.titulo}" (${data.veiculo_placa}) R$ ${data.custo} — IRREVERSÍVEL`;
  },

  handler: async (input, ctx) => {
    const supabase = ctx.supabase as Record<string, unknown>;
    const tenantId = ctx.tenant_id as string;
    if (input.confirm !== true) return { ok: false, error: "Confirme a exclusão com 'confirm: true'." };

    const id = String(input.maintenance_id).trim();
    const { data } = await (supabase as any).from("manutencoes")
      .select("id, titulo, veiculo_placa, custo")
      .eq("tenant_id", tenantId).eq("id", id).single();
    if (!data) return { ok: false, error: `Manutenção ${id} não encontrada.` };

    const display = `🗑️ Excluir manutenção "${data.titulo}" (${data.veiculo_placa}) R$ ${data.custo}`;
    return { ok: true, data: { maintenance_id: id }, display };
  },
};
