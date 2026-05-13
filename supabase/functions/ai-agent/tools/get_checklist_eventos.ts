import { AtrTool } from "../types.ts";

export const getChecklistEventos: AtrTool = {
  name: "get_checklist_eventos",
  category: "read",
  description:
    "Consulta eventos de checklist de contratos (check-in/check-out). Use para perguntas sobre quilometragem, combustível, fotos, observações de vistoria.",
  input_schema: {
    type: "object",
    properties: {
      contrato_id: { type: "string", description: "UUID do contrato." },
      tipo: { type: "string", description: "Tipo: checkin, checkout." },
      limit: { type: "integer", description: "Máximo de registros. Default 20." },
    },
    required: ["contrato_id"],
  },
  handler: async (input, ctx) => {
    const supabase = ctx.supabase;
    const tenantId = ctx.tenant_id;
    const limit = Math.min(input.limit || 20, 50);

    let query = supabase.from("checklist_eventos")
      .select("id, contrato_id, tipo, km_odometro, km_percorridos, combustivel_pct, observacoes, fotos, realizado_por, created_at")
      .eq("tenant_id", tenantId)
      .eq("contrato_id", input.contrato_id)
      .order("created_at", { ascending: false })
      .limit(limit);

    if (input.tipo) query = query.eq("tipo", input.tipo);

    const { data, error } = await query;
    if (error) return { ok: false, error: error.message };

    return {
      ok: true,
      data: data || [],
      total: (data || []).length,
      message: `${(data || []).length} evento(s) de checklist encontrado(s).`,
    };
  },
};
