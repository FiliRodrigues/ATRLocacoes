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

export const createMulta: AtrTool = {
  name: "create_multa",
  category: "write",
  description:
    "Registra uma nova multa de trânsito para um veículo. Use para: 'lança multa de R$ 300 no ABC-1234'. " +
    "Para atualizar multa existente (ex: marcar como paga), use update_multa.",
  input_schema: {
    type: "object",
    properties: {
      vehicle_identifier: {
        type: "string",
        description: "Placa ou UUID do veículo.",
      },
      ano_referencia: {
        type: "integer",
        description: "Ano de referência da multa (ex: 2025).",
      },
      mes: {
        type: "string",
        description: "Mês da multa (ex: 'Janeiro', '01', '1').",
      },
      valor: {
        type: "number",
        description: "Valor da multa em R$.",
      },
      descricao: {
        type: "string",
        description: "Descrição/motivo da multa (ex: 'Excesso de velocidade 50km/h').",
      },
      data_infracao: {
        type: "string",
        description: "Data da infração no formato YYYY-MM-DD.",
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
        description: "Data de pagamento YYYY-MM-DD (preencher somente se já paga).",
      },
    },
    required: ["vehicle_identifier", "ano_referencia", "mes", "valor"],
  },

  preview: async (input, ctx) => {
    const supabase = ctx.supabase as any;
    const tenantId = ctx.tenant_id as string;
    const v = await resolveVeiculoId(String(input.vehicle_identifier), supabase, tenantId);
    const placa = v ? v.placa : String(input.vehicle_identifier);
    return `Registrar multa ${input.mes}/${input.ano_referencia} — ${placa} — R$ ${Number(input.valor).toFixed(2)}`;
  },

  handler: async (input, ctx) => {
    const supabase = ctx.supabase as any;
    const tenantId = ctx.tenant_id as string;

    const v = await resolveVeiculoId(String(input.vehicle_identifier), supabase, tenantId);
    if (!v) return { ok: false, error: `Veículo não encontrado: "${input.vehicle_identifier}".` };

    const anoRef = Number(input.ano_referencia);
    if (!Number.isInteger(anoRef) || anoRef < 2000 || anoRef > 2099) {
      return { ok: false, error: `Ano de referência inválido: ${input.ano_referencia}.` };
    }

    const valor = Number(input.valor);
    if (isNaN(valor) || valor <= 0) {
      return { ok: false, error: `Valor da multa inválido: ${input.valor}. Deve ser maior que zero.` };
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
      mes: String(input.mes),
      valor,
      status_pagamento: status,
    };
    if (input.descricao) insert.descricao = String(input.descricao);
    if (input.data_infracao) insert.data_infracao = String(input.data_infracao);
    if (input.data_vencimento) insert.data_vencimento = String(input.data_vencimento);
    if (input.data_pagamento) insert.data_pagamento = String(input.data_pagamento);

    const { data, error } = await supabase
      .from("multas")
      .insert(insert)
      .select("id, veiculo_id, ano_referencia, mes, valor, status_pagamento")
      .single();

    if (error) return { ok: false, error: `Erro ao registrar multa: ${error.message}` };

    return {
      ok: true,
      data,
      display: `✅ Multa ${input.mes}/${anoRef} registrada para ${v.placa} — R$ ${valor.toFixed(2)} (${status})`,
    };
  },
};
