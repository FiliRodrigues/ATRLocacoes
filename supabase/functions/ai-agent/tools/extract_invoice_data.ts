import { AtrTool } from "../types.ts";

export const extractInvoiceData: AtrTool = {
  name: "extract_invoice_data",
  category: "read",
  description:
    "Processa dados de notas fiscais extraídas pelo Claude (de imagens ou texto) e cruza com a frota da ATR. " +
    "Para cada NF, identifica o veículo pela placa (normalizada: uppercase, sem hífen) e, " +
    "se a placa não bater, tenta busca por modelo/marca via vehicle_hint. " +
    "Valida totais dos itens contra o total da NF (tolerância de 1%). " +
    "NÃO escreve nada no banco — apenas estrutura os dados para conferência antes da inserção. " +
    "Use quando o usuário enviar foto de NF e perguntar: " +
    "'processa essa nota fiscal', " +
    "'extrai os dados dessa NF', " +
    "'essa NF é de qual veículo?', " +
    "'confere os valores dessa nota', " +
    "'identifica o veículo dessas NFs que vou te enviar'.",
  input_schema: {
    type: "object",
    properties: {
      invoices: {
        type: "array",
        description:
          "Array de notas fiscais extraídas. Cada objeto representa uma NF com dados lidos da imagem/texto.",
        items: {
          type: "object",
          properties: {
            vehicle_plate: {
              type: "string",
              description: "Placa do veículo conforme lida na NF (com ou sem hífen).",
            },
            vehicle_hint: {
              type: "string",
              description:
                "Dica para identificar o veículo caso a placa não seja encontrada. " +
                "Pode ser modelo ('Corolla'), marca ('Toyota') ou ambos. " +
                "Usado como busca ILIKE em modelo OU marca da tabela veiculos.",
            },
            date: {
              type: "string",
              description: "Data da NF no formato YYYY-MM-DD.",
            },
            workshop_name: {
              type: "string",
              description: "Nome da oficina/prestador emitente da NF.",
            },
            workshop_cnpj: {
              type: "string",
              description: "CNPJ do emitente da NF (apenas dígitos).",
            },
            invoice_number: {
              type: "string",
              description: "Número da nota fiscal.",
            },
            items: {
              type: "array",
              description: "Itens/serviços descritos na NF.",
              items: {
                type: "object",
                properties: {
                  description: {
                    type: "string",
                    description: "Descrição do item/serviço.",
                  },
                  quantity: {
                    type: "number",
                    description: "Quantidade.",
                  },
                  unit_price: {
                    type: "number",
                    description: "Preço unitário.",
                  },
                  total: {
                    type: "number",
                    description: "Valor total do item (qtd * preco_unitario).",
                  },
                },
              },
            },
            total_amount: {
              type: "number",
              description:
                "Valor total da NF (soma dos itens, usado para validação).",
            },
            maintenance_type: {
              type: "string",
              description:
                "Tipo de manutenção/serviço inferido. Ex: 'Freio', 'Motor', 'Suspensão', 'Revisão', 'Pneu', 'Elétrica'.",
            },
          },
          required: ["date", "total_amount"],
        },
      },
    },
    required: ["invoices"],
  },
  handler: async (input, ctx) => {
    const supabase = ctx.supabase;
    const tenantId = ctx.tenant_id;

    const invoices = input.invoices as Array<Record<string, unknown>>;

    if (!Array.isArray(invoices) || invoices.length === 0) {
      return { ok: false, error: "Array 'invoices' é obrigatório e deve conter pelo menos 1 NF." };
    }

    if (invoices.length > 50) {
      return { ok: false, error: "Máximo de 50 NFs por chamada." };
    }

    // Coleta todas as placas e hints para resolver em batch
    const placasParaBuscar = new Set<string>();
    const hintsParaBuscar: Array<{ index: number; hint: string }> = [];

    for (let i = 0; i < invoices.length; i++) {
      const inv = invoices[i];
      if (inv.vehicle_plate) {
        const placaNorm = String(inv.vehicle_plate).replace(/-/g, "").toUpperCase();
        placasParaBuscar.add(placaNorm);
        // Guarda a placa normalizada de volta no objeto para uso posterior
        inv._placa_norm = placaNorm;
      }
      if (inv.vehicle_hint) {
        hintsParaBuscar.push({ index: i, hint: String(inv.vehicle_hint) });
      }
    }

    // Batch: busca veículos por placa (aceita DB com ou sem hífen)
    const placaToVeiculo: Record<string, { id: string; placa: string; modelo: string; marca: string }> = {};
    if (placasParaBuscar.size > 0) {
      const placasNorm = Array.from(placasParaBuscar); // sem hífen, uppercase
      // Monta variantes com hífen para cobrir o formato "ABC-1234"
      const placasComHifen = placasNorm
        .filter((p) => p.length === 7)
        .map((p) => `${p.slice(0, 3)}-${p.slice(3)}`);
      const todasPlacas = [...new Set([...placasNorm, ...placasComHifen])];

      for (let i = 0; i < todasPlacas.length; i += 50) {
        const batch = todasPlacas.slice(i, i + 50);
        const { data: veiculos, error: vErr } = await supabase
          .from("veiculos")
          .select("id, placa, modelo, marca")
          .eq("tenant_id", tenantId)
          .in("placa", batch);

        if (!vErr && veiculos) {
          for (const v of veiculos) {
            // Indexa pela versão normalizada (sem hífen) para que o match sempre funcione
            const chave = v.placa.replace(/-/g, "").toUpperCase();
            placaToVeiculo[chave] = v;
          }
        }
      }
    }

    // Resolve hints para veículos que não foram encontrados por placa
    const hintCache: Record<string, Array<{ id: string; placa: string; modelo: string; marca: string }>> = {};
    for (const { hint } of hintsParaBuscar) {
      const hintKey = hint.toLowerCase().trim();
      if (hintCache[hintKey]) continue; // já buscou

      const { data: veiculos, error: hErr } = await supabase
        .from("veiculos")
        .select("id, placa, modelo, marca")
        .eq("tenant_id", tenantId)
        .or(`modelo.ilike.%${hint}%,marca.ilike.%${hint}%`)
        .limit(10);

      if (!hErr && veiculos) {
        hintCache[hintKey] = veiculos;
      }
    }

    // Processa cada NF
    const matched: Array<Record<string, unknown>> = [];
    const unmatched: Array<Record<string, unknown>> = [];

    for (let i = 0; i < invoices.length; i++) {
      const inv = invoices[i];
      const placaNorm = (inv._placa_norm as string) || "";
      const hint = inv.vehicle_hint ? String(inv.vehicle_hint).trim() : null;
      const items = (inv.items as Array<Record<string, unknown>>) || [];
      const totalAmount = Number(inv.total_amount) || 0;

      // Validação de totais: SUM(items[].total) vs total_amount (tolerância 1%)
      let itemsTotal = 0;
      let validationWarning: string | null = null;
      if (items.length > 0) {
        itemsTotal = items.reduce((sum, it) => sum + (Number(it.total) || 0), 0);
        if (totalAmount > 0 && Math.abs(itemsTotal - totalAmount) / totalAmount > 0.01) {
          validationWarning =
            `Divergência nos totais: soma dos itens = R$ ${itemsTotal.toFixed(2)} vs total NF = R$ ${totalAmount.toFixed(2)}. ` +
            `Diferença: R$ ${Math.abs(itemsTotal - totalAmount).toFixed(2)}.`;
        }
      }

      // Tenta match por placa
      let veiculoMatch: { id: string; placa: string; modelo: string; marca: string } | null = null;
      let matchMethod: "placa" | "hint" | "none" = "none";
      let candidates: Array<{ id: string; placa: string; modelo: string; marca: string }> = [];

      if (placaNorm && placaToVeiculo[placaNorm]) {
        veiculoMatch = placaToVeiculo[placaNorm];
        matchMethod = "placa";
      }

      // Se não achou por placa, tenta hint
      if (!veiculoMatch && hint) {
        const hintKey = hint.toLowerCase().trim();
        const hintResults = hintCache[hintKey];
        if (hintResults && hintResults.length === 1) {
          veiculoMatch = hintResults[0];
          matchMethod = "hint";
        } else if (hintResults && hintResults.length > 1) {
          candidates = hintResults;
          matchMethod = "hint";
        }
      }

      const invoiceResult: Record<string, unknown> = {
        index: i,
        invoice_number: inv.invoice_number || null,
        date: inv.date || null,
        workshop_name: inv.workshop_name || null,
        workshop_cnpj: inv.workshop_cnpj || null,
        maintenance_type: inv.maintenance_type || null,
        total_amount: totalAmount,
        items_count: items.length,
        items_total: itemsTotal,
        validation_warning: validationWarning,
        match_method: matchMethod,
      };

      if (veiculoMatch) {
        invoiceResult.vehicle = {
          id: veiculoMatch.id,
          placa: veiculoMatch.placa,
          modelo: veiculoMatch.modelo,
          marca: veiculoMatch.marca,
        };
        invoiceResult.match_method = matchMethod;
        matched.push(invoiceResult);
      } else if (candidates.length > 1) {
        // Ambíguo: múltiplos candidatos
        invoiceResult.ambiguous_candidates = candidates.map((c) => ({
          id: c.id,
          placa: c.placa,
          modelo: c.modelo,
          marca: c.marca,
        }));
        invoiceResult.error =
          `Hint "${hint}" retornou ${candidates.length} veículos. ` +
          `Refine a busca ou informe a placa exata. Candidatos: ${candidates.map((c) => `${c.placa} (${c.marca} ${c.modelo})`).join(", ")}.`;
        unmatched.push(invoiceResult);
      } else {
        invoiceResult.error = veiculoMatch
          ? null
          : placaNorm
            ? `Placa "${inv.vehicle_plate}" não encontrada na frota.`
            : "Nenhuma placa ou hint informada para identificar o veículo.";
        unmatched.push(invoiceResult);
      }

      // Limpa dados internos
      delete inv._placa_norm;
    }

    // Resumo
    const total = invoices.length;
    const matchedCount = matched.length;
    const unmatchedCount = unmatched.length;

    const summaryParts: string[] = [];
    summaryParts.push(
      `${matchedCount} de ${total} NF(s) identificada(s) com sucesso.`
    );

    if (unmatchedCount > 0) {
      summaryParts.push(
        `${unmatchedCount} NF(s) não identificada(s) — verifique placas ou refine os hints.`
      );
    }

    const withWarnings = matched.filter((m) => m.validation_warning).length;
    if (withWarnings > 0) {
      summaryParts.push(
        `${withWarnings} NF(s) com divergência nos valores (soma dos itens vs total).`
      );
    }

    // Display detalhado
    const displayParts: string[] = [];
    displayParts.push(summaryParts.join(" "));
    displayParts.push("");

    if (matched.length > 0) {
      displayParts.push("--- NFs IDENTIFICADAS ---");
      for (const m of matched) {
        const veic = m.vehicle as Record<string, string> | undefined;
        displayParts.push(
          `NF #${m.invoice_number || "s/n"} - ${m.date || "s/data"} - ` +
          `${veic ? `${veic.placa} (${veic.marca} ${veic.modelo})` : "s/veículo"} - ` +
          `R$ ${Number(m.total_amount).toFixed(2)}` +
          (m.validation_warning ? ` [ALERTA: ${m.validation_warning}]` : "")
        );
      }
    }

    if (unmatched.length > 0) {
      displayParts.push("");
      displayParts.push("--- NFs NÃO IDENTIFICADAS ---");
      for (const u of unmatched) {
        displayParts.push(
          `NF #${u.invoice_number || "s/n"} - ${u.date || "s/data"} - ` +
          `R$ ${Number(u.total_amount).toFixed(2)} - ${u.error || "Erro desconhecido"}`
        );
      }
    }

    return {
      ok: true,
      data: {
        total_invoices: total,
        matched_count: matchedCount,
        unmatched_count: unmatchedCount,
        matched,
        unmatched,
        summary: summaryParts.join(" "),
      },
      display: displayParts.join("\n"),
    };
  },
};
