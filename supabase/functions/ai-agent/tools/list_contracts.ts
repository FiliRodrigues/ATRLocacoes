import { AtrTool } from "../types.ts";

export const listContracts: AtrTool = {
  name: "list_contracts",
  category: "read",
  description:
    "Lista contratos de locação da ATR. " +
    "Use para perguntas como: 'quais contratos estão ativos?', " +
    "'liste os contratos encerrados', " +
    "'contratos do cliente XPTO', " +
    "'qual o contrato do veículo ABC-1234?', " +
    "'mostre todos os contratos', " +
    "'contratos que vencem este mês', " +
    "'qual o valor mensal do contrato X?'.",
  input_schema: {
    type: "object",
    properties: {
      status: {
        type: "string",
        description:
          "Filtra por status do contrato. " +
          "'active' (default) = apenas ativos, " +
          "'ended' = apenas encerrados, " +
          "'all' = todos (ativos, encerrados, suspensos, rascunho).",
        enum: ["active", "ended", "all"],
      },
      client_search: {
        type: "string",
        description: "Busca livre (ILIKE) no nome do cliente.",
      },
      vehicle_identifier: {
        type: "string",
        description:
          "Placa do veículo (com ou sem hífen, case-insensitive) para filtrar contratos daquele veículo.",
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

    // Resolver vehicle_identifier para placa normalizada
    let veiculoPlaca: string | null = null;
    if (input.vehicle_identifier) {
      const placaQuery = input.vehicle_identifier.replace("-", "").toUpperCase();
      const { data: veiculo } = await supabase
        .from("veiculos")
        .select("placa")
        .eq("tenant_id", tenantId)
        .ilike("placa", placaQuery)
        .single();

      if (!veiculo) {
        return {
          ok: false,
          error: `Veículo com placa "${input.vehicle_identifier}" não encontrado.`,
        };
      }
      veiculoPlaca = veiculo.placa;
    }

    // Monta query base
    let query = supabase
      .from("contratos")
      .select(
        "id, numero, cliente_nome, cliente_cnpj, veiculo_placa, data_inicio, data_fim, valor_mensal, status, observacoes"
      )
      .eq("tenant_id", tenantId)
      .order("data_inicio", { ascending: false })
      .limit(limit);

    // Filtro de status
    const statusInput = input.status || "active";
    if (statusInput === "active") {
      query = query.eq("status", "ativo");
    } else if (statusInput === "ended") {
      query = query.eq("status", "encerrado");
    }
    // "all" não aplica filtro de status

    // Filtro de cliente
    if (input.client_search) {
      query = query.ilike("cliente_nome", `%${input.client_search}%`);
    }

    // Filtro de veículo
    if (veiculoPlaca) {
      query = query.eq("veiculo_placa", veiculoPlaca);
    }

    const { data, error } = await query;
    if (error) return { ok: false, error: error.message };

    // Soma dos valores mensais
    const totalMensal = (data || []).reduce(
      (sum, c) => sum + (Number(c.valor_mensal) || 0),
      0
    );

    // Contagem por status
    const porStatus: Record<string, number> = {};
    for (const c of data || []) {
      porStatus[c.status] = (porStatus[c.status] || 0) + 1;
    }

    const statusLabel =
      statusInput === "active"
        ? "ativos"
        : statusInput === "ended"
          ? "encerrados"
          : "todos os status";

    return {
      ok: true,
      data: data || [],
      total: (data || []).length,
      total_mensal: totalMensal,
      por_status: porStatus,
      message:
        `${(data || []).length} contrato(s) encontrado(s) (${statusLabel}). ` +
        `Valor mensal total: R$ ${totalMensal.toFixed(2)}.`,
    };
  },
};
