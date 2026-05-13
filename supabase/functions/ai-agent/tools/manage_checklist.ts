import { AtrTool } from "../types.ts";

// ================================================================
// Criar evento de checklist (check-in / check-out)
// ================================================================
export const createChecklistEvento: AtrTool = {
  name: "create_checklist_evento",
  category: "write",
  description:
    "Registra check-in (saída) ou check-out (retorno) de um contrato de locação. " +
    "Use para: 'registra saída do veículo no contrato CTR-001 com 45.000 km', " +
    "'faz check-out do ABC-1234 com 80% de combustível'.",
  input_schema: {
    type: "object",
    properties: {
      contrato_id: { type: "string", description: "ID (UUID) do contrato." },
      tipo: { type: "string", description: "Tipo: 'saida' (check-in) ou 'retorno' (check-out)." },
      km_odometro: { type: "integer", description: "Quilometragem atual do veículo." },
      realizado_por: { type: "string", description: "Nome de quem realizou o checklist." },
      combustivel_pct: { type: "integer", description: "Nível de combustível em % (0-100). Default: 100." },
      km_percorridos: { type: "integer", description: "Km percorridos desde o último checklist (opcional)." },
      observacoes: { type: "string", description: "Observações adicionais (opcional)." },
    },
    required: ["contrato_id", "tipo", "km_odometro", "realizado_por"],
  },

  preview: async (input, ctx) => {
    const supabase = ctx.supabase as Record<string, unknown>;
    const tenantId = ctx.tenant_id as string;
    const { data } = await (supabase as any)
      .from("contratos")
      .select("numero, cliente_nome, veiculo_placa")
      .eq("tenant_id", tenantId)
      .eq("id", String(input.contrato_id))
      .single();
    const tipoLabel = input.tipo === "saida" ? "Saída" : "Retorno";
    if (!data) return `Registrar ${tipoLabel}: contrato ${input.contrato_id} — ${input.km_odometro} km`;
    return `Registrar ${tipoLabel} — Contrato ${data.numero} (${data.veiculo_placa}) — ${input.km_odometro} km — por ${input.realizado_por}`;
  },

  handler: async (input, ctx) => {
    const supabase = ctx.supabase as Record<string, unknown>;
    const tenantId = ctx.tenant_id as string;

    const tipo = String(input.tipo).trim().toLowerCase();
    if (!["saida", "retorno"].includes(tipo)) {
      return { ok: false, error: "Tipo inválido. Use 'saida' ou 'retorno'." };
    }

    const { data: contrato } = await (supabase as any)
      .from("contratos")
      .select("id, numero")
      .eq("tenant_id", tenantId)
      .eq("id", String(input.contrato_id))
      .single();
    if (!contrato) return { ok: false, error: "Contrato não encontrado." };

    const km = Number(input.km_odometro);
    if (!Number.isInteger(km) || km < 0) {
      return { ok: false, error: "km_odometro deve ser um inteiro positivo." };
    }

    const combustivel = input.combustivel_pct != null ? Number(input.combustivel_pct) : 100;
    if (combustivel < 0 || combustivel > 100) {
      return { ok: false, error: "combustivel_pct deve ser entre 0 e 100." };
    }

    const validatedData: Record<string, unknown> = {
      contrato_id: String(input.contrato_id),
      tipo,
      km_odometro: km,
      combustivel_pct: combustivel,
      realizado_por: String(input.realizado_por).trim(),
      observacoes: input.observacoes ? String(input.observacoes).trim() : "",
      fotos: [],
    };

    if (input.km_percorridos != null) {
      validatedData.km_percorridos = Number(input.km_percorridos);
    }

    const display = (await createChecklistEvento.preview!(input, ctx)) ?? "";
    return { ok: true, data: validatedData, display };
  },
};

// ================================================================
// Atualizar evento de checklist
// ================================================================
export const updateChecklistEvento: AtrTool = {
  name: "update_checklist_evento",
  category: "write",
  description:
    "Atualiza um evento de checklist — corrige km, nível de combustível, observações. " +
    "Use para: 'corrige o km do check-in para 46.000', 'adiciona observação no retorno'.",
  input_schema: {
    type: "object",
    properties: {
      checklist_id: { type: "string", description: "ID (UUID) do evento de checklist." },
      km_odometro: { type: "integer", description: "Novo valor de km." },
      combustivel_pct: { type: "integer", description: "Novo nível de combustível (0-100)." },
      observacoes: { type: "string", description: "Novas observações." },
      realizado_por: { type: "string", description: "Atualizar responsável." },
    },
    required: ["checklist_id"],
  },

  preview: async (input, ctx) => {
    const supabase = ctx.supabase as Record<string, unknown>;
    const tenantId = ctx.tenant_id as string;
    const { data } = await (supabase as any)
      .from("checklist_eventos")
      .select("id, tipo, km_odometro")
      .eq("tenant_id", tenantId)
      .eq("id", String(input.checklist_id))
      .single();
    if (!data) return `Atualizar checklist: ID ${input.checklist_id} não encontrado.`;
    const tipoLabel = data.tipo === "saida" ? "Saída" : "Retorno";
    return `Atualizar checklist ${tipoLabel} (ID ${input.checklist_id})`;
  },

  handler: async (input, ctx) => {
    const supabase = ctx.supabase as Record<string, unknown>;
    const tenantId = ctx.tenant_id as string;
    const id = String(input.checklist_id).trim();

    const { data } = await (supabase as any)
      .from("checklist_eventos")
      .select("id")
      .eq("tenant_id", tenantId)
      .eq("id", id)
      .single();
    if (!data) return { ok: false, error: "Evento de checklist não encontrado." };

    const updates: Record<string, unknown> = {};
    if (input.km_odometro !== undefined) {
      const km = Number(input.km_odometro);
      if (!Number.isInteger(km) || km < 0) return { ok: false, error: "km_odometro inválido." };
      updates.km_odometro = km;
    }
    if (input.combustivel_pct !== undefined) {
      const pct = Number(input.combustivel_pct);
      if (pct < 0 || pct > 100) return { ok: false, error: "combustivel_pct deve ser entre 0 e 100." };
      updates.combustivel_pct = pct;
    }
    if (input.observacoes !== undefined) updates.observacoes = String(input.observacoes).trim();
    if (input.realizado_por !== undefined) updates.realizado_por = String(input.realizado_por).trim();

    if (Object.keys(updates).length === 0) return { ok: false, error: "Nenhum campo para atualizar." };

    const display = (await updateChecklistEvento.preview!(input, ctx)) ?? "";
    return { ok: true, data: { checklist_id: id, updates }, display };
  },
};
