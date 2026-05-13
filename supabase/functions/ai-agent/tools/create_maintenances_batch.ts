import { AtrTool } from "../types.ts";
import {
  buildDuplicateWarningMessage,
  checkDuplicateMaintenance,
} from "./maintenance_duplicates.ts";

// ---------------------------------------------------------------
// Helper: resolve veículo por placa (case-insensitive, sem hífen) ou UUID.
// ---------------------------------------------------------------
async function resolveVehicle(
  identifier: unknown,
  ctx: Record<string, unknown>
) {
  const supabase = ctx.supabase as Record<string, unknown>;
  const tenantId = ctx.tenant_id as string;
  const ident = String(identifier);

  const isUuid =
    /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(
      ident
    );

  if (isUuid) {
    const result = await (supabase as any)
      .from("veiculos")
      .select("id, placa, modelo, km_atual")
      .eq("tenant_id", tenantId)
      .eq("id", ident)
      .single();

    return result.data || null;
  }

  const placaQuery = ident.replace("-", "").toUpperCase();
  const result = await (supabase as any)
    .from("veiculos")
    .select("id, placa, modelo, km_atual")
    .eq("tenant_id", tenantId)
    .ilike("placa", placaQuery)
    .single();

  return result.data || null;
}

// ---------------------------------------------------------------
// Valida um único item de manutenção (sem resolver veículo — usado no lote).
// Retorna { ok: true, data: itemValidado } ou { ok: false, error: ... }.
// ---------------------------------------------------------------
function validateMaintenanceItem(item: Record<string, unknown>, index: number) {
  const errors: string[] = [];

  // vehicle_identifier obrigatório
  if (!item.vehicle_identifier || String(item.vehicle_identifier).trim() === "") {
    errors.push(`vehicle_identifier é obrigatório`);
  }

  // date obrigatório + formato
  if (!item.date || !/^\d{4}-\d{2}-\d{2}$/.test(String(item.date))) {
    errors.push(`date inválido ou ausente (use YYYY-MM-DD)`);
  }

  // type obrigatório
  if (!item.type || String(item.type).trim() === "") {
    errors.push(`type é obrigatório`);
  }

  // cost obrigatório + > 0
  const cost = Number(item.cost);
  if (isNaN(cost) || cost <= 0) {
    errors.push(`cost deve ser um número > 0`);
  }

  // mileage opcional mas se informado deve ser inteiro >= 0
  const mileage = item.mileage != null ? Number(item.mileage) : undefined;
  if (mileage !== undefined && (!Number.isInteger(mileage) || mileage < 0)) {
    errors.push(`mileage deve ser inteiro >= 0`);
  }

  if (errors.length > 0) {
    return {
      ok: false,
      error: `Item #${index + 1}: ${errors.join("; ")}`,
    };
  }

  return {
    ok: true,
    data: {
      vehicle_identifier: String(item.vehicle_identifier).trim(),
      date: String(item.date),
      type: String(item.type).trim(),
      cost,
      description: item.description ? String(item.description).trim() : null,
      mileage: mileage ?? null,
      workshop_name: item.workshop_name
        ? String(item.workshop_name).trim()
        : null,
      workshop_cnpj: item.workshop_cnpj
        ? String(item.workshop_cnpj).trim()
        : null,
      invoice_number: item.invoice_number
        ? String(item.invoice_number).trim()
        : null,
    },
  };
}

