import { AtrTool } from "../types.ts";

export const getMultas: AtrTool = {
  name: "get_multas",
  category: "read",
  description:
    "Consulta multas por veículo. Use para perguntas sobre infrações, valores, status de pagamento, datas de vencimento.",
  input_schema: {
    type: "object",
    properties: {
      placa: { type: "string", description: "Placa do veículo." },
      ano: { type: "integer", description: "Ano de referência." },
      status: { type: "string", description: "Filtro: Pendente, Pago, Vencido." },
    },
  },
  handler: async (input, ctx) => {
    const supabase = ctx.supabase;
    const tenantId = ctx.tenant_id;

    let veiculoId: string | null = null;
    if (input.placa) {
      const placaNorm = input.placa.replace("-", "").toUpperCase();
      const { data: v } = await supabase.from("veiculos")
        .select("id").eq("tenant_id", tenantId)
        .ilike("placa", placaNorm).maybeSingle();
      if (!v) return { ok: false, error: `Veículo ${input.placa} não encontrado.` };
      veiculoId = v.id;
    }

    let query = supabase.from("multas")
      .select("id, veiculo_id, ano_referencia, mes, valor, descricao, status_pagamento, data_infracao, data_vencimento, data_pagamento")
      .eq("tenant_id", tenantId)
      .order("data_infracao", { ascending: false })
      .limit(50);

    if (veiculoId) query = query.eq("veiculo_id", veiculoId);
    if (input.ano) query = query.eq("ano_referencia", input.ano);
    if (input.status) query = query.eq("status_pagamento", input.status);

    const { data, error } = await query;
    if (error) return { ok: false, error: error.message };

    const totalValor = (data || []).reduce((sum, m) => sum + (m.valor || 0), 0);

    return {
      ok: true,
      data: data || [],
      total: (data || []).length,
      message: `${(data || []).length} multa(s) encontrada(s). Valor total: R$ ${totalValor.toFixed(2)}.`,
    };
  },
};
