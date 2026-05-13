import { AtrTool } from "../types.ts";

export const searchGlobal: AtrTool = {
  name: "search_global",
  category: "read",
  description:
    "Busca global em todas as entidades da ATR. " +
    "Encontra veículos, contratos, manutenções, despesas, motoristas, clientes, etc. " +
    "Use para perguntas como: 'tudo sobre ABC-1234', 'pesquisa contrato do XPTO', " +
    "'acha manutenção de freio', 'busca qualquer coisa sobre o cliente João'.",
  input_schema: {
    type: "object",
    properties: {
      query: { type: "string", description: "Termo de busca." },
      limit: { type: "integer", description: "Máximo de resultados por entidade (default 10, max 30)." },
    },
    required: ["query"],
  },

  handler: async (input, ctx) => {
    const supabase = ctx.supabase as Record<string, unknown>;
    const tenantId = ctx.tenant_id as string;
    const query = String(input.query || "").trim();
    const limit = Math.min(Number(input.limit) || 10, 30);

    if (!query) return { ok: false, error: "Termo de busca é obrigatório." };

    const results: Record<string, unknown> = {};
    const like = `%${query}%`;

    // 1. Veículos (placa, modelo, marca)
    const { data: veiculos } = await (supabase as any)
      .from("veiculos")
      .select("id, placa, marca, modelo, ano_fabricacao_modelo, situacao_operacional, km_atual")
      .eq("tenant_id", tenantId)
      .or(`placa.ilike.${like},modelo.ilike.${like},marca.ilike.${like}`)
      .limit(limit);
    if (veiculos) results.veiculos = veiculos;

    // 2. Contratos (número, cliente)
    const { data: contratos } = await (supabase as any)
      .from("contratos")
      .select("id, numero, cliente_nome, cliente_cnpj, veiculo_placa, status, data_inicio, data_fim, valor_mensal")
      .eq("tenant_id", tenantId)
      .or(`numero.ilike.${like},cliente_nome.ilike.${like},cliente_cnpj.ilike.${like}`)
      .limit(limit);
    if (contratos) results.contratos = contratos;

    // 3. Manutenções (tipo, descrição, fornecedor)
    const { data: manutencoes } = await (supabase as any)
      .from("manutencoes")
      .select("id, veiculo_placa, data, tipo, descricao, fornecedor, custo, status_pagamento")
      .eq("tenant_id", tenantId)
      .or(`tipo.ilike.${like},descricao.ilike.${like},fornecedor.ilike.${like}`)
      .order("data", { ascending: false })
      .limit(limit);
    if (manutencoes) results.manutencoes = manutencoes;

    // 4. Despesas (descrição, tipo, motorista)
    const { data: despesas } = await (supabase as any)
      .from("despesas")
      .select("id, veiculo_placa, motorista, data, tipo, descricao, valor, pago")
      .eq("tenant_id", tenantId)
      .or(`descricao.ilike.${like},tipo.ilike.${like},motorista.ilike.${like}`)
      .order("data", { ascending: false })
      .limit(limit);
    if (despesas) results.despesas = despesas;

    // 5. Ocorrências (descrição, tipo)
    const { data: ocorrencias } = await (supabase as any)
      .from("ocorrencias")
      .select("id, contrato_id, tipo, descricao, status, data_ocorrencia, valor_estimado")
      .eq("tenant_id", tenantId)
      .or(`descricao.ilike.${like},tipo.ilike.${like}`)
      .limit(limit);
    if (ocorrencias) results.ocorrencias = ocorrencias;

    // 6. Regras manutenção (título, tipo)
    const { data: regras } = await (supabase as any)
      .from("regras_manutencao")
      .select("id, titulo, tipo, veiculo_placa, intervalo_km, intervalo_dias, custo_estimado")
      .eq("tenant_id", tenantId)
      .or(`titulo.ilike.${like},tipo.ilike.${like}`)
      .limit(limit);
    if (regras) results.regras_manutencao = regras;

    const totalCount = Object.values(results).reduce((sum: number, arr: any) => sum + (arr?.length || 0), 0);

    return {
      ok: true,
      data: {
        results,
        total_count: totalCount,
        query,
      },
    };
  },
};
