import { AtrTool } from "../types.ts";

export const getOcorrencias: AtrTool = {
  name: "get_ocorrencias",
  category: "read",
  description:
    "Consulta ocorrências de contratos (sinistros, avarias, multas). Use para perguntas sobre incidentes, responsáveis, valores, status de resolução.",
  input_schema: {
    type: "object",
    properties: {
      contrato_id: { type: "string", description: "UUID do contrato." },
      tipo: { type: "string", description: "Tipo: sinistro, avaria, multa, outro." },
      status: { type: "string", description: "Status: aberta, em_andamento, resolvida, cancelada." },
      limit: { type: "integer", description: "Máximo de registros. Default 20." },
    },
  },
  handler: async (input, ctx) => {
    const supabase = ctx.supabase;
    const tenantId = ctx.tenant_id;
    const limit = Math.min(input.limit || 20, 50);

    let query = supabase.from("ocorrencias")
      .select("id, contrato_id, tipo, status, descricao, data_ocorrencia, valor_estimado, valor_final, impacto_financeiro, responsavel_pagamento, registrado_por, data_resolucao, observacoes")
      .eq("tenant_id", tenantId)
      .order("data_ocorrencia", { ascending: false })
      .limit(limit);

    if (input.contrato_id) query = query.eq("contrato_id", input.contrato_id);
    if (input.tipo) query = query.eq("tipo", input.tipo);
    if (input.status) query = query.eq("status", input.status);

    const { data, error } = await query;
    if (error) return { ok: false, error: error.message };

    const abertas = (data || []).filter((o) => o.status === "aberta").length;

    return {
      ok: true,
      data: data || [],
      total: (data || []).length,
      message: `${(data || []).length} ocorrência(s) encontrada(s). ${abertas} em aberto.`,
    };
  },
};
