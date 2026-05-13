import { AtrTool } from "../types.ts";

export const getCostsSummary: AtrTool = {
  name: "get_costs_summary",
  category: "read",
  description:
    "Resumo de custos agregados da frota ATR. Agrega despesas de manutenções (tabela manutencoes) " +
    "e despesas operacionais (tabela despesas) por mês, veículo ou categoria. " +
    "Use para perguntas como: 'quanto gastamos em manutenção nos últimos 3 meses?', " +
    "'resumo de custos por veículo em 2025', " +
    "'gasto total com combustível em janeiro de 2025?', " +
    "'custos do carro ABC-1234 nos últimos 6 meses', " +
    "'quanto gastamos por categoria em março?', " +
    "'compare os custos mensais de 2025'.",
  input_schema: {
    type: "object",
    properties: {
      start_date: {
        type: "string",
        description:
          "Data inicial do período (YYYY-MM-DD). Obrigatório. Ex: '2025-01-01'.",
      },
      end_date: {
        type: "string",
        description:
          "Data final do período (YYYY-MM-DD). Obrigatório. Ex: '2025-03-31'.",
      },
      vehicle_identifier: {
        type: "string",
        description:
          "Placa (com ou sem hífen) ou UUID do veículo para filtrar. Se omitido, retorna custos de todos os veículos.",
      },
      group_by: {
        type: "string",
        enum: ["vehicle", "category", "month"],
        description:
          "Como agrupar os resultados. 'month' (padrão): agrupa por mês YYYY-MM. " +
          "'vehicle': agrupa por veículo (placa + modelo). " +
          "'category': agrupa por tipo de custo (despesas.tipo + manutenções.tipo).",
      },
    },
    required: ["start_date", "end_date"],
  },
  handler: async (input, ctx) => {
    const supabase = ctx.supabase;
    const tenantId = ctx.tenant_id;

    const startDate = String(input.start_date);
    const endDate = String(input.end_date);
    const groupBy = (input.group_by as string) || "month";

    // Validar datas
    if (!/^\d{4}-\d{2}-\d{2}$/.test(startDate) || !/^\d{4}-\d{2}-\d{2}$/.test(endDate)) {
      return { ok: false, error: "Datas devem estar no formato YYYY-MM-DD." };
    }

    // Resolver veículo se informado
    let veiculoId: string | null = null;
    let veiculoPlaca: string | null = null;
    let veiculoModelo: string | null = null;
    let veiculoMarca: string | null = null;

    if (input.vehicle_identifier) {
      const ident = String(input.vehicle_identifier).trim();
      const isUuid =
        /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(ident);

      if (isUuid) {
        const { data: v, error: vErr } = await supabase
          .from("veiculos")
          .select("id, placa, modelo, marca")
          .eq("tenant_id", tenantId)
          .eq("id", ident)
          .single();

        if (vErr || !v) {
          return { ok: false, error: "Veículo não encontrado com esse UUID." };
        }
        veiculoId = v.id;
        veiculoPlaca = v.placa;
        veiculoModelo = v.modelo;
        veiculoMarca = v.marca;
      } else {
        const placaQuery = ident.replace("-", "").toUpperCase();
        const { data: v, error: vErr } = await supabase
          .from("veiculos")
          .select("id, placa, modelo, marca")
          .eq("tenant_id", tenantId)
          .ilike("placa", placaQuery)
          .single();

        if (vErr || !v) {
          return { ok: false, error: `Veículo com placa "${ident}" não encontrado.` };
        }
        veiculoId = v.id;
        veiculoPlaca = v.placa;
        veiculoModelo = v.modelo;
        veiculoMarca = v.marca;
      }
    }

    // Busca manutenções no período
    let manutQuery = supabase
      .from("manutencoes")
      .select("id, veiculo_id, data, tipo, custo")
      .eq("tenant_id", tenantId)
      .gte("data", startDate)
      .lte("data", endDate);

    if (veiculoId) {
      manutQuery = manutQuery.eq("veiculo_id", veiculoId);
    }

    // Busca despesas no período
    let despQuery = supabase
      .from("despesas")
      .select("id, veiculo_placa, data, tipo, valor")
      .eq("tenant_id", tenantId)
      .gte("data", startDate)
      .lte("data", endDate);

    if (veiculoPlaca) {
      despQuery = despQuery.eq("veiculo_placa", veiculoPlaca);
    }

    const [manutResult, despResult] = await Promise.all([manutQuery, despQuery]);

    if (manutResult.error) {
      return { ok: false, error: `Erro ao buscar manutenções: ${manutResult.error.message}` };
    }
    if (despResult.error) {
      return { ok: false, error: `Erro ao buscar despesas: ${despResult.error.message}` };
    }

    const manutencoes = manutResult.data || [];
    const despesas = despResult.data || [];

    // Agrupamento
    const grupos: Record<string, {
      manutencao_total: number;
      despesas_total: number;
      total: number;
      count: number;
    }> = {};

    const getGroupKey = (item: Record<string, unknown>, source: "manutencao" | "despesa"): string => {
      switch (groupBy) {
        case "vehicle":
          if (source === "manutencao") return `veiculo_id:${item.veiculo_id}`;
          return `placa:${item.veiculo_placa || "sem_placa"}`;

        case "category":
          if (source === "manutencao") return `manutencao: ${item.tipo || "sem tipo"}`;
          return `despesa: ${item.tipo || "sem tipo"}`;

        case "month":
        default:
          const dateStr = (item.data || "0000-00") as string;
          return dateStr.substring(0, 7); // YYYY-MM
      }
    };

    // Processa manutenções
    for (const m of manutencoes) {
      const key = getGroupKey(m, "manutencao");
      if (!grupos[key]) {
        grupos[key] = { manutencao_total: 0, despesas_total: 0, total: 0, count: 0 };
      }
      const valor = Number(m.custo) || 0;
      grupos[key].manutencao_total += valor;
      grupos[key].total += valor;
      grupos[key].count += 1;
    }

    // Processa despesas
    for (const d of despesas) {
      const key = getGroupKey(d, "despesa");
      if (!grupos[key]) {
        grupos[key] = { manutencao_total: 0, despesas_total: 0, total: 0, count: 0 };
      }
      const valor = Number(d.valor) || 0;
      grupos[key].despesas_total += valor;
      grupos[key].total += valor;
      grupos[key].count += 1;
    }

    // Se group_by for vehicle, resolve os nomes dos veículos
    let vehicleNames: Record<string, string> = {};
    if (groupBy === "vehicle" && Object.keys(grupos).length > 0) {
      // Coleta todos os IDs de veículo e placas para resolver em lote
      const veiculoIds = new Set<string>();
      const placas = new Set<string>();

      for (const key of Object.keys(grupos)) {
        if (key.startsWith("veiculo_id:")) {
          veiculoIds.add(key.slice("veiculo_id:".length));
        } else if (key.startsWith("placa:")) {
          placas.add(key.slice("placa:".length));
        }
      }

      // Resolve veículos por ID
      if (veiculoIds.size > 0) {
        const idsArray = Array.from(veiculoIds);
        const batchSize = 50;
        for (let i = 0; i < idsArray.length; i += batchSize) {
          const batch = idsArray.slice(i, i + batchSize);
          const { data: veiculos, error: vErr } = await supabase
            .from("veiculos")
            .select("id, placa, modelo, marca")
            .eq("tenant_id", tenantId)
            .in("id", batch);

          if (!vErr && veiculos) {
            for (const v of veiculos) {
              vehicleNames[`veiculo_id:${v.id}`] =
                `${v.placa} - ${v.marca || ""} ${v.modelo || ""}`.trim();
            }
          }
        }
      }

      // Resolve veículos por placa (despesas sem veiculo_id)
      if (placas.size > 0) {
        const placasArray = Array.from(placas).filter((p) => p !== "sem_placa");
        if (placasArray.length > 0) {
          const batchSize = 50;
          for (let i = 0; i < placasArray.length; i += batchSize) {
            const batch = placasArray.slice(i, i + batchSize);
            const { data: veiculos, error: vErr } = await supabase
              .from("veiculos")
              .select("placa, modelo, marca")
              .eq("tenant_id", tenantId)
              .in("placa", batch);

            if (!vErr && veiculos) {
              for (const v of veiculos) {
                vehicleNames[`placa:${v.placa}`] =
                  `${v.placa} - ${v.marca || ""} ${v.modelo || ""}`.trim();
              }
            }
          }
        }
        if (placas.has("sem_placa")) {
          vehicleNames["placa:sem_placa"] = "Sem placa";
        }
      }
    }

    // Converte grupos para array ordenado
    const groupLabel =
      groupBy === "vehicle" ? "Veículo" : groupBy === "category" ? "Categoria" : "Mês";

    const gruposArray = Object.entries(grupos)
      .map(([key, values]) => ({
        [groupLabel.toLowerCase()]:
          groupBy === "vehicle" ? (vehicleNames[key] || key) : key,
        manutencao_total: values.manutencao_total,
        despesas_total: values.despesas_total,
        total: values.total,
        registros: values.count,
      }))
      .sort((a, b) => b.total - a.total); // Maior total primeiro

    // Totais gerais
    const totalManutencao = gruposArray.reduce((s, g) => s + g.manutencao_total, 0);
    const totalDespesas = gruposArray.reduce((s, g) => s + g.despesas_total, 0);
    const totalGeral = totalManutencao + totalDespesas;

    // Display
    const veiculoInfo = veiculoPlaca
      ? ` do veículo ${veiculoPlaca} (${veiculoMarca || ""} ${veiculoModelo || ""})`.trimEnd()
      : " da frota";

    const displayParts: string[] = [];
    displayParts.push(`Resumo de custos${veiculoInfo}`);
    displayParts.push(`Período: ${startDate} a ${endDate}`);
    displayParts.push(`Agrupamento: ${groupLabel}`);
    displayParts.push("");
    displayParts.push(
      `Total Manutenções: R$ ${totalManutencao.toFixed(2)} | ` +
      `Total Despesas Operacionais: R$ ${totalDespesas.toFixed(2)} | ` +
      `Total Geral: R$ ${totalGeral.toFixed(2)}`
    );
    displayParts.push("");
    for (const g of gruposArray) {
      const label = g[groupLabel.toLowerCase()] || g["mês"] || "";
      displayParts.push(
        `${label}: R$ ${g.total.toFixed(2)} (${g.registros} registro(s))`
      );
    }

    return {
      ok: true,
      data: {
        period: { start_date: startDate, end_date: endDate },
        group_by: groupBy,
        vehicle: veiculoPlaca
          ? {
              placa: veiculoPlaca,
              modelo: veiculoModelo,
              marca: veiculoMarca,
              id: veiculoId,
            }
          : null,
        groups: gruposArray,
        totals: {
          manutencao: totalManutencao,
          despesas: totalDespesas,
          geral: totalGeral,
        },
      },
      display: displayParts.join("\n"),
    };
  },
};
