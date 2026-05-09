import { AtrTool } from "../types.ts";

export const listDrivers: AtrTool = {
  name: "list_drivers",
  category: "read",
  description:
    "Lista motoristas distintos registrados nas despesas da frota. " +
    "Os motoristas são extraídos do campo 'motorista' da tabela 'despesas' (não existe tabela de motoristas separada). " +
    "Use para perguntas como: 'quais motoristas temos cadastrados?', " +
    "'liste todos os motoristas da frota', " +
    "'busque motoristas com nome contendo Silva', " +
    "'quantos motoristas diferentes já registraram despesas?', " +
    "'motoristas que abasteceram em março'.",
  input_schema: {
    type: "object",
    properties: {
      search: {
        type: "string",
        description:
          "Busca parcial pelo nome do motorista (ILIKE). Ex: 'Silva' retorna 'João Silva', 'Maria Silva' etc. " +
          "Se omitido, retorna todos os motoristas.",
      },
      active_only: {
        type: "boolean",
        description:
          "Se true, retorna apenas motoristas que aparecem em despesas não nulas. " +
          "Como não existe campo 'active', o padrão true filtra motorista IS NOT NULL e != ''. " +
          "Default: true.",
      },
    },
  },
  handler: async (input, ctx) => {
    const supabase = ctx.supabase;
    const tenantId = ctx.tenant_id;

    const activeOnly = input.active_only !== false; // default true

    let query = supabase
      .from("despesas")
      .select("motorista")
      .eq("tenant_id", tenantId);

    // Filtra motoristas não-nulos e não-vazios se active_only
    if (activeOnly) {
      query = query.not("motorista", "is", null).neq("motorista", "");
    }

    // Busca textual se fornecida
    if (input.search) {
      query = query.ilike("motorista", `%${String(input.search)}%`);
    }

    const { data, error } = await query;

    if (error) {
      return { ok: false, error: `Erro ao buscar motoristas: ${error.message}` };
    }

    if (!data || data.length === 0) {
      return {
        ok: true,
        data: [],
        total: 0,
        message: input.search
          ? `Nenhum motorista encontrado com "${input.search}".`
          : "Nenhum motorista encontrado nas despesas.",
        display: "Nenhum motorista encontrado.",
      };
    }

    // Extrai nomes únicos, ordena alfabeticamente, limita a 100
    const motoristasSet = new Set<string>();
    for (const row of data) {
      if (row.motorista) {
        motoristasSet.add(row.motorista.trim());
      }
    }

    const motoristas = Array.from(motoristasSet)
      .sort((a, b) => a.localeCompare(b, "pt-BR"))
      .slice(0, 100);

    const searchInfo = input.search ? ` contendo "${input.search}"` : "";

    return {
      ok: true,
      data: motoristas,
      total: motoristas.length,
      message: `${motoristas.length} motorista(s) encontrado(s)${searchInfo}.`,
      display: `${motoristas.length} motorista(s)${searchInfo}:\n${motoristas.map((m) => `  - ${m}`).join("\n")}`,
    };
  },
};
