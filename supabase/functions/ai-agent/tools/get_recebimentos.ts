import { AtrTool } from "../types.ts";

export const getRecebimentos: AtrTool = {
  name: "get_recebimentos",
  category: "read",
  description:
    "Consulta recebimentos de locação por veículo. Use para perguntas sobre mensalidades, valores recebidos, inadimplência, datas de vencimento.",
  input_schema: {
    type: "object",
    properties: {
      placa: { type: "string", description: "Placa do veículo." },
      status: { type: "string", description: "Status: Pendente, Pago, Atrasado." },
      limit: { type: "integer", description: "Máximo de registros. Default 20, máximo 50." },
    },
  },
  handler: async (input, ctx) => {
    const supabase = ctx.supabase;
    const tenantId = ctx.tenant_id;
    const limit = Math.min(input.limit || 20, 50);

    let veiculoId: string | null = null;
    if (input.placa) {
      const placaNorm = input.placa.replace("-", "").toUpperCase();
      const { data: v } = await supabase.from("veiculos")
        .select("id").eq("tenant_id", tenantId)
        .ilike("placa", placaNorm).maybeSingle();
      if (!v) return { ok: false, error: `Veículo ${input.placa} não encontrado.` };
      veiculoId = v.id;
    }

    let query = supabase.from("recebimentos")
      .select("id, veiculo_id, locatario, numero_parcela, valor_previsto, valor_recebido, data_vencimento, data_recebimento, status_pagamento, observacoes")
      .eq("tenant_id", tenantId)
      .order("data_vencimento", { ascending: false })
      .limit(limit);

    if (veiculoId) query = query.eq("veiculo_id", veiculoId);
    if (input.status) query = query.eq("status_pagamento", input.status);

    const { data, error } = await query;
    if (error) return { ok: false, error: error.message };

    const totalPrevisto = (data || []).reduce((sum, r) => sum + (r.valor_previsto || 0), 0);
    const totalRecebido = (data || []).reduce((sum, r) => sum + (r.valor_recebido || 0), 0);
    const pendentes = (data || []).filter((r) => r.status_pagamento !== "Pago").length;

    return {
      ok: true,
      data: data || [],
      total: (data || []).length,
      message: `${(data || []).length} recebimento(s). Previsto: R$ ${totalPrevisto.toFixed(2)}, Recebido: R$ ${totalRecebido.toFixed(2)}. ${pendentes} pendente(s).`,
    };
  },
};
