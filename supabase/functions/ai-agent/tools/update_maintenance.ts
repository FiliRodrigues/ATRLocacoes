import { AtrTool } from "../types.ts";

export const updateMaintenance: AtrTool = {
  name: "update_maintenance",
  category: "write",
  description:
    "Atualiza uma manutenção existente na frota ATR Locações. " +
    "Use para: 'marca manutenção ABC123 como paga', " +
    "'altera prioridade da manutenção XYZ para alta', " +
    "'move manutenção para coluna pendentes', " +
    "'corrige valor da manutenção para R$ 500'. " +
    "Todos os campos são opcionais — apenas os informados serão alterados.",
  input_schema: {
    type: "object",
    properties: {
      maintenance_id: {
        type: "string",
        description: "ID (UUID) da manutenção a ser atualizada (obrigatório). Informe o ID exato.",
      },
      titulo: { type: "string", description: "Novo título/tipo do serviço." },
      descricao: { type: "string", description: "Nova descrição." },
      tipo: { type: "string", description: "Novo tipo de serviço." },
      data: { type: "string", description: "Nova data no formato YYYY-MM-DD." },
      fornecedor: { type: "string", description: "Novo fornecedor/oficina." },
      custo: { type: "number", description: "Novo valor em reais." },
      km_no_servico: { type: "number", description: "Novo km no serviço." },
      prioridade: { type: "string", description: "Nova prioridade: 'alta', 'media', 'baixa', 'ok'." },
      coluna: { type: "string", description: "Nova coluna/status: 'pendentes', 'emOficina', 'concluidos'." },
      status_pagamento: { type: "string", description: "Status de pagamento: 'Pago', 'Pendente', 'Aguardando'." },
      is_preventiva: { type: "boolean", description: "Se é manutenção preventiva (true) ou corretiva (false)." },
      odometro: { type: "integer", description: "Novo odômetro/km do veículo." },
      observacoes: { type: "string", description: "Novas observações." },
    },
    required: ["maintenance_id"],
  },

  preview: async (input, _ctx) => {
    const mudancas: string[] = [];
    for (const [k, v] of Object.entries(input)) {
      if (k !== "maintenance_id" && v !== undefined && v !== null) {
        mudancas.push(`${k}=${v}`);
      }
    }
    return `Atualizar manutenção ${input.maintenance_id}: ${mudancas.join(", ") || "sem alterações"}`;
  },

  handler: async (input, ctx) => {
    const supabase = ctx.supabase as Record<string, unknown>;
    const tenantId = ctx.tenant_id as string;
    const id = String(input.maintenance_id || "").trim();

    if (!id) return { ok: false, error: "ID da manutenção é obrigatório." };

    // Verifica existência
    const { data: existente } = await (supabase as any)
      .from("manutencoes")
      .select("id, titulo, veiculo_placa")
      .eq("tenant_id", tenantId)
      .eq("id", id)
      .single();

    if (!existente) return { ok: false, error: `Manutenção ${id} não encontrada.` };

    const updates: Record<string, unknown> = {};
    const campos: [string, string][] = [
      ["titulo", "string"], ["descricao", "string"], ["tipo", "string"],
      ["data", "string"], ["fornecedor", "string"], ["custo", "number"],
      ["km_no_servico", "number"], ["prioridade", "string"], ["coluna", "string"],
      ["status_pagamento", "string"], ["is_preventiva", "boolean"], ["odometro", "integer"],
      ["observacoes", "string"],
    ];

    for (const [campo, tipo] of campos) {
      if (input[campo] !== undefined && input[campo] !== null) {
        if (tipo === "number" || tipo === "integer") updates[campo] = Number(input[campo]);
        else if (tipo === "boolean") updates[campo] = Boolean(input[campo]);
        else updates[campo] = String(input[campo]).trim();
      }
    }

    if (Object.keys(updates).length === 0) {
      return { ok: false, error: "Nenhum campo para atualizar foi informado." };
    }

    // Valida prioridade se informada
    if (updates.prioridade && !["alta", "media", "baixa", "ok"].includes(String(updates.prioridade))) {
      return { ok: false, error: "Prioridade inválida. Use: 'alta', 'media', 'baixa' ou 'ok'." };
    }

    // Valida coluna se informada
    if (updates.coluna && !["pendentes", "emOficina", "concluidos"].includes(String(updates.coluna))) {
      return { ok: false, error: "Coluna inválida. Use: 'pendentes', 'emOficina' ou 'concluidos'." };
    }

    // Valida data se informada
    if (updates.data && !/^\d{4}-\d{2}-\d{2}$/.test(String(updates.data))) {
      return { ok: false, error: "Data inválida. Use o formato YYYY-MM-DD." };
    }

    const display = (await updateMaintenance.preview!(input, ctx)) ?? "";
    return { ok: true, data: { maintenance_id: id, updates, current_plate: (existente as any).veiculo_placa, current_titulo: (existente as any).titulo }, display };
  },
};
