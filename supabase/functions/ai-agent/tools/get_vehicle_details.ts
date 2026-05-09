import { AtrTool } from "../types.ts";

export const getVehicleDetails: AtrTool = {
  name: "get_vehicle_details",
  category: "read",
  description:
    "Busca todos os detalhes de um veículo pela placa (com ou sem hífen) ou pelo UUID. " +
    "Retorna dados do veículo, financiamento ativo com parcelas, contrato ativo e últimas 3 manutenções. " +
    "Use para perguntas como: 'me mostre os detalhes do carro ABC-1234', " +
    "'qual a situação do veículo de placa XYZ?', " +
    "'resumo completo da placa AAA-0000', " +
    "'detalhes do veículo com ID tal', " +
    "'quantas parcelas faltam pagar do financiamento do carro X?'.",
  input_schema: {
    type: "object",
    properties: {
      placa: {
        type: "string",
        description:
          "Placa do veículo (aceita com ou sem hífen, maiúscula ou minúscula). Ex: 'ABC-1234' ou 'abc1234'.",
      },
      id: {
        type: "string",
        description: "UUID do veículo. Usado se placa não for informada.",
      },
    },
  },
  handler: async (input, ctx) => {
    const supabase = ctx.supabase;
    const tenantId = ctx.tenant_id;

    // 1. Buscar veículo por ID ou placa (query única que já retorna dados completos)
    let veiculoQuery;

    if (input.id) {
      veiculoQuery = supabase
        .from("veiculos")
        .select("*")
        .eq("tenant_id", tenantId)
        .eq("id", input.id)
        .single();
    } else if (input.placa) {
      const placaNorm = input.placa.replace("-", "").toUpperCase();
      veiculoQuery = supabase
        .from("veiculos")
        .select("*")
        .eq("tenant_id", tenantId)
        .ilike("placa", placaNorm)
        .single();
    } else {
      return { ok: false, error: "Informe placa ou id do veículo." };
    }

    const { data: veiculo, error: veiculoErr } = await veiculoQuery;

    if (veiculoErr || !veiculo) {
      return {
        ok: false,
        error:
          veiculoErr?.message ||
          `Veículo "${input.placa || input.id}" não encontrado.`,
      };
    }

    // 2. Queries paralelas: financiamento + contrato + manutenções
    const veiculoId = veiculo.id;
    const veiculoPlaca = veiculo.placa;

    const [finResult, contratoResult, manutResult] = await Promise.all([
      // Financiamento ativo
      supabase
        .from("financiamentos")
        .select(
          "id, veiculo_id, situacao, banco_financeira, valor_total_veiculo, valor_entrada, valor_financiado, valor_total_com_juros, valor_ja_pago, quantidade_parcelas, recebimento_mensal, valor_parcela, taxa_juros_mensal"
        )
        .eq("tenant_id", tenantId)
        .eq("veiculo_id", veiculoId)
        .neq("situacao", "Quitado")
        .maybeSingle(),

      // Contrato ativo
      supabase
        .from("contratos")
        .select(
          "id, numero, cliente_nome, cliente_cnpj, cliente_contato, veiculo_placa, data_inicio, data_fim, sla_km_mes, valor_mensal, status, observacoes"
        )
        .eq("tenant_id", tenantId)
        .eq("veiculo_placa", veiculoPlaca)
        .eq("status", "ativo")
        .maybeSingle(),

      // Últimas 3 manutenções (usa veiculoId para buscar pela FK)
      supabase
        .from("manutencoes")
        .select(
          "id, veiculo_id, data_servico, descricao, tipo_servico, oficina, valor_servico, km_registro, status_pagamento, observacoes"
        )
        .eq("tenant_id", tenantId)
        .eq("veiculo_id", veiculoId)
        .order("data_servico", { ascending: false })
        .limit(3),
    ]);

    const financData = finResult.data;
    const financErr = finResult.error;
    if (financErr) return { ok: false, error: financErr.message };

    const contratoData = contratoResult.data;
    const contratoErr = contratoResult.error;
    if (contratoErr) return { ok: false, error: contratoErr.message };

    const manutencoes = manutResult.data || [];
    const manutErr = manutResult.error;
    if (manutErr) return { ok: false, error: manutErr.message };

    // 3. Parcelas do financiamento (se existir financiamento ativo)
    let financiamentoCompleto = null;
    if (financData) {
      const { data: parcelas, error: parcErr } = await supabase
        .from("parcelas_financiamento")
        .select(
          "id, numero_parcela, valor_parcela, data_vencimento, data_pagamento, status_pagamento"
        )
        .eq("tenant_id", tenantId)
        .eq("financiamento_id", financData.id)
        .order("numero_parcela", { ascending: true });

      if (parcErr) return { ok: false, error: parcErr.message };

      const pagas = (parcelas || []).filter(
        (p) => p.status_pagamento === "Pago"
      ).length;
      const pendentes = (parcelas || []).filter(
        (p) => p.status_pagamento !== "Pago"
      ).length;

      financiamentoCompleto = {
        ...financData,
        parcelas: parcelas || [],
        total_parcelas: (parcelas || []).length,
        parcelas_pagas: pagas,
        parcelas_pendentes: pendentes,
      };
    }

    // 4. Resposta consolidada
    return {
      ok: true,
      data: {
        veiculo,
        financiamento: financiamentoCompleto,
        contrato_ativo: contratoData || null,
        ultimas_manutencoes: manutencoes,
      },
      message:
        `Detalhes de ${veiculo.marca} ${veiculo.modelo} (${veiculo.placa}). ` +
        `Status: ${veiculo.situacao_operacional}. ` +
        `KM: ${veiculo.km_atual ?? "N/D"}. ` +
        (financiamentoCompleto
          ? `Financiamento ativo: ${financiamentoCompleto.parcelas_pagas}/${financiamentoCompleto.total_parcelas} parcelas pagas. `
          : "Sem financiamento ativo. ") +
        (contratoData
          ? `Contrato ativo com ${contratoData.cliente_nome}.`
          : "Sem contrato ativo."),
    };
  },
};
