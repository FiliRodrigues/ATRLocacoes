import { AtrTool } from "../types.ts";

export const listVehicles: AtrTool = {
  name: "list_vehicles",
  category: "read",
  description:
    "Lista veículos da frota ATR Locações com filtros opcionais. " +
    "Use para perguntas como: 'quantos carros ativos temos?', " +
    "'liste todos os veículos da Toyota', " +
    "'quais veículos têm financiamento ativo?', " +
    "'mostre os veículos inativos', " +
    "'busque veículos com placa contendo ABC', " +
    "'liste os carros vendidos'.",
  input_schema: {
    type: "object",
    properties: {
      status: {
        type: "string",
        description:
          "Filtra por situacao_operacional. Valores comuns: 'Ativo', 'Inativo', 'Vendido'. " +
          "Se omitido, retorna veículos de qualquer situação.",
      },
      has_financing: {
        type: "boolean",
        description:
          "Se true, retorna apenas veículos com financiamento ativo (situacao != 'Quitado').",
      },
      search: {
        type: "string",
        description:
          "Busca livre (ILIKE) nos campos placa, modelo e marca.",
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

    // Se tem has_financing, fazemos JOIN com financiamentos
    if (input.has_financing) {
      let query = supabase
        .from("veiculos")
        .select(
          `
          id,
          placa,
          modelo,
          marca,
          ano_fabricacao_modelo,
          situacao_operacional,
          km_atual,
          valor_veiculo,
          financiamentos!inner(situacao)
        `
        )
        .eq("tenant_id", tenantId)
        .neq("financiamentos.situacao", "Quitado");

      if (input.status) {
        query = query.eq("situacao_operacional", input.status);
      }
      if (input.search) {
        const safeSearch = input.search.replace(/[%_]/g, "\\$&");
        query = query.or(
          `placa.ilike.%${safeSearch}%,modelo.ilike.%${safeSearch}%,marca.ilike.%${safeSearch}%`
        );
      }

      query = query.limit(limit);

      const { data, error } = await query;
      if (error) return { ok: false, error: error.message };

      // Remove o subobjeto financiamentos da resposta para ficar limpo
      const clean = (data || []).map(
        ({ financiamentos: _f, ...rest }) => rest
      );

      return {
        ok: true,
        data: clean,
        total: clean.length,
        message: `${clean.length} veículo(s) encontrado(s) com financiamento ativo.`,
      };
    }

    // Query normal sem JOIN de financiamento
    let query = supabase
      .from("veiculos")
      .select(
        "id, placa, modelo, marca, ano_fabricacao_modelo, situacao_operacional, km_atual, valor_veiculo"
      )
      .eq("tenant_id", tenantId)
      .limit(limit);

    if (input.status) {
      query = query.eq("situacao_operacional", input.status);
    }
    if (input.search) {
      const safeSearch = input.search.replace(/[%_]/g, "\\$&");
      query = query.or(
        `placa.ilike.%${safeSearch}%,modelo.ilike.%${safeSearch}%,marca.ilike.%${safeSearch}%`
      );
    }

    query = query.order("placa", { ascending: true });

    const { data, error } = await query;
    if (error) return { ok: false, error: error.message };

    const statusLabel = input.status || "todos os status";
    return {
      ok: true,
      data: data || [],
      total: (data || []).length,
      message: `${(data || []).length} veículo(s) encontrado(s) (${statusLabel}).`,
    };
  },
};
