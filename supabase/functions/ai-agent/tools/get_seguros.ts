import { AtrTool } from "../types.ts";

export const getSeguros: AtrTool = {
  name: "get_seguros",
  category: "read",
  description:
    "Consulta apólices de seguro por veículo. Use para perguntas sobre seguradora, valor da apólice, vigência, número de parcelas.",
  input_schema: {
    type: "object",
    properties: {
      placa: { type: "string", description: "Placa do veículo." },
      ano: { type: "integer", description: "Ano de referência da apólice." },
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

    let query = supabase.from("seguros")
      .select("id, veiculo_id, ano_referencia, empresa, numero_apolice, valor_apolice, num_parcelas, data_inicio, data_renovacao, valor_total_pago, status_pagamento, observacoes")
      .eq("tenant_id", tenantId)
      .order("ano_referencia", { ascending: false })
      .limit(50);

    if (veiculoId) query = query.eq("veiculo_id", veiculoId);
    if (input.ano) query = query.eq("ano_referencia", input.ano);

    const { data, error } = await query;
    if (error) return { ok: false, error: error.message };

    return {
      ok: true,
      data: data || [],
      total: (data || []).length,
      message: `${(data || []).length} apólice(s) de seguro encontrada(s).`,
    };
  },
};
