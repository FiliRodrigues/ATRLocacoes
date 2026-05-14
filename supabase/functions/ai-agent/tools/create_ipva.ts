import { AtrTool } from "../types.ts";

function normalizePlaca(raw: string): string {
  return raw.replace(/[\s\-\.]/g, "").toUpperCase().trim();
}

async function resolveVeiculoId(identifier: string, supabase: any, tenantId: string): Promise<{ id: string; placa: string } | null> {
  const isUuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(identifier);
  if (isUuid) {
    const { data } = await supabase.from("veiculos").select("id, placa").eq("tenant_id", tenantId).eq("id", identifier).single();
    return data || null;
  }
  const placa = normalizePlaca(identifier);
  const { data } = await supabase.from("veiculos").select("id, placa").eq("tenant_id", tenantId).ilike("placa", placa).single();
  return data || null;
}

export const createIpva: AtrTool = {
  name: "create_ipva",
  category: "write",
  description:
    "Registra um novo IPVA para um veículo. Use para: 'lança IPVA 2025 do ABC-1234 R$ 1.200'. " +
    "Para atualizar um IPVA existente (ex: marcar como pago), use update_ipva.",
  input_schema: {
    type: "object",
    properties: {
      vehicle_identifier: {
        type: "string",
        description: "Placa ou UUID do veículo.",
      },
      ano_referencia: {
        type: "integer",
        description: "Ano de referência do IPVA (ex: 2025).",
      },
      valor_total: {
        type: "number",
        description: "Valor total do IPVA em R$.",
      },
      data_vencimento: {
        type: "string",
        description: "Data de vencimento no formato YYYY-MM-DD.",
      },
      status_pagamento: {
        type: "string",
        description: "Status: 'Pendente', 'Pago' ou 'Vencido'. Default: 'Pendente'.",
      },
      data_pagamento: {
        type: "string",
        description: "Data de pagamento YYYY-MM-DD (preencher somente se já pago).",
      },
      observacoes: {
        type: "string",
        description: "Observações opcionais.",
      },
    },
    required: ["vehicle_identifier", "ano_referencia", "valor_total", "data_vencimento"],
  },

  preview: async (input, ctx) => {
    const supabase = ctx.supabase as any;
    const tenantId = ctx.tenant_id as string;
    const v = await resolveVeiculoId(String(input.vehicle_identifier), supabase, tenantId);
    const placa = v ? v.placa : String(input.vehicle_identifier);
    return `Registrar IPVA ${input.ano_referencia} — ${placa} — R$ ${Number(input.valor_total).toFixed(2)}`;
  },

  handler: async (input, ctx) => {
    const supabase = ctx.supabase as any;
    const tenantId = ctx.tenant_id as string;

    const v = await resolveVeiculoId(String(input.vehicle_identifier), supabase, tenantId);
    if (!v) return { ok: false, error: `Veículo não encontrado: "${input.vehicle_identifier}".` };

    const anoRef = Number(input.ano_referencia);
    if (!Number.isInteger(anoRef) || anoRef < 2000 || anoRef > 2099) {
      return { ok: false, error: `Ano de referência inválido: ${input.ano_referencia}. Use um ano entre 2000 e 2099.` };
    }

    const valor = Number(input.valor_total);
    if (isNaN(valor) || valor <= 0) {
      return { ok: false, error: `Valor total inválido: ${input.valor_total}. Deve ser maior que zero.` };
    }

    const statusValidos = ["Pendente", "Pago", "Vencido"];
    const status = input.status_pagamento ? String(input.status_pagamento) : "Pendente";
    if (!statusValidos.includes(status)) {
      return { ok: false, error: `Status inválido: "${status}". Use: ${statusValidos.join(", ")}.` };
    }

    const insert: Record<string, unknown> = {
      id: crypto.randomUUID(),
      tenant_id: tenantId,
      veiculo_id: v.id,
      ano_referencia: anoRef,
      valor_total: valor,
      data_vencimento: String(input.data_vencimento),
      status_pagamento: status,
    };
    if (input.data_pagamento) insert.data_pagamento = String(input.data_pagamento);
    if (input.observacoes) insert.observacoes = String(input.observacoes);

    const { data, error } = await supabase
      .from("ipva")
      .insert(insert)
      .select("id, veiculo_id, ano_referencia, valor_total, status_pagamento")
      .single();

    if (error) return { ok: false, error: `Erro ao registrar IPVA: ${error.message}` };

    return {
      ok: true,
      data,
      display: `✅ IPVA ${anoRef} registrado para ${v.placa} — R$ ${valor.toFixed(2)} (${status})`,
    };
  },
};
