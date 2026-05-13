import { AtrTool } from "../types.ts";

export const getRegrasManutencao: AtrTool = {
  name: "get_regras_manutencao",
  category: "read",
  description:
    "Consulta regras de manutenção preventiva. Use para perguntas sobre intervalos de KM/dias, custos estimados, última execução.",
  input_schema: {
    type: "object",
    properties: {
      placa: { type: "string", description: "Placa do veículo (opcional)." },
      tipo: { type: "string", description: "Tipo de manutenção (opcional)." },
      ativa: { type: "boolean", description: "Filtra apenas regras ativas. Default true." },
    },
  },
  handler: async (input, ctx) => {
    const supabase = ctx.supabase;
    const tenantId = ctx.tenant_id;

    let query = supabase.from("regras_manutencao")
      .select("id, titulo, tipo, veiculo_placa, intervalo_km, intervalo_dias, custo_estimado, prioridade, is_ativa, km_ultima_execucao, data_ultima_execucao")
      .eq("tenant_id", tenantId)
      .order("titulo", { ascending: true })
      .limit(100);

    if (input.placa) {
      const placaNorm = input.placa.replace("-", "").toUpperCase();
      query = query.ilike("veiculo_placa", placaNorm);
    }
    if (input.tipo) query = query.eq("tipo", input.tipo);
    if (input.ativa !== false) query = query.eq("is_ativa", true);

    const { data, error } = await query;
    if (error) return { ok: false, error: error.message };

    return {
      ok: true,
      data: data || [],
      total: (data || []).length,
      message: `${(data || []).length} regra(s) de manutenção encontrada(s).`,
    };
  },
};
