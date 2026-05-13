import { AtrTool } from "../types.ts";

export const getContratosProximosVencer: AtrTool = {
  name: "get_contratos_proximos_vencer",
  category: "read",
  description:
    "Lista contratos ativos que vencem nos próximos N dias (padrão 30). " +
    "Use para: 'contratos próximos do vencimento', 'quais contratos vencem esse mês'.",
  input_schema: {
    type: "object",
    properties: {
      dias: { type: "integer", description: "Janela em dias (padrão 30)." },
    },
    required: [],
  },
  preview: async (input, _ctx) => {
    const dias = input.dias || 30;
    return `Listar contratos ativos que vencem nos próximos ${dias} dias`;
  },
  handler: async (input, ctx) => {
    const supabase = ctx.supabase as any;
    const tenantId = ctx.tenant_id as string;
    const dias = input.dias || 30;
    const hoje = new Date();
    const dataLimite = new Date(hoje.getTime() + dias * 24 * 60 * 60 * 1000);
    const dataLimiteStr = dataLimite.toISOString().split("T")[0];
    const { data, error } = await supabase
      .from("contratos")
      .select("id, numero, cliente_nome, veiculo_placa, data_fim, status")
      .eq("tenant_id", tenantId)
      .eq("status", "ativo")
      .lte("data_fim", dataLimiteStr)
      .order("data_fim", { ascending: true });
    if (error) return { ok: false, error: error.message };
    return { ok: true, data };
  },
};
