import { AtrTool } from "../types.ts";

export const listExpenses: AtrTool = {
  name: "list_expenses",
  category: "read",
  description:
    "Lista despesas operacionais da frota ATR com filtros por placa, data, tipo, status de pagamento. " +
    "Retorna soma total dos valores. Use para: 'lista despesas de combustível', " +
    "'mostra despesas não pagas', 'despesas do veículo ABC-1234 em maio'.",
  input_schema: {
    type: "object",
    properties: {
      vehicle_plate: { type: "string", description: "Filtrar por placa (opcional)." },
      start_date: { type: "string", description: "Data inicial YYYY-MM-DD." },
      end_date: { type: "string", description: "Data final YYYY-MM-DD." },
      tipo: { type: "string", description: "Tipo: 'combustível', 'multa', 'IPVA', 'seguro', 'outros'." },
      pago: { type: "boolean", description: "Filtrar por status de pagamento." },
      search: { type: "string", description: "Busca em descrição e motorista." },
      limit: { type: "integer", description: "Máximo de resultados (default 100, max 200)." },
    },
    required: [],
  },

  handler: async (input, ctx) => {
    const supabase = ctx.supabase as Record<string, unknown>;
    const tenantId = ctx.tenant_id as string;
    const limit = Math.min(Number(input.limit) || 100, 200);

    let query = (supabase as any).from("despesas")
      .select("id, veiculo_placa, motorista, data, tipo, descricao, odometro, litros, valor, pago, nf, created_at")
      .eq("tenant_id", tenantId)
      .order("data", { ascending: false })
      .limit(limit);

    if (input.vehicle_plate) {
      query = query.ilike("veiculo_placa", String(input.vehicle_plate).replace("-", "").toUpperCase());
    }
    if (input.start_date) query = query.gte("data", String(input.start_date));
    if (input.end_date) query = query.lte("data", String(input.end_date));
    if (input.tipo) query = query.eq("tipo", String(input.tipo));
    if (input.pago !== undefined && input.pago !== null) query = query.eq("pago", Boolean(input.pago));
    if (input.search) query = query.or(`descricao.ilike.%${String(input.search)}%,motorista.ilike.%${String(input.search)}%`);

    const { data, error } = await query;
    if (error) return { ok: false, error: `Erro ao listar despesas: ${error.message}` };

    const total = (data as any[] || []).reduce((sum: number, d: any) => sum + (Number(d.valor) || 0), 0);
    return {
      ok: true,
      data: {
        expenses: data,
        total,
        count: (data as any[]).length,
      },
    };
  },
};
