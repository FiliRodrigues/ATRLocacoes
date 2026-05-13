import { AtrTool } from "../types.ts";

export const updateExpense: AtrTool = {
  name: "update_expense",
  category: "write",
  description:
    "Atualiza uma despesa existente. Use para: 'marca despesa ABC como paga', " +
    "'altera valor da despesa XYZ para R$ 500', 'atualiza motorista da despesa'. " +
    "Todos os campos são opcionais — apenas os informados serão alterados.",
  input_schema: {
    type: "object",
    properties: {
      expense_id: { type: "string", description: "ID da despesa a ser atualizada." },
      tipo: { type: "string", description: "Nova categoria: 'combustível', 'multa', 'IPVA', 'seguro', 'outros'." },
      descricao: { type: "string", description: "Nova descrição." },
      valor: { type: "number", description: "Novo valor em reais." },
      data: { type: "string", description: "Nova data YYYY-MM-DD." },
      pago: { type: "boolean", description: "Marcar como paga (true) ou não paga (false)." },
      motorista: { type: "string", description: "Nome do motorista." },
      odometro: { type: "integer", description: "Odômetro/km." },
      litros: { type: "number", description: "Litros (para combustível)." },
      nf: { type: "string", description: "Número da nota fiscal." },
      veiculo_placa: { type: "string", description: "Nova placa do veículo vinculado." },
    },
    required: ["expense_id"],
  },

  preview: async (input, ctx) => {
    const supabase = ctx.supabase as Record<string, unknown>;
    const tenantId = ctx.tenant_id as string;
    const { data } = await (supabase as any).from("despesas")
      .select("id, tipo, valor, veiculo_placa")
      .eq("tenant_id", tenantId).eq("id", String(input.expense_id)).single();
    if (!data) return `Atualizar despesa: ID ${input.expense_id} não encontrado.`;
    const mudancas: string[] = [];
    for (const [k, v] of Object.entries(input)) {
      if (k !== "expense_id" && v !== undefined && v !== null) mudancas.push(`${k}=${v}`);
    }
    return `Atualizar despesa ${data.tipo} R$ ${data.valor} (${data.veiculo_placa || "geral"}): ${mudancas.join(", ") || "sem alterações"}`;
  },

  handler: async (input, ctx) => {
    const supabase = ctx.supabase as Record<string, unknown>;
    const tenantId = ctx.tenant_id as string;
    const id = String(input.expense_id).trim();
    if (!id) return { ok: false, error: "ID da despesa é obrigatório." };

    const { data } = await (supabase as any).from("despesas")
      .select("id, tipo, valor, veiculo_placa")
      .eq("tenant_id", tenantId).eq("id", id).single();
    if (!data) return { ok: false, error: `Despesa ${id} não encontrada.` };

    const updates: Record<string, unknown> = {};
    if (input.tipo !== undefined && input.tipo !== null) updates.tipo = String(input.tipo).trim();
    if (input.descricao !== undefined && input.descricao !== null) updates.descricao = String(input.descricao).trim();
    if (input.valor !== undefined && input.valor !== null) updates.valor = Number(input.valor);
    if (input.data !== undefined && input.data !== null) updates.data = String(input.data).trim();
    if (input.pago !== undefined && input.pago !== null) updates.pago = Boolean(input.pago);
    if (input.motorista !== undefined && input.motorista !== null) updates.motorista = String(input.motorista).trim();
    if (input.odometro !== undefined && input.odometro !== null) updates.odometro = Number(input.odometro);
    if (input.litros !== undefined && input.litros !== null) updates.litros = Number(input.litros);
    if (input.nf !== undefined && input.nf !== null) updates.nf = String(input.nf).trim();
    if (input.veiculo_placa !== undefined && input.veiculo_placa !== null) updates.veiculo_placa = String(input.veiculo_placa).trim();

    if (Object.keys(updates).length === 0) return { ok: false, error: "Nenhum campo para atualizar informado." };
    if (updates.data && !/^\d{4}-\d{2}-\d{2}$/.test(String(updates.data))) {
      return { ok: false, error: "Data inválida. Use YYYY-MM-DD." };
    }

    const display = (await updateExpense.preview!(input, ctx)) ?? "";
    return { ok: true, data: { expense_id: id, updates }, display };
  },
};
