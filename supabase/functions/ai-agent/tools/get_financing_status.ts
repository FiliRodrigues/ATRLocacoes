import { AtrTool } from "../types.ts";

export const getFinancingStatus: AtrTool = {
  name: "get_financing_status",
  category: "read",
  description:
    "Busca o status do financiamento de um veículo pela placa ou UUID. " +
    "Retorna dados consolidados: valor total financiado, valor já pago, parcelas pagas vs pendentes, " +
    "próxima data de vencimento e resumo financeiro. " +
    "Use para perguntas como: 'qual o financiamento do carro ABC-1234?', " +
    "'quantas parcelas faltam pagar do veículo X?', " +
    "'quanto já pagamos do financiamento do carro Y?', " +
    "'qual a próxima parcela a vencer do veículo Z?', " +
    "'mostre o resumo financeiro do financiamento da placa AAA-0000'.",
  input_schema: {
    type: "object",
    properties: {
      vehicle_identifier: {
        type: "string",
        description:
          "Placa do veículo (aceita com ou sem hífen, maiúscula ou minúscula) ou UUID do veículo. " +
          "Ex: 'ABC-1234', 'abc1234', ou UUID.",
      },
    },
    required: ["vehicle_identifier"],
  },
  handler: async (input, ctx) => {
    const supabase = ctx.supabase;
    const tenantId = ctx.tenant_id;

    const ident = String(input.vehicle_identifier).trim();
    const isUuid =
      /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(ident);

    let veiculoId: string;
    let veiculoPlaca: string;
    let veiculoModelo: string;
    let veiculoMarca: string;

    // 1. Resolver veículo
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
      veiculoModelo = v.modelo || "";
      veiculoMarca = v.marca || "";
    } else {
      // Normaliza placa: tira hífen, uppercase
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
      veiculoModelo = v.modelo || "";
      veiculoMarca = v.marca || "";
    }

    // 2. Busca financiamento ativo do veículo
    const { data: financiamento, error: finErr } = await supabase
      .from("financiamentos")
      .select(
        "id, situacao, banco_financeira, valor_total_veiculo, valor_entrada, valor_financiado, valor_total_com_juros, valor_ja_pago, quantidade_parcelas, recebimento_mensal, valor_parcela, taxa_juros_mensal"
      )
      .eq("tenant_id", tenantId)
      .eq("veiculo_id", veiculoId)
      .neq("situacao", "Quitado")
      .maybeSingle();

    if (finErr) {
      return { ok: false, error: finErr.message };
    }

    // 3. Se não tem financiamento ativo
    if (!financiamento) {
      return {
        ok: true,
        data: {
          vehicle_plate: veiculoPlaca,
          vehicle_model: `${veiculoMarca} ${veiculoModelo}`.trim(),
          vehicle_id: veiculoId,
          has_financing: false,
        },
        message: `Veículo ${veiculoPlaca} (${veiculoMarca} ${veiculoModelo}) não possui financiamento ativo.`,
      };
    }

    const fin = financiamento;

    // 4. Busca parcelas do financiamento
    const { data: parcelas, error: parcErr } = await supabase
      .from("parcelas_financiamento")
      .select(
        "id, numero_parcela, valor_parcela, data_vencimento, data_pagamento, status_pagamento"
      )
      .eq("tenant_id", tenantId)
      .eq("financiamento_id", fin.id)
      .order("numero_parcela", { ascending: true });

    if (parcErr) {
      return { ok: false, error: parcErr.message };
    }

    const todasParcelas = parcelas || [];
    const parcelasPagas = todasParcelas.filter(
      (p) => p.status_pagamento === "Pago"
    );
    const parcelasPendentes = todasParcelas.filter(
      (p) => p.status_pagamento !== "Pago"
    );

    // Cálculos financeiros
    const totalPaid = parcelasPagas.reduce(
      (sum, p) => sum + (Number(p.valor_parcela) || 0),
      0
    );
    const totalPending = parcelasPendentes.reduce(
      (sum, p) => sum + (Number(p.valor_parcela) || 0),
      0
    );

    // Próxima data de vencimento (menor data_vencimento entre pendentes)
    const datasPendentes = parcelasPendentes
      .map((p) => p.data_vencimento)
      .filter((d): d is string => d !== null)
      .sort();
    const nextDueDate = datasPendentes.length > 0 ? datasPendentes[0] : null;

    // Parcela atual (primeira pendente por número)
    const primeiraPendente = parcelasPendentes.length > 0 ? parcelasPendentes[0] : null;

    // Progresso percentual do pagamento
    const valorTotalComJuros = Number(fin.valor_total_com_juros) || 0;
    const percentualPago =
      valorTotalComJuros > 0
        ? Math.round((totalPaid / valorTotalComJuros) * 100)
        : 0;

    // Display amigável
    const displayParts: string[] = [];
    displayParts.push(
      `Financiamento do veículo ${veiculoPlaca} (${veiculoMarca} ${veiculoModelo})`
    );
    displayParts.push(`Banco/Financeira: ${fin.banco_financeira || "N/D"}`);
    displayParts.push(`Situação: ${fin.situacao || "N/D"}`);
    displayParts.push(
      `Valor total financiado: R$ ${(Number(fin.valor_financiado) || 0).toFixed(2)}`
    );
    displayParts.push(
      `Valor total com juros: R$ ${valorTotalComJuros.toFixed(2)}`
    );
    displayParts.push(`Valor já pago: R$ ${totalPaid.toFixed(2)}`);
    displayParts.push(
      `Valor restante: R$ ${(valorTotalComJuros - totalPaid).toFixed(2)}`
    );
    displayParts.push(
      `Parcelas: ${parcelasPagas.length}/${todasParcelas.length} pagas (${percentualPago}%)`
    );
    if (nextDueDate) {
      displayParts.push(`Próximo vencimento: ${nextDueDate}`);
    }
    if (primeiraPendente) {
      displayParts.push(
        `Próxima parcela: #${primeiraPendente.numero_parcela} - R$ ${(Number(primeiraPendente.valor_parcela) || 0).toFixed(2)}`
      );
    }

    return {
      ok: true,
      data: {
        vehicle_plate: veiculoPlaca,
        vehicle_model: `${veiculoMarca} ${veiculoModelo}`.trim(),
        vehicle_id: veiculoId,
        has_financing: true,
        financing: {
          id: fin.id,
          situacao: fin.situacao,
          banco_financeira: fin.banco_financeira,
          valor_total_veiculo: fin.valor_total_veiculo,
          valor_entrada: fin.valor_entrada,
          valor_financiado: fin.valor_financiado,
          valor_total_com_juros: fin.valor_total_com_juros,
          valor_ja_pago: fin.valor_ja_pago,
          quantidade_parcelas: fin.quantidade_parcelas,
          recebimento_mensal: fin.recebimento_mensal,
          valor_parcela: fin.valor_parcela,
          taxa_juros_mensal: fin.taxa_juros_mensal,
        },
        installments: {
          total: todasParcelas.length,
          paid: parcelasPagas.length,
          pending: parcelasPendentes.length,
          total_paid: totalPaid,
          total_pending: totalPending,
          percentual_pago: percentualPago,
          next_due_date: nextDueDate,
          next_installment: primeiraPendente
            ? {
                numero_parcela: primeiraPendente.numero_parcela,
                valor_parcela: primeiraPendente.valor_parcela,
                data_vencimento: primeiraPendente.data_vencimento,
                status_pagamento: primeiraPendente.status_pagamento,
              }
            : null,
        },
        all_installments: todasParcelas.map((p) => ({
          numero_parcela: p.numero_parcela,
          valor_parcela: p.valor_parcela,
          data_vencimento: p.data_vencimento,
          data_pagamento: p.data_pagamento,
          status_pagamento: p.status_pagamento,
        })),
      },
      display: displayParts.join("\n"),
    };
  },
};
