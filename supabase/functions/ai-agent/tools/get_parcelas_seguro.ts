import { AtrTool } from "../types.ts";

export const getParcelasSeguro: AtrTool = {
  name: "get_parcelas_seguro",
  category: "read",
  description:
    "Consulta parcelas de uma apólice de seguro. Use para ver status de pagamento das parcelas, vencimentos e valores.",
  input_schema: {
    type: "object",
    properties: {
      seguro_id: { type: "string", description: "UUID da apólice de seguro." },
      status: { type: "string", description: "Filtro: Pago, Pendente, Vencido." },
    },
    required: ["seguro_id"],
  },
  handler: async (input, ctx) => {
    const supabase = ctx.supabase;
    const tenantId = ctx.tenant_id;

    let query = supabase.from("parcelas_seguro")
      .select("id, seguro_id, numero_parcela, valor_parcela, data_vencimento, data_pagamento, status_pagamento")
      .eq("tenant_id", tenantId)
      .eq("seguro_id", input.seguro_id)
      .order("numero_parcela", { ascending: true })
      .limit(100);

    if (input.status) query = query.eq("status_pagamento", input.status);

    const { data, error } = await query;
    if (error) return { ok: false, error: error.message };

    const pagas = (data || []).filter((p) => p.status_pagamento === "Pago").length;
    const total = (data || []).length;

    return {
      ok: true,
      data: data || [],
      total,
      message: `${total} parcela(s). ${pagas} paga(s), ${total - pagas} pendente(s).`,
    };
  },
};
