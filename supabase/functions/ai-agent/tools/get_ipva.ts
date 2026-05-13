import { AtrTool } from "../types.ts";

export const getIpva: AtrTool = {
  name: "get_ipva",
  category: "read",
  description:
    "Consulta IPVA por veículo. Use para perguntas sobre valores, vencimentos e status de pagamento de IPVA.",
  input_schema: {
    type: "object",
    properties: {
      placa: { type: "string", description: "Placa do veículo." },
      ano: { type: "integer", description: "Ano de referência. Se omitido, retorna todos." },
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

    let query = supabase.from("ipva")
      .select("id, veiculo_id, ano_referencia, valor_total, data_vencimento, data_pagamento, status_pagamento, observacoes")
      .eq("tenant_id", tenantId)
      .order("ano_referencia", { ascending: false })
      .limit(50);

    if (veiculoId) query = query.eq("veiculo_id", veiculoId);
    if (input.ano) query = query.eq("ano_referencia", input.ano);
    if (input.status) query = query.eq("status_pagamento", input.status);

    const { data, error } = await query;
    if (error) return { ok: false, error: error.message };

    return {
      ok: true,
      data: data || [],
      total: (data || []).length,
      message: `${(data || []).length} registro(s) de IPVA encontrado(s).`,
    };
  },
};
