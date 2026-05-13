import { AtrTool } from "../types.ts";

export const listMaintenances: AtrTool = {
  name: "list_maintenances",
  category: "read",
  description:
    "Lista manutenções dos veículos da frota. " +
    "Use para perguntas como: 'quais foram as últimas manutenções?', " +
    "'liste as manutenções do carro ABC-1234', " +
    "'manutenções de freio nos últimos 6 meses', " +
    "'quanto gastamos com manutenção em março?', " +
    "'manutenções pendentes de pagamento', " +
    "'serviços feitos na oficina X'.",
  input_schema: {
    type: "object",
    properties: {
      vehicle_identifier: {
        type: "string",
        description:
          "Placa (com ou sem hífen) ou UUID do veículo para filtrar manutenções. Se omitido, lista de todos os veículos.",
      },
      start_date: {
        type: "string",
        description:
          "Data inicial do filtro (YYYY-MM-DD). Filtra por data >= start_date.",
      },
      end_date: {
        type: "string",
        description:
          "Data final do filtro (YYYY-MM-DD). Filtra por data <= end_date.",
      },
      type: {
        type: "string",
        description:
          "Filtra por tipo de serviço (ILIKE). Ex: 'Freio', 'Motor', 'Suspensão', 'Revisão'.",
      },
      limit: {
        type: "integer",
        description: "Máximo de registros. Default 50, máximo 200.",
      },
    },
  },
  handler: async (input, ctx) => {
    const supabase = ctx.supabase;
    const tenantId = ctx.tenant_id;

    const limit = Math.min(input.limit || 50, 200);

    // Resolver vehicle_identifier se informado
    let veiculoId: string | null = null;
    if (input.vehicle_identifier) {
      const ident = input.vehicle_identifier;

      const isUuid =
        /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(ident);

      if (isUuid) {
        const { data: byId } = await supabase
          .from("veiculos")
          .select("id")
          .eq("tenant_id", tenantId)
          .eq("id", ident)
          .single();

        if (!byId) {
          return { ok: false, error: `Veículo com ID "${ident}" não encontrado.` };
        }
        veiculoId = (byId as any).id;
      } else {
        const placaQuery = ident.replace("-", "").toUpperCase();
        const { data: byPlaca } = await supabase
          .from("veiculos")
          .select("id")
          .eq("tenant_id", tenantId)
          .ilike("placa", placaQuery)
          .single();

        if (!byPlaca) {
          return { ok: false, error: `Veículo com placa "${ident}" não encontrado.` };
        }
        veiculoId = (byPlaca as any).id;
      }
    }

    // Monta query base
    let query = supabase
      .from("manutencoes")
      .select(
        "id, veiculo_id, data, descricao, tipo, fornecedor, custo, km_no_servico"
      )
      .eq("tenant_id", tenantId)
      .order("data", { ascending: false })
      .limit(limit);

    if (veiculoId) {
      query = query.eq("veiculo_id", veiculoId);
    }
    if (input.start_date) {
      query = query.gte("data", input.start_date);
    }
    if (input.end_date) {
      query = query.lte("data", input.end_date);
    }
    if (input.type) {
      query = query.ilike("tipo", `%${input.type}%`);
    }

    const { data, error } = await query;
    if (error) return { ok: false, error: error.message };

    // Soma dos valores para informação adicional
    const totalValor = (data || []).reduce(
      (sum, m) => sum + (Number(m.custo) || 0),
      0
    );

    const filtros: string[] = [];
    if (input.vehicle_identifier) filtros.push(`veículo específico`);
    if (input.start_date) filtros.push(`a partir de ${input.start_date}`);
    if (input.end_date) filtros.push(`até ${input.end_date}`);
    if (input.type) filtros.push(`tipo "${input.type}"`);
    const filtroStr = filtros.length > 0 ? ` (filtros: ${filtros.join(", ")})` : "";

    return {
      ok: true,
      data: data || [],
      total: (data || []).length,
      valor_total: totalValor,
      message:
        `${(data || []).length} manutenção(ões) encontrada(s)${filtroStr}. ` +
        `Valor total: R$ ${totalValor.toFixed(2)}.`,
    };
  },
};
