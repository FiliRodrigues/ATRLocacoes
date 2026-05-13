import { AtrTool } from "../types.ts";

export const getAbastecimentos: AtrTool = {
  name: "get_abastecimentos",
  category: "read",
  description:
    "Consulta abastecimentos por veículo. Use para perguntas sobre consumo, gastos com combustível, quilometragem, tipo de combustível.",
  input_schema: {
    type: "object",
    properties: {
      placa: { type: "string", description: "Placa do veículo." },
      tipo: { type: "string", description: "Tipo de combustível: gasolina, etanol, diesel." },
      limit: { type: "integer", description: "Máximo de registros. Default 20, máximo 50." },
    },
  },
  handler: async (input, ctx) => {
    const supabase = ctx.supabase;
    const tenantId = ctx.tenant_id;
    const limit = Math.min(input.limit || 20, 50);

    let veiculoPlaca: string | null = null;
    if (input.placa) {
      veiculoPlaca = input.placa.replace("-", "").toUpperCase();
    }

    let query = supabase.from("abastecimentos")
      .select("id, veiculo_placa, data, litros, valor_total, km_odometro, tipo, posto, registrado_por")
      .eq("tenant_id", tenantId)
      .order("data", { ascending: false })
      .limit(limit);

    if (veiculoPlaca) query = query.ilike("veiculo_placa", veiculoPlaca);
    if (input.tipo) query = query.eq("tipo", input.tipo);

    const { data, error } = await query;
    if (error) return { ok: false, error: error.message };

    const totalLitros = (data || []).reduce((sum, a) => sum + (a.litros || 0), 0);
    const totalValor = (data || []).reduce((sum, a) => sum + (a.valor_total || 0), 0);

    return {
      ok: true,
      data: data || [],
      total: (data || []).length,
      message: `${(data || []).length} abastecimento(s). Total: ${totalLitros.toFixed(1)}L, R$ ${totalValor.toFixed(2)}.`,
    };
  },
};
