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
    const queryNormalized = query.replace(/[\s\-.]/g, "").toUpperCase();
    const normalizedLike = `%${queryNormalized}%`;
    const extendedLimit = Math.min(limit, 5);
    const isYearQuery = /^\d{4}$/.test(query);
    const yearQuery = isYearQuery ? Number(query) : null;

    const uniqueById = <T extends { id: string }>(rows: T[]): T[] => {
      const map = new Map<string, T>();
      for (const row of rows) map.set(row.id, row);
      return Array.from(map.values());
    };

    const placaByVeiculoId = new Map<string, string>();
    const { data: veiculosMatchByPlaca } = await (supabase as any)
      .from("veiculos")
      .select("id, placa")
      .eq("tenant_id", tenantId)
      .or(`placa.ilike.${like},placa.ilike.${normalizedLike}`)
      .limit(50);

    const matchedVehicleIds = (veiculosMatchByPlaca || []).map((v: any) => v.id as string);
    for (const v of veiculosMatchByPlaca || []) {
      placaByVeiculoId.set(v.id, v.placa);
    }

    const attachVehiclePlate = async <T extends { veiculo_id: string | null }>(rows: T[]) => {
      const missingIds = Array.from(new Set(
        rows
          .map((row) => row.veiculo_id)
          .filter((id): id is string => Boolean(id) && !placaByVeiculoId.has(id)),
      ));

      if (missingIds.length > 0) {
        const { data: missingVehicles } = await (supabase as any)
          .from("veiculos")
          .select("id, placa")
          .eq("tenant_id", tenantId)
          .in("id", missingIds);

        for (const v of missingVehicles || []) {
          placaByVeiculoId.set(v.id, v.placa);
        }
      }

      return rows.map((row) => ({
        ...row,
        veiculo_placa: row.veiculo_id ? placaByVeiculoId.get(row.veiculo_id) || null : null,
      }));
    };

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

    // 7. Abastecimentos (placa, posto, tipo)
    const { data: abastecimentos } = await (supabase as any)
      .from("abastecimentos")
      .select("id, veiculo_placa, data, litros, valor_total, km_odometro, tipo, posto, registrado_por")
      .eq("tenant_id", tenantId)
      .or(`veiculo_placa.ilike.${like},veiculo_placa.ilike.${normalizedLike},posto.ilike.${like},tipo.ilike.${like}`)
      .order("data", { ascending: false })
      .limit(extendedLimit);
    if (abastecimentos) results.abastecimentos = abastecimentos;

    // 8. IPVA (placa via veiculo_id, ano_referencia, status_pagamento)
    const ipvaRows: any[] = [];
    if (matchedVehicleIds.length > 0) {
      const { data } = await (supabase as any)
        .from("ipva")
        .select("id, veiculo_id, ano_referencia, valor_total, data_vencimento, data_pagamento, status_pagamento, observacoes")
        .eq("tenant_id", tenantId)
        .in("veiculo_id", matchedVehicleIds)
        .order("ano_referencia", { ascending: false })
        .limit(extendedLimit);
      if (data) ipvaRows.push(...data);
    }
    if (isYearQuery && yearQuery !== null) {
      const { data } = await (supabase as any)
        .from("ipva")
        .select("id, veiculo_id, ano_referencia, valor_total, data_vencimento, data_pagamento, status_pagamento, observacoes")
        .eq("tenant_id", tenantId)
        .eq("ano_referencia", yearQuery)
        .order("ano_referencia", { ascending: false })
        .limit(extendedLimit);
      if (data) ipvaRows.push(...data);
    }
    const { data: ipvaByStatus } = await (supabase as any)
      .from("ipva")
      .select("id, veiculo_id, ano_referencia, valor_total, data_vencimento, data_pagamento, status_pagamento, observacoes")
      .eq("tenant_id", tenantId)
      .ilike("status_pagamento", like)
      .order("ano_referencia", { ascending: false })
      .limit(extendedLimit);
    if (ipvaByStatus) ipvaRows.push(...ipvaByStatus);
    const ipvaMerged = uniqueById(ipvaRows).slice(0, extendedLimit);
    if (ipvaMerged.length > 0) results.ipva = await attachVehiclePlate(ipvaMerged);

    // 9. Licenciamento (placa via veiculo_id, ano_referencia, status_pagamento)
    const licenciamentoRows: any[] = [];
    if (matchedVehicleIds.length > 0) {
      const { data } = await (supabase as any)
        .from("licenciamento")
        .select("id, veiculo_id, ano_referencia, mes_vencimento, valor_total, data_vencimento, data_pagamento, status_pagamento, observacoes")
        .eq("tenant_id", tenantId)
        .in("veiculo_id", matchedVehicleIds)
        .order("ano_referencia", { ascending: false })
        .limit(extendedLimit);
      if (data) licenciamentoRows.push(...data);
    }
    if (isYearQuery && yearQuery !== null) {
      const { data } = await (supabase as any)
        .from("licenciamento")
        .select("id, veiculo_id, ano_referencia, mes_vencimento, valor_total, data_vencimento, data_pagamento, status_pagamento, observacoes")
        .eq("tenant_id", tenantId)
        .eq("ano_referencia", yearQuery)
        .order("ano_referencia", { ascending: false })
        .limit(extendedLimit);
      if (data) licenciamentoRows.push(...data);
    }
    const { data: licenciamentoByStatus } = await (supabase as any)
      .from("licenciamento")
      .select("id, veiculo_id, ano_referencia, mes_vencimento, valor_total, data_vencimento, data_pagamento, status_pagamento, observacoes")
      .eq("tenant_id", tenantId)
      .ilike("status_pagamento", like)
      .order("ano_referencia", { ascending: false })
      .limit(extendedLimit);
    if (licenciamentoByStatus) licenciamentoRows.push(...licenciamentoByStatus);
    const licenciamentoMerged = uniqueById(licenciamentoRows).slice(0, extendedLimit);
    if (licenciamentoMerged.length > 0) results.licenciamento = await attachVehiclePlate(licenciamentoMerged);

    // 10. Multas (placa via veiculo_id, mes, descricao, status_pagamento)
    const multasRows: any[] = [];
    if (matchedVehicleIds.length > 0) {
      const { data } = await (supabase as any)
        .from("multas")
        .select("id, veiculo_id, ano_referencia, mes, valor, descricao, status_pagamento, data_infracao, data_vencimento, data_pagamento")
        .eq("tenant_id", tenantId)
        .in("veiculo_id", matchedVehicleIds)
        .order("data_infracao", { ascending: false })
        .limit(extendedLimit);
      if (data) multasRows.push(...data);
    }
    if (isYearQuery && yearQuery !== null) {
      const { data } = await (supabase as any)
        .from("multas")
        .select("id, veiculo_id, ano_referencia, mes, valor, descricao, status_pagamento, data_infracao, data_vencimento, data_pagamento")
        .eq("tenant_id", tenantId)
        .eq("ano_referencia", yearQuery)
        .order("data_infracao", { ascending: false })
        .limit(extendedLimit);
      if (data) multasRows.push(...data);
    }
    const { data: multasByText } = await (supabase as any)
      .from("multas")
      .select("id, veiculo_id, ano_referencia, mes, valor, descricao, status_pagamento, data_infracao, data_vencimento, data_pagamento")
      .eq("tenant_id", tenantId)
      .or(`mes.ilike.${like},descricao.ilike.${like},status_pagamento.ilike.${like}`)
      .order("data_infracao", { ascending: false })
      .limit(extendedLimit);
    if (multasByText) multasRows.push(...multasByText);
    const multasMerged = uniqueById(multasRows).slice(0, extendedLimit);
    if (multasMerged.length > 0) results.multas = await attachVehiclePlate(multasMerged);

    // 11. Seguros (placa via veiculo_id, empresa, numero_apolice, status_pagamento)
    const segurosRows: any[] = [];
    if (matchedVehicleIds.length > 0) {
      const { data } = await (supabase as any)
        .from("seguros")
        .select("id, veiculo_id, ano_referencia, empresa, numero_apolice, valor_apolice, num_parcelas, data_inicio, data_renovacao, valor_total_pago, status_pagamento, observacoes")
        .eq("tenant_id", tenantId)
        .in("veiculo_id", matchedVehicleIds)
        .order("ano_referencia", { ascending: false })
        .limit(extendedLimit);
      if (data) segurosRows.push(...data);
    }
    if (isYearQuery && yearQuery !== null) {
      const { data } = await (supabase as any)
        .from("seguros")
        .select("id, veiculo_id, ano_referencia, empresa, numero_apolice, valor_apolice, num_parcelas, data_inicio, data_renovacao, valor_total_pago, status_pagamento, observacoes")
        .eq("tenant_id", tenantId)
        .eq("ano_referencia", yearQuery)
        .order("ano_referencia", { ascending: false })
        .limit(extendedLimit);
      if (data) segurosRows.push(...data);
    }
    const { data: segurosByText } = await (supabase as any)
      .from("seguros")
      .select("id, veiculo_id, ano_referencia, empresa, numero_apolice, valor_apolice, num_parcelas, data_inicio, data_renovacao, valor_total_pago, status_pagamento, observacoes")
      .eq("tenant_id", tenantId)
      .or(`empresa.ilike.${like},numero_apolice.ilike.${like},status_pagamento.ilike.${like}`)
      .order("ano_referencia", { ascending: false })
      .limit(extendedLimit);
    if (segurosByText) segurosRows.push(...segurosByText);
    const segurosMerged = uniqueById(segurosRows).slice(0, extendedLimit);
    if (segurosMerged.length > 0) results.seguros = await attachVehiclePlate(segurosMerged);

    // 12. Hodometros (último km por placa)
    const { data: hodometrosRaw } = await (supabase as any)
      .from("hodometros")
      .select("id, veiculo_placa, km, registrado_por, created_at")
      .eq("tenant_id", tenantId)
      .or(`veiculo_placa.ilike.${like},veiculo_placa.ilike.${normalizedLike}`)
      .order("created_at", { ascending: false })
      .limit(extendedLimit * 5);

    const latestByPlaca = new Map<string, any>();
    for (const row of hodometrosRaw || []) {
      const placa = String(row.veiculo_placa || "");
      if (!placa || latestByPlaca.has(placa)) continue;
      latestByPlaca.set(placa, row);
      if (latestByPlaca.size >= extendedLimit) break;
    }
    const hodometros = Array.from(latestByPlaca.values());
    if (hodometros.length > 0) results.hodometros = hodometros;

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