// ---------------------------------------------------------------
// Tool: create_maintenances_batch
// ---------------------------------------------------------------
export const createMaintenancesBatch: AtrTool = {
  name: "create_maintenances_batch",
  category: "write",
  description:
    "Registra múltiplas manutenções em lote para veículos da frota ATR Locações. " +
    "Cada item do array tem os mesmos campos de create_maintenance: " +
    "vehicle_identifier, date, type, cost, description (opcional), mileage (opcional), " +
    "workshop_name (opcional), workshop_cnpj (opcional), invoice_number (opcional). " +
    "Use para solicitações como: " +
    "'lança essas 3 manutenções: troca de óleo ABC-1234 R$280, freio DEF-5678 R$1500, revisão XYZ-9999 R$890', " +
    "'registra manutenções em lote para todos os veículos da revisão mensal', " +
    "'cria manutenções para os 5 caminhões que fizeram serviço hoje'. " +
    "Mínimo 1 item, máximo 50 itens. " +
    "Todos os registros ficam pendentes de confirmação — o usuário precisa aprovar antes da gravação.",
  input_schema: {
    type: "object",
    properties: {
      maintenances: {
        type: "array",
        description:
          "Lista de manutenções a registrar (1 a 50 itens). " +
          "Cada item deve conter: vehicle_identifier, date, type, cost. " +
          "Opcionais: description, mileage, workshop_name, workshop_cnpj, invoice_number.",
        items: {
          type: "object",
          properties: {
            vehicle_identifier: {
              type: "string",
              description:
                "Placa (com ou sem hífen) ou UUID do veículo. Ex: 'ABC-1234'.",
            },
            date: {
              type: "string",
              description: "Data do serviço (YYYY-MM-DD). Ex: '2026-05-15'.",
            },
            type: {
              type: "string",
              description:
                "Tipo do serviço. Ex: 'Troca de óleo', 'Revisão', 'Freio'.",
            },
            cost: {
              type: "number",
              description: "Valor do serviço em reais (> 0). Ex: 280.00.",
            },
            description: {
              type: "string",
              description: "Descrição adicional (opcional).",
            },
            mileage: {
              type: "integer",
              description:
                "Quilometragem no momento do serviço (opcional, >= 0).",
            },
            workshop_name: {
              type: "string",
              description: "Nome da oficina (opcional).",
            },
            workshop_cnpj: {
              type: "string",
              description: "CNPJ da oficina (opcional).",
            },
            invoice_number: {
              type: "string",
              description: "Número da nota fiscal (opcional).",
            },
          },
          required: ["vehicle_identifier", "date", "type", "cost"],
        },
      },
    },
    required: ["maintenances"],
  },

  // ---------------------------------------------------------------
  // Preview: tabela markdown com todas as manutenções + total geral
  // ---------------------------------------------------------------
  preview: async (input, ctx) => {
    const items = input.maintenances as Record<string, unknown>[];

    if (!items || !Array.isArray(items) || items.length === 0) {
      return "Nenhuma manutenção informada no lote.";
    }

    // Resolve todos os veículos em paralelo para montar a tabela
    const resolved = await Promise.all(
      items.map(async (item, i) => {
        try {
          const veiculo = await resolveVehicle(
            item.vehicle_identifier,
            ctx
          );
          if (!veiculo) {
            return {
              index: i + 1,
              veiculoStr: `Nao encontrado (${item.vehicle_identifier})`,
              tipo: String(item.type || "-"),
              valor: Number(item.cost),
              data: String(item.date || "-"),
              erro: true,
            };
          }
          const modelo = (veiculo as any).modelo || "Veículo";
          const placa = (veiculo as any).placa;

          let duplicateMatches = 0;
          let duplicateCheckFailed = false;
          const date = String(item.date || "");
          const type = String(item.type || "").trim();
          const cost = Number(item.cost);
          if (/^\d{4}-\d{2}-\d{2}$/.test(date) && type && !isNaN(cost) && cost > 0) {
            try {
              const duplicateCheck = await checkDuplicateMaintenance({
                // @ts-ignore compatibilidade com tools que usam ctx.supabase
                supabase: ctx.supabase,
                tenantId: String(ctx.tenant_id),
                vehicleId: String((veiculo as any).id),
                date,
                type,
                cost,
              });
              duplicateMatches = duplicateCheck.matches.length;
            } catch {
              duplicateCheckFailed = true;
            }
          }

          return {
            index: i + 1,
            veiculoStr: `${modelo} (${placa})`,
            tipo: String(item.type || "-"),
            valor: Number(item.cost),
            data: String(item.date || "-"),
            duplicateMatches,
            duplicateCheckFailed,
            erro: false,
          };
        } catch {
          return {
            index: i + 1,
            veiculoStr: `Erro ao resolver (${item.vehicle_identifier})`,
            tipo: String(item.type || "-"),
            valor: Number(item.cost),
            data: String(item.date || "-"),
            duplicateMatches: 0,
            duplicateCheckFailed: false,
            erro: true,
          };
        }
      })
    );

    // Monta tabela markdown
    let tabela = "| # | Veículo | Tipo | Valor | Data | Duplicidade |\n";
    tabela += "|---|---------|------|-------|------|-------------|\n";

    let totalGeral = 0;
    let duplicateItems = 0;
    let duplicateUnknownItems = 0;
    for (const r of resolved) {
      const valorStr = `R$ ${r.valor.toFixed(2).replace(".", ",")}`;
      const duplicateStr = r.duplicateCheckFailed
        ? "⚠️ não verificado"
        : r.duplicateMatches > 0
        ? `⚠️ ${r.duplicateMatches} similar(es)`
        : "-";
      tabela += `| ${r.index} | ${r.veiculoStr} | ${r.tipo} | ${valorStr} | ${r.data} | ${duplicateStr} |\n`;
      totalGeral += r.valor;
      if (r.duplicateMatches > 0) duplicateItems++;
      if (r.duplicateCheckFailed) duplicateUnknownItems++;
    }

    const totalStr = totalGeral.toFixed(2).replace(".", ",");
    const erros = resolved.filter((r) => r.erro).length;
    tabela += `\n**Total: ${resolved.length} manutenção(ões) — R$ ${totalStr}**`;
    if (erros > 0) {
      tabela += `\n⚠️ ${erros} veículo(s) não encontrado(s) — serão reportados como erro na validação.`;
    }
    if (duplicateItems > 0) {
      tabela += `\n\n⚠️ **${duplicateItems} item(ns) com possível duplicidade.**`;
      tabela += "\nSe confirmar, o sistema incluirá o lote completo mesmo com itens similares existentes.";
    }
    if (duplicateUnknownItems > 0) {
      tabela += `\n\n⚠️ ${duplicateUnknownItems} item(ns) sem validação de duplicidade por falha de consulta.`;
    }

    return tabela;
  },

  // ---------------------------------------------------------------
  // Handler: valida cada item, resolve veículos, retorna dados para lote
  // ---------------------------------------------------------------
  handler: async (input, ctx) => {
    const items = input.maintenances as Record<string, unknown>[];

    // 1. Valida tamanho do lote
    if (!items || !Array.isArray(items)) {
      return {
        ok: false,
        error:
          "O campo 'maintenances' deve ser um array com 1 a 50 itens.",
      };
    }
    if (items.length === 0) {
      return {
        ok: false,
        error: "O array 'maintenances' está vazio. Informe ao menos 1 item.",
      };
    }
    if (items.length > 50) {
      return {
        ok: false,
        error: `Máximo de 50 manutenções por lote. Recebido: ${items.length}.`,
      };
    }

    // 2. Valida campos de cada item (sem resolver veículos ainda)
    const validationErrors: string[] = [];
    const validItems: {
      index: number;
      item: Record<string, unknown>;
    }[] = [];

    for (let i = 0; i < items.length; i++) {
      const result = validateMaintenanceItem(items[i], i);
      if (!result.ok) {
        validationErrors.push(result.error!);
      } else {
        validItems.push({ index: i, item: result.data! });
      }
    }

    if (validationErrors.length > 0) {
      return {
        ok: false,
        error:
          `Erros de validação encontrados:\n${validationErrors.join("\n")}`,
      };
    }

    // 3. Resolve todos os veículos em paralelo
    const resolvedItems = await Promise.all(
      validItems.map(async ({ index, item }) => {
        const veiculo = await resolveVehicle(
          item.vehicle_identifier,
          ctx
        );
        if (!veiculo) {
          return {
            ok: false,
            error: `Item #${index + 1}: Veículo não encontrado para "${item.vehicle_identifier}". Use uma placa válida ou UUID.`,
          };
        }
        return {
          ok: true,
          data: {
            vehicle_id: (veiculo as any).id as string,
            plate: (veiculo as any).placa as string,
            model: ((veiculo as any).modelo as string) || null,
            date: item.date,
            type: item.type,
            cost: item.cost,
            description: item.description,
            mileage: item.mileage,
            workshop_name: item.workshop_name,
            workshop_cnpj: item.workshop_cnpj,
            invoice_number: item.invoice_number,
          },
        };
      })
    );

    // 4. Coleta erros de resolução de veículos
    const resolutionErrors = resolvedItems
      .filter((r) => !r.ok)
      .map((r) => (r as any).error as string);

    if (resolutionErrors.length > 0) {
      return {
        ok: false,
        error:
          `Erros ao resolver veículos:\n${resolutionErrors.join("\n")}`,
      };
    }

    // 5. Todos os itens validados e veículos resolvidos
    const allValidated = resolvedItems
      .filter((r) => r.ok)
      .map((r) => (r as any).data);

    const duplicateSummaries: string[] = [];
    for (const item of allValidated as Array<Record<string, unknown>>) {
      try {
        const duplicateCheck = await checkDuplicateMaintenance({
          // @ts-ignore compatibilidade com tools que usam ctx.supabase
          supabase: ctx.supabase,
          tenantId: String(ctx.tenant_id),
          vehicleId: String(item.vehicle_id),
          date: String(item.date),
          type: String(item.type),
          cost: Number(item.cost),
        });

        if (duplicateCheck.isDuplicate) {
          duplicateSummaries.push(
            `Placa ${item.plate}: ${duplicateCheck.matches.length} similar(es)`
          );
        }
      } catch {
        // Não bloqueia o lote se consulta de duplicidade falhar
      }
    }

    const totalCost = allValidated.reduce(
      (sum: number, item: any) => sum + item.cost,
      0
    );

    // 6. Gera preview para exibição
    let display =
      (await createMaintenancesBatch.preview!(input, ctx)) ?? "";
    if (duplicateSummaries.length > 0) {
      display +=
        `\n\n⚠️ Possíveis duplicidades no lote:` +
        `\n${duplicateSummaries.join("\n")}` +
        "\nConfirme apenas se deseja incluir os lançamentos mesmo assim.";
    }

    return {
      ok: true,
      data: {
        items: allValidated,
        total_items: allValidated.length,
        total_cost: totalCost,
        duplicate_count: duplicateSummaries.length,
      },
      display,
    };
  },
};
