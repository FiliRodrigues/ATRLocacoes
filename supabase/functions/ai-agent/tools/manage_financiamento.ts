import { AtrTool } from "../types.ts";

// ================================================================
// Criar financiamento
// ================================================================
export const createFinanciamento: AtrTool = {
  name: "create_financiamento",
  category: "write",
  description:
    "Registra um novo financiamento de veículo. " +
    "Use para: 'cria financiamento do ABC-1234 no Bradesco 48x R$2.800', " +
    "'registra financiamento da van XYZ no Santander'.",
  input_schema: {
    type: "object",
    properties: {
      veiculo_placa: { type: "string", description: "Placa do veículo (ex: ABC-1234)." },
      banco_financeira: { type: "string", description: "Banco/financeira (ex: 'Bradesco', 'Santander', 'BV')." },
      valor_total_veiculo: { type: "number", description: "Valor total do veículo em R$." },
      quantidade_parcelas: { type: "integer", description: "Número de parcelas." },
      valor_parcela: { type: "number", description: "Valor de cada parcela em R$." },
      valor_entrada: { type: "number", description: "Valor de entrada em R$ (opcional)." },
      valor_financiado: { type: "number", description: "Valor financiado em R$ (opcional — calculado se omitido)." },
      taxa_juros_mensal: { type: "number", description: "Taxa de juros mensal em decimal (ex: 0.0139 = 1,39%). Default: 0.0139." },
      situacao: { type: "string", description: "Situação: 'Ativo', 'Quitado', 'Inadimplente'. Default: 'Ativo'." },
      previsao_quitacao: { type: "string", description: "Mês/ano previsto para quitação (ex: '12/2028')." },
    },
    required: ["veiculo_placa", "banco_financeira", "valor_total_veiculo", "quantidade_parcelas", "valor_parcela"],
  },

  preview: async (input, ctx) => {
    const placa = String(input.veiculo_placa).toUpperCase().trim();
    const parcelas = `${input.quantidade_parcelas}x R$ ${Number(input.valor_parcela).toFixed(2)}`;
    return `Registrar financiamento — ${placa} — ${input.banco_financeira} — ${parcelas}`;
  },

  handler: async (input, ctx) => {
    const supabase = ctx.supabase as Record<string, unknown>;
    const tenantId = ctx.tenant_id as string;

    const placa = String(input.veiculo_placa).toUpperCase().trim();
    const { data: veiculo } = await (supabase as any)
      .from("veiculos")
      .select("id, placa")
      .eq("tenant_id", tenantId)
      .eq("placa", placa)
      .single();
    if (!veiculo) return { ok: false, error: `Veículo com placa ${placa} não encontrado.` };

    const valorTotal = Number(input.valor_total_veiculo);
    const qtdParcelas = Number(input.quantidade_parcelas);
    const valorParcela = Number(input.valor_parcela);

    if (valorTotal <= 0) return { ok: false, error: "valor_total_veiculo deve ser > 0." };
    if (!Number.isInteger(qtdParcelas) || qtdParcelas <= 0) return { ok: false, error: "quantidade_parcelas deve ser inteiro positivo." };
    if (valorParcela <= 0) return { ok: false, error: "valor_parcela deve ser > 0." };

    const valorEntrada = input.valor_entrada != null ? Number(input.valor_entrada) : 0;
    const valorFinanciado = input.valor_financiado != null
      ? Number(input.valor_financiado)
      : (valorTotal - valorEntrada);

    const validatedData: Record<string, unknown> = {
      veiculo_id: veiculo.id,
      banco_financeira: String(input.banco_financeira).trim(),
      valor_total_veiculo: valorTotal,
      quantidade_parcelas: qtdParcelas,
      valor_parcela: valorParcela,
      valor_entrada: valorEntrada,
      valor_financiado: valorFinanciado,
      valor_total_com_juros: qtdParcelas * valorParcela,
      valor_ja_pago: 0,
      taxa_juros_mensal: input.taxa_juros_mensal != null ? Number(input.taxa_juros_mensal) : 0.0139,
      situacao: input.situacao ? String(input.situacao).trim() : "Ativo",
    };

    if (input.previsao_quitacao) validatedData.previsao_quitacao = String(input.previsao_quitacao).trim();

    const display = (await createFinanciamento.preview!(input, ctx)) ?? "";
    return { ok: true, data: validatedData, display };
  },
};

// ================================================================
// Atualizar financiamento
// ================================================================
export const updateFinanciamento: AtrTool = {
  name: "update_financiamento",
  category: "write",
  description:
    "Atualiza dados de um financiamento (situação, valor já pago, previsão de quitação). " +
    "Use para: 'marca financiamento como quitado', 'atualiza valor já pago do financiamento', " +
    "'registra quitação antecipada'.",
  input_schema: {
    type: "object",
    properties: {
      financiamento_id: { type: "string", description: "ID (UUID) do financiamento." },
      situacao: { type: "string", description: "Nova situação: 'Ativo', 'Quitado', 'Inadimplente'." },
      valor_ja_pago: { type: "number", description: "Novo valor total já pago em R$." },
      previsao_quitacao: { type: "string", description: "Nova previsão de quitação (ex: '12/2028')." },
      banco_financeira: { type: "string", description: "Atualizar banco/financeira." },
      valor_parcela: { type: "number", description: "Novo valor de parcela (renegociação)." },
      taxa_juros_mensal: { type: "number", description: "Nova taxa de juros mensal." },
    },
    required: ["financiamento_id"],
  },

  preview: async (input, ctx) => {
    const supabase = ctx.supabase as Record<string, unknown>;
    const tenantId = ctx.tenant_id as string;
    const { data } = await (supabase as any)
      .from("financiamentos")
      .select("id, banco_financeira, situacao")
      .eq("tenant_id", tenantId)
      .eq("id", String(input.financiamento_id))
      .single();
    if (!data) return `Atualizar financiamento: ID ${input.financiamento_id} não encontrado.`;
    const novaSit = input.situacao ? ` → ${input.situacao}` : "";
    return `Atualizar financiamento ${data.banco_financeira}${novaSit} (ID ${input.financiamento_id})`;
  },

  handler: async (input, ctx) => {
    const supabase = ctx.supabase as Record<string, unknown>;
    const tenantId = ctx.tenant_id as string;
    const id = String(input.financiamento_id).trim();

    const { data } = await (supabase as any)
      .from("financiamentos")
      .select("id")
      .eq("tenant_id", tenantId)
      .eq("id", id)
      .single();
    if (!data) return { ok: false, error: "Financiamento não encontrado." };

    const updates: Record<string, unknown> = {};
    if (input.situacao !== undefined) updates.situacao = String(input.situacao).trim();
    if (input.valor_ja_pago !== undefined) updates.valor_ja_pago = Number(input.valor_ja_pago);
    if (input.previsao_quitacao !== undefined) updates.previsao_quitacao = String(input.previsao_quitacao).trim();
    if (input.banco_financeira !== undefined) updates.banco_financeira = String(input.banco_financeira).trim();
    if (input.valor_parcela !== undefined) updates.valor_parcela = Number(input.valor_parcela);
    if (input.taxa_juros_mensal !== undefined) updates.taxa_juros_mensal = Number(input.taxa_juros_mensal);

    if (Object.keys(updates).length === 0) return { ok: false, error: "Nenhum campo para atualizar." };

    const display = (await updateFinanciamento.preview!(input, ctx)) ?? "";
    return { ok: true, data: { financiamento_id: id, updates }, display };
  },
};
