import { AtrTool } from "../types.ts";

export const getHodometros: AtrTool = {
  name: "get_hodometros",
  category: "read",
  description:
    "Lista registros de hodômetro (km registrado ao longo do tempo) de um veículo. " +
    "Use para: 'histórico de km do ABC-1234', 'qual o último km registrado do veículo X'.",
  input_schema: {
    type: "object",
    properties: {
      veiculo_placa: {
        type: "string",
        description: "Placa do veículo (obrigatório).",
      },
      limit: {
        type: "integer",
        description: "Número máximo de registros a retornar. Default: 20.",
      },
      data_inicio: {
        type: "string",
        description: "Filtrar registros a partir desta data (YYYY-MM-DD). Opcional.",
      },
      data_fim: {
        type: "string",
        description: "Filtrar registros até esta data (YYYY-MM-DD). Opcional.",
      },
    },
    required: ["veiculo_placa"],
  },

  handler: async (input, ctx) => {
    const supabase = ctx.supabase as any;
    const tenantId = ctx.tenant_id as string;

    const placaNorm = String(input.veiculo_placa).replace(/[\s\-\.]/g, "").toUpperCase();
    const limit = Math.min(Number(input.limit) || 20, 100);

    let query = supabase
      .from("hodometros")
      .select("id, veiculo_placa, km, registrado_por, created_at")
      .eq("tenant_id", tenantId)
      .ilike("veiculo_placa", placaNorm)
      .order("created_at", { ascending: false })
      .limit(limit);

    if (input.data_inicio) {
      query = query.gte("created_at", `${input.data_inicio}T00:00:00`);
    }
    if (input.data_fim) {
      query = query.lte("created_at", `${input.data_fim}T23:59:59`);
    }

    const { data, error } = await query;
    if (error) return { ok: false, error: `Erro ao buscar hodômetros: ${error.message}` };

    if (!data || data.length === 0) {
      return { ok: true, data: [], display: `Nenhum registro de hodômetro encontrado para ${placaNorm}.` };
    }

    const ultimo = data[0];
    const display = `${data.length} registro(s) de km para ${ultimo.veiculo_placa}. ` +
      `Último: ${ultimo.km.toLocaleString("pt-BR")} km em ${new Date(ultimo.created_at).toLocaleDateString("pt-BR")}.`;

    return { ok: true, data, display };
  },
};
